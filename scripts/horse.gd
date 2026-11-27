extends Node2D
## Spirit, Adeline's horse: dark brown with a black mane and tail.
## Spirit waits in the stable, comes when called, carries Adeline at a gallop,
## and stays back from goblin fights. Built from cutout art.

const RigScript := preload("res://scripts/rig.gd")
const Look := preload("res://scripts/look.gd")
const Moves := preload("res://scripts/moves.gd")
const Ui := preload("res://scripts/ui.gd")

const GALLOP := 620.0
const SEAT := Vector2(-31.0, -32.0)  # the dip of Spirit's back, measured from the body joint

var game = null
var font: Font
var state := "idle"  # idle, coming, retreat or mounted
var facing := 1
var target_x := 0.0
var speed := 0.0  # ground speed, drives the leg animation
var stride := 0.0
var clock := 0.0
var art := "res://art/spirit"  # which drawings to wear; the pony and the unicorn have their own
var kind := "spirit"  # spirit or unicorn
var title := "Spirit"  # her name, shown over her head
var rein_colors := [Color(0.13, 0.07, 0.04), Color(0.5, 0.27, 0.13)]  # the edge of the reins, and the leather
var wings := false  # true for a horse whose drawings include wings
var flying := false  # in the air on her wings
var wings_open := true  # which wing pictures are showing: spread, or folded against her sides
var unfold := 1.0  # seconds since her wings last opened or folded, for the way they sweep out
var flap := 9.0  # seconds since her last wingbeat
static var wing_data := {}  # drawings folder -> the pivots of its wing pictures
var seat_at := SEAT
var bit_at := BIT
var pommel_at := POMMEL
var hands_at := Vector2(21.0, -19.0)  # the rider's hands, measured from the seat
# Where her neck bends, as shares of her body picture: the middle of the bend, and where
# along her length it starts and ends. Everything in front of it (her head) nods as one.
var neck := { "strips": 12, "across": true, "at": Vector2(0.71, 0.45), "from": 0.63, "to": 0.82, "pose": "neck" }
var rider_art := ""  # drawings for a rider of her own (the other horses in a race have one)
var jockey = null
var hoof_pitch := 1.0  # small hooves sound lighter
var step_rate := 0.035  # how far through a stride each pixel of ground takes her; short legs step faster
var rig = null
var was_air := false
var land_time := 9.0  # seconds since she last landed from a jump
var rider = null  # a second copy of Adeline's rig that shows only her near leg
var saddle: Sprite2D = null
var subject = null  # whoever this horse carries; Adeline unless told otherwise
var wild := false  # a horse moved by something other than Adeline: a race, or her sister
var tack := true  # whether it wears a saddle and reins

# Recolours a horse's coat: how grey it goes, what colour it is washed with, how bright.
const COAT_SHADER := "
shader_type canvas_item;
uniform float grey = 0.0;
uniform vec3 wash = vec3(1.0);
uniform float gain = 1.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	float l = dot(c.rgb, vec3(0.3, 0.59, 0.11));
	c.rgb = clamp(mix(c.rgb, vec3(l), grey) * wash * gain, 0.0, 1.0);
	COLOR = c;
}
"
var reins: Array = []  # two lines: a dark edge and the leather on top

# Spots on Spirit's body picture, in its own pixels.
const BIT := Vector2(248.0, 72.0)  # the ring at the corner of her mouth
const POMMEL := Vector2(120.0, 96.0)  # the front of the saddle, where loose reins rest


