extends Node2D
## Hide and seek in the farmyard, with Adeline's little sister. Adeline shuts her eyes and
## counts to three while her sister runs off behind something. Then it is a matter of
## watching: every so often she cannot help peeking out and giggling. Tap the thing she is
## behind and Adeline goes to look. Behind some of the others are the yard's animals, who
## peek out too. Three rounds, and she gets sneakier each time.

const Ui := preload("res://scripts/ui.gd")

# What there is to hide behind: [picture, where it stands, how big it is drawn]
const SPOTS := [
	["well", Vector2(300.0, 452.0), 0.86], ["sheet", Vector2(566.0, 440.0), 0.9], ["kennel", Vector2(826.0, 452.0), 0.84], ["barrel", Vector2(1076.0, 446.0), 0.86],
	["bales", Vector2(226.0, 656.0), 1.0], ["bush", Vector2(516.0, 664.0), 1.0], ["barrow", Vector2(800.0, 660.0), 1.0], ["crates", Vector2(1096.0, 658.0), 1.0],
]
const ANIMALS := [["hen", "Cluck!", "cluck"], ["cat", "Meow!", "meow"], ["rabbit", "Boing!", "pop"], ["mouse", "Squeak!", "squeak"]]
const ROUNDS := 3
const PEEK_OUT := [62.0, 50.0, 40.0]  # how far she leans out, round by round
const PEEK_TIME := [1.2, 0.9, 0.65]  # and for how long
const PEEK_GAP := [2.0, 2.8, 3.4]  # and how long between peeks

var host = null
var game = null
var who := {}
var sis := {}
var props: Array = []
var wobble := {}  # which prop -> seconds since something behind it moved
var hiding := -1  # which one she is behind
var animals := {}  # which prop -> [sprite, name, word, sound], for the ones with an animal behind
var loose: Array = []  # animals that have been found and are running off: [sprite, age, way]
var peeker := -1  # the prop something is peeking from right now (hers, or an animal's)
var peek_time := 9.0
var peek_wait := 1.5
var peek_side := 1
var phase := "hello"  # "hello", "count", "seek", "walk", "found", "end"
var phase_time := 0.0
var turn := 0
var wrong := 0
var looking := -1  # the one Adeline is walking over to look behind
var sizes := {}
var counted := 0
var tucked := false  # she has got to her hiding place this round


func begin() -> void:
	sizes = JSON.parse_string(FileAccess.get_file_as_string("res://art/mini/sizes.json"))
	for i in SPOTS.size():
		var node: Sprite2D = host.picture("res://art/mini/%s.png" % SPOTS[i][0], SPOTS[i][1], float(sizes[SPOTS[i][0]]) * float(SPOTS[i][2]), int(SPOTS[i][1].y))
		props.append(node)
		wobble[i] = 9.0
	who = host.girl("res://art/adeline", Vector2(640.0, 560.0), 2.2)
	sis = host.girl("res://art/sister", Vector2(730.0, 566.0), 2.2)
	sis["facing"] = -1
	sis["speed"] = 420.0
	z_index = 3  # shadows


func how() -> String:
	return "Adeline counts while her sister hides.\nWatch for a peek, then tap her hiding place!"


func go() -> void:
	game.sound.shout("sister", "sister_hide", 1.0, true)
	sis["hop"] = 0.4
	_go("hello")


func _go(to: String) -> void:
	phase = to
	phase_time = 0.0
	if to == "count":
		counted = 0
		tucked = false


func wide(i: int) -> float:
	return float(sizes[SPOTS[i][0]]) * float(SPOTS[i][2])


func press(at: Vector2) -> void:
	if phase != "seek":
		return
	# The nearest thing in front wins when two overlap.
	var best := -1
	for i in SPOTS.size():
		var foot: Vector2 = SPOTS[i][1]
		var tall: float = props[i].texture.get_height() * props[i].scale.y
		if Rect2(foot.x - wide(i) / 2.0 - 10.0, foot.y - tall - 10.0, wide(i) + 20.0, tall + 30.0).has_point(at):
			if best < 0 or foot.y > SPOTS[best][1].y:
				best = i
	if best < 0:
		return
	looking = best
	var foot: Vector2 = SPOTS[best][1]
	var side := 1.0 if who["at"].x > foot.x else -1.0
	who["goal"] = Vector2(clampf(foot.x + side * (wide(best) / 2.0 + 46.0), 110.0, 1234.0), foot.y + 8.0)
	_go("walk")
	game.sound.play("pop", -10.0)


func drag(_at: Vector2) -> void:
	pass


func release(_at: Vector2) -> void:
	pass


