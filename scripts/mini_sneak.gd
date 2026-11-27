extends Node2D
## Mission 4, part one: the little sister creeps down the goblin burrow.
##
## The tunnel runs from daylight on the left to the chief's door on the right. Three
## goblin sentries doze along it, each with a lantern. Every so often one wakes: first he
## yawns, which is the warning, then he lifts his lantern and looks, and the stretch of
## path in front of him is lit. If she is in the light, he sees her, and she scampers back
## to the last thing she hid behind. Between the stretches are things to hide behind: big
## mushrooms, barrels, sacks, a rock. There she is safe whatever the goblins do.
##
## Hold a finger where she should go and she tiptoes there. So the game is: wait behind
## something, watch the goblin, and cross when he is asleep. Nothing is lost by being
## seen but a little ground, and nobody can be hurt. The sentries get quicker along the way.

const Ui := preload("res://scripts/ui.gd")

const PATH := 640.0  # the line she walks along
const START := 150.0
const DOOR := 1250.0  # reaching this is the end of the tunnel
const HIDES := [["hide_mushrooms", 236.0], ["hide_barrels", 522.0], ["hide_sacks", 808.0], ["hide_rock", 1090.0]]
const HIDE_REACH := 52.0  # how near the middle of a hiding place counts as behind it
# Each sentry: where he sits, the stretch he lights, how long he sleeps (least, most),
# how long he looks, and when his first waking comes.
const SENTRIES := [
	{ "x": 380.0, "from": 292.0, "to": 466.0, "nap": [4.4, 5.6], "look": 2.0, "first": 3.2 },
	{ "x": 664.0, "from": 578.0, "to": 752.0, "nap": [3.6, 4.8], "look": 2.2, "first": 5.0 },
	{ "x": 950.0, "from": 864.0, "to": 1034.0, "nap": [3.0, 4.0], "look": 2.4, "first": 2.4 },
]
const YAWN := 1.15  # the warning before he looks
const GOBLIN := 0.34  # how big the goblin pictures are drawn
const HIDE_SIZE := 0.42

var host = null
var game = null
var who := {}
var art := {}
var sentries: Array = []
var top: Node2D = null
var held := false
var clock := 0.0
var seen := 0  # how many times a goblin has seen her
var caught := 0.0  # counts down while she runs back after being seen
var back_to := START
var done := 0.0  # counts up once she is through the door
var whispered := false
var snore := 2.0


func begin() -> void:
	for name in ["sentry_sleep", "sentry_yawn", "sentry_look", "sentry_shout"]:
		art[name] = load("res://art/mini/%s.png" % name)
	# Her pony waits at the mouth of the tunnel: it is too small in there even for her.
	var pony: Sprite2D = host.picture("res://art/mini/pony.png", Vector2(34.0, 664.0), 250.0, 600)
	pony.modulate = Color(0.92, 0.9, 0.95)
	for spec in SENTRIES:
		var node: Sprite2D = host.picture("res://art/mini/sentry_sleep.png", Vector2(float(spec["x"]), PATH - 40.0), 10.0, int(PATH) - 60)
		sentries.append({ "node": node, "spec": spec, "state": "sleep", "time": float(spec["first"]), "light": 0.0 })
	for hide in HIDES:
		var tex: Texture2D = load("res://art/mini/%s.png" % hide[0])
		host.picture("res://art/mini/%s.png" % hide[0], Vector2(float(hide[1]), PATH + 46.0), tex.get_width() * HIDE_SIZE, int(PATH) + 60)
	who = host.girl("res://art/sister", Vector2(START, PATH), 2.5)
	who["speed"] = 150.0
	top = Node2D.new()
	top.z_index = int(PATH) - 30  # the lantern light lies on the path, under her feet
	top.draw.connect(_draw_light)
	host.stage.add_child(top)
	_pose_sentries(0.0)


func how() -> String:
	return "Hold a finger where she should tiptoe.\nHide behind things. Cross when the goblin is asleep!"


func go() -> void:
	game.sound.shout("sister", "sister_shh", 1.0, true)


func press(at: Vector2) -> void:
	held = true
	drag(at)


func drag(at: Vector2) -> void:
	if held and caught <= 0.0 and done <= 0.0:
		who["goal"] = Vector2(clampf(at.x, START - 20.0, DOOR + 30.0), PATH)