func _ready() -> void:
	font = ThemeDB.fallback_font
	rig = Node2D.new()
	rig.set_script(RigScript)
	add_child(rig)
	rig.bends["body"] = neck
	rig.build(art)
	wings = rig.info.has("wing_near")
	if wings:
		rig.tint("wing_far", Color(0.8, 0.8, 0.9))
		wings_open = false
		set_wings(rig, art, false)
	# The far legs sit in shadow.
	for part in ["leg_front_far_upper", "leg_front_far_lower", "leg_hind_far_upper", "leg_hind_far_lower"]:
		rig.tint(part, Color(0.72, 0.72, 0.78))
	# The saddle is a layer the same size as the body picture, laid exactly over it,
	# under the near legs.
	var body_sprite = rig.info["body"]["sprite"]
	saddle = Sprite2D.new()
	if ResourceLoader.exists(art + "/saddle.png"):
		saddle.texture = load(art + "/saddle.png")
	saddle.centered = false
	saddle.offset = body_sprite.offset
	saddle.scale = body_sprite.scale
	rig.add_child(saddle)
	rig.move_child(saddle, body_sprite.get_index() + 1)
	if rider_art != "":
		Look.plain(rig, art)  # somebody else's horse wears nothing of Spirit's
	elif art.ends_with("spirit"):
		saddle.material = Look.blanket()  # the blanket's colour, from the shop
	# Borrow Adeline's leg art for the rider's near leg.
	rider = Node2D.new()
	rider.set_script(RigScript)
	rig.add_child(rider)
	rider.build("res://art/adeline")
	rider.show_only("leg_near")
	rider.visible = false
	if rider_art != "":
		jockey = Node2D.new()
		jockey.set_script(RigScript)
		add_child(jockey)
		jockey.build(rider_art)
		for part in ["leg_far_upper", "leg_far_lower"]:
			jockey.info[part]["sprite"].visible = false  # on the other side of the horse
	for style in [[5.0, rein_colors[0]], [2.4, rein_colors[1]]]:
		var line := Line2D.new()
		line.width = style[0]
		line.default_color = style[1]
		line.joint_mode = Line2D.LINE_JOINT_ROUND
		line.begin_cap_mode = Line2D.LINE_CAP_ROUND
		line.end_cap_mode = Line2D.LINE_CAP_ROUND
		rig.add_child(line)
		reins.append(line)


## Shows a winged horse's wings spread for flying, or folded against her sides. Works on any
## rig built from her drawings: the one outdoors and the one in the stable.
static func set_wings(on, folder: String, open: bool) -> void:
	if not wing_data.has(folder):
		var data = JSON.parse_string(FileAccess.get_file_as_string(folder + "/rig.json"))
		wing_data[folder] = data.get("wings", {})
	var pivots: Dictionary = wing_data[folder]
	var key := "spread" if open else "folded"
	var tex: Texture2D = load(folder + ("/wing_near.png" if open else "/wing_folded.png"))
	for part in ["wing_near", "wing_far"]:
		on.swap(part, tex, Vector2(pivots[key][0], pivots[key][1]), on.info[part]["pos"])


## One beat of her wings.
func beat() -> void:
	flap = 0.0
	game.sound.play("wing", -9.0, 0.08, 1.0, 0.1)


func place(x: float) -> void:
	position = Vector2(x, game.GROUND_Y)
	state = "idle"
	facing = 1
	speed = 0.0
	z_index = 0
	flying = false
	reset_physics_interpolation()


func come() -> void:
	if state != "mounted":
		state = "coming"


func retreat(x: float) -> void:
	target_x = x
	state = "retreat"
	z_index = 0


func set_mounted(on: bool) -> void:
	state = "mounted" if on else "idle"
	# Adeline is drawn in front of Spirit, sitting on the saddle. Her far leg, which would
	# be behind Spirit, is hidden while she rides.
	z_index = 0


func _who():
	return subject if subject != null else game.player


func set_coat(grey: float, wash: Color, gain: float) -> void:
	var shader := Shader.new()
	shader.code = COAT_SHADER
	var material := ShaderMaterial.new()
	material.shader = shader
	material.set_shader_parameter("grey", grey)
	material.set_shader_parameter("wash", Vector3(wash.r, wash.g, wash.b))
	material.set_shader_parameter("gain", gain)
	for part in rig.info:
		rig.info[part]["sprite"].material = material


func _physics_process(delta: float) -> void:
	if state == "mounted" or wild:
		return  # Adeline moves Spirit while she rides, so the two never drift apart
	clock += delta
	var p = game.player
	match state:
		"coming":
			var side := 1.0 if p.position.x >= position.x else -1.0
			if _move_to(p.position.x - 80.0 * side, GALLOP, delta):
				state = "idle"
				facing = int(side)
		"retreat":
			if _move_to(target_x, GALLOP * 0.7, delta):
				state = "idle"
		_:
			speed = move_toward(speed, 0.0, 2400.0 * delta)
	stride += speed * delta * step_rate
	_animate()
	queue_redraw()