## A new round: she picks somewhere new, and the animals shuffle round too.
func _hide() -> void:
	var was := hiding
	while hiding == was:
		hiding = randi() % SPOTS.size()
	for i in animals:
		animals[i][0].queue_free()
	animals.clear()
	var others := range(SPOTS.size()).filter(func(i): return i != hiding)
	others.shuffle()
	var kinds := ANIMALS.duplicate()
	kinds.shuffle()
	for n in mini(1 + turn, 3):
		var i: int = others[n]
		var node: Sprite2D = host.picture("res://art/mini/%s.png" % kinds[n][0], SPOTS[i][1] + Vector2(0.0, -4.0), float(sizes[kinds[n][0]]) * float(SPOTS[i][2]), int(SPOTS[i][1].y) - 2)
		node.visible = false
		animals[i] = [node, kinds[n][0], kinds[n][1], kinds[n][2]]
	sis["at"] = SPOTS[hiding][1] + Vector2(0.0, -6.0)
	sis["goal"] = sis["at"]
	peek_wait = 1.2
	peek_time = 9.0
	peeker = -1


func frame(delta: float) -> void:
	phase_time += delta
	peek_time += delta
	for i in wobble:
		wobble[i] = float(wobble[i]) + delta
	var playing: bool = host.playing()
	var extra := {}
	if phase == "count":
		extra = { "arm_upper": -128.0, "arm_lower": -118.0, "head": 10.0 }  # hands over her eyes
	elif phase == "found":
		extra = { "arm_upper": -150.0 + sin(host.clock * 10.0) * 14.0, "arm_lower": -20.0 }
	host.step(who, delta, extra, host.depth(who["at"].y))
	if playing:
		match phase:
			"hello":
				# Her sister waves, then off she goes.
				if phase_time > 1.3:
					_go("count")
					counted = 0
			"count":
				var n := int(phase_time / 0.75) + 1
				if n > counted and n <= 3:
					counted = n
					game.sound.play("pop", -8.0, 0.0, 0.9 + n * 0.12)
				if phase_time > 0.5 and not tucked:
					tucked = true  # Adeline's eyes are shut: now she runs
					_hide()
				if phase_time > 2.7:
					_go("seek")
					game.sound.shout("adeline", "ready_or_not", 1.0, true)
			"seek":
				_peeking(delta)
			"walk":
				if not bool(who["moving"]) and phase_time > 0.2:
					_look()
			"found":
				if phase_time > 2.2:
					turn += 1
					if turn >= ROUNDS:
						_go("end")
					else:
						_go("count")
						counted = 0
			"end":
				if phase_time > 0.3:
					host.finish(3 if wrong <= 1 else (2 if wrong <= 4 else 1), "Found her every time!" if wrong <= 1 else "Found her three times. She is a good hider!")
	_sister(delta)
	# Things that have just had something move behind them rock a little.
	for i in props.size():
		var w := float(wobble[i])
		props[i].rotation = sin(w * 26.0) * 0.045 * maxf(1.0 - w / 0.5, 0.0)
	for i in animals:
		var node: Sprite2D = animals[i][0]
		var out := _lean(i)
		node.visible = out > 0.0 and phase != "count"
		node.position = SPOTS[i][1] + Vector2(peek_side * (wide(i) / 2.0 - 34.0 + out), -4.0)
		node.flip_h = peek_side < 0
	for a in loose:
		a[1] = float(a[1]) + delta
		var node: Sprite2D = a[0]
		node.position.x += float(a[2]) * 420.0 * delta
		node.offset.y = -node.texture.get_height() / 2.0 - absf(sin(float(a[1]) * 14.0)) * 26.0
		node.flip_h = float(a[2]) < 0.0
	queue_redraw()


## How far whatever is behind prop `i` is leaning out right now.
func _lean(i: int) -> float:
	if i != peeker:
		return 0.0
	var long: float = PEEK_TIME[mini(turn, ROUNDS - 1)]
	if peek_time > long:
		return 0.0
	return sin(peek_time / long * PI) * float(PEEK_OUT[mini(turn, ROUNDS - 1)])


func _peeking(delta: float) -> void:
	var long: float = PEEK_TIME[mini(turn, ROUNDS - 1)]
	if peek_time < long:
		return
	peek_wait -= delta
	if peek_wait > 0.0:
		return
	peek_wait = float(PEEK_GAP[mini(turn, ROUNDS - 1)]) * randf_range(0.8, 1.2)
	# Mostly it is her. From the second round the animals join in.
	peeker = hiding
	if not animals.is_empty() and turn > 0 and randf() < 0.4:
		peeker = animals.keys().pick_random()
	peek_time = 0.0
	peek_side = 1 if randf() < 0.5 else -1
	wobble[peeker] = 0.0
	if peeker == hiding:
		game.sound.shout("sister", "sister_giggle", 1.0, true, -3.0)
	else:
		game.sound.play("brush", -14.0, 0.1, 1.4)  # a rustle


func _sister(delta: float) -> void:
	var rig = sis["rig"]
	if phase == "hello" or phase == "found" or phase == "end":
		rig.visible = true
		host.step(sis, delta, { "arm_upper": -150.0 + sin(host.clock * 11.0) * 16.0, "arm_lower": -20.0 } if not bool(sis["moving"]) else {}, host.depth(sis["at"].y))
		return
	if hiding < 0:
		# Still beside Adeline, about to run.
		host.step(sis, delta, {}, host.depth(sis["at"].y))
		return
	# Behind her hiding place, out of sight unless she is leaning out to look.
	var out := _lean(hiding)
	var foot: Vector2 = SPOTS[hiding][1]
	rig.visible = out > 0.0 and phase != "count"
	sis["facing"] = peek_side
	sis["at"] = foot + Vector2(peek_side * (wide(hiding) / 2.0 - 44.0 + out), -6.0)
	sis["goal"] = sis["at"]
	host.step(sis, delta, { "torso": 12.0, "head": -8.0 }, float(SPOTS[hiding][2]))
	rig.z_index = int(foot.y) - 1


