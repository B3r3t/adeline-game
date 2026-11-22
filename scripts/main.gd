extends Node2D
## Mission 1, "Goblin Trouble", built from placeholder shapes, with Spirit the horse to ride.
## The home island is one long strip: Adeline's house and stable on the left,
## Merlin's hut, three goblin camps to the east, and the river with the boat at the far end.

const PlayerScript := preload("res://scripts/player.gd")
const GoblinScript := preload("res://scripts/goblin.gd")
const HillsScript := preload("res://scripts/hills.gd")
const HudScript := preload("res://scripts/hud.gd")
const TouchScript := preload("res://scripts/touch_controls.gd")
const DialogScript := preload("res://scripts/dialog.gd")
const HorseScript := preload("res://scripts/horse.gd")

const GROUND_Y := 560.0
const LEVEL_LEFT := 0.0
const LEVEL_RIGHT := 5400.0
const CAMERA_ZOOM := 1.4  # bigger characters are easier to read on an 8 inch screen

const HOUSE_X := 40.0  # left edge of the farmhouse
const STABLE_X := 549.0  # where Spirit waits, inside the stable
const START_X := 800.0
const HUT_X := 1150.0  # middle of Merlin's hut
const MERLIN_X := 1420.0
const SIGN_X := 1640.0
const GATE_X := 1760.0  # Adeline cannot head east until she has the mission
const RIVER_X := 5080.0
const TALK_RANGE := 120.0
const RIDE_RANGE := 100.0
const SAVE_PATH := "user://save.json"
const ART_SCALE := 1.0 / 2.2  # scenery art is drawn at 2.2 pixels per world pixel

# Five goblins in three camps. The first teaches the swing, the second the charge,
# and the third mixes both with one goblin attacking at a time.
const ENCOUNTERS := [
	{
		"trigger": 2000.0, "left": 1800.0, "right": 2700.0,
		"goblins": [{ "x": 2560.0, "attacks": "swing" }],
		"hint": "Its club goes up before it swings. Step back, then hit it while it sees stars.",
	},
	{
		"trigger": 3050.0, "left": 2850.0, "right": 3750.0,
		"goblins": [{ "x": 3610.0, "attacks": "charge" }],
		"hint": "This one crouches before it charges. Jump over it, then hit back.",
	},
	{
		"trigger": 4100.0, "left": 3900.0, "right": 4960.0,
		"goblins": [{ "x": 4660.0, "attacks": "both" }, { "x": 4790.0, "attacks": "both" }, { "x": 4920.0, "attacks": "both" }],
		"hint": "Three goblins! Only one attacks at a time. Watch for the warning.",
	},
]

var player = null
var horse = null
var merlin: Sprite2D
var boat: Sprite2D
var goblins: Array = []
var projectiles: Node2D
var camera: Camera2D
var hills_far: Node2D
var hills_near: Node2D
var hud = null
var controls = null
var dialog = null
var font: Font

var mode := "title"  # title or play
var data := {}  # saved progress
var encounter := {}  # the fight in progress, or empty
var encounter_kind := ""  # mission or practice
var attacker = null  # only one goblin attacks at a time
var defeated := false
var defeat_time := 0.0
var toast_text := ""
var toast_time := 0.0
var context_action := ""  # talk, boat or nothing
var new_game_armed := false
var clock := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	_setup_input()
	_build_backdrop()
	_build_ground()
	_build_scenery()

	projectiles = Node2D.new()
	add_child(projectiles)

	horse = Node2D.new()
	horse.set_script(HorseScript)
	horse.game = self
	add_child(horse)

	player = CharacterBody2D.new()
	player.set_script(PlayerScript)
	player.game = self
	add_child(player)

	camera = Camera2D.new()
	camera.limit_left = int(LEVEL_LEFT)
	camera.limit_right = int(LEVEL_RIGHT)
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)
	camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Control.new()
	hud.set_script(HudScript)
	hud.game = self
	layer.add_child(hud)
	controls = Control.new()
	controls.set_script(TouchScript)
	controls.game = self
	layer.add_child(controls)
	dialog = Control.new()
	dialog.set_script(DialogScript)
	dialog.game = self
	layer.add_child(dialog)

	_load()
	_place_player()
	camera.position = _camera_target()
	camera.reset_smoothing()


# --- Setup ------------------------------------------------------------------

