extends Node2D
## Lost lambs. Six lambs have wandered off across the meadow and the sun is going down.
## Tap where Adeline should walk. A lamb she comes close to follows her, nose to tail with
## the others, and when she brings them to the barn they hop inside. One is caught in a
## bramble bush and has to be worked free: stand by it for a moment. A fox comes sniffing
## round now and then. If it gets among the lambs they scatter; tap it and Adeline shoos
## it away.

const Season := preload("res://scripts/season.gd")
const Ui := preload("res://scripts/ui.gd")

const DOOR := Vector2(268.0, 352.0)  # the barn's doorway
const FIELD := Rect2(110.0, 372.0, 1140.0, 290.0)  # where there is grass to walk on
const DAY := 90.0  # seconds until the sun is down
const STARTS := [Vector2(640.0, 420.0), Vector2(930.0, 620.0), Vector2(1140.0, 410.0), Vector2(1200.0, 630.0), Vector2(520.0, 630.0), Vector2(830.0, 500.0)]
const STUCK := 5  # which of them is in the brambles

var host = null
var game = null
var who := {}
var lambs: Array = []  # each a Dictionary: node, at, state, time, flip, step
var art := {}
var bramble: Sprite2D = null
var free_time := 0.0  # how long Adeline has been working at the brambles
var fox: Sprite2D = null
var fox_state := ""  # "", "come", "flee"
var fox_time := 0.0
var fox_next := 7.0
var sun := 0.0  # seconds of the day gone
var home := 0
var scares := 0
var shooed := 0
var dusk: Polygon2D = null
var top: Node2D = null
var over := -1.0
var held := false
var gate := 0.0  # seconds until the next lamb may go in at the door


func begin() -> void:
	for name in ["lamb_stand", "lamb_walk_1", "lamb_walk_2", "lamb_jump", "lamb_sit", "lamb_sleep", "fox_1", "fox_2", "fox_scared"]:
		art[name] = Season.tex("res://art/mini/%s.png" % name)
	who = host.girl("res://art/adeline", Vector2(430.0, 470.0), 2.05)
	who["speed"] = 280.0
	for i in STARTS.size():
		var node: Sprite2D = host.picture("res://art/mini/lamb_stand.png", STARTS[i], 98.0)
		node.set_meta("size", node.scale.x)
		lambs.append({ "node": node, "at": STARTS[i], "spot": STARTS[i], "state": "stuck" if i == STUCK else "lost", "time": randf() * 3.0, "flip": randf() < 0.5, "step": 0.0, "baa": randf_range(2.0, 6.0) })
	bramble = host.picture("res://art/mini/bramble.png", STARTS[STUCK] + Vector2(6.0, 26.0), 190.0)
	fox = host.picture("res://art/mini/fox_1.png", Vector2(1500.0, 420.0), 154.0)
	fox.set_meta("size", fox.scale.x)
	fox.visible = false
	# The evening coming on: a wash of blue over everything, deepening.
	dusk = Polygon2D.new()
	dusk.polygon = PackedVector2Array([Vector2.ZERO, Vector2(host.W, 0.0), Vector2(host.W, host.H), Vector2(0.0, host.H)])
	dusk.color = Color(0.1, 0.08, 0.3, 0.0)
	dusk.z_index = 3000
	host.stage.add_child(dusk)
	top = Node2D.new()
	top.z_index = 3200
	top.draw.connect(_draw_top)
	host.stage.add_child(top)
	z_index = 2  # shadows, just over the grass


func how() -> String:
	return "Tap where Adeline should walk. Lambs follow her.\nLead them to the barn, and tap the fox to shoo it!"


func go() -> void:
	game.sound.shout("adeline", "lambs", 1.0, true)


func press(at: Vector2) -> void:
	held = true
	if fox_state == "come" and at.distance_to(fox.position + Vector2(0.0, -50.0)) < 110.0:
		_shoo()
		return
	drag(at)


func drag(at: Vector2) -> void:
	if held:
		who["goal"] = Vector2(clampf(at.x, FIELD.position.x, FIELD.end.x), clampf(at.y, FIELD.position.y, FIELD.end.y))


func release(_at: Vector2) -> void:
	held = false


func followers() -> Array:
	return lambs.filter(func(l): return str(l["state"]) == "follow")


func _shoo() -> void:
	shooed += 1
	fox_state = "flee"
	fox_time = 0.0
	who["facing"] = 1 if fox.position.x > who["at"].x else -1
	host.burst(fox.position + Vector2(0.0, -60.0), "star", 10)
	host.word(fox.position + Vector2(0.0, -130.0), "Shoo!")
	game.sound.play("zap", -8.0)
	game.sound.play("yip", -6.0)
	game.sound.shout("adeline", "shoo", 1.0, true)