## Adeline has reached the one she chose and looks behind it.
func _look() -> void:
	wobble[looking] = 0.0
	var foot: Vector2 = SPOTS[looking][1]
	if looking == hiding:
		# There she is. She runs out beside Adeline and jumps for joy.
		_go("found")
		hiding = -1
		peeker = -1
		var side := 1.0 if who["at"].x < foot.x else -1.0
		sis["rig"].visible = true
		sis["at"] = foot + Vector2(0.0, 4.0)
		sis["goal"] = Vector2(clampf(who["at"].x - side * 84.0, 110.0, 1234.0), who["at"].y + 4.0)
		sis["hop"] = 0.4
		who["hop"] = 0.4
		who["facing"] = 1 if sis["goal"].x > who["at"].x else -1
		host.burst(foot + Vector2(0.0, -120.0), "heart", 5)
		host.burst(foot + Vector2(0.0, -120.0), "star", 10)
		host.word(foot + Vector2(0.0, -200.0), "Found you!")
		game.sound.play("chime", -5.0)
		game.sound.shout("adeline", "found_you", 1.0, true)
		game.sound.shout("sister", "sister_found", 1.0, true)
		return
	wrong += 1
	_go("seek")
	if animals.has(looking):
		# Not her: one of the animals, which bolts.
		var found: Array = animals[looking]
		animals.erase(looking)
		var node: Sprite2D = found[0]
		node.visible = true
		node.z_index = int(foot.y) + 40
		node.position = foot + Vector2(0.0, 20.0)
		loose.append([node, 0.0, -1.0 if who["at"].x > foot.x else 1.0])
		host.word(foot + Vector2(0.0, -190.0), str(found[2]), Color(1.0, 1.0, 1.0))
		game.sound.play(str(found[3]), -6.0)
		if peeker == looking:
			peeker = -1
	else:
		host.burst(foot + Vector2(0.0, -100.0), "leaf", 8)
		host.word(foot + Vector2(0.0, -190.0), "Not here!", Color(1.0, 1.0, 1.0))
	game.sound.shout("adeline", "not_here", 1.0)


func _draw() -> void:
	var feet: Array = [[who["at"], 34.0]]
	if sis["rig"].visible and (phase == "hello" or phase == "found" or phase == "end" or hiding < 0):
		feet.append([sis["at"], 26.0])
	for f in feet:
		draw_set_transform(f[0], 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, float(f[1]) * host.depth(f[0].y), Color(0.2, 0.1, 0.02, 0.28))
	# Each thing to hide behind has a shadow of its own on the dirt.
	for i in SPOTS.size():
		draw_set_transform(SPOTS[i][1] + Vector2(0.0, -4.0), 0.0, Vector2(1.0, 0.16))
		draw_circle(Vector2.ZERO, wide(i) * 0.56, Color(0.2, 0.1, 0.02, 0.24))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func draw_ui(on: Control, s: Vector2) -> void:
	if phase == "count":
		# Her eyes are shut: the dark closes in from above and below, and she counts.
		var shut := Ui.ease(phase_time / 0.3) * (1.0 - Ui.ease((phase_time - 2.4) / 0.3))
		on.draw_rect(Rect2(0.0, 0.0, s.x, s.y / 2.0 * shut), Color(0.06, 0.05, 0.14))
		on.draw_rect(Rect2(0.0, s.y - s.y / 2.0 * shut, s.x, s.y / 2.0 * shut), Color(0.06, 0.05, 0.14))
		if counted > 0 and phase_time < 2.4:
			var age := phase_time - (counted - 1) * 0.75
			var k := maxf(Ui.pop(age / 0.25), 0.01)
			on.draw_set_transform(s / 2.0, 0.0, Vector2(k, k))
			var text := str(counted)
			var across: float = host.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 150).x
			on.draw_string_outline(host.font, Vector2(-across / 2.0, 50.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 150, 14, Color(0.3, 0.2, 0.5))
			on.draw_string(host.font, Vector2(-across / 2.0, 50.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 150, Color(1.0, 0.92, 0.5))
			on.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		return
	var line := "Where is she hiding? Watch for a peek, then tap."
	if phase == "hello":
		line = "Ready... she is going to hide!"
	elif phase == "walk":
		line = "Let's have a look..."
	elif phase == "found" or phase == "end":
		line = "Found her!"
	host.banner(on, line, 26.0)
	# One heart for each time she has been found.
	for i in ROUNDS:
		Ui.heart(on, Vector2(60.0 + i * 46.0, 50.0), 17.0, i < turn + (1 if phase == "found" else 0))