func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_action("strike", [KEY_J, KEY_Z])
	_add_action("fireball", [KEY_K, KEY_X])
	_add_action("shield", [KEY_L, KEY_C])
	_add_action("interact", [KEY_E, KEY_ENTER])


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _build_backdrop() -> void:
	hills_far = Node2D.new()
	hills_far.set_script(HillsScript)
	hills_far.color = Color(0.62, 0.84, 0.72)
	hills_far.base_y = GROUND_Y - 40.0
	hills_far.amplitude = 190.0
	hills_far.wavelength = 900.0
	hills_far.z_index = -20
	add_child(hills_far)

	hills_near = Node2D.new()
	hills_near.set_script(HillsScript)
	hills_near.color = Color(0.45, 0.75, 0.5)
	hills_near.base_y = GROUND_Y - 10.0
	hills_near.amplitude = 110.0
	hills_near.wavelength = 520.0
	hills_near.phase = 1.7
	hills_near.z_index = -10
	add_child(hills_near)


func _build_ground() -> void:
	_add_wall(Rect2(LEVEL_LEFT - 400.0, GROUND_Y, LEVEL_RIGHT - LEVEL_LEFT + 800.0, 400.0))
	_add_wall(Rect2(LEVEL_LEFT - 200.0, GROUND_Y - 1200.0, 200.0, 1200.0))
	_add_wall(Rect2(LEVEL_RIGHT, GROUND_Y - 1200.0, 200.0, 1200.0))


## Scenery art sits behind the characters. Each piece stands on the ground line.
func _build_scenery() -> void:
	_add_scenery("house", HOUSE_X, false)
	_add_scenery("hut", HUT_X, true)
	merlin = _add_scenery("merlin", MERLIN_X, true)
	boat = _add_scenery("boat", RIVER_X + 210.0, true)


func _add_scenery(art: String, x: float, centred: bool) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load("res://art/props/%s.png" % art)
	sprite.centered = false
	sprite.scale = Vector2(ART_SCALE, ART_SCALE)
	var size := sprite.texture.get_size() * ART_SCALE
	sprite.position = Vector2(x - (size.x / 2.0 if centred else 0.0), GROUND_Y + 4.0 - size.y)
	add_child(sprite)
	return sprite


func _add_wall(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = rect.position + rect.size / 2.0
	body.add_child(col)
	add_child(body)


# --- Saved progress ---------------------------------------------------------

func _default_data() -> Dictionary:
	return { "m1": "available", "cleared": 0, "shield": false, "checkpoint_x": START_X, "practice_round": 1 }


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _load() -> void:
	data = _default_data()
	if not has_save():
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for key in data:
			if parsed.has(key):
				data[key] = parsed[key]


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))


func cleared() -> int:
	return int(data["cleared"])


func has_shield() -> bool:
	return bool(data["shield"])


# --- Starting and placing ---------------------------------------------------

func _start(new_game: bool) -> void:
	if new_game:
		data = _default_data()
	_save()
	new_game_armed = false
	mode = "play"
	_place_player()


func _place_player() -> void:
	_clear_goblins()
	encounter = {}
	encounter_kind = ""
	defeated = false
	var cx := float(data["checkpoint_x"])
	player.reset(Vector2(cx, GROUND_Y))
	# Spirit starts in the stable, or close by when continuing from far along the island.
	horse.place(STABLE_X if cx < 1000.0 else cx - 130.0)
	_update_limits()


func _update_limits() -> void:
	var lo := LEVEL_LEFT + 40.0
	var hi := RIVER_X - 30.0
	if data["m1"] == "available":
		hi = GATE_X
	if not encounter.is_empty():
		lo = float(encounter["left"])
		hi = float(encounter["right"])
	player.min_x = lo
	player.max_x = hi


func input_locked() -> bool:
	return mode != "play" or dialog.active or defeated


func toast(text: String) -> void:
	toast_text = text
	toast_time = 3.5


# --- Encounters -------------------------------------------------------------

func _begin_encounter(enc: Dictionary, kind: String) -> void:
	encounter = enc
	encounter_kind = kind
	_spawn_goblins()
	_update_limits()


func _clear_goblins() -> void:
	for g in goblins:
		if is_instance_valid(g):
			g.queue_free()
	goblins.clear()
	if projectiles != null:
		for p in projectiles.get_children():
			p.queue_free()
	attacker = null


func _spawn_goblins() -> void:
	_clear_goblins()
	var specs: Array = encounter["goblins"]
	for i in specs.size():
		var spec: Dictionary = specs[i]
		var g = CharacterBody2D.new()
		g.set_script(GoblinScript)
		g.game = self
		g.attacks = spec["attacks"]
		g.hold_slot = i
		g.think = 0.6 + 0.4 * i
		g.min_x = float(encounter["left"]) + 20.0
		g.max_x = float(encounter["right"]) - 10.0
		g.position = Vector2(float(spec["x"]), GROUND_Y)
		add_child(g)
		goblins.append(g)


