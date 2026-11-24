extends Node2D
## Mission 1, "Goblin Trouble", built from placeholder shapes, with Spirit the horse to ride.
## The home island is one long strip: Adeline's house and stable on the left,
## Merlin's hut, three goblin camps to the east, and the river with the boat at the far end.

const PlayerScript := preload("res://scripts/player.gd")
const GoblinScript := preload("res://scripts/goblin.gd")
const HudScript := preload("res://scripts/hud.gd")
const TouchScript := preload("res://scripts/touch_controls.gd")
const DialogScript := preload("res://scripts/dialog.gd")
const HorseScript := preload("res://scripts/horse.gd")
const RideScript := preload("res://scripts/ride.gd")
const SoundScript := preload("res://scripts/sound.gd")
const IndoorsScript := preload("res://scripts/indoors.gd")
const SisterScript := preload("res://scripts/sister.gd")
const Mission2Script := preload("res://scripts/mission2.gd")

const GROUND_Y := 560.0
const LEVEL_LEFT := 0.0
const LEVEL_RIGHT := 5400.0
const CAMERA_ZOOM := 1.4  # bigger characters are easier to read on an 8 inch screen
const RIDE_ZOOM := 1.15  # the riding course shows more of what is coming

const HOUSE_X := 40.0  # left edge of the farmhouse
const STABLE_X := 549.0  # where Spirit waits, inside the stable
const DOOR_X := 238.0  # the front door of the house
const START_X := 800.0
const HUT_X := 1150.0  # middle of Merlin's hut
const MERLIN_X := 1420.0
const SIGN_X := 1640.0
const GATE_X := 1760.0  # Adeline cannot head east until she has the mission
const RIVER_X := 5080.0
const TALK_RANGE := 120.0
const RIDE_RANGE := 100.0
const SAVE_PATH := "user://save.json"
const SETTINGS_PATH := "user://settings.json"
# Where the game looks for newer content. The files are published by the build on GitHub.
const UPDATE_URL := "https://github.com/B3r3t/adeline-game/releases/download/latest/"
const ART_SCALE := 1.0 / 2.2  # scenery art is drawn at 2.2 pixels per world pixel
const GROUND_ART_HEIGHT := 170.0  # how tall the grass-and-soil strip is in the world
const GRASS_RISE := 24.0  # how far the grass tufts stand above the line characters walk on
const STRIP_START := -3000.0

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
var sister = null  # Adeline's little sister, on her pony
var puffs: Array = []  # dust kicked up by feet and hooves: [where, age, size, drift]
var shake := 0.0  # how hard the picture is being shaken, in pixels
var mission2 = null  # the rescue of Mom and Dad, and the island it happens on
var ride = null  # the riding course
var sound = null  # voices, grunts and effects
var sound_on := true
var indoors = null  # the living room and the stable
var place_action := ""  # a building Adeline is standing at: house or stable
var zoom := CAMERA_ZOOM
var merlin: Sprite2D
var boat: Sprite2D
var goblins: Array = []
var projectiles: Node2D
var camera: Camera2D
var hills_far: Sprite2D
var hills_near: Sprite2D
var ground_art: Texture2D
var cam_pos := Vector2.ZERO  # where the camera is, eased toward Adeline

# Shared pieces for glowing effects such as the fireball.
var spark: GradientTexture2D
var additive: CanvasItemMaterial
var fire_ramp: Gradient
var shrink: Curve
var camps: Array = []
var hud = null
var controls = null
var dialog = null
var font: Font

var mode := "title"  # title, play (the adventure) or ride (the riding course)
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
var update_note := ""  # shown on the title screen
var guard_cleared := false
var clock := 0.0