func _baa(lamb: Dictionary, loud := -10.0) -> void:
	game.sound.play("bleat", loud, 0.12)
	host.word(lamb["at"] + Vector2(0.0, -110.0), "Baa!", Color(1.0, 1.0, 1.0))


func frame(delta: float) -> void:
	var playing: bool = host.playing()
	var me: Vector2 = who["at"]
	# Working at the brambles, her arm goes in and out of the bush.
	var working := playing and str(lambs[STUCK]["state"]) == "stuck" and me.distance_to(STARTS[STUCK]) < 100.0 and not bool(who["moving"])
	var extra := {}
	if working:
		who["facing"] = 1 if STARTS[STUCK].x > me.x else -1
		extra = { "arm_upper": -70.0 + sin(host.clock * 12.0) * 14.0, "arm_lower": -20.0, "torso": 8.0 }
	host.step(who, delta, extra, host.depth(me.y))
	if playing and over < 0.0:
		sun += delta
		_fox(delta)
		if working:
			free_time += delta
			bramble.rotation = sin(host.clock * 30.0) * 0.04
			if randf() < delta * 8.0:
				host.spark(bramble.position + Vector2(randf_range(-60.0, 60.0), -80.0), "leaf")
			if free_time > 1.7:
				lambs[STUCK]["state"] = "follow"
				lambs[STUCK]["time"] = 0.0
				bramble.rotation = 0.0
				host.burst(STARTS[STUCK] + Vector2(0.0, -60.0), "heart", 3)
				_baa(lambs[STUCK], -6.0)
				game.sound.shout("adeline", "free", 1.0)
		else:
			free_time = maxf(free_time - delta * 2.0, 0.0)
			bramble.rotation = 0.0
		if sun >= DAY or home == lambs.size():
			over = 0.0
			if home == lambs.size():
				game.sound.shout("adeline", "we_did_it", 1.0, true)
	dusk.color.a = clampf(sun / DAY, 0.0, 1.0) * 0.42
	gate -= delta
	var line := followers()
	for lamb in lambs:
		_lamb(lamb, delta, playing, line)
	# Lambs in the line do not stand on top of one another, or on Adeline.
	for i in line.size():
		for other in [who] + line.slice(0, i):
			var apart: Vector2 = line[i]["at"] - other["at"]
			if apart.length() < 72.0:
				var push := (apart.normalized() if apart.length() > 0.5 else Vector2.RIGHT.rotated(i * 2.4)) * (72.0 - apart.length()) * minf(delta * 8.0, 1.0)
				line[i]["at"] = (line[i]["at"] + push).clamp(FIELD.position, FIELD.end)
	top.queue_redraw()
	queue_redraw()
	if over >= 0.0:
		over += delta
		# Any still out when night falls follow the lantern home by themselves.
		for lamb in lambs:
			if str(lamb["state"]) in ["lost", "follow", "stuck", "scared"]:
				lamb["state"] = "home"
				lamb["time"] = 0.0
		# Nobody is told "well done" while a lamb is still out in the field.
		var indoors := lambs.all(func(l): return str(l["state"]) == "in" and float(l["time"]) > 0.4)
		if (over > 2.6 and indoors) or over > 14.0:
			var all_in := sun < DAY
			var won := 1
			if all_in:
				won = 3 if (sun < DAY * 0.7 and scares <= 1) else 2
			host.finish(won, "All six lambs are safe in the barn." if all_in else "It got dark, but the lambs found the lantern.")