func add_projectile(node: Node2D) -> void:
	projectiles.add_child(node)


func can_attack(goblin) -> bool:
	return attacker == null or not is_instance_valid(attacker) or attacker == goblin


func request_attack(goblin) -> bool:
	if can_attack(goblin):
		attacker = goblin
		return true
	return false


func release_attack(goblin) -> void:
	if attacker == goblin:
		attacker = null


func goblins_left() -> int:
	var n := 0
	for g in goblins:
		if is_instance_valid(g) and not g.is_dead():
			n += 1
	return n


func on_goblin_defeated(_goblin) -> void:
	if goblins_left() == 0 and not encounter.is_empty():
		_encounter_cleared()


func _encounter_cleared() -> void:
	if encounter_kind == "mission":
		data["cleared"] = cleared() + 1
		data["checkpoint_x"] = player.position.x
		toast("Goblins defeated! Progress saved.")
	else:
		data["practice_round"] = mini(int(data["practice_round"]) + 1, 3)
		toast("Practice fight won!")
	encounter = {}
	encounter_kind = ""
	attacker = null
	player.health = player.MAX_HEALTH
	_update_limits()
	_save()


func on_player_defeated() -> void:
	defeated = true
	defeat_time = 0.0


## Back to the start of the unfinished fight with full health. Nothing earned is lost.
func _retry() -> void:
	defeated = false
	player.reset(Vector2(float(encounter["left"]) + 90.0, GROUND_Y))
	_spawn_goblins()


func _check_triggers() -> void:
	if not encounter.is_empty() or data["m1"] != "active":
		return
	var n := cleared()
	if n >= ENCOUNTERS.size():
		return
	var enc: Dictionary = ENCOUNTERS[n]
	if player.position.x >= float(enc["trigger"]):
		if player.mounted:
			_dismount()
			toast("Spirit waits back here, safe from the goblins.")
		horse.retreat(float(enc["left"]) - 90.0)
		_begin_encounter(enc, "mission")


# --- Merlin, the boat and missions -------------------------------------------

func _update_context() -> void:
	context_action = ""
	if dialog.active or not encounter.is_empty():
		return
	var px: float = player.position.x
	if absf(px - MERLIN_X) <= TALK_RANGE:
		context_action = "talk"
	elif px >= RIVER_X - 160.0:
		context_action = "boat"
	elif player.mounted:
		context_action = "dismount"
	elif absf(px - horse.position.x) <= RIDE_RANGE:
		context_action = "ride"
	else:
		context_action = "call"


func merlin_has_news() -> bool:
	return data["m1"] == "available" or (data["m1"] == "active" and cleared() >= ENCOUNTERS.size())


func _interact() -> void:
	controls.release_all()
	if context_action == "ride":
		_mount()
	elif context_action == "dismount":
		_dismount()
	elif context_action == "call":
		horse.come()
	elif context_action == "talk":
		_dismount()
		_talk_to_merlin()
	elif context_action == "boat":
		_dismount()
		dialog.say("", ["The magic boat rocks gently on the river.", "It will fly to the other islands once the rescue mission is ready."])


func _mount() -> void:
	if not player.is_on_floor():
		return
	player.mounted = true
	player.position.x = horse.position.x
	player.facing = horse.facing
	horse.set_mounted(true)


func _dismount() -> void:
	if not player.mounted:
		return
	player.mounted = false
	horse.set_mounted(false)
	horse.position = Vector2(player.position.x, GROUND_Y)
	player.position.x += player.facing * 80.0


func _talk_to_merlin() -> void:
	var m1: String = data["m1"]
	if m1 == "available":
		dialog.say("Merlin", [
			"Adeline! Thank goodness you're here.",
			"Goblins are causing trouble all over our island. They work for the ogre across the water.",
			"Pick a mission and I'll tell you what to do.",
		], _show_missions)
	elif m1 == "active" and cleared() < ENCOUNTERS.size():
		dialog.say("Merlin", [
			"The goblins are east of here, past the signpost.",
			"Watch what a goblin does before it attacks. It always gives itself away.",
		])
	elif m1 == "active":
		dialog.say("Merlin", [
			"You did it! The island is safe again.",
			"Here is your reward: the Magic Shield.",
			"Tap SHIELD just before an attack lands and it will bounce right off.",
		], _give_shield)
	else:
		_show_missions()


