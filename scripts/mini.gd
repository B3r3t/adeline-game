extends Control
## The farm games: five little games reached from the title screen. Three are Adeline's
## own (picking apples for Grandma's pie, bringing the lost lambs home, mixing potions
## with Merlin) and two she plays with her little sister (hide and seek in the farmyard,
## washing the muddy pony).
##
## This is the frame they all run in. It shows the list to choose from, sets up the
## painted scene a game is played on, hands touches to the game, and when a game is over
## shows the stars won and saves the best. Each game is its own short script
## (`mini_apples.gd` and so on) and only has to say what happens in it.
##
## Every scene is painted 1344 by 752 and is scaled to cover the screen, so on a long
## phone a strip is lost off the top and bottom, and on a squarer tablet off the sides.
## Games keep everything that matters inside `SAFE`.

const Ui := preload("res://scripts/ui.gd")
const RigScript := preload("res://scripts/rig.gd")
const Moves := preload("res://scripts/moves.gd")

const W := 1344.0
const H := 752.0
const SAFE := Rect2(84.0, 84.0, 1176.0, 588.0)

const LIST := [
	{ "id": "apples", "name": "Apple picking", "who": "Adeline", "line": "Catch what Grandma needs for her pie.", "scene": "orchard", "view": [0.5, 0.52, 0.8], "color": Color(0.82, 0.26, 0.22), "script": preload("res://scripts/mini_apples.gd") },
	{ "id": "lambs", "name": "Lost lambs", "who": "Adeline", "line": "Bring the lambs home before the sun sets.", "scene": "meadow", "view": [0.27, 0.36, 0.62], "color": Color(0.3, 0.62, 0.34), "script": preload("res://scripts/mini_lambs.gd") },
	{ "id": "potions", "name": "Merlin's potions", "who": "Adeline", "line": "Watch what Merlin puts in, then do the same.", "scene": "hut", "view": [0.5, 0.48, 0.8], "color": Color(0.5, 0.34, 0.8), "script": preload("res://scripts/mini_potions.gd") },
	{ "id": "hide", "name": "Hide and seek", "who": "With her sister", "line": "Where is she hiding? Watch for a peek.", "scene": "yard", "view": [0.33, 0.4, 0.7], "color": Color(0.9, 0.56, 0.16), "script": preload("res://scripts/mini_hide.gd") },
	{ "id": "wash", "name": "Pony wash", "who": "With her sister", "line": "Scrub off the mud, then rinse off the soap.", "scene": "wash", "view": [0.36, 0.5, 0.8], "color": Color(0.2, 0.6, 0.82), "script": preload("res://scripts/mini_wash.gd") },
]

var game = null
var font: Font
var stage: Node2D = null
var fx: Node2D = null
var overlay: Control = null
var play = null  # the game being played
var which := -1  # its place in LIST
var state := ""  # "intro" (the card saying what to do), "play" or "done"
var state_time := 0.0
var clock := 0.0
var stars := 0
var said := ""  # the line on the results panel
var rung := 0
var list_age := 0.0
var sparks: Array = []  # little things flying about: each a Dictionary
var words: Array = []  # words that pop up and drift: [where, text, colour, age]
var thumbs := {}
var finger := -1  # the touch a game is following
var sizes := {}  # how wide each picture in art/mini is drawn, by name


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	get_viewport().size_changed.connect(_layout)


# --- The list ---------------------------------------------------------------------

func open_list() -> void:
	close()
	game.mode = "games"
	list_age = 0.0
	game.sound.play("pop", -8.0)


func back_rect() -> Rect2:
	return Rect2(36.0, 30.0, 150.0, 54.0)


## Where each game's card is on the list: three of Adeline's, then the two with her sister.
func card_rect(i: int) -> Rect2:
	var s := get_viewport_rect().size
	var gap := 16.0
	var wide := minf((s.x - 72.0 - gap * 4.0 - 24.0) / 5.0, 250.0)
	var all := wide * 5.0 + gap * 4.0 + 24.0
	var left := (s.x - all) / 2.0
	return Rect2(left + i * (wide + gap) + (24.0 if i >= 3 else 0.0), s.y * 0.5 - 150.0 + 26.0, wide, 330.0)


