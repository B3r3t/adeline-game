extends Node2D
## Apple picking. Grandma is baking a pie and has written down what she needs: so many
## red apples, so many green, a couple of golden ones. Apples ripen along the bottom of
## the old tree's branches, wobble, and drop. Adeline runs under them with her basket:
## hold a finger on the screen and she goes to it. Wormy apples are best left to fall.
## When the list is filled Grandma comes out with the pie.

const Season := preload("res://scripts/season.gd")
const Ui := preload("res://scripts/ui.gd")

const GROUND := 664.0
const BRANCH := Vector2(150.0, 205.0)  # apples hang between these heights
const NEEDS := { "red": 6, "green": 4, "gold": 2 }
const KINDS := ["red", "green", "gold"]
const FALL := 380.0  # how fast a falling apple gathers speed
const TOP_SPEED := 350.0
const REACH := 66.0  # how far either side of the basket's middle an apple can be caught

var host = null
var game = null
var who := {}
var basket: Sprite2D = null
var apples: Array = []  # each: { "node", "kind", "state", "time", "speed", "x" }
var got := { "red": 0, "green": 0, "gold": 0 }
var worms := 0
var next := 0.6
var held := false
var shake := 0.0
var over := -1.0  # seconds since the list was filled, or -1 before
var grandma: Sprite2D = null
var pie: Sprite2D = null
var jumped := {}  # kind -> seconds since its count last went up
var icons := {}


func begin() -> void:
	who = host.girl("res://art/adeline", Vector2(672.0, GROUND), 2.6)
	who["speed"] = 560.0
	basket = host.picture("res://art/mini/basket.png", Vector2.ZERO, 140.0)
	for kind in KINDS + ["worm"]:
		icons[kind] = Season.tex("res://art/mini/apple_%s.png" % kind)
		jumped[kind] = 9.0


func how() -> String:
	return "Hold a finger where Adeline should run.\nCatch the apples on Grandma's list, not the wormy ones!"


func go() -> void:
	game.sound.shout("adeline", "apples", 1.0, true)


func done() -> bool:
	for kind in KINDS:
		if int(got[kind]) < int(NEEDS[kind]):
			return false
	return true


func press(at: Vector2) -> void:
	held = true
	drag(at)


func drag(at: Vector2) -> void:
	who["goal"] = Vector2(clampf(at.x, host.SAFE.position.x + 30.0, host.SAFE.end.x - 30.0), GROUND)


func release(_at: Vector2) -> void:
	held = false


## Where the middle of the basket's mouth is.
func mouth() -> Vector2:
	return who["at"] + Vector2(int(who["facing"]) * 44.0, -132.0)


func _grow_apple() -> void:
	# Mostly what is still needed, now and then a wormy one.
	var kind := "worm"
	if randf() > 0.2:
		var wanted := KINDS.filter(func(k): return int(got[k]) < int(NEEDS[k]))
		kind = wanted.pick_random() if not wanted.is_empty() and randf() < 0.8 else KINDS.pick_random()
	# Not right on top of another one that is still hanging.
	var x := 0.0
	for attempt in 8:
		x = randf_range(host.SAFE.position.x + 60.0, host.SAFE.end.x - 60.0)
		if apples.all(func(a): return str(a["state"]) == "fall" or absf(float(a["x"]) - x) > 90.0):
			break
	var node: Sprite2D = host.picture("res://art/mini/apple_%s.png" % kind, Vector2(x, randf_range(BRANCH.x, BRANCH.y)), 72.0 if kind == "worm" else 62.0, 600)
	node.offset = Vector2(0.0, node.texture.get_height() * 0.42)  # it hangs by its stalk
	node.set_meta("size", node.scale.x)
	node.scale = Vector2.ZERO
	apples.append({ "node": node, "kind": kind, "state": "hang", "time": 0.0, "wait": randf_range(1.0, 1.9), "speed": 0.0, "x": x })
	host.spark(node.position, "leaf")


