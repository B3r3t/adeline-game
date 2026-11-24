extends Node2D
## Adeline's little sister, who rides her pony about near home. Nobody plays her: she trots
## up and down the meadow, stops for a rest now and then, and calls hello when Adeline is near.
##
## She and her pony have drawings of their own: a five-year-old with a big head and short
## legs, and a round, shaggy pony. Neither is a bigger character made small.

const RigScript := preload("res://scripts/rig.gd")
const Moves := preload("res://scripts/moves.gd")
const HorseScript := preload("res://scripts/horse.gd")

const PONY_SIZE := 1.0
const GIRL_SIZE := 1.0
const LEFT := 330.0  # she stays between the house and the signpost
const RIGHT := 1660.0
const TROT := 210.0

var game = null
var pony = null
var girl = null
var who := { "position": Vector2.ZERO, "velocity": Vector2.ZERO, "air": false, "pitch": 0.0, "facing": 1 }
var x := 1250.0
var facing := -1
var speed := 0.0
var goal := 700.0
var rest := 1.5  # seconds left of standing still
var hello := 6.0  # seconds until she may call out again
var hop := 0.0
var clock := 0.0
var mode := "roam"  # roam (her own wandering), follow (Adeline), stay (on a spot) or charge
var spot := 0.0  # where to stay, or where a charge ends
var charging := false  # true while a charge is under way

# Things the sisters do together.
const RACE_LENGTH := 820.0
const RIBBONS := [["yellow", 0.0], ["pink", 0.78], ["blue", 0.46], ["green", 0.19], ["red", 0.86], ["purple", 0.62]]
# Turns the yellow of her hair ribbon another colour and leaves her hair alone.
const RIBBON_SHADER := "
shader_type canvas_item;
uniform float shift = 0.0;
vec3 to_hsv(vec3 c) {
	vec4 k = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, k.wz), vec4(c.gb, k.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}
vec3 to_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 h = to_hsv(c.rgb);
	float yellow = smoothstep(0.09, 0.12, h.x) * (1.0 - smoothstep(0.18, 0.21, h.x)) * smoothstep(0.45, 0.6, h.y) * smoothstep(0.5, 0.7, h.z);
	h.x = fract(h.x + shift * yellow);
	c.rgb = mix(c.rgb, to_rgb(h), yellow);
	COLOR = c;
}
"
var activity := ""  # count, race, cheer, regroup or hair; empty when she is just being herself
var on_foot := false
var pony_x := 0.0
var pony_facing := 1
var pony_speed := 0.0
var walk := 0.0
var timer := 0.0
var shown := 0
var race_dir := 1
var race_from := 0.0
var race_to := 0.0
var race_pace := 270.0
var ribbon := 0
var ribbon_look: ShaderMaterial = null


func _ready() -> void:
	pony = Node2D.new()
	pony.set_script(HorseScript)
	pony.game = game
	pony.wild = true
	pony.subject = who
	pony.art = "res://art/pony"
	pony.seat_at = Vector2(-10.0, -29.0)  # just behind her mane
	pony.bit_at = Vector2(171.0, 74.0)  # the ring of her halter
	pony.pommel_at = Vector2(96.0, 72.0)
	pony.hands_at = Vector2(13.0, -11.0)
	pony.step_rate = 0.056
	pony.hoof_pitch = 1.3
	add_child(pony)
	pony.state = "mounted"

	girl = Node2D.new()
	girl.set_script(RigScript)
	add_child(girl)
	girl.build("res://art/sister")
	var look := Shader.new()
	look.code = RIBBON_SHADER
	ribbon_look = ShaderMaterial.new()
	ribbon_look.shader = look
	girl.info["ponytail"]["sprite"].material = ribbon_look
	set_ribbon(int(game.data.get("ribbon", 0)))