func best(id: String) -> int:
	return int(game.data["mini_stars"].get(id, 0))


func total_stars() -> int:
	var sum := 0
	for info in LIST:
		sum += best(str(info["id"]))
	return sum


# --- Starting and stopping a game -----------------------------------------------------

func start(i: int) -> void:
	close()
	which = i
	var info: Dictionary = LIST[i]
	game.mode = "mini"
	stage = Node2D.new()
	add_child(stage)
	var backdrop := Sprite2D.new()
	backdrop.texture = load("res://art/mini/%s.jpg" % info["scene"])
	backdrop.centered = false
	backdrop.scale = Vector2(W, H) / backdrop.texture.get_size()
	backdrop.z_index = -100
	stage.add_child(backdrop)
	fx = Node2D.new()
	fx.z_index = 3500
	fx.draw.connect(_draw_fx)
	stage.add_child(fx)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 4000  # words and panels stay in front of everything in the scene
	overlay.draw.connect(_draw_ui)
	add_child(overlay)
	_layout()
	play = Node2D.new()
	play.set_script(info["script"])
	play.host = self
	play.game = game
	stage.add_child(play)
	play.begin()
	state = "intro"
	state_time = 0.0
	stars = 0
	rung = 0


func close() -> void:
	if stage != null:
		stage.queue_free()
		overlay.queue_free()
	stage = null
	overlay = null
	fx = null
	play = null
	which = -1
	state = ""
	finger = -1
	sparks.clear()
	words.clear()


## Called by a game when it is over.
func finish(won: int, line: String) -> void:
	if state != "play":
		return
	state = "done"
	state_time = 0.0
	stars = clampi(won, 1, 3)
	said = line
	var id := str(LIST[which]["id"])
	if stars > best(id):
		game.data["mini_stars"][id] = stars
		game._save()
	game.sound.play("fanfare", -5.0)
	for i in 40:
		spark(Vector2(randf_range(SAFE.position.x, SAFE.end.x), SAFE.position.y - randf() * 120.0), "confetti")


func playing() -> bool:
	return state == "play"


func _layout() -> void:
	if stage == null:
		return
	var s := get_viewport_rect().size
	var k := maxf(s.x / W, s.y / H)
	stage.scale = Vector2(k, k)
	stage.position = (s - Vector2(W, H) * k) / 2.0


func to_stage(screen: Vector2) -> Vector2:
	return (screen - stage.position) / stage.scale.x


func to_screen(at: Vector2) -> Vector2:
	return at * stage.scale.x + stage.position


# --- Things the games build their scenes from -----------------------------------------

## How wide the picture called `name` is meant to be drawn, from the list the art was built with.
func picture_size(name: String) -> float:
	if sizes.is_empty():
		sizes = JSON.parse_string(FileAccess.get_file_as_string("res://art/mini/sizes.json"))
	return float(sizes[name])


## A picture in the scene, standing on `foot` and drawn `wide` across.
func picture(path: String, foot: Vector2, wide: float, z := 0) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	var k := wide / sprite.texture.get_width()
	sprite.scale = Vector2(k, k)
	sprite.offset = Vector2(0.0, -sprite.texture.get_height() / 2.0)
	sprite.position = foot
	sprite.z_index = z
	stage.add_child(sprite)
	return sprite


## Adeline or her sister, as a walker: the paper puppet and where she is going.
func girl(folder: String, at: Vector2, size: float) -> Dictionary:
	var rig := Node2D.new()
	rig.set_script(RigScript)
	stage.add_child(rig)
	rig.build(folder)
	if folder.ends_with("sister"):
		var Sister = load("res://scripts/sister.gd")
		Sister.wear_hair(rig, int(game.data.get("hair", 0)))
	var who := { "rig": rig, "at": at, "goal": at, "facing": 1, "walk": 0.0, "size": size, "speed": 300.0, "moving": false, "hop": 0.0 }
	step(who, 0.0)
	rig.snap()
	return who