func _lamb(lamb: Dictionary, delta: float, playing: bool, line: Array) -> void:
	var node: Sprite2D = lamb["node"]
	var at: Vector2 = lamb["at"]
	var state := str(lamb["state"])
	lamb["time"] = float(lamb["time"]) + delta
	var t := float(lamb["time"])
	var picture := "lamb_stand"
	var want := at
	var pace := 0.0
	var grow := 1.0
	match state:
		"lost":
			# Standing about, looking this way and that, calling for the others.
			picture = "lamb_sit" if fmod(t, 7.0) > 4.0 else "lamb_stand"
			if fmod(t, 3.1) < delta:
				lamb["flip"] = not bool(lamb["flip"])
			lamb["baa"] = float(lamb["baa"]) - delta
			if float(lamb["baa"]) <= 0.0 and playing:
				lamb["baa"] = randf_range(5.0, 9.0)
				_baa(lamb, -16.0)
			if playing and at.distance_to(who["at"]) < 96.0:
				lamb["state"] = "follow"
				lamb["time"] = 0.0
				host.spark(at + Vector2(0.0, -110.0), "heart")
				_baa(lamb)
		"stuck":
			picture = "lamb_sit"
			lamb["baa"] = float(lamb["baa"]) - delta
			if float(lamb["baa"]) <= 0.0 and playing:
				lamb["baa"] = randf_range(4.0, 7.0)
				_baa(lamb, -14.0)
		"follow":
			# Behind Adeline, or behind the lamb ahead of it in the line.
			var place := line.find(lamb)
			var ahead: Vector2 = who["at"] if place <= 0 else line[place - 1]["at"]
			if at.distance_to(ahead) > 86.0:
				want = ahead
				pace = 380.0
			picture = "lamb_jump" if t < 0.35 else "lamb_stand"
			# At the barn they go in one after another.
			if who["at"].distance_to(DOOR + Vector2(40.0, 60.0)) < 150.0 and place == 0 and t > 0.4 and gate <= 0.0:
				lamb["state"] = "home"
				lamb["time"] = 0.0
				gate = 0.4
		"scared":
			want = lamb["spot"]
			pace = 460.0
			if at.distance_to(want) < 8.0:
				lamb["state"] = "lost"
				lamb["time"] = 0.0
		"home":
			want = DOOR
			pace = 300.0 if over < 0.0 else 520.0  # at nightfall they run for the lantern
			if at.distance_to(DOOR) < 10.0:
				lamb["state"] = "in"
				lamb["time"] = 0.0
				home += 1
				host.burst(DOOR + Vector2(0.0, -70.0), "heart", 2)
				host.word(DOOR + Vector2(0.0, -150.0), "%d home!" % home)
				game.sound.play("chime", -8.0, 0.0, 0.9 + home * 0.08)
				game.sound.play("bleat", -12.0, 0.15)
		"in":
			# Hopping in through the doorway and out of sight.
			picture = "lamb_jump"
			grow = maxf(1.0 - t / 0.35, 0.0)
			at.y = DOOR.y - sin(minf(t / 0.35, 1.0) * PI) * 26.0
	if pace > 0.0 and at.distance_to(want) > 2.0:
		var to := want - at
		at += to.normalized() * minf(pace * delta, to.length())
		lamb["flip"] = to.x < 0.0
		lamb["step"] = float(lamb["step"]) + pace * delta
		picture = "lamb_walk_1" if fmod(float(lamb["step"]), 64.0) < 32.0 else "lamb_walk_2"
	lamb["at"] = at
	node.texture = art[picture]
	node.offset = Vector2(0.0, -node.texture.get_height() / 2.0)
	node.flip_h = bool(lamb["flip"])
	# A little bounce in the walk, and a breath when standing.
	var bob := absf(sin(float(lamb["step"]) * 0.1)) * 5.0 if pace > 0.0 else sin(host.clock * 2.4 + at.x) * 1.5
	var k: float = float(node.get_meta("size")) * host.depth(at.y) * grow
	node.scale = Vector2(k, k)
	node.position = at + Vector2(0.0, -bob)
	node.z_index = int(at.y) - (1 if state == "stuck" else 0)
	node.visible = grow > 0.0


func _fox(delta: float) -> void:
	fox_time += delta
	var size := float(fox.get_meta("size"))
	if fox_state == "":
		fox_next -= delta
		if fox_next <= 0.0:
			fox_state = "come"
			fox_time = 0.0
			fox.position = Vector2(host.SAFE.end.x + 150.0, randf_range(FIELD.position.y + 20.0, FIELD.end.y - 40.0))
			fox.visible = true
			game.sound.play("yip", -10.0, 0.1, 1.15)
		return
	var line := followers()
	if fox_state == "come":
		# Slinking toward the lamb at the back of the line, or just across the field.
		var target := Vector2(-200.0, fox.position.y)
		if not line.is_empty():
			target = line[line.size() - 1]["at"]
		var to := target - fox.position
		fox.position += to.normalized() * 150.0 * delta
		fox.flip_h = to.x < 0.0
		fox.texture = art["fox_1"] if fmod(fox_time, 0.36) < 0.18 else art["fox_2"]
		fox.offset = Vector2(0.0, -fox.texture.get_height() / 2.0 - absf(sin(fox_time * 17.0)) * 4.0)
		if not line.is_empty() and to.length() < 70.0:
			# Among the lambs. They bolt back to where they were.
			scares += 1
			for lamb in line:
				lamb["state"] = "scared"
			host.word(target + Vector2(0.0, -120.0), "Baa-aa!", Color(1.0, 0.8, 0.8))
			game.sound.play("bleat", -4.0, 0.2, 1.2)
			fox_state = "flee"
			fox_time = 0.0
		elif fox.position.x < host.SAFE.position.x - 160.0:
			fox_state = ""
			fox_next = randf_range(7.0, 11.0)
			fox.visible = false
	elif fox_state == "flee":
		# A jump of fright, then away to the right as fast as it can go.
		fox.texture = art["fox_scared"] if fox_time < 0.45 else (art["fox_1"] if fmod(fox_time, 0.2) < 0.1 else art["fox_2"])
		fox.offset = Vector2(0.0, -fox.texture.get_height() / 2.0 - (sin(fox_time / 0.45 * PI) * 40.0 if fox_time < 0.45 else 0.0))
		if fox_time >= 0.45:
			fox.flip_h = false
			fox.position.x += 620.0 * delta
		if fox.position.x > host.SAFE.end.x + 220.0:
			fox_state = ""
			fox_next = randf_range(8.0, 12.0)
			fox.visible = false
	var k: float = size * host.depth(fox.position.y)
	fox.scale = Vector2(k, k)
	fox.z_index = int(fox.position.y)