func _show_missions() -> void:
	var m1: String = data["m1"]
	var status := { "available": "Available", "active": "Active", "done": "Completed" }
	var rows := [
		{ "id": "m1", "label": "Goblin Trouble", "status": status[m1], "enabled": m1 == "available" },
		{ "id": "m2", "label": "Rescue Adeline's Parents", "status": "Coming soon" if m1 == "done" else "Locked", "enabled": false },
	]
	if m1 == "done":
		var n := int(data["practice_round"])
		rows.append({ "id": "practice", "label": "Practice fight: %d goblin%s" % [n, "" if n == 1 else "s"], "status": "Ready", "enabled": true })
	dialog.choose("Merlin's missions", rows, _on_mission_picked)


func _on_mission_picked(id: String) -> void:
	if id == "m1":
		data["m1"] = "active"
		_update_limits()
		_save()
		dialog.say("Merlin", [
			"Head east past the signpost and send those goblins packing.",
			"Your wand strikes fast up close. Your fireball hits three times as hard, but it needs a moment between casts.",
		])
	elif id == "practice":
		_begin_practice()


func _give_shield() -> void:
	data["m1"] = "done"
	data["shield"] = true
	_save()
	toast("New spell: Magic Shield!")


func _begin_practice() -> void:
	_dismount()
	horse.retreat(MERLIN_X - 260.0)
	var n := int(data["practice_round"])
	var specs := []
	for i in n:
		specs.append({ "x": MERLIN_X + 680.0 + 130.0 * i, "attacks": "both" })
	_begin_encounter({
		"left": MERLIN_X - 150.0, "right": MERLIN_X + 1100.0, "goblins": specs,
		"hint": "Practice: tap SHIELD just before an attack lands.",
	}, "practice")


# --- Text for the top of the screen -----------------------------------------

func objective() -> String:
	if not encounter.is_empty():
		var total: int = encounter["goblins"].size()
		if total == 1:
			return "Defeat the goblin"
		return "Defeat the goblins: %d left" % goblins_left()
	var m1: String = data["m1"]
	if m1 == "available":
		return "Talk to Merlin"
	if m1 == "active":
		return "Find the goblins" if cleared() < ENCOUNTERS.size() else "Return to Merlin"
	return "Mission complete"


func hint() -> String:
	if mode != "play" or dialog.active or defeated:
		return ""
	if not encounter.is_empty():
		return str(encounter.get("hint", ""))
	var m1: String = data["m1"]
	if m1 == "available":
		if context_action == "talk":
			return "Tap TALK to speak with Merlin."
		if context_action == "ride":
			return "Tap RIDE to hop on Spirit."
		if player.mounted:
			return "Ride right. Merlin is waiting by his hut."
		return "Tap CALL and Spirit will come to you. Merlin is waiting to the right."
	if m1 == "active":
		if cleared() < ENCOUNTERS.size():
			return "Head east past the signpost. Spirit can carry you there fast."
		return "The goblins are gone. Call Spirit and ride back west to Merlin."
	return "Talk to Merlin for a practice fight and try your new shield."


# --- Loop -------------------------------------------------------------------

func new_game_rect() -> Rect2:
	var s := get_viewport_rect().size
	return Rect2(s.x / 2.0 - 190.0, s.y * 0.76, 380.0, 64.0)


func _unhandled_input(event: InputEvent) -> void:
	var tapped := false
	var has_pos := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch and event.pressed:
		tapped = true
		has_pos = true
		pos = event.position
	elif event is InputEventKey and event.pressed and not event.echo:
		tapped = true
	if not tapped:
		return
	if mode == "title":
		if clock < 0.5:
			return
		if has_save() and has_pos and new_game_rect().has_point(pos):
			if new_game_armed:
				_start(true)
			else:
				new_game_armed = true
		else:
			_start(not has_save())
	elif defeated and defeat_time >= 1.0:
		_retry()


func _physics_process(delta: float) -> void:
	if mode != "play":
		return
	if defeated:
		defeat_time += delta
		return
	_update_context()
	if dialog.active:
		return
	if Input.is_action_just_pressed("interact") and context_action != "":
		_interact()
		return
	_check_triggers()
	if data["m1"] == "available" and player.position.x >= GATE_X - 2.0 and toast_time <= 0.0:
		toast("Talk to Merlin first. He is back by his hut.")