## Moves a walker toward her goal and poses her: walking, or standing and breathing.
## `extra` is laid over the pose, for an arm holding something out, say.
func step(who: Dictionary, delta: float, extra := {}, depth := 1.0) -> void:
	var rig = who["rig"]
	var pose: Dictionary = Moves.girl_idle(clock + float(who["size"]))
	var to: Vector2 = who["goal"] - who["at"]
	who["moving"] = to.length() > 4.0
	if who["moving"]:
		var pace: float = who["speed"]
		who["at"] += to.normalized() * minf(pace * delta, to.length())
		if absf(to.x) > 3.0:
			who["facing"] = 1 if to.x > 0.0 else -1
		who["walk"] = float(who["walk"]) + pace * delta * 0.026 / maxf(float(who["size"]) / 2.3, 0.5)
		pose = Moves.girl_run(float(who["walk"]), clampf((pace - 200.0) / 400.0, 0.2, 1.0))
	for part in extra:
		pose[part] = extra[part]
	var lift: float = pose.get("_lift", 0.0)
	pose.erase("_lift")
	# A hop for joy: up and down once.
	who["hop"] = maxf(float(who["hop"]) - delta, 0.0)
	lift -= sin(float(who["hop"]) / 0.4 * PI) * 16.0 if float(who["hop"]) > 0.0 else 0.0
	rig.pose = pose
	rig.root_offset = Vector2(0.0, lift)
	rig.apply(delta if delta > 0.0 else -1.0)
	rig.position = who["at"]
	var size: float = float(who["size"]) * depth
	rig.scale = Vector2(size * int(who["facing"]), size)
	rig.z_index = int(who["at"].y)


## How big something looks standing this far down the picture: smaller further back.
func depth(y: float) -> float:
	return lerpf(0.78, 1.06, clampf((y - 330.0) / 360.0, 0.0, 1.0))


## A little thing that flies off and fades: "star", "heart", "leaf", "bubble", "drop",
## "smoke" or "confetti".
func spark(at: Vector2, kind: String, color := Color.WHITE, push := Vector2.ZERO) -> void:
	var s := { "at": at, "kind": kind, "color": color, "age": 0.0, "life": 0.8, "size": randf_range(6.0, 11.0), "spin": randf() * TAU, "vel": push + Vector2(randf_range(-90.0, 90.0), randf_range(-160.0, -40.0)), "pull": 320.0 }
	match kind:
		"bubble":
			s["vel"] = push + Vector2(randf_range(-30.0, 30.0), randf_range(-70.0, -20.0))
			s["pull"] = -20.0
			s["life"] = randf_range(0.7, 1.3)
			s["size"] = randf_range(5.0, 13.0)
		"smoke":
			s["vel"] = push + Vector2(randf_range(-40.0, 40.0), randf_range(-110.0, -50.0))
			s["pull"] = -30.0
			s["life"] = 1.1
			s["size"] = randf_range(14.0, 26.0)
		"heart":
			s["vel"] = Vector2(randf_range(-20.0, 20.0), -70.0)
			s["pull"] = 0.0
			s["life"] = 1.1
			s["size"] = 13.0
		"confetti":
			s["vel"] = Vector2(randf_range(-60.0, 60.0), randf_range(60.0, 220.0))
			s["pull"] = 120.0
			s["life"] = 2.6
			s["color"] = Color.from_hsv(randf(), 0.75, 1.0)
		"drop":
			s["life"] = 0.5
			s["size"] = randf_range(3.0, 6.0)
		"leaf":
			s["vel"] = Vector2(randf_range(-50.0, 50.0), randf_range(20.0, 60.0))
			s["pull"] = 40.0
			s["life"] = 1.6
	sparks.append(s)


func burst(at: Vector2, kind: String, amount: int, color := Color.WHITE) -> void:
	for i in amount:
		spark(at + Vector2(randf_range(-10.0, 10.0), randf_range(-10.0, 10.0)), kind, color)


## A word that pops up out of something and drifts away.
func word(at: Vector2, text: String, color := Color(1.0, 0.95, 0.6)) -> void:
	words.append([at, text, color, 0.0])


