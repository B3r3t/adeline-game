extends Node2D
## Pony wash, with Adeline's little sister. Her pony has been rolling in the mud. First
## the mud is scrubbed off with a soapy sponge: rub a finger over each splat. Then her
## sister turns on the hose and the soap is rinsed away: hold a finger where the water
## should go. Last, the pony is rubbed dry with a towel until she shines all over, and
## gets a bow in her mane. Nothing can go wrong; quicker hands win more stars.

const Ui := preload("res://scripts/ui.gd")

const PONY := Vector2(690.0, 664.0)  # where her hooves stand
# Where the mud is, as shares of the pony's picture across and down, with which splat
# picture and how big.
const MUD := [
	[0.33, 0.52, "mud_2", 1.0], [0.47, 0.60, "mud_1", 1.0], [0.56, 0.47, "mud_1", 0.9], [0.41, 0.43, "mud_3", 1.1],
	[0.27, 0.68, "mud_3", 1.2], [0.60, 0.68, "mud_3", 1.1], [0.33, 0.87, "mud_3", 0.9], [0.63, 0.88, "mud_3", 0.9], [0.86, 0.42, "mud_3", 0.9],
]
# The places that have to be rubbed dry, the same way.
const DRY := [[0.30, 0.50], [0.42, 0.56], [0.54, 0.52], [0.62, 0.66], [0.30, 0.74], [0.80, 0.36], [0.47, 0.30], [0.12, 0.62]]
const STAGES := ["scrub", "rinse", "dry"]
const TOOL := { "scrub": "sponge", "rinse": "", "dry": "towel" }
const RUB := 520.0  # how much rubbing a splat takes, in pixels of finger travel
const FAST := 60.0  # seconds: under this is three stars
const STEADY := 95.0

var host = null
var game = null
var who := {}
var sis := {}
var pony: Sprite2D = null
var splats: Array = []  # each: [sprite, how much mud is left 0..1, size]
var foam: Array = []  # blobs of soap: [where, size, washing away 0..1 (or -1 while it sits), how long the water has been on it]
var shine: Array = []  # how dry each place is, 0..1
var tool: Sprite2D = null
var nozzle: Sprite2D = null
var pipe: Line2D = null
var bow: Sprite2D = null
var suds: Node2D = null
var stage := 0
var stage_time := 0.0
var clock := 0.0
var touching := false
var at := Vector2.ZERO  # where the finger is
var last := Vector2.ZERO
var noise := 0.0
var shiver := 9.0  # seconds since the pony last shook herself
var finished := -1.0
var wet := 0.0
var soap := 1  # how many blobs of soap there were to rinse off


func begin() -> void:
	pony = host.picture("res://art/mini/pony.png", PONY, 510.0, 500)
	pony.set_meta("size", pony.scale.x)
	for m in MUD:
		var node: Sprite2D = host.picture("res://art/mini/%s.png" % m[2], _on_pony(float(m[0]), float(m[1])), 10.0, 510)
		node.offset = Vector2.ZERO
		var k: float = float(host.picture_size(str(m[2]))) / node.texture.get_width() * float(m[3])
		node.scale = Vector2(k, k)
		node.rotation = randf_range(-0.5, 0.5)
		splats.append([node, 1.0, k])
	for d in DRY:
		shine.append(0.0)
	suds = Node2D.new()
	suds.z_index = 520
	suds.draw.connect(_draw_suds)
	host.stage.add_child(suds)
	# The girls are drawn large here: they stand nearer than the pony, and she is only a small pony.
	sis = host.girl("res://art/sister", Vector2(236.0, 668.0), 3.0)
	who = host.girl("res://art/adeline", Vector2(1140.0, 672.0), 3.0)
	who["facing"] = -1
	host.picture("res://art/mini/bucket.png", Vector2(1010.0, 672.0), 110.0, 660)
	# The hose runs from the tap on the post to the nozzle in her sister's hands.
	pipe = Line2D.new()
	pipe.width = 11.0
	pipe.default_color = Color(0.2, 0.62, 0.25)
	pipe.joint_mode = Line2D.LINE_JOINT_ROUND
	pipe.z_index = 640
	host.stage.add_child(pipe)
	nozzle = host.picture("res://art/mini/hose.png", Vector2.ZERO, 136.0, 700)
	nozzle.offset = Vector2(-nozzle.texture.get_width() * 0.2, 0.0)
	tool = host.picture("res://art/mini/sponge.png", Vector2.ZERO, 112.0, 900)
	tool.offset = Vector2.ZERO
	z_index = 3


func _on_pony(across: float, down: float) -> Vector2:
	var size := pony.texture.get_size() * float(pony.get_meta("size"))
	return PONY + Vector2((across - 0.5) * size.x, (down - 1.0) * size.y)