func _physics_process(delta: float) -> void:
	clock += delta
	hello = maxf(hello - delta, 0.0)
	hop = maxf(hop - delta, 0.0)
	if activity != "":
		_play(delta)
		return
	var want := 0.0
	var quick := 420.0
	if mode == "follow":
		# Keeps a little way behind Adeline, and hurries when she gets far ahead.
		var gap: float = game.player.position.x - x
		if absf(gap) > 150.0:
			facing = 1 if gap > 0.0 else -1
			want = clampf((absf(gap) - 110.0) * 3.0, 120.0, 640.0)
			quick = 900.0
		elif speed < 5.0:
			facing = 1 if gap > 0.0 else -1
	elif mode == "stay" or mode == "charge":
		var gap := spot - x
		if absf(gap) > 8.0:
			facing = 1 if gap > 0.0 else -1
			want = 560.0 if mode == "charge" else minf(300.0, absf(gap) * 4.0 + 60.0)
			quick = 1400.0 if mode == "charge" else 900.0
		else:
			quick = 2400.0
			if charging:
				charging = false
				mode = "stay"
	else:
		if rest > 0.0:
			rest -= delta
			if rest <= 0.0:
				# Off again, to somewhere a fair way from here.
				goal = randf_range(LEFT, RIGHT)
				if absf(goal - x) < 320.0:
					goal = LEFT if x > (LEFT + RIGHT) / 2.0 else RIGHT
				if game.mode == "play" and absf(game.player.position.x - x) < 700.0:
					game.sound.shout("sister", "sister_whee", 0.4)
		elif absf(goal - x) < 12.0:
			rest = randf_range(2.0, 5.0)
		else:
			facing = 1 if goal > x else -1
			want = TROT
	speed = move_toward(speed, want, quick * delta)
	x += facing * speed * delta

	# A hello for Adeline when she comes close.
	if mode == "roam" and game.mode == "play" and hello <= 0.0 and absf(game.player.position.x - x) < 190.0 and not game.dialog.active:
		hello = 28.0
		hop = 0.6
		game.sound.shout("sister", "sister_hello", 1.0, true)

	_show(delta)


## Puts her and her pony where they are, riding or on foot.
func _show(delta: float) -> void:
	var lift := -absf(sin(hop * 10.5)) * 10.0 if hop > 0.0 else 0.0
	if not on_foot:
		pony_x = x
		pony_facing = facing
		pony_speed = speed
	who["position"] = Vector2(pony_x, game.GROUND_Y + (0.0 if on_foot else lift))
	who["velocity"] = Vector2(pony_facing * pony_speed, 0.0)
	who["facing"] = pony_facing
	pony.carry(delta)
	# On the pony her far leg is out of sight on the other side.
	for part in ["leg_far_upper", "leg_far_lower"]:
		girl.info[part]["sprite"].visible = on_foot
	var pose: Dictionary
	if on_foot:
		# Short legs take quick little steps.
		walk += speed * delta * 0.087
		pose = Moves.girl_run(walk, clampf(speed / 280.0, 0.0, 1.0)) if speed > 15.0 else Moves.girl_idle(clock)
		girl.position = Vector2(x, game.GROUND_Y + lift)
		girl.root_offset = Vector2(0.0, float(pose["_lift"]))
	else:
		var seat: Vector2 = pony.seat()
		pose = Moves.girl_ride(clock, clampf(speed / TROT, 0.0, 1.0), pony.stride)
		girl.position = Vector2(x + seat.x * facing, game.GROUND_Y + lift + seat.y)
		girl.root_offset = -girl.rest_pos("torso") + Vector2(0.0, float(pose["_lift"]))
	if hop > 0.0:
		pose["arm_upper"] = -105.0 + sin(clock * 16.0) * 10.0  # an arm up, waving
		pose["arm_lower"] = -20.0 + sin(clock * 16.0 + 1.0) * 14.0
	pose.erase("_lift")
	girl.scale = Vector2(facing, 1.0)
	girl.pose = pose
	girl.apply()
	queue_redraw()


# --- Things the sisters do together -----------------------------------------

## True while Adeline should stand still and watch: the countdown, or having hair done.
func busy() -> bool:
	return activity == "count" or activity == "hair"


## A race on foot. She hops off her pony, they line up, and it is first past the flag.
func start_race() -> void:
	var dir := 1 if x + RACE_LENGTH <= RIGHT + 40.0 else -1
	race_dir = dir
	race_from = x
	race_to = x + dir * RACE_LENGTH
	race_pace = randf_range(258.0, 284.0)  # Adeline runs at 300, so it is close but winnable
	on_foot = true
	pony_x = x
	pony_speed = 0.0
	facing = dir
	speed = 0.0
	timer = 3.3
	shown = 4
	activity = "count"
	var p = game.player
	p.position.x = x - dir * 40.0
	p.velocity = Vector2.ZERO
	p.facing = dir
	p.reset_physics_interpolation()
	game.sound.shout("sister", "sister_race", 1.0, true)


## Adeline does her hair: a brush, some sparkles, and a ribbon in the next colour.
func do_hair() -> void:
	activity = "hair"
	timer = 2.4
	shown = 0
	speed = 0.0
	var p = game.player
	p.velocity = Vector2.ZERO
	p.position.x = x - facing * 46.0  # behind her, where the ponytail is
	p.facing = facing
	p.reset_physics_interpolation()


func set_ribbon(n: int) -> void:
	ribbon = posmod(n, RIBBONS.size())
	ribbon_look.set_shader_parameter("shift", float(RIBBONS[ribbon][1]))