func frame(delta: float) -> void:
	var playing: bool = host.playing()
	for kind in jumped:
		jumped[kind] = float(jumped[kind]) + delta
	shake = maxf(shake - delta, 0.0)
	# Adeline, holding the basket out in front of her.
	if not held and playing:
		who["goal"] = who["at"]
	host.step(who, delta, { "arm_upper": -62.0, "arm_lower": -34.0 })
	var total := int(got["red"]) + int(got["green"]) + int(got["gold"])
	if total == 5:
		basket.texture = Season.tex("res://art/mini/basket_full.png")
	basket.position = mouth() + Vector2(sin(shake * 50.0) * 8.0 * shake, 84.0)
	basket.z_index = int(GROUND) + 2
	if playing and over < 0.0:
		next -= delta
		if next <= 0.0:
			next = randf_range(0.55, 0.95)
			_grow_apple()
	for apple in apples:
		var node: Sprite2D = apple["node"]
		apple["time"] = float(apple["time"]) + delta
		var size := float(node.get_meta("size"))
		if str(apple["state"]) == "hang":
			var t := float(apple["time"])
			var k: float = size * Ui.pop(t / 0.35)
			node.scale = Vector2(k, k)
			# It swings gently, then shivers just before it lets go.
			var loose := clampf((t - float(apple["wait"]) + 0.5) / 0.5, 0.0, 1.0)
			node.rotation = sin(t * 3.0 + float(apple["x"])) * 0.12 + sin(t * 40.0) * 0.12 * loose
			if t > float(apple["wait"]) and playing:
				apple["state"] = "fall"
				apple["time"] = 0.0
				node.offset = Vector2.ZERO
				node.position.y += node.texture.get_height() * size * 0.42
		elif str(apple["state"]) == "fall":
			apple["speed"] = minf(float(apple["speed"]) + FALL * delta, TOP_SPEED)
			var was := node.position.y
			node.position.y += float(apple["speed"]) * delta
			node.rotation += delta * 2.0 * (1.0 if int(float(apple["x"])) % 2 == 0 else -1.0)
			var m := mouth()
			if playing and over < 0.0 and was <= m.y and node.position.y > m.y and absf(node.position.x - m.x) < REACH:
				_catch(apple)
			elif node.position.y > GROUND - 8.0:
				apple["state"] = "roll"
				apple["time"] = 0.0
				game.sound.play("thump", -24.0, 0.2, 1.6)
		elif str(apple["state"]) == "roll":
			# It bounces once on the grass, rolls a little way and fades.
			var t := float(apple["time"])
			node.position.y = GROUND - 8.0 - absf(sin(minf(t, 0.5) / 0.5 * PI)) * 22.0
			node.position.x += (30.0 if int(float(apple["x"])) % 2 == 0 else -30.0) * delta
			node.rotation += delta * 3.0
			node.modulate.a = clampf(1.6 - t, 0.0, 1.0)
			if t > 1.6:
				apple["state"] = "gone"
		elif str(apple["state"]) == "caught":
			# Into the basket: it shrinks down into the mouth of it.
			var t := float(apple["time"]) / 0.18
			node.position = node.position.lerp(mouth() + Vector2(0.0, 30.0), minf(t, 1.0))
			var k := size * maxf(1.0 - t, 0.0)
			node.scale = Vector2(k, k)
			if t >= 1.0:
				apple["state"] = "gone"
	for apple in apples:
		if str(apple["state"]) == "gone":
			apple["node"].queue_free()
	apples = apples.filter(func(a): return str(a["state"]) != "gone")
	# Now and then a leaf comes down by itself.
	if randf() < delta * 0.7:
		host.spark(Vector2(randf_range(host.SAFE.position.x, host.SAFE.end.x), 200.0), "leaf")
	if over >= 0.0:
		_ending(delta)


func _catch(apple: Dictionary) -> void:
	var kind := str(apple["kind"])
	apple["state"] = "caught"
	apple["time"] = 0.0
	var at: Vector2 = mouth()
	if kind == "worm":
		worms += 1
		shake = 0.5
		host.word(at + Vector2(0.0, -40.0), "Yuck!", Color(0.7, 0.9, 0.3))
		host.burst(at, "leaf", 6)
		game.sound.play("squirt", -8.0)
		game.sound.shout("adeline", "yuck", 1.0)
		return
	var need := int(NEEDS[kind])
	if int(got[kind]) < need:
		got[kind] = int(got[kind]) + 1
		jumped[kind] = 0.0
		host.burst(at, "star", 4)
		host.word(at + Vector2(0.0, -40.0), "%d of %d" % [int(got[kind]), need])
		game.sound.play("pop", -6.0, 0.0, 1.0 + 0.06 * (int(got["red"]) + int(got["green"]) + int(got["gold"])))
	else:
		host.word(at + Vector2(0.0, -40.0), "One for later!", Color(1.0, 1.0, 1.0))
		game.sound.play("pop", -12.0, 0.0, 0.8)
	who["hop"] = 0.4 if done() else 0.0
	if done() and over < 0.0:
		over = 0.0
		game.sound.play("chime", -5.0)
		game.sound.shout("adeline", "we_did_it", 1.0, true)