func how() -> String:
	return "Rub off the mud, rinse away the soap,\nthen rub the pony dry until she shines!"


func go() -> void:
	game.sound.shout("sister", "sister_muddy", 1.0, true)
	game.sound.shout("adeline", "bath_time", 1.0)


func now() -> String:
	return STAGES[mini(stage, STAGES.size() - 1)]


func press(where: Vector2) -> void:
	touching = true
	at = where
	last = where


func drag(where: Vector2) -> void:
	at = where


func release(_where: Vector2) -> void:
	touching = false


func _next_stage() -> void:
	stage += 1
	stage_time = 0.0
	shiver = 0.0
	game.sound.play("chime", -6.0, 0.0, 1.0 + stage * 0.12)
	game.sound.play("whinny", -12.0, 0.1, 1.25)
	if stage == 1:
		soap = maxi(foam.size(), 1)
		game.sound.shout("sister", "sister_splash", 1.0, true)
	if stage >= STAGES.size():
		# All done: the bow goes in her mane.
		finished = 0.0
		bow = host.picture("res://art/mini/bow.png", _on_pony(0.6, 0.2), 84.0, 530)
		bow.offset = Vector2.ZERO
		bow.set_meta("size", bow.scale.x)
		host.burst(_on_pony(0.6, 0.2), "star", 16)
		host.burst(_on_pony(0.45, 0.5), "heart", 6)
		sis["hop"] = 0.4
		who["hop"] = 0.4
		game.sound.shout("sister", "sister_sparkly", 1.0, true)
		game.sound.shout("adeline", "shiny", 1.0)


func frame(delta: float) -> void:
	clock += delta
	stage_time += delta
	shiver += delta
	noise -= delta
	var playing: bool = host.playing()
	if playing and finished < 0.0:
		wet += delta
	var moved := at.distance_to(last) if touching else 0.0
	last = at
	var stage_now := now()
	if playing and finished < 0.0 and touching:
		match stage_now:
			"scrub":
				_scrub(moved)
			"rinse":
				_rinse(delta)
			"dry":
				_dry(moved)
	# The pony: breathing, leaning into a good scrub, and shaking herself between jobs.
	var size := float(pony.get_meta("size"))
	var breath := 1.0 + sin(clock * 1.7) * 0.008
	var shake := sin(shiver * 44.0) * 0.03 * maxf(1.0 - shiver / 0.7, 0.0)
	pony.scale = Vector2(size, size * breath)
	pony.rotation = shake + (sin(clock * 9.0) * 0.006 if touching and moved > 0.0 else 0.0)
	if shiver < 0.7 and randf() < delta * 60.0:
		host.spark(_on_pony(randf_range(0.2, 0.8), randf_range(0.3, 0.7)), "drop", Color.WHITE, Vector2(randf_range(-220.0, 220.0), -160.0))
	for i in splats.size():
		var node: Sprite2D = splats[i][0]
		var left := float(splats[i][1])
		node.position = _on_pony(float(MUD[i][0]), float(MUD[i][1]))
		node.modulate.a = clampf(left * 1.4, 0.0, 1.0)
		var k := float(splats[i][2]) * lerpf(0.6, 1.0, left)
		node.scale = Vector2(k, k)
	# Foam being rinsed slides down and thins.
	for f in foam:
		if float(f[2]) >= 0.0:
			f[2] = float(f[2]) + delta * 2.2
			f[0] = f[0] + Vector2(0.0, 120.0 * delta)
	foam = foam.filter(func(f): return float(f[2]) < 1.0)
	_people(delta, stage_now, playing)
	_tool(stage_now, playing)
	suds.queue_redraw()
	queue_redraw()
	if finished >= 0.0:
		finished += delta
		var k := float(bow.get_meta("size")) * Ui.pop(finished / 0.35)
		bow.scale = Vector2(k, k)
		bow.position = _on_pony(0.6, 0.2)
		if randf() < delta * 12.0:
			host.spark(_on_pony(randf_range(0.1, 0.9), randf_range(0.2, 0.9)), "star")
		if finished > 2.4:
			host.finish(3 if wet < FAST else (2 if wet < STEADY else 1), "The shiniest pony on the island!")