func _camera_target() -> Vector2:
	var view_h := get_viewport_rect().size.y
	# Keep the ground about three quarters of the way down the screen on any device.
	return Vector2(player.position.x + player.facing * 60.0, GROUND_Y - 0.24 * view_h / CAMERA_ZOOM)


func _process(delta: float) -> void:
	clock += delta
	toast_time = maxf(toast_time - delta, 0.0)
	goblins = goblins.filter(func(g): return is_instance_valid(g))
	camera.position = _camera_target()
	var cam_x := camera.get_screen_center_position().x
	hills_far.position.x = cam_x * 0.85
	hills_near.position.x = cam_x * 0.6
	# Merlin turns to face Adeline, and the boat hovers over the river.
	merlin.flip_h = player.position.x < MERLIN_X
	var boat_h := boat.texture.get_size().y * ART_SCALE
	boat.position.y = GROUND_Y + 34.0 - boat_h + sin(clock * 2.0) * 5.0
	queue_redraw()


# --- Placeholder scenery ----------------------------------------------------

func _draw() -> void:
	var g := GROUND_Y
	# Grass and dirt.
	var left := LEVEL_LEFT - 400.0
	var width := LEVEL_RIGHT - LEVEL_LEFT + 800.0
	draw_rect(Rect2(left, g, width, 600.0), Color(0.42, 0.3, 0.2))
	draw_rect(Rect2(left, g, width, 26.0), Color(0.36, 0.72, 0.3))
	var x := LEVEL_LEFT
	var i := 0
	while x <= RIVER_X:
		draw_circle(Vector2(x + 90.0, g + 60.0 + (i % 3) * 30.0), 10.0, Color(0.36, 0.25, 0.17))
		draw_rect(Rect2(x + 30.0, g - 8.0, 5.0, 8.0), Color(0.3, 0.62, 0.26))
		draw_rect(Rect2(x + 42.0, g - 12.0, 5.0, 12.0), Color(0.3, 0.62, 0.26))
		x += 200.0
		i += 1

	_draw_merlin_mark(g)
	_draw_sign(g)
	for n in ENCOUNTERS.size():
		if n >= cleared():
			var enc: Dictionary = ENCOUNTERS[n]
			_draw_camp(float(enc["right"]) - 60.0, g)
	_draw_river(g)


func _draw_merlin_mark(g: float) -> void:
	# A bobbing mark over Merlin when he has something new to say.
	if mode == "play" and merlin_has_news():
		var bob := sin(clock * 4.0) * 5.0
		draw_rect(Rect2(MERLIN_X - 5.0, g - 226.0 + bob, 10.0, 26.0), Color(1.0, 0.85, 0.2))
		draw_circle(Vector2(MERLIN_X, g - 188.0 + bob), 6.0, Color(1.0, 0.85, 0.2))


func _draw_sign(g: float) -> void:
	draw_rect(Rect2(SIGN_X - 4.0, g - 96.0, 8.0, 96.0), Color(0.45, 0.3, 0.17))
	draw_colored_polygon(PackedVector2Array([
		Vector2(SIGN_X - 62.0, g - 110.0), Vector2(SIGN_X + 48.0, g - 110.0), Vector2(SIGN_X + 76.0, g - 88.0),
		Vector2(SIGN_X + 48.0, g - 66.0), Vector2(SIGN_X - 62.0, g - 66.0),
	]), Color(0.72, 0.55, 0.32))
	draw_string(font, Vector2(SIGN_X - 56.0, g - 80.0), "GOBLINS", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 18, Color(0.25, 0.15, 0.08))


func _draw_camp(cx: float, g: float) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 60.0, g), Vector2(cx, g - 84.0), Vector2(cx + 60.0, g)]), Color(0.3, 0.4, 0.25))
	draw_colored_polygon(PackedVector2Array([Vector2(cx - 16.0, g), Vector2(cx, g - 46.0), Vector2(cx + 16.0, g)]), Color(0.12, 0.16, 0.1))
	draw_rect(Rect2(cx - 2.0, g - 122.0, 4.0, 40.0), Color(0.4, 0.26, 0.15))
	draw_colored_polygon(PackedVector2Array([Vector2(cx + 2.0, g - 122.0), Vector2(cx + 34.0, g - 112.0), Vector2(cx + 2.0, g - 100.0)]), Color(0.75, 0.2, 0.2))


func _draw_river(g: float) -> void:
	draw_rect(Rect2(RIVER_X, g + 6.0, 800.0, 600.0), Color(0.25, 0.55, 0.85))
	draw_rect(Rect2(RIVER_X, g + 6.0, 800.0, 10.0), Color(0.6, 0.82, 0.98))