## Grandma comes out with the pie, and that is the game.
func _ending(delta: float) -> void:
	over += delta
	if grandma == null and over > 0.5:
		grandma = host.picture("res://art/props/crowd_4.png", Vector2(host.SAFE.end.x + 160.0, GROUND + 4.0), 124.0)
		grandma.flip_h = true
		pie = host.picture("res://art/room/kitchen/pie.png", Vector2.ZERO, 92.0)
		who["goal"] = Vector2(560.0, GROUND)
	if grandma != null:
		var stop: float = who["at"].x + 210.0
		grandma.position.x = maxf(grandma.position.x - 260.0 * delta, stop)
		var walking := grandma.position.x > stop
		grandma.offset.y = -grandma.texture.get_height() / 2.0 - (absf(sin(over * 9.0)) * 5.0 if walking else (0.5 + 0.5 * sin(over * 2.2)) * 3.0)
		grandma.z_index = int(GROUND) + 1
		pie.position = grandma.position + Vector2(-62.0, -92.0 - (0.0 if walking else 10.0 * absf(sin(over * 3.0))))
		pie.z_index = grandma.z_index + 1
		if not walking:
			who["facing"] = 1
			if randf() < delta * 5.0:
				host.spark(pie.position + Vector2(randf_range(-30.0, 30.0), -50.0), "smoke", Color(1.0, 1.0, 1.0))
			if over > 2.4:
				host.finish(3 if worms == 0 else (2 if worms <= 2 else 1), ("Grandma's Christmas pie is the best yet." if Season.festive() else "Grandma's apple pie is the best yet.") if worms == 0 else "The pie is baked, worms and all!")


func draw_ui(on: Control, s: Vector2) -> void:
	# Grandma's list: each kind of apple and how many of it are in the basket.
	var wide := 500.0
	var box := Rect2((s.x - wide) / 2.0, 22.0, wide, 76.0)
	Ui.panel(on, box, Color(0.98, 0.93, 0.78, 0.96), Color(0.55, 0.36, 0.16, 0.95), 16.0)
	on.draw_string(host.font, Vector2(box.position.x + 18.0, box.position.y + 30.0), "Grandma's", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 19, Color(0.4, 0.24, 0.1))
	on.draw_string(host.font, Vector2(box.position.x + 18.0, box.position.y + 56.0), "pie needs", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 19, Color(0.4, 0.24, 0.1))
	for i in KINDS.size():
		var kind: String = KINDS[i]
		var at := Vector2(box.position.x + 160.0 + i * 116.0, box.get_center().y)
		var full := int(got[kind]) >= int(NEEDS[kind])
		var k := 1.0 + 0.5 * maxf(1.0 - float(jumped[kind]) / 0.3, 0.0)
		on.draw_texture_rect(icons[kind], Rect2(at - Vector2(24.0, 26.0) * k, Vector2(48.0, 52.0) * k), false)
		on.draw_string(host.font, at + Vector2(30.0, 10.0), "%d/%d" % [int(got[kind]), int(NEEDS[kind])], HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, Color(0.16, 0.5, 0.2) if full else Color(0.3, 0.18, 0.08))
		if full:
			# A tick over the ones that are done.
			on.draw_polyline(PackedVector2Array([at + Vector2(-16.0, 0.0), at + Vector2(-4.0, 14.0), at + Vector2(20.0, -16.0)]), Color(0.16, 0.62, 0.24), 6.0)
	if worms > 0:
		on.draw_texture_rect(icons["worm"], Rect2(box.end.x + 16.0, box.position.y + 12.0, 52.0, 50.0), false)
		host._text(on, Vector2(box.end.x + 72.0, box.position.y + 48.0), "x%d" % worms, 24, Color(0.85, 1.0, 0.5))