func _draw_fx() -> void:
	for s in sparks:
		var k: float = float(s["age"]) / float(s["life"])
		var c: Color = s["color"]
		var at: Vector2 = s["at"]
		var size: float = s["size"]
		match str(s["kind"]):
			"star":
				Ui.star(fx, at, size * (1.0 - k * 0.5), true)
			"heart":
				Ui.heart(fx, at, size * minf(k * 6.0, 1.0), true)
			"bubble":
				fx.draw_circle(at, size, Color(1.0, 1.0, 1.0, 0.5 * (1.0 - k)))
				fx.draw_arc(at, size, 0.0, TAU, 20, Color(0.75, 0.92, 1.0, 0.9 * (1.0 - k)), 1.5)
				fx.draw_circle(at + Vector2(-size * 0.35, -size * 0.35), size * 0.22, Color(1.0, 1.0, 1.0, 0.9 * (1.0 - k)))
			"smoke":
				fx.draw_circle(at, size * (0.6 + k), Color(c.r, c.g, c.b, 0.55 * (1.0 - k)))
			"drop":
				fx.draw_circle(at, size, Color(0.55, 0.82, 1.0, 0.9 * (1.0 - k)))
			"leaf":
				fx.draw_set_transform(at, float(s["spin"]) + k * 4.0, Vector2(1.0, 0.5))
				fx.draw_circle(Vector2.ZERO, size, Color(0.35, 0.68, 0.2, 1.0 - k))
				fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			_:
				fx.draw_set_transform(at, float(s["spin"]) + k * 9.0, Vector2(1.0, 0.6))
				fx.draw_rect(Rect2(-size / 2.0, -size / 2.0, size, size), Color(c.r, c.g, c.b, minf((1.0 - k) * 3.0, 1.0)))
				fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	for w in words:
		var age: float = w[3]
		var c: Color = w[2]
		var grown := maxf(Ui.pop(age / 0.22), 0.01)
		var at: Vector2 = w[0] + Vector2(0.0, -age * 50.0)
		var wide := font.get_string_size(str(w[1]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 34).x
		fx.draw_set_transform(at, 0.0, Vector2(grown, grown))
		var fade := clampf((1.1 - age) * 3.0, 0.0, 1.0)
		fx.draw_string_outline(font, Vector2(-wide / 2.0, 0.0), str(w[1]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 34, 8, Color(0.12, 0.08, 0.2, fade))
		fx.draw_string(font, Vector2(-wide / 2.0, 0.0), str(w[1]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 34, Color(c.r, c.g, c.b, fade))
		fx.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


# --- Every frame ----------------------------------------------------------------------

func _process(delta: float) -> void:
	if game == null:
		return
	visible = game.mode == "games" or game.mode == "mini"
	if game.mode == "games":
		list_age += delta
		queue_redraw()
		return
	if game.mode != "mini" or play == null:
		return
	clock += delta
	state_time += delta
	for s in sparks:
		s["age"] = float(s["age"]) + delta
		s["vel"] = s["vel"] + Vector2(0.0, float(s["pull"]) * delta)
		s["at"] = s["at"] + s["vel"] * delta
	sparks = sparks.filter(func(s): return float(s["age"]) < float(s["life"]))
	for w in words:
		w[3] = float(w[3]) + delta
	words = words.filter(func(w): return float(w[3]) < 1.1)
	play.frame(delta)
	fx.queue_redraw()
	overlay.queue_redraw()
	queue_redraw()


# --- Touch ----------------------------------------------------------------------------

func again_rect() -> Rect2:
	var p := _done_panel()
	return Rect2(p.position.x + 36.0, p.end.y - 104.0, p.size.x / 2.0 - 48.0, 72.0)


func more_rect() -> Rect2:
	var p := _done_panel()
	return Rect2(p.position.x + p.size.x / 2.0 + 12.0, p.end.y - 104.0, p.size.x / 2.0 - 48.0, 72.0)


func _done_panel() -> Rect2:
	var s := get_viewport_rect().size
	return Rect2(s.x / 2.0 - 340.0, s.y / 2.0 - 200.0, 680.0, 400.0)


func _input(event: InputEvent) -> void:
	if game == null or game.menu != "" or not (game.mode == "games" or game.mode == "mini"):
		return
	if event is InputEventScreenTouch:
		if event.pressed and game.mode == "mini" and game.menu_rect().has_point(event.position):
			return  # the menu button: the game itself answers that
		if game.mode == "games":
			if event.pressed and list_age > 0.35:
				_tap_list(event.position)
		elif state == "intro":
			if event.pressed and state_time > 0.5:
				state = "play"
				state_time = 0.0
				game.sound.play("chime", -8.0)
				play.go()
		elif state == "done":
			if event.pressed and state_time > 1.0:
				if again_rect().has_point(event.position):
					start(which)
				elif more_rect().has_point(event.position):
					open_list()
		elif event.pressed:
			finger = event.index
			play.press(to_stage(event.position))
		elif event.index == finger:
			finger = -1
			play.release(to_stage(event.position))
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and game.mode == "mini" and state == "play" and event.index == finger:
		play.drag(to_stage(event.position))
		get_viewport().set_input_as_handled()


func _tap_list(pos: Vector2) -> void:
	if back_rect().has_point(pos):
		game.go_title()
		game.sound.play("pop", -8.0, 0.0, 0.9)
		return
	for i in LIST.size():
		if card_rect(i).has_point(pos):
			game.sound.play("pop", -8.0, 0.0, 1.2)
			start(i)
			return


# --- Drawing ---------------------------------------------------------------------------

func _text(on: CanvasItem, pos: Vector2, text: String, text_size: int, color: Color, align := HORIZONTAL_ALIGNMENT_LEFT, width := -1.0) -> void:
	on.draw_string_outline(font, pos, text, align, width, text_size, 6, Color(0.1, 0.08, 0.2, color.a * 0.85))
	on.draw_string(font, pos, text, align, width, text_size, color)


## A line of words on a dark plate across the top of a game: what to do now.
func banner(on: CanvasItem, text: String, y := 34.0) -> void:
	var s := get_viewport_rect().size
	var wide := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26).x + 56.0
	Ui.plate(on, Rect2((s.x - wide) / 2.0, y, wide, 48.0), Color(0.09, 0.11, 0.24, 0.6))
	_text(on, Vector2(0.0, y + 33.0), text, 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s.x)


func _draw() -> void:
	if game == null or game.mode != "games":
		return
	var s := get_viewport_rect().size
	# The title painting, dimmed, behind the cards.
	var art: Texture2D = load("res://art/ui/title.jpg")
	var size := art.get_size()
	var k := maxf(s.x / size.x, s.y / size.y)
	var shown := s / k
	draw_texture_rect_region(art, Rect2(Vector2.ZERO, s), Rect2((size.x - shown.x) / 2.0, 0.0, shown.x, shown.y))
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.06, 0.18, 0.72))
	var head := (1.0 - Ui.ease(list_age / 0.4)) * -90.0
	_text(self, Vector2(0.0, 74.0 + head), "Farm games", 46, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	Ui.button(self, font, back_rect(), "Back", 22, Color(0.09, 0.11, 0.24, 0.7))
	var won := total_stars()
	Ui.star(self, Vector2(s.x - 150.0, 56.0), 15.0, true)
	_text(self, Vector2(s.x - 128.0, 66.0), "%d of %d" % [won, LIST.size() * 3], 24, Color.WHITE)
	for group in [[0, 2, "Adeline's games"], [3, 4, "With her little sister"]]:
		var a := card_rect(int(group[0]))
		var b := card_rect(int(group[1]))
		_text(self, Vector2(a.position.x, a.position.y - 16.0), str(group[2]), 22, Color(1.0, 0.95, 0.75), HORIZONTAL_ALIGNMENT_CENTER, b.end.x - a.position.x)
	for i in LIST.size():
		var info: Dictionary = LIST[i]
		var r := card_rect(i)
		r.position.y += (1.0 - Ui.pop((list_age - 0.08 - i * 0.07) / 0.45)) * 520.0  # they come up one after another
		var c: Color = info["color"]
		Ui.button(self, font, r, "", 20, Color(c.r, c.g, c.b, 0.97))
		# A window onto the scene it is played in.
		var scene := str(info["scene"])
		if not thumbs.has(scene):
			thumbs[scene] = load("res://art/mini/%s.jpg" % scene)
		var view := Rect2(r.position.x + 12.0, r.position.y + 12.0, r.size.x - 24.0, 150.0)
		var tex: Texture2D = thumbs[scene]
		# The part of the painting that shows what the game is about.
		var look: Array = info["view"]
		var cut := Vector2(view.size.x / view.size.y, 1.0) * tex.get_size().y * float(look[2])
		var corner := Vector2(tex.get_size().x * float(look[0]), tex.get_size().y * float(look[1])) - cut / 2.0
		corner = corner.clamp(Vector2.ZERO, tex.get_size() - cut)
		draw_texture_rect_region(tex, view, Rect2(corner, cut))
		draw_rect(view, Color(1.0, 1.0, 1.0, 0.9), false, 3.0)
		_text(self, Vector2(r.position.x, r.position.y + 200.0), str(info["name"]), 25, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		draw_multiline_string(font, Vector2(r.position.x + 14.0, r.position.y + 230.0), str(info["line"]), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 28.0, 17, 2, Color(1.0, 0.97, 0.85))
		for n in 3:
			Ui.star(self, Vector2(r.get_center().x + (n - 1) * 34.0, r.end.y - 30.0), 13.0, n < best(str(info["id"])))


func _draw_ui() -> void:
	if play == null:
		return
	var s := get_viewport_rect().size
	if state == "play":
		play.draw_ui(overlay, s)
	elif state == "intro":
		overlay.draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.05, 0.14, 0.45))
		var info: Dictionary = LIST[which]
		var panel := Rect2(s.x / 2.0 - 380.0, s.y / 2.0 - 160.0, 760.0, 320.0)
		var grown := maxf(Ui.pop(state_time / 0.3), 0.001)
		overlay.draw_set_transform(panel.get_center() * (1.0 - grown), 0.0, Vector2(grown, grown))
		Ui.panel(overlay, panel)
		_text(overlay, Vector2(panel.position.x, panel.position.y + 78.0), str(info["name"]), 46, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		overlay.draw_multiline_string(font, Vector2(panel.position.x + 40.0, panel.position.y + 138.0), str(play.how()), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 80.0, 25, 3, Color.WHITE)
		var beat := 0.6 + 0.4 * sin(clock * 4.0)
		_text(overlay, Vector2(panel.position.x, panel.end.y - 34.0), "Tap to start", 28, Color(1.0, 0.95, 0.7, beat), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	elif state == "done" and state_time > 0.6:
		var age := state_time - 0.6
		var panel := _done_panel()
		overlay.draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.05, 0.14, 0.4 * minf(age / 0.3, 1.0)))
		var grown := maxf(Ui.pop(age / 0.3), 0.001)
		overlay.draw_set_transform(panel.get_center() * (1.0 - grown), 0.0, Vector2(grown, grown))
		Ui.panel(overlay, panel)
		_text(overlay, Vector2(panel.position.x, panel.position.y + 70.0), "Well done!", 46, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		_text(overlay, Vector2(panel.position.x + 20.0, panel.position.y + 236.0), said, 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x - 40.0)
		Ui.button(overlay, font, again_rect(), "Play again", 26, Color(0.26, 0.6, 0.36, 0.95))
		Ui.button(overlay, font, more_rect(), "More games", 26, Color(0.25, 0.42, 0.8, 0.95))
		overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		# The stars arrive one at a time, each with a higher chime.
		if age < 0.2:
			rung = 0
		for i in 3:
			var at := Vector2(panel.get_center().x + (i - 1) * 110.0, panel.position.y + 140.0)
			var mine := age - 0.45 - i * 0.32
			if mine <= 0.0 or i >= stars:
				if age > 0.3:
					Ui.star(overlay, at, 44.0, false)
				continue
			if rung <= i:
				rung = i + 1
				game.sound.play("chime", -7.0, 0.0, 1.0 + i * 0.16)
			var k := maxf(Ui.pop(mine / 0.34), 0.001)
			Ui.star(overlay, at, 44.0, false)
			overlay.draw_set_transform(at * (1.0 - k), 0.0, Vector2(k, k))
			Ui.star(overlay, at, 44.0, true)
			overlay.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