## Called by Adeline each tick while she rides, right after she has moved.
func carry(delta: float) -> void:
	clock += delta
	var p = _who()
	position = p.position
	facing = p.facing
	speed = p.velocity.length()
	_hoofbeats(speed * delta * step_rate, not p.air)
	stride += speed * delta * step_rate
	_animate()
	queue_redraw()


## Hoofbeats land when the hooves do: four even beats at a walk, two at a trot, and at a
## gallop four quick ones and then a pause while she is off the ground. They are soft, and
## softer still for any horse that is not Adeline's own, fading out with distance.
func _hoofbeats(advance: float, on_ground: bool) -> void:
	if not on_ground or speed < 30.0 or not (game.mode == "play" or game.mode == "ride" or game.mode == "sky"):
		return
	var loud := -17.0 + 4.0 * clampf(speed / 600.0, 0.0, 1.0)
	if wild:
		var away := absf(position.x - float(game.player.position.x))
		if away > 650.0:
			return
		loud -= 6.0 + away / 55.0
	var before := fposmod(stride, TAU) / TAU
	var after := before + advance / TAU
	var beats: Array = Moves.horse_footfalls(speed)
	for i in beats.size():
		var beat: float = beats[i]
		if (before < beat and after >= beat) or (after >= 1.0 + beat):
			# Every other beat is lighter, and no two are quite alike, so it has a lilt and
			# not a drumming. Hooves that land together make one sound.
			var accent: float = [0.0, -3.5, -1.0, -3.5][i]
			game.sound.play("clop_far" if wild else "clop", loud + accent + randf_range(-2.0, 1.0), 0.08, hoof_pitch, 0.035)
			if speed > 250.0 and i % 2 == 0:
				game.puff(position + Vector2(-facing * randf_range(10.0, 50.0), 0.0), 0.7)


func _move_to(x: float, pace: float, delta: float) -> bool:
	position.y = game.GROUND_Y
	var dx := x - position.x
	if absf(dx) < 6.0:
		speed = 0.0
		return true
	facing = 1 if dx > 0.0 else -1
	position.x += minf(absf(dx), pace * delta) * facing
	speed = pace
	return false