func _play(delta: float) -> void:
	var p = game.player
	match activity:
		"count":
			timer -= delta
			var n := int(ceil(timer))
			if n != shown and n >= 1 and n <= 3:
				shown = n
				game.toast_text = str(n)
				game.toast_time = 0.95
				game.sound.play("pop", -6.0, 0.0, 0.8)
			if timer <= 0.0:
				activity = "race"
				game.toast_text = "GO!"
				game.toast_time = 1.0
				game.sound.play("chime", -4.0)
		"race":
			# A five-year-old runs in bursts.
			speed = move_toward(speed, race_pace * (0.94 + 0.08 * sin(clock * 3.1)), 900.0 * delta)
			x += race_dir * speed * delta
			var hers := (x - race_from) * race_dir
			var yours: float = (p.position.x - race_from) * race_dir
			if hers >= RACE_LENGTH or yours >= RACE_LENGTH:
				if yours >= hers:
					game.toast("You won the race!")
					game.sound.play("fanfare", -6.0, 0.0)
					game.sound.shout("adeline", "woohoo", 1.0, true)
				else:
					game.toast("Your sister won! She is fast.")
					game.sound.shout("sister", "sister_whee", 1.0, true)
				hop = 0.9
				timer = 1.6
				activity = "cheer"
		"cheer":
			speed = move_toward(speed, 0.0, 700.0 * delta)
			x += race_dir * speed * delta
			timer -= delta
			if timer <= 0.0:
				activity = "regroup"
		"regroup":
			# Her pony trots over to fetch her.
			speed = 0.0
			var gap := x - pony_x
			pony_facing = 1 if gap > 0.0 else -1
			pony_speed = 270.0
			pony_x += pony_facing * pony_speed * delta
			if absf(gap) < 16.0:
				on_foot = false
				facing = pony_facing
				activity = ""
		"hair":
			timer -= delta
			var strokes := int((2.4 - timer) / 0.55)
			if strokes > shown and strokes <= 3:
				shown = strokes
				game.sound.play("brush", -5.0, 0.1)
			if timer <= 0.0:
				set_ribbon(ribbon + 1)
				game.data["ribbon"] = ribbon
				game._save()
				game.toast("A %s ribbon! She loves it." % RIBBONS[ribbon][0])
				game.sound.play("chime", -5.0)
				game.sound.shout("sister", "sister_love", 1.0, true)
				hop = 0.8
				activity = ""
	_show(delta)


func _draw() -> void:
	var g: float = game.GROUND_Y
	if activity == "count" or activity == "race" or activity == "cheer":
		# The finish: a pole with a chequered flag.
		draw_line(Vector2(race_to, g), Vector2(race_to, g - 150.0), Color(0.3, 0.2, 0.12), 6.0)
		for row in 3:
			for col in 4:
				var white := (row + col) % 2 == 0
				draw_rect(Rect2(race_to + 3.0 + col * 14.0, g - 150.0 + row * 14.0, 14.0, 14.0), Color.WHITE if white else Color(0.1, 0.1, 0.1))
		draw_line(Vector2(race_from, g + 2.0), Vector2(race_from, g - 6.0), Color(1.0, 1.0, 1.0, 0.8), 5.0)
	if activity == "hair":
		# Sparkles round her hair while it is brushed.
		var head := Vector2(x - facing * 14.0, g - (86.0 if not on_foot else 62.0))
		for i in 6:
			var a := clock * 3.0 + i * TAU / 6.0
			var at := head + Vector2(cos(a) * 26.0, sin(a * 1.3) * 18.0)
			var r := 3.0 + 2.0 * sin(clock * 9.0 + i)
			draw_line(at - Vector2(r, 0.0), at + Vector2(r, 0.0), Color(1.0, 0.95, 0.6), 2.0)
			draw_line(at - Vector2(0.0, r), at + Vector2(0.0, r), Color(1.0, 0.95, 0.6), 2.0)


## Comes along behind Adeline.
func follow() -> void:
	mode = "follow"
	charging = false


## Goes to a spot and waits there.
func stay_at(at: float) -> void:
	mode = "stay"
	spot = at
	charging = false


## Gallops flat out to a spot, through anything in the way.
func charge_to(at: float) -> void:
	mode = "charge"
	spot = at
	charging = true


## Back to wandering about near home.
func roam() -> void:
	mode = "roam"
	charging = false
	rest = 1.0
	goal = clampf(x, LEFT, RIGHT)


func put(at: float) -> void:
	x = at
	speed = 0.0
	pony.rig.moved = false
	girl.moved = false


## Back to how she starts: on her pony, wandering near home, wearing the saved ribbon.
func reset() -> void:
	activity = ""
	on_foot = false
	hop = 0.0
	set_ribbon(int(game.data.get("ribbon", 0)))
	roam()