## Shadows under everyone, so they stand on the grass.
func _draw() -> void:
	var feet: Array = [[who["at"], 34.0]]
	for lamb in lambs:
		if str(lamb["state"]) != "in":
			feet.append([lamb["at"], 30.0])
	if fox.visible:
		feet.append([fox.position, 46.0])
	for f in feet:
		var k: float = host.depth(f[0].y)
		draw_set_transform(f[0], 0.0, Vector2(1.0, 0.3))
		draw_circle(Vector2.ZERO, float(f[1]) * k, Color(0.1, 0.12, 0.05, 0.28))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_top() -> void:
	# The ring that fills while she frees the lamb from the brambles.
	if str(lambs[STUCK]["state"]) == "stuck":
		var at: Vector2 = STARTS[STUCK] + Vector2(0.0, -170.0)
		var beat := 0.5 + 0.5 * sin(host.clock * 5.0)
		if free_time > 0.0:
			top.draw_arc(at, 24.0, -PI / 2.0, -PI / 2.0 + TAU * minf(free_time / 1.7, 1.0), 40, Color(1.0, 0.9, 0.4), 8.0)
		else:
			# Something here needs her: a bobbing mark.
			top.draw_rect(Rect2(at.x - 5.0, at.y - 22.0 - beat * 6.0, 10.0, 26.0), Color(1.0, 0.85, 0.2))
			top.draw_circle(Vector2(at.x, at.y + 16.0 - beat * 6.0), 6.0, Color(1.0, 0.85, 0.2))
	# A mark over the fox, so it is noticed and tapped.
	if fox_state == "come":
		var at: Vector2 = fox.position + Vector2(0.0, -150.0 * host.depth(fox.position.y))
		var beat := 0.5 + 0.5 * sin(host.clock * 9.0)
		top.draw_circle(at, 26.0 + beat * 5.0, Color(0.9, 0.2, 0.15, 0.85))
		top.draw_rect(Rect2(at.x - 4.0, at.y - 16.0, 8.0, 20.0), Color.WHITE)
		top.draw_circle(at + Vector2(0.0, 12.0), 4.5, Color.WHITE)
	# The lantern in the doorway glows brighter as the light goes.
	top.draw_circle(DOOR + Vector2(4.0, -110.0), 60.0, Color(1.0, 0.8, 0.4, 0.3 * clampf(sun / DAY + 0.2, 0.0, 1.0)))


func draw_ui(on: Control, s: Vector2) -> void:
	# The lambs brought home, and the sun going down.
	var box := Rect2(s.x / 2.0 - 330.0, 22.0, 660.0, 76.0)
	Ui.panel(on, box, Color(0.09, 0.11, 0.24, 0.72), Color(1.0, 0.86, 0.45, 0.9), 18.0)
	var icon: Texture2D = art["lamb_stand"]
	for i in lambs.size():
		var r := Rect2(box.position.x + 18.0 + i * 54.0, box.position.y + 12.0, 48.0, 53.0)
		on.draw_texture_rect(icon, r, false, Color(1.0, 1.0, 1.0, 1.0) if i < home else Color(1.0, 1.0, 1.0, 0.28))
	# The sun slides along its track and reddens as it sinks.
	var k := clampf(sun / DAY, 0.0, 1.0)
	var left := box.position.x + 372.0
	var right := box.end.x - 34.0
	on.draw_line(Vector2(left, box.get_center().y + 14.0), Vector2(right, box.get_center().y + 14.0), Color(1.0, 1.0, 1.0, 0.35), 6.0)
	var at := Vector2(lerpf(left, right, k), box.get_center().y + 14.0 - sin((1.0 - k) * PI * 0.5) * 22.0)
	on.draw_circle(at, 17.0, Color(1.0, 0.86, 0.3).lerp(Color(1.0, 0.4, 0.2), k))
	on.draw_arc(at, 22.0, 0.0, TAU, 24, Color(1.0, 0.9, 0.5, 0.5), 3.0)
	host._text(on, Vector2(right - 6.0, box.position.y + 30.0), "night", 15, Color(0.8, 0.85, 1.0), HORIZONTAL_ALIGNMENT_LEFT)