func _ready() -> void:
	font = ThemeDB.fallback_font
	_setup_input()
	_build_effects()
	_build_backdrop()
	_build_ground()
	_build_scenery()

	mission2 = Node2D.new()
	mission2.set_script(Mission2Script)
	mission2.game = self
	add_child(mission2)

	ride = Node2D.new()
	ride.set_script(RideScript)
	ride.game = self
	add_child(ride)

	sound = Node.new()
	sound.set_script(SoundScript)
	sound.game = self
	add_child(sound)

	projectiles = Node2D.new()
	add_child(projectiles)

	sister = Node2D.new()
	sister.set_script(SisterScript)
	sister.game = self
	add_child(sister)

	horse = Node2D.new()
	horse.set_script(HorseScript)
	horse.game = self
	add_child(horse)

	player = CharacterBody2D.new()
	player.set_script(PlayerScript)
	player.game = self
	add_child(player)

	camera = Camera2D.new()
	camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	# The camera, hills and characters all move on the same clock (the physics tick) and are
	# smoothed between ticks by the engine. Mixing clocks is what makes scrolling judder.
	camera.process_callback = Camera2D.CAMERA2D_PROCESS_PHYSICS
	add_child(camera)
	camera.make_current()

	var layer := CanvasLayer.new()
	add_child(layer)
	indoors = Control.new()
	indoors.set_script(IndoorsScript)
	indoors.game = self
	layer.add_child(indoors)
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
	_check_for_update()


# --- Setup ------------------------------------------------------------------

func _setup_input() -> void:
	_add_action("move_left", [KEY_A, KEY_LEFT])
	_add_action("move_right", [KEY_D, KEY_RIGHT])
	_add_action("jump", [KEY_SPACE, KEY_W, KEY_UP])
	_add_action("strike", [KEY_J, KEY_Z])
	_add_action("fireball", [KEY_K, KEY_X])
	_add_action("shield", [KEY_L, KEY_C])
	_add_action("interact", [KEY_E, KEY_ENTER])
	_add_action("boost", [KEY_K, KEY_X, KEY_SHIFT])


func _add_action(action: String, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)


func _build_effects() -> void:
	# A soft round glow, drawn brighter where glows overlap.
	var falloff := Gradient.new()
	falloff.set_color(0, Color(1.0, 1.0, 1.0, 1.0))
	falloff.set_color(1, Color(1.0, 1.0, 1.0, 0.0))
	spark = GradientTexture2D.new()
	spark.gradient = falloff
	spark.width = 48
	spark.height = 48
	spark.fill = GradientTexture2D.FILL_RADIAL
	spark.fill_from = Vector2(0.5, 0.5)
	spark.fill_to = Vector2(1.0, 0.5)
	additive = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	fire_ramp = Gradient.new()
	fire_ramp.set_color(0, Color(1.0, 0.95, 0.6, 1.0))
	fire_ramp.set_color(1, Color(0.9, 0.15, 0.05, 0.0))
	fire_ramp.add_point(0.4, Color(1.0, 0.55, 0.12, 0.9))
	shrink = Curve.new()
	shrink.add_point(Vector2(0.0, 1.0))
	shrink.add_point(Vector2(1.0, 0.0))


func _build_backdrop() -> void:
	# Two layers of hills that slide past at different speeds for a feeling of depth.
	hills_far = _add_strip("hills_far", 230.0, GROUND_Y + 24.0, -20)
	hills_near = _add_strip("hills_near", 270.0, GROUND_Y + 14.0, -10)
	ground_art = load("res://art/props/ground.png")
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