func _scrub(moved: float) -> void:
	var busy := false
	for s in splats:
		if float(s[1]) > 0.0 and at.distance_to(s[0].position) < 78.0:
			s[1] = maxf(float(s[1]) - moved / RUB, 0.0)
			busy = true
			if float(s[1]) <= 0.0:
				# A good lather is left where the mud was, to be rinsed off after.
				for n in 5:
					foam.append([s[0].position + Vector2(randf_range(-34.0, 34.0), randf_range(-26.0, 26.0)), randf_range(15.0, 26.0), -1.0, 0.0])
				host.burst(s[0].position, "bubble", 8)
				host.word(s[0].position + Vector2(0.0, -30.0), "Clean!", Color(0.8, 1.0, 1.0))
				game.sound.play("pop", -8.0, 0.1, 1.3)
	if moved > 1.0 and _over_pony(at):
		# Soap is left wherever the sponge has been.
		if foam.size() < 150 and randf() < moved / 14.0:
			foam.append([at + Vector2(randf_range(-26.0, 26.0), randf_range(-22.0, 22.0)), randf_range(12.0, 24.0), -1.0, 0.0])
		if noise <= 0.0:
			noise = 0.22
			game.sound.play("scrub", -12.0 if busy else -18.0, 0.15)
	if splats.all(func(s): return float(s[1]) <= 0.0):
		_next_stage()


func _rinse(delta: float) -> void:
	# The water lands where the finger is, and takes the soap there with it.
	for f in foam:
		if float(f[2]) < 0.0 and at.distance_to(f[0]) < 74.0:
			# It takes a moment of water to shift it.
			f[3] = float(f[3]) + delta
			if float(f[3]) > 0.3:
				f[2] = 0.0
	if randf() < delta * 40.0:
		host.spark(at, "drop", Color.WHITE, Vector2(randf_range(-150.0, 150.0), randf_range(-140.0, -40.0)))
	if noise <= 0.0:
		noise = 0.3
		game.sound.play("spray", -12.0, 0.08)
	if foam.all(func(f): return float(f[2]) >= 0.0):
		_next_stage()


func _dry(moved: float) -> void:
	for i in DRY.size():
		if shine[i] < 1.0 and at.distance_to(_on_pony(float(DRY[i][0]), float(DRY[i][1]))) < 92.0:
			shine[i] = minf(float(shine[i]) + moved / 300.0, 1.0)
			if shine[i] >= 1.0:
				host.burst(_on_pony(float(DRY[i][0]), float(DRY[i][1])), "star", 5)
				game.sound.play("chime", -12.0, 0.0, 1.2 + i * 0.07)
	if moved > 1.0 and noise <= 0.0:
		noise = 0.25
		game.sound.play("brush", -12.0, 0.15)
	if shine.all(func(v): return float(v) >= 1.0):
		_next_stage()


func _over_pony(where: Vector2) -> bool:
	var size := pony.texture.get_size() * float(pony.get_meta("size"))
	return Rect2(PONY.x - size.x / 2.0, PONY.y - size.y, size.x, size.y).grow(-20.0).has_point(where)


## Adeline and her sister. Her sister has the hose; Adeline reaches in when scrubbing.
func _people(delta: float, stage_now: String, playing: bool) -> void:
	var spraying := stage_now == "rinse" and touching and playing and finished < 0.0
	var hold := { "arm_upper": -72.0, "arm_lower": -26.0 }
	if spraying:
		hold["arm_upper"] = -84.0 + sin(clock * 20.0) * 2.0
	elif finished >= 0.0:
		hold = { "arm_upper": -150.0 + sin(clock * 11.0) * 16.0, "arm_lower": -20.0 }
	host.step(sis, delta, hold)
	var reach := {}
	if touching and playing and finished < 0.0 and stage_now != "rinse":
		reach = { "arm_upper": -80.0 + sin(clock * 14.0) * 12.0, "arm_lower": -16.0, "torso": 6.0 }
	elif finished >= 0.0:
		reach = { "arm_upper": -150.0 + sin(clock * 10.0 + 1.0) * 16.0, "arm_lower": -20.0 }
	host.step(who, delta, reach)
	# The nozzle in her sister's hands, pointed at the finger.
	var hand: Vector2 = sis["at"] + Vector2(84.0, -132.0)
	var aim := (at - hand).angle() if spraying else -0.25
	nozzle.position = hand
	nozzle.rotation = clampf(aim, -1.1, 0.7)
	nozzle.visible = finished < 0.0
	pipe.visible = nozzle.visible
	# It hangs from the tap, lies along the cobbles and comes up to her hands in one easy curve.
	var bend := Curve2D.new()
	bend.add_point(Vector2(112.0, 322.0), Vector2.ZERO, Vector2(0.0, 150.0))
	bend.add_point(Vector2(150.0, 690.0), Vector2(-40.0, -90.0), Vector2(50.0, 30.0))
	bend.add_point(hand + Vector2(-30.0, 16.0), Vector2(-50.0, 110.0), Vector2.ZERO)
	pipe.points = bend.tessellate()