func _animate() -> void:
	if rig.scale.x != facing:
		rig.scale.x = facing
		rig.reset_physics_interpolation()
	# Walk, trot or gallop, by how fast she is going.
	var pose: Dictionary = Moves.horse_ground(clock, stride, speed)
	var in_air: bool = state == "mounted" and _who().air
	flap += get_physics_process_delta_time()
	if wings:
		# Her wings open the moment she leaves the ground and fold when she lands.
		var aloft := in_air
		if aloft != wings_open:
			wings_open = aloft
			set_wings(rig, art, aloft)
			unfold = 0.0
		flying = aloft
		# They sweep out from her shoulders as they open, and tuck in as they fold, instead
		# of changing in a blink.
		unfold += get_physics_process_delta_time()
		var grown := Ui.pop(unfold / 0.24) if wings_open else lerpf(1.25, 1.0, Ui.ease(unfold / 0.2))
		for part in ["wing_near", "wing_far"]:
			rig.info[part]["sprite"].scale = Vector2(maxf(grown, 0.35), lerpf(0.55, 1.0, minf(grown, 1.0))) * rig.tex_scale
	if in_air and flying:
		pose = Moves.horse_fly(clock, _who().velocity.y)
	elif in_air:
		Moves.horse_air(pose, _who().velocity.y)
	if wings:
		if wings_open:
			# A beat is a quick sweep down and a slower lift. Between beats they are held high.
			var k := flap / 0.5
			var down := 0.0
			if k < 0.4:
				down = sin(k / 0.4 * PI * 0.5)
			elif k < 1.0:
				down = 0.5 + 0.5 * cos((k - 0.4) / 0.6 * PI)
			var hold := sin(clock * 6.5) * 3.0
			pose["wing_near"] = -6.0 - 104.0 * down + hold
			pose["wing_far"] = 4.0 - 96.0 * down + hold
			rig.sharp["wing_near"] = true  # the beat has its own timing
			rig.sharp["wing_far"] = true
		else:
			pose["wing_near"] = -10.0 + sin(clock * 1.3) * 1.2
			pose["wing_far"] = -8.0 + sin(clock * 1.3 + 0.6) * 1.2
	# Her legs give as she lands, then push her on.
	if was_air and not in_air:
		land_time = 0.0
	was_air = in_air
	land_time += get_physics_process_delta_time()
	if not in_air and land_time < 0.26:
		var give := sin(land_time / 0.26 * PI)
		for side in ["near", "far"]:
			pose["leg_front_%s_lower" % side] = float(pose["leg_front_%s_lower" % side]) + 20.0 * give
			pose["leg_hind_%s_lower" % side] = float(pose["leg_hind_%s_lower" % side]) - 14.0 * give
		pose["body"] = float(pose["body"]) + 3.5 * give
		pose["_lift"] = float(pose["_lift"]) + 3.0 * give
	var bounce: float = pose["_lift"]
	pose.erase("_lift")
	rig.pose = pose
	# On a hill Spirit tips to match it, turning about her hooves so all four stay on the ground.
	var tilt: float = _who().pitch * facing if state == "mounted" else 0.0
	var joint: Vector2 = rig.rest_pos("body")
	rig.root_angle = tilt
	rig.root_offset = Vector2(0.0, bounce) + joint.rotated(tilt) - joint
	rig.apply()
	# Adeline draws her own near leg now that she sits in front of Spirit.
	rider.visible = false
	rider.root_offset = seat() - rider.rest_pos("torso")
	rider.root_angle = tilt
	_tack()
	rider.pose = { "leg_near_upper": -52.0, "leg_near_lower": 62.0 }
	rider.apply()
	if jockey != null:
		# Her rider sits to the stride and folds forward over a jump, as Adeline does.
		var up := -float(_who().velocity.y) if in_air else 0.0
		var sits: Dictionary = Moves.girl_ride(clock, clampf(speed / 560.0, 0.0, 1.0), stride, up)
		var settle := float(sits["_lift"])
		sits.erase("_lift")
		jockey.pose = sits
		jockey.scale = Vector2(facing, 1.0)
		jockey.root_angle = rig.root_angle
		jockey.root_offset = seat() - jockey.rest_pos("torso") + Vector2(0.0, settle)
		jockey.apply()


## Where a spot on Spirit's body picture is right now, with her leaning and bobbing.
func _body_point(pixel: Vector2) -> Vector2:
	return rig.point("body", pixel)


## Keeps the saddle on her back and hangs the reins from the bit: to Adeline's hands
## while she rides, and looped back to the saddle when she does not.
func _tack() -> void:
	saddle.visible = tack
	for line in reins:
		line.visible = tack
	if not tack:
		return
	var body = rig.info["body"]["sprite"]
	saddle.position = body.position
	saddle.rotation = body.rotation
	var from := _body_point(bit_at)
	var to := _body_point(pommel_at)
	var sag := 9.0
	if state == "mounted":
		to = seat() + hands_at.rotated(rig.root_angle)
		sag = 5.0 + 3.0 * sin(stride * 2.0) * clampf(speed / 500.0, 0.0, 1.0)
	var middle := (from + to) / 2.0 + Vector2(0.0, sag)
	var points := PackedVector2Array()
	for i in 9:
		var k := i / 8.0
		points.append(from.lerp(middle, k).lerp(middle.lerp(to, k), k))
	for line in reins:
		line.points = points


## Where a rider sits, relative to Spirit's feet and facing right.
func seat() -> Vector2:
	return rig.rest_pos("body") + rig.root_offset + seat_at.rotated(rig.root_angle)


func _draw() -> void:
	if wild:
		return
	if state != "mounted" and game.mode == "play" and absf(game.player.position.x - position.x) < 260.0:
		var y := -170.0
		draw_string_outline(font, Vector2(-60.0, y), title, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 20, 5, Color(0.0, 0.0, 0.0, 0.5))
		draw_string(font, Vector2(-60.0, y), title, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 20, Color.WHITE)