## A long picture that repeats sideways, standing on the given line.
func _add_strip(art: String, world_height: float, bottom_y: float, depth: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	var tex: Texture2D = load("res://art/props/%s.png" % art)
	sprite.texture = tex
	sprite.centered = false
	sprite.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	sprite.region_enabled = true
	# Two pixels are left off the top: with the picture repeating, its bottom row would
	# otherwise bleed in there as a faint line across the sky.
	sprite.region_rect = Rect2(0.0, 2.0, tex.get_width() * 8.0, tex.get_height() - 2.0)
	var k := world_height / tex.get_height()
	sprite.scale = Vector2(k, k)
	sprite.position = Vector2(STRIP_START, bottom_y - world_height)
	sprite.z_index = depth
	add_child(sprite)
	return sprite


func _build_ground() -> void:
	# The floor runs under the island and on under the riding course.
	_add_wall(Rect2(LEVEL_LEFT - 400.0, GROUND_Y, 8000.0 + 14000.0 + 2000.0, 400.0))
	_add_wall(Rect2(LEVEL_LEFT - 200.0, GROUND_Y - 1200.0, 200.0, 1200.0))
	_add_wall(Rect2(LEVEL_RIGHT, GROUND_Y - 1200.0, 200.0, 1200.0))


## Scenery art sits behind the characters. Each piece stands on the ground line.
func _build_scenery() -> void:
	_add_scenery("house", HOUSE_X, false)
	_add_scenery("hut", HUT_X, true)
	merlin = _add_scenery("merlin", MERLIN_X, true)
	boat = _add_scenery("boat", RIVER_X + 210.0, true)
	_add_scenery("sign", SIGN_X, true)
	for enc in ENCOUNTERS:
		camps.append(_add_scenery("camp", float(enc["right"]) - 40.0, true))


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
	return { "m1": "available", "cleared": 0, "shield": false, "checkpoint_x": START_X, "practice_round": 1, "ride_course": 1, "ride_stars": {}, "race_course": 1, "race_stars": {}, "ribbon": 0, "hair": 0, "m2": "available", "m2_step": 0, "m2_thanked": false }


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
	# Whether sound is on is kept apart from the adventure, so a new adventure does not reset it.
	if FileAccess.file_exists(SETTINGS_PATH):
		var settings = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if settings is Dictionary:
			sound_on = bool(settings.get("sound", true))
	if sound != null:
		sound.set_muted(not sound_on)


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))


func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({ "sound": sound_on }))


func cleared() -> int:
	return int(data["cleared"])


func has_shield() -> bool:
	return bool(data["shield"])


# --- Updates over the internet ----------------------------------------------
# On the title screen the game asks GitHub for the newest build number. If it is newer,
# the new content downloads quietly and is used the next time the game is opened.

func build_number() -> int:
	return int(Engine.get_meta("build", 0))


func _update_url() -> String:
	var override := OS.get_environment("ADELINE_UPDATE_URL")  # for testing
	return override if override != "" else UPDATE_URL


func _check_for_update() -> void:
	var req := HTTPRequest.new()
	add_child(req)
	req.timeout = 15.0
	req.request_completed.connect(_on_update_info.bind(req))
	if req.request(_update_url() + "version.json") != OK:
		req.queue_free()


func _on_update_info(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray, req: HTTPRequest) -> void:
	req.queue_free()
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		return  # offline, or nothing published: carry on as normal
	var info = JSON.parse_string(body.get_string_from_utf8())
	if not (info is Dictionary):
		return
	var latest := int(info.get("build", 0))
	if latest <= build_number():
		return
	if int(Engine.get_meta("installed_build", 0)) < int(info.get("min_app_build", 0)):
		update_note = "A new version is out. Install it from the download page."
		return
	if FileAccess.file_exists("user://update_new.json"):
		var have = JSON.parse_string(FileAccess.get_file_as_string("user://update_new.json"))
		if have is Dictionary and int(have.get("build", 0)) >= latest:
			update_note = "Update ready. It will be here next time you open the game."
			return
	update_note = "Downloading an update..."
	var dl := HTTPRequest.new()
	add_child(dl)
	dl.download_file = "user://update_new.tmp"
	dl.request_completed.connect(_on_update_pack.bind(dl, latest, int(info.get("size", 0))))
	if dl.request(_update_url() + "adeline.pck") != OK:
		dl.queue_free()
		update_note = ""