func release(_at: Vector2) -> void:
	held = false
	if caught <= 0.0 and done <= 0.0:
		who["goal"] = who["at"]


## The hiding place she is behind just now, or -1.
func hiding() -> int:
	for i in HIDES.size():
		if absf(float(who["at"].x) - float(HIDES[i][1])) < HIDE_REACH:
			return i
	return -1


## Where she runs back to when she is seen: the last hiding place behind her.
func _retreat() -> float:
	var x := START
	for hide in HIDES:
		if float(hide[1]) < float(who["at"].x) - 20.0:
			x = float(hide[1])
	return x


func frame(delta: float) -> void:
	clock += delta
	var playing: bool = host.state == "play"
	if playing and done <= 0.0:
		_watch(delta)
		snore -= delta
		if snore <= 0.0:
			snore = randf_range(3.0, 4.6)
			if sentries.any(func(s): return str(s["state"]) == "sleep"):
				game.sound.play("snore", -15.0, 0.1, randf_range(1.15, 1.4))
	if caught > 0.0:
		caught -= delta
		who["speed"] = 430.0
		who["goal"] = Vector2(back_to, PATH)
		if caught <= 0.0 or absf(float(who["at"].x) - back_to) < 4.0:
			caught = 0.0
			who["speed"] = 150.0
			who["goal"] = who["at"]
	# Through the door at the end.
	if playing and done <= 0.0 and float(who["at"].x) >= DOOR - 6.0:
		done = 0.001
		who["hop"] = 0.4
		game.sound.play("chime", -5.0)
		game.sound.shout("sister", "sister_made_it", 1.0, true)
		host.burst(who["at"] + Vector2(0.0, -110.0), "star", 14, Color(1.0, 0.9, 0.5))
	if done > 0.0:
		done += delta
		if done > 1.7:
			host.finish(3, "")
	# Behind something and standing still she crouches down small.
	var tucked := hiding() >= 0 and not bool(who["moving"]) and caught <= 0.0 and done <= 0.0
	host.step(who, delta)
	if tucked:
		who["rig"].scale.y *= 0.88
		who["rig"].position.y += 4.0
	if not whispered and playing and float(who["at"].x) > float(SENTRIES[0]["from"]) - 30.0:
		whispered = true
		game.sound.shout("sister", "sister_shh", 1.0)
	_pose_sentries(delta)
	top.queue_redraw()


## The sentries' turns of sleeping, yawning and looking, and whether one sees her.
func _watch(delta: float) -> void:
	for s in sentries:
		var spec: Dictionary = s["spec"]
		s["time"] = float(s["time"]) - delta
		match str(s["state"]):
			"sleep":
				if float(s["time"]) <= 0.0:
					s["state"] = "yawn"
					s["time"] = YAWN
					game.sound.play("goblin_taunt", -14.0, 0.1, 0.8)
			"yawn":
				if float(s["time"]) <= 0.0:
					s["state"] = "look"
					s["time"] = float(spec["look"])
			"look":
				var x := float(who["at"].x)
				if caught <= 0.0 and x > float(spec["from"]) and x < float(spec["to"]):
					# In the light. He sees her, and back she goes.
					seen += 1
					s["state"] = "shout"
					s["time"] = 1.3
					back_to = _retreat()
					caught = 2.4
					held = false
					game.sound.play("goblin_attack", -7.0, 0.1)
					game.sound.shout("sister", "sister_uhoh", 1.0, true)
					host.word(Vector2(float(spec["x"]), PATH - 250.0), "Oi!", Color(1.0, 0.75, 0.6))
				elif float(s["time"]) <= 0.0:
					s["state"] = "sleep"
					s["time"] = randf_range(float(spec["nap"][0]), float(spec["nap"][1]))
			"shout":
				if float(s["time"]) <= 0.0:
					# He decides it was a mouse, and nods off for a good long while.
					s["state"] = "sleep"
					s["time"] = float(spec["nap"][1]) + 1.2
		var bright := 0.0
		if str(s["state"]) == "look" or str(s["state"]) == "shout":
			bright = 1.0
		elif str(s["state"]) == "yawn":
			bright = 0.22 + 0.12 * sin(clock * 22.0)  # the lantern flickers up as he wakes
		s["light"] = move_toward(float(s["light"]), bright, delta * 5.0)