## The sponge or the towel: under the finger, or waiting at the bottom to be picked up.
func _tool(stage_now: String, playing: bool) -> void:
	var name := str(TOOL[stage_now])
	tool.visible = name != "" and finished < 0.0
	if not tool.visible:
		return
	var path := "res://art/mini/%s.png" % name
	if tool.texture.resource_path != path:
		tool.texture = load(path)
	var rest := Vector2(690.0, 640.0) + Vector2(0.0, sin(clock * 4.0) * 8.0)
	tool.position = at if (touching and playing) else rest
	tool.rotation = sin(clock * 16.0) * 0.12 if touching else 0.0
	var k: float = float(host.picture_size(name)) / tool.texture.get_width() * (1.0 if touching else 1.0 + 0.08 * sin(clock * 4.0))
	tool.scale = Vector2(k, k)


func _draw() -> void:
	# Shadows on the cobbles.
	for f in [[PONY + Vector2(-10.0, -6.0), 230.0], [sis["at"], 30.0], [who["at"], 36.0]]:
		draw_set_transform(f[0], 0.0, Vector2(1.0, 0.16 if float(f[1]) > 100.0 else 0.3))
		draw_circle(Vector2.ZERO, float(f[1]), Color(0.15, 0.08, 0.02, 0.26))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## Everything wet: the soap, the water from the hose, and the shine as she dries.
func _draw_suds() -> void:
	for f in foam:
		var going := maxf(float(f[2]), 0.0)
		var where: Vector2 = f[0]
		var size := float(f[1]) * (1.0 - going * 0.5)
		suds.draw_circle(where, size, Color(1.0, 1.0, 1.0, 0.92 * (1.0 - going)))
		suds.draw_arc(where, size, 0.0, TAU, 18, Color(0.7, 0.88, 1.0, 0.8 * (1.0 - going)), 2.0)
		suds.draw_circle(where + Vector2(-size * 0.3, -size * 0.3), size * 0.25, Color(1.0, 1.0, 1.0, 1.0 - going))
	if now() == "rinse" and touching and host.playing() and finished < 0.0:
		# The water: an arc of drops from the nozzle to the finger.
		var from: Vector2 = nozzle.position + Vector2.RIGHT.rotated(nozzle.rotation) * 96.0
		for i in 22:
			var k := (i + fmod(clock * 9.0, 1.0)) / 22.0
			var p := from.lerp(at, k) + Vector2(0.0, -sin(k * PI) * 70.0)
			suds.draw_circle(p, 9.0 + 5.0 * k, Color(0.5, 0.8, 1.0, 0.75))
			suds.draw_circle(p + Vector2(-2.0, -2.0), 4.0 + 2.0 * k, Color(1.0, 1.0, 1.0, 0.8))
		suds.draw_circle(at, 30.0 + sin(clock * 30.0) * 5.0, Color(0.7, 0.9, 1.0, 0.45))
	# Dry patches gleam: a twinkling star on each.
	for i in DRY.size():
		var where := _on_pony(float(DRY[i][0]), float(DRY[i][1]))
		var v := float(shine[i])
		if now() == "dry" and v < 1.0:
			# Still damp here: a ring that closes as it is rubbed.
			suds.draw_arc(where, 30.0, 0.0, TAU, 24, Color(0.6, 0.85, 1.0, 0.5), 4.0)
			suds.draw_arc(where, 30.0, -PI / 2.0, -PI / 2.0 + TAU * v, 24, Color(1.0, 0.92, 0.5), 6.0)
		elif v >= 1.0:
			var glint := 0.6 + 0.4 * sin(clock * 5.0 + i * 1.7)
			Ui.star(suds, where, 13.0 * glint, true)


func draw_ui(on: Control, s: Vector2) -> void:
	var text: String = ["Scrub off the mud with the sponge!", "Rinse off the soap! Hold where the water should go.", "Rub her dry with the towel until she shines!", "All clean!"][mini(stage, 3)]
	host.banner(on, text, 26.0)
	# Three steps, and how far through this one.
	var done := 1.0
	match now():
		"scrub":
			var left := 0.0
			for sp in splats:
				left += float(sp[1])
			done = 1.0 - left / splats.size()
		"rinse":
			done = 1.0 - foam.filter(func(f): return float(f[2]) < 0.0).size() / float(soap)
		"dry":
			var sum := 0.0
			for v in shine:
				sum += float(v)
			done = sum / shine.size()
	for i in STAGES.size():
		var c := Vector2(s.x / 2.0 + (i - 1) * 150.0, 104.0)
		var r := Rect2(c.x - 64.0, c.y - 9.0, 128.0, 18.0)
		Ui.plate(on, r, Color(0.09, 0.11, 0.24, 0.65))
		var fill := 1.0 if i < stage else (done if i == stage else 0.0)
		if fill > 0.0:
			on.draw_rect(Rect2(r.position.x + 4.0, r.position.y + 4.0, (r.size.x - 8.0) * fill, r.size.y - 8.0), Color(0.5, 0.85, 1.0) if i < stage else Color(1.0, 0.9, 0.4))