## The download is kept under its own name and is only put to use at the next start (see
## handoff.gd). The files the game is running from are never touched while it runs.
func _on_update_pack(result: int, code: int, _headers: PackedStringArray, _body: PackedByteArray, dl: HTTPRequest, latest: int, size: int) -> void:
	dl.queue_free()
	var dir := DirAccess.open("user://")
	var good := result == HTTPRequest.RESULT_SUCCESS and code == 200 and dir != null
	if good and size > 0:
		var file := FileAccess.open("user://update_new.tmp", FileAccess.READ)
		good = file != null and file.get_length() == size  # a cut-off download is thrown away
	if not good:
		update_note = ""
		if dir != null and dir.file_exists("update_new.tmp"):
			dir.remove("update_new.tmp")
		return
	for old in ["update_new.pck", "update_new.json"]:
		if dir.file_exists(old):
			dir.remove(old)
	dir.rename("update_new.tmp", "update_new.pck")
	var note := FileAccess.open("user://update_new.json", FileAccess.WRITE)
	note.store_string(JSON.stringify({ "build": latest }))
	update_note = "Update ready. It will be here next time you open the game."


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
	ride.clear()
	sister.reset()
	zoom = CAMERA_ZOOM
	camera.zoom = Vector2(zoom, zoom)
	encounter = {}
	encounter_kind = ""
	defeated = false
	var cx := float(data["checkpoint_x"])
	player.reset(Vector2(cx, GROUND_Y))
	# Spirit starts in the stable, or close by when continuing from far along the island.
	horse.place(STABLE_X if cx < 1000.0 else cx - 130.0)
	mission2.restore()
	_update_limits()
	_update_camera(0.0, true)


func _update_limits() -> void:
	var lo := LEVEL_LEFT + 40.0
	var hi := RIVER_X - 30.0
	if data["m1"] == "available":
		hi = GATE_X
	if mission2.on_island:
		lo = mission2.LEFT + 40.0
		hi = mission2.wall()
	if not encounter.is_empty():
		lo = float(encounter["left"])
		hi = float(encounter["right"])
	player.min_x = lo
	player.max_x = hi


func input_locked() -> bool:
	return mode == "title" or mode == "house" or mode == "stable" or dialog.active or defeated or (mode == "ride" and ride.finished) or (mode == "play" and (sister.busy() or mission2.fading()))


## A little cloud of dust on the ground.
func puff(at: Vector2, size := 1.0) -> void:
	if puffs.size() < 48:
		puffs.append([at, 0.0, size, randf_range(-1.0, 1.0)])


## Shakes the picture for a moment, for a heavy blow.
func jolt(amount: float) -> void:
	shake = maxf(shake, amount)