func _pose_sentries(_delta: float) -> void:
	for i in sentries.size():
		var s: Dictionary = sentries[i]
		var node: Sprite2D = s["node"]
		var tex: Texture2D = art["sentry_" + str(s["state"])]
		node.texture = tex
		var breath := 1.0
		if str(s["state"]) == "sleep":
			breath = 1.0 + sin(clock * 1.6 + i * 2.0) * 0.025
		elif str(s["state"]) == "shout":
			breath = 1.0 + absf(sin(clock * 18.0)) * 0.03
		node.scale = Vector2(GOBLIN, GOBLIN * breath)
		node.offset = Vector2(0.0, -tex.get_height() / 2.0)


## The pool of lantern light on the path in front of each sentry, and his beam down to it.
func _draw_light() -> void:
	for s in sentries:
		var a := float(s["light"])
		if a <= 0.01:
			continue
		var spec: Dictionary = s["spec"]
		var from := float(spec["from"])
		var to := float(spec["to"])
		var mid := Vector2((from + to) / 2.0, PATH + 8.0)
		var lamp := Vector2(float(spec["x"]) - 56.0, PATH - 188.0)
		var warm := Color(1.0, 0.93, 0.5)
		top.draw_colored_polygon(PackedVector2Array([lamp, Vector2(from + 14.0, PATH + 6.0), Vector2(to - 14.0, PATH + 6.0)]), Color(warm.r, warm.g, warm.b, 0.26 * a))
		var pulse := 1.0 + sin(clock * 6.0) * 0.03
		for ring in 4:
			top.draw_set_transform(mid, 0.0, Vector2(1.0, 0.3))
			top.draw_circle(Vector2.ZERO, (to - from) / 2.0 * (1.0 - ring * 0.17) * pulse, Color(warm.r, warm.g, warm.b, 0.3 * a))
		top.draw_set_transform(mid, 0.0, Vector2(1.0, 0.3))
		top.draw_arc(Vector2.ZERO, (to - from) / 2.0 * pulse, 0.0, TAU, 48, Color(1.0, 0.98, 0.75, 0.9 * a), 6.0)
		top.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_ui(on: Control, s: Vector2) -> void:
	if host.state != "play":
		return
	if done > 0.0:
		host.banner(on, "She made it!")
	elif caught > 0.0:
		host.banner(on, "He saw her! Back behind something, quick.")
	elif hiding() >= 0 and not bool(who["moving"]):
		host.banner(on, "Safe here. Wait for him to nod off, then go.")
	else:
		host.banner(on, "Tiptoe to the door. Stay out of the lantern light!")
	# Over each sentry: z's while he sleeps, a mark when he wakes.
	for sentry in sentries:
		var spec: Dictionary = sentry["spec"]
		var head: Vector2 = host.to_screen(Vector2(float(spec["x"]) + 10.0, PATH - 236.0))
		match str(sentry["state"]):
			"sleep":
				for i in 3:
					var t := fmod(clock * 0.45 + i * 0.33, 1.0)
					host._text(on, head + Vector2(20.0 + t * 26.0, 60.0 - t * 60.0), "z", int(18 + t * 14.0), Color(1.0, 1.0, 1.0, 1.0 - t))
			"yawn":
				host._text(on, head + Vector2(-8.0, 30.0), "?", 44, Color(1.0, 0.9, 0.4))
			"look":
				host._text(on, head + Vector2(-8.0, 6.0), "!", 50, Color(1.0, 0.55, 0.3))
	# Where she is safe: a little leaf of a mark over the hiding place she is behind.
	if hiding() >= 0 and not bool(who["moving"]) and caught <= 0.0:
		var over: Vector2 = host.to_screen(Vector2(float(HIDES[hiding()][1]), PATH - 196.0))
		var bob := sin(clock * 4.0) * 3.0
		Ui.plate(on, Rect2(over.x - 46.0, over.y - 16.0 + bob, 92.0, 32.0), Color(0.2, 0.62, 0.34, 0.9))
		host._text(on, Vector2(over.x - 46.0, over.y + 7.0 + bob), "Hidden", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, 92.0)