## Freezes everything for an instant when a hit lands, so it is felt.
func hit_stop(seconds := 0.05) -> void:
	Engine.time_scale = 0.06
	get_tree().create_timer(seconds, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func toast(text: String) -> void:
	toast_text = text
	toast_time = 3.5


# --- Encounters -------------------------------------------------------------

func _begin_encounter(enc: Dictionary, kind: String) -> void:
	encounter = enc
	encounter_kind = kind
	_spawn_goblins()
	sound.shout("goblin", "goblin_taunt", 1.0, true)
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
		if spec.get("ogre", false):
			# The ogre is slow and huge, and nothing hurts him unless something has his attention.
			g.art = "res://art/ogre"
			g.size = 1.9
			g.draw_size = 1.0
			g.tough = true
			g.max_health = 14
			g.health = 14
			g.walk_speed = 85.0
			g.swing_windup = 1.15
			g.mouth = "ogre"
			g.cries = { "attack": "ogre_roar", "hurt": "ogre_hurt", "down": "ogre_down" }
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


func on_hit_shrugged_off(_goblin) -> void:
	mission2.on_shrugged()


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
	elif encounter_kind == "m2":
		pass  # the mission says what happens next, below
	else:
		data["practice_round"] = mini(int(data["practice_round"]) + 1, 3)
		toast("Practice fight won!")
	encounter = {}
	encounter_kind = ""
	attacker = null
	player.health = player.MAX_HEALTH
	if mission2.on_island:
		mission2.on_fight_won()
	_update_limits()
	_save()
	sound.play("fanfare", -5.0, 0.0)
	sound.shout("adeline", "take_that", 1.0, true)


func on_player_defeated() -> void:
	defeated = true
	defeat_time = 0.0
	sound.shout("adeline", "defeat", 1.0, true)


## Back to the start of the unfinished fight with full health. Nothing earned is lost.
func _retry() -> void:
	defeated = false
	player.reset(Vector2(float(encounter["left"]) + 90.0, GROUND_Y))
	_spawn_goblins()
	_update_camera(0.0, true)


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
	place_action = ""
	if mode != "play" or dialog.active or not encounter.is_empty():
		return
	var px: float = player.position.x
	if mission2.on_island:
		context_action = mission2.island_context()
		return
	if absf(px - DOOR_X) <= 85.0:
		place_action = "house"
	elif absf(px - STABLE_X) <= 130.0:
		place_action = "stable"
	if sister.activity != "":
		return  # racing or having her hair done: nothing else to tap
	if absf(px - MERLIN_X) <= TALK_RANGE:
		context_action = "talk"
	elif absf(px - sister.x) <= 105.0 and not player.mounted and sister.mode != "stay" and sister.mode != "charge":
		context_action = "sister"
	elif px >= RIVER_X - 160.0:
		context_action = "boat"
	elif player.mounted:
		context_action = "dismount"
	elif absf(px - horse.position.x) <= RIDE_RANGE:
		context_action = "ride"
	else:
		context_action = "call"
	context_action = mission2.home_context(context_action)


func merlin_has_news() -> bool:
	if data["m1"] == "done":
		return data["m2"] == "available" or (data["m2"] == "done" and not data["m2_thanked"])
	return data["m1"] == "available" or (data["m1"] == "active" and cleared() >= ENCOUNTERS.size())


func _interact() -> void:
	controls.release_all()
	if context_action == "ride":
		_mount()
	elif context_action == "dismount":
		_dismount()
	elif context_action == "call":
		horse.come()
		sound.shout("adeline", "call", 1.0, true)
		get_tree().create_timer(0.7).timeout.connect(func(): sound.play("whinny", -5.0))
	elif context_action == "talk":
		_dismount()
		_talk_to_merlin()
	elif context_action == "sister":
		_talk_to_sister()
	elif context_action in ["fly", "stay", "come", "open"]:
		mission2.interact(context_action)
	elif context_action == "boat":
		_dismount()
		if data["m2"] == "active":
			dialog.say("", ["The magic boat rocks gently on the river.", "It will not leave without your little sister. Bring her with you."])
		elif data["m2"] == "done":
			dialog.say("", ["The magic boat rocks gently on the river, home from Ogre Island."])
		else:
			dialog.say("", ["The magic boat rocks gently on the river.", "Merlin will know where it should fly."])


func _mount() -> void:
	if not player.is_on_floor():
		return
	player.mounted = true
	player.position.x = horse.position.x
	player.reset_physics_interpolation()
	player.facing = horse.facing
	horse.set_mounted(true)
	sound.shout("adeline", "lets_go", 1.0, true)
	sound.play("snort", -6.0)


func _dismount() -> void:
	if not player.mounted:
		return
	player.mounted = false
	horse.set_mounted(false)
	horse.position = Vector2(player.position.x, GROUND_Y)
	player.position.x += player.facing * 80.0


## Things to do with her little sister. Small and quick, and none of them is a mission.
func _talk_to_sister() -> void:
	var rows := [
		{ "id": "race", "label": "Race you on foot!", "status": "Play", "enabled": true },
		{ "id": "hair", "label": "Do her hair", "status": "Play", "enabled": true },
	]
	if data["m2"] == "active" and int(data["m2_step"]) == 0:
		rows.insert(0, { "id": "m2", "label": "Come and help rescue Mom and Dad!", "status": "Mission", "enabled": true })
	if data["m2"] == "active" and int(data["m2_step"]) >= 1:
		pass  # she is on the mission and stays with Adeline
	elif sister.mode == "follow":
		rows.append({ "id": "play", "label": "Off you go and play", "status": "", "enabled": true })
	else:
		rows.append({ "id": "follow", "label": "Come with me", "status": "", "enabled": true })
	dialog.choose("Your little sister", rows, _on_sister_picked)


func _on_sister_picked(id: String) -> void:
	if id == "m2":
		mission2.sister_joins()
	elif id == "race":
		sister.start_race()
	elif id == "hair":
		sister.do_hair()
	elif id == "follow":
		sister.follow()
		sound.shout("sister", "sister_coming", 1.0, true)
		toast("She will ride along behind you.")
	elif id == "play":
		sister.roam()
		sound.shout("sister", "sister_whee", 1.0, true)


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
	elif data["m2"] == "done" and not data["m2_thanked"]:
		data["m2_thanked"] = true
		_save()
		dialog.say("Merlin", ["You brought them home! I never doubted the two of you for a moment."], _show_missions)
	elif data["m2"] == "active":
		dialog.say("Merlin", [
			"Fetch your little sister. Then take the flying boat at the river.",
			"Its gate only opens when two stones are pressed at the very same moment. Nobody can do that alone.",
		])
	else:
		_show_missions()


func _show_missions() -> void:
	var m1: String = data["m1"]
	var status := { "available": "Available", "active": "Active", "done": "Completed" }
	var rows := [
		{ "id": "m1", "label": "Goblin Trouble", "status": status[m1], "enabled": m1 == "available" },
		{ "id": "m2", "label": "Rescue Mom and Dad", "status": status[str(data["m2"])] if m1 == "done" else "Locked", "enabled": m1 == "done" and data["m2"] == "available" },
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
	elif id == "m2":
		data["m2"] = "active"
		data["m2_step"] = 0
		_save()
		dialog.say("Merlin", [
			"The ogre has locked your mother and father in his fort on the island across the water.",
			"Its gate only opens when two stones are pressed at the very same moment. Nobody can do that alone.",
			"Fetch your little sister. Then take the flying boat at the river.",
		])
	elif id == "practice":
		_begin_practice()


func _give_shield() -> void:
	data["m1"] = "done"
	data["shield"] = true
	_save()
	toast("New spell: Magic Shield!")
	sound.play("fanfare", -5.0, 0.0)


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
		if encounter.has("title"):
			return str(encounter["title"])
		if total == 1:
			return "Defeat the goblin"
		return "Defeat the goblins: %d left" % goblins_left()
	var m1: String = data["m1"]
	if m1 == "available":
		return "Talk to Merlin"
	if m1 == "active":
		return "Find the goblins" if cleared() < ENCOUNTERS.size() else "Return to Merlin"
	if data["m2"] == "active":
		return mission2.objective()
	if data["m2"] == "available":
		return "Talk to Merlin"
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
	if data["m2"] == "active":
		return mission2.hint()
	if data["m2"] == "available":
		return "Merlin has a new mission: the rescue of Mom and Dad."
	return "Your family is home. Race your sister, do her hair, or ride with Spirit."


# --- Loop -------------------------------------------------------------------

# Where the on-screen buttons that are not thumb controls sit.
func adventure_rect() -> Rect2:
	var s := get_viewport_rect().size
	return Rect2(s.x / 2.0 - 400.0, s.y * 0.56, 380.0, 110.0)


func ride_rect() -> Rect2:
	var s := get_viewport_rect().size
	return Rect2(s.x / 2.0 + 20.0, s.y * 0.56, 380.0, 110.0)


func race_rect() -> Rect2:
	var s := get_viewport_rect().size
	return Rect2(s.x / 2.0 + 20.0, s.y * 0.56 + 124.0, 380.0, 54.0)


func new_game_rect() -> Rect2:
	var s := get_viewport_rect().size
	return Rect2(s.x / 2.0 - 400.0, s.y * 0.56 + 124.0, 380.0, 54.0)


func enter_rect() -> Rect2:
	var s := get_viewport_rect().size
	return Rect2(s.x / 2.0 - 180.0, 150.0, 360.0, 66.0)


## Goes into the house to decorate, or into the stable to look after Spirit.
func enter_place(which: String) -> void:
	controls.release_all()
	_dismount()
	if which == "stable":
		horse.place(STABLE_X)
		sound.play("whinny", -6.0)
	mode = which
	place_action = ""
	context_action = ""
	indoors.open(which)


func leave_place() -> void:
	var was := mode
	mode = "play"
	indoors.close()
	player.position.x = DOOR_X if was == "house" else STABLE_X - 110.0
	player.velocity = Vector2.ZERO
	player.reset_physics_interpolation()
	_update_camera(0.0, true)


func sound_rect() -> Rect2:
	var s := get_viewport_rect().size
	return Rect2(40.0, s.y - 96.0, 190.0, 56.0)


func menu_rect() -> Rect2:
	var s := get_viewport_rect().size
	return Rect2(s.x - 160.0, 52.0, 120.0, 48.0)


func again_rect() -> Rect2:
	var s := get_viewport_rect().size
	return Rect2(s.x / 2.0 - 330.0, s.y * 0.6, 310.0, 80.0)


func next_rect() -> Rect2:
	var s := get_viewport_rect().size
	return Rect2(s.x / 2.0 + 20.0, s.y * 0.6, 310.0, 80.0)


# --- The riding course -------------------------------------------------------

func start_ride(number: int, race := false) -> void:
	_place_player()
	mode = "ride"
	new_game_armed = false
	data["race_course" if race else "ride_course"] = number
	_save()
	zoom = RIDE_ZOOM
	camera.zoom = Vector2(zoom, zoom)
	player.reset(Vector2(ride.START_X, GROUND_Y))
	player.min_x = ride.START_X - 200.0
	player.max_x = ride.START_X + ride.LENGTH + 300.0
	horse.place(ride.START_X)
	player.mounted = true
	horse.set_mounted(true)
	ride.start(number, race)
	_update_camera(0.0, true)
	sound.shout("adeline", "lets_ride", 1.0, true)
	sound.play("whinny", -6.0)


func on_ride_finished(number: int, stars: int) -> void:
	var best: Dictionary = data["race_stars" if ride.racing else "ride_stars"]
	var key := str(number)
	if stars > int(best.get(key, 0)):
		best[key] = stars
	_save()
	sound.play("fanfare", -5.0, 0.0)
	sound.shout("adeline", "we_did_it", 1.0, true)


func go_title() -> void:
	if not dialog.active:
		mode = "title"
		_place_player()
		sound.hush()


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
		if has_pos and sound_rect().has_point(pos):
			sound_on = not sound_on
			sound.set_muted(not sound_on)
			_save_settings()
			sound.play("chime", -4.0)
		elif has_pos and ride_rect().has_point(pos):
			start_ride(int(data["ride_course"]))
		elif has_pos and race_rect().has_point(pos):
			start_ride(int(data["race_course"]), true)
		elif has_save() and has_pos and new_game_rect().has_point(pos):
			if new_game_armed:
				_start(true)
			else:
				new_game_armed = true
		elif not has_pos or adventure_rect().has_point(pos):
			_start(not has_save())
	elif has_pos and menu_rect().has_point(pos):
		go_title()
	elif mode == "play" and place_action != "" and has_pos and enter_rect().has_point(pos) and not dialog.active:
		enter_place(place_action)
	elif mode == "ride":
		if ride.finished and ride.finish_time >= 0.8 and has_pos:
			if again_rect().has_point(pos):
				start_ride(ride.course, ride.racing)
			elif next_rect().has_point(pos):
				start_ride(ride.course + 1, ride.racing)
	elif defeated and defeat_time >= 1.0:
		_retry()


func _physics_process(delta: float) -> void:
	_update_camera(delta, false)
	if mode != "play":
		context_action = ""
		place_action = ""
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
	var view := get_viewport_rect().size / zoom
	# Look a little ahead of Adeline, and keep the ground about three quarters of the way down.
	var x: float = player.position.x + player.facing * 45.0
	if mode == "ride":
		# On the course Spirit sits toward the left so the next jump is in view early.
		x = player.position.x + view.x * 0.24
		x = clampf(x, ride.START_X - 300.0 + view.x / 2.0, ride.START_X + ride.LENGTH + 500.0 - view.x / 2.0)
		# Follow the hills, looking at the ground a little ahead of Spirit rather than at her jumps.
		return Vector2(x, ride.ground_y(player.position.x + 140.0) - 0.26 * view.y)
	elif mission2.on_island:
		x = clampf(x, mission2.LEFT - 190.0 + view.x / 2.0, mission2.RIGHT - view.x / 2.0)
	else:
		x = clampf(x, LEVEL_LEFT + view.x / 2.0, LEVEL_RIGHT - view.x / 2.0)
	return Vector2(x, GROUND_Y - 0.24 * view.y)


## Eases the camera toward Adeline and slides the hills behind it. With snap, it jumps
## straight there, for moments when she is placed somewhere new.
func _update_camera(delta: float, snap: bool) -> void:
	var target := _camera_target()
	if snap:
		cam_pos = target
	else:
		var ease := 1.0 - exp(-7.0 * delta)
		cam_pos.x = lerpf(cam_pos.x, target.x, ease)
		cam_pos.y = lerpf(cam_pos.y, target.y, 1.0 - exp(-4.0 * delta)) if mode == "ride" else target.y
	camera.position = cam_pos
	hills_far.position.x = STRIP_START + cam_pos.x * 0.85
	hills_near.position.x = STRIP_START + cam_pos.x * 0.6
	var boat_h := boat.texture.get_size().y * ART_SCALE
	boat.position.y = GROUND_Y + 34.0 - boat_h + sin(clock * 2.0) * 5.0
	if snap:
		for node in [camera, hills_far, hills_near, boat]:
			node.reset_physics_interpolation()


func _process(delta: float) -> void:
	clock += delta
	if not guard_cleared and clock > 3.0:
		# The game has been running fine for a few seconds, so any update just loaded is good.
		guard_cleared = true
		for guard in ["user://update_loading", "user://update_next_loading"]:
			if FileAccess.file_exists(guard):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(guard))
	toast_time = maxf(toast_time - delta, 0.0)
	for dust in puffs:
		dust[1] = float(dust[1]) + delta
	puffs = puffs.filter(func(d): return float(d[1]) < 0.5)
	shake = move_toward(shake, 0.0, delta * 34.0)
	camera.offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * shake
	goblins = goblins.filter(func(g): return is_instance_valid(g))
	# Merlin turns to face Adeline. A goblin camp packs up once its goblins are beaten.
	merlin.flip_h = player.position.x < MERLIN_X
	# He breathes, so he does not look like a cardboard cutout.
	var breath := 1.0 + sin(clock * 1.8) * 0.012
	merlin.scale.y = ART_SCALE * breath
	merlin.position.y = GROUND_Y + 4.0 - merlin.texture.get_height() * ART_SCALE * breath
	for n in camps.size():
		camps[n].visible = n >= cleared()
	queue_redraw()


# --- Placeholder scenery ----------------------------------------------------

func _draw() -> void:
	var g := GROUND_Y
	var left := LEVEL_LEFT - 600.0
	var width: float = ride.START_X - 300.0 - left  # the island; the riding course draws its own hills
	# Deep soil, then the repeating grass-and-soil strip on top of it.
	draw_rect(Rect2(left, g + 100.0, width, 700.0), Color(0.33, 0.17, 0.1))
	var k := GROUND_ART_HEIGHT / ground_art.get_height()
	draw_set_transform(Vector2(left, g - GRASS_RISE), 0.0, Vector2(k, k))
	draw_texture_rect(ground_art, Rect2(0.0, 0.0, width / k, ground_art.get_height()), true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	_draw_merlin_mark(g)
	_draw_river(g)
	for dust in puffs:
		var age := float(dust[1]) / 0.5
		var big := float(dust[2])
		var at: Vector2 = dust[0] + Vector2(float(dust[3]) * 9.0 * age, -3.0 - 11.0 * age * big)
		draw_circle(at, (4.0 + 13.0 * age) * big, Color(0.95, 0.9, 0.78, 0.5 * (1.0 - age)))


func _draw_merlin_mark(g: float) -> void:
	# A bobbing mark over Merlin when he has something new to say.
	if mode == "play" and merlin_has_news():
		var bob := sin(clock * 4.0) * 5.0
		draw_rect(Rect2(MERLIN_X - 5.0, g - 226.0 + bob, 10.0, 26.0), Color(1.0, 0.85, 0.2))
		draw_circle(Vector2(MERLIN_X, g - 188.0 + bob), 6.0, Color(1.0, 0.85, 0.2))


func _draw_river(g: float) -> void:
	draw_rect(Rect2(RIVER_X, g + 6.0, 800.0, 600.0), Color(0.25, 0.55, 0.85))
	draw_rect(Rect2(RIVER_X, g + 6.0, 800.0, 10.0), Color(0.6, 0.82, 0.98))
