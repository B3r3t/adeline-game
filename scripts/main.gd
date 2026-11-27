extends Node2D
## Mission 1, "Goblin Trouble", built from placeholder shapes, with Spirit the horse to ride.
## The home island is one long strip: Adeline's house and stable on the left,
## Merlin's hut, three goblin camps to the east, and the river with the boat at the far end.

const Season := preload("res://scripts/season.gd")
const Ui := preload("res://scripts/ui.gd")
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
const Mission3Script := preload("res://scripts/mission3.gd")
const SkyScript := preload("res://scripts/sky.gd")
const MiniScript := preload("res://scripts/mini.gd")
const ShopScript := preload("res://scripts/shop.gd")
const Look := preload("res://scripts/look.gd")
const SceneryScript := preload("res://scripts/scenery.gd")

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

# The animals Adeline can ride, and what is particular to each. The unicorn joins the
# stable at the end of Mission 3. Spots are in pixels of each one's body picture.
const MOUNTS := {
	"spirit": { "art": "res://art/spirit", "title": "Spirit" },
	"unicorn": {
		"art": "res://art/unicorn", "title": "Aurora", "seat": Vector2(-31.0, -33.0), "bit": Vector2(236.0, 71.0),
		"pommel": Vector2(128.0, 88.0), "reins": [Color(0.5, 0.16, 0.36), Color(1.0, 0.62, 0.8)],
	},
}

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
var mission3 = null  # the missing unicorn
var sky = null  # the ride above the clouds
var scenery = null  # the sky, trees, flowers and small animals
var music_on := true
var button_size := 1  # the thumb buttons: 0 small, 1 medium, 2 large
var easy_fights := false  # goblins with less health and slower swings
var menu := ""  # which menu is open over the game: "", "settings" (title screen) or "pause"
var fx: Array = []  # numbers and stars that pop out of a hit and drift up: [where, age, text, colour]
var ride = null  # the riding course
var sound = null  # voices, grunts and effects
var sound_on := true
var indoors = null  # the living room and the stable
var mini = null  # the farm games
var shop = null  # Merlin's shop
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
var earned := 0  # the stars the last game paid into the purse, for its results panel
var merry := 4.0  # seconds until Merlin may call his Christmas greeting again


func _ready() -> void:
	# Whether it is Christmas has to be known before the first picture is loaded.
	Season.mode = _saved_season()
	Season.look()
	Ui.snowy = Season.festive()
	# A rounded, friendly typeface for every word in the game. Anything it lacks falls
	# back to the engine's own.
	var face: FontFile = load("res://art/ui/Fredoka-Medium.ttf")
	if face != null and not (ThemeDB.fallback_font is FontFile and (ThemeDB.fallback_font as FontFile).resource_path == face.resource_path):
		face.fallbacks = [ThemeDB.fallback_font]
		ThemeDB.fallback_font = face
	font = ThemeDB.fallback_font
	process_mode = Node.PROCESS_MODE_ALWAYS  # so the pause menu still works while all else stands still
	_setup_input()
	_build_effects()
	_build_backdrop()
	_build_ground()
	_build_scenery()

	mission2 = Node2D.new()
	mission2.set_script(Mission2Script)
	mission2.game = self
	add_child(mission2)
	mission3 = Node2D.new()
	mission3.set_script(Mission3Script)
	mission3.game = self
	add_child(mission3)
	scenery = Node2D.new()
	scenery.set_script(SceneryScript)
	scenery.game = self
	add_child(scenery)
	move_child(scenery, mission2.get_index())  # behind everything the adventure puts on the island

	ride = Node2D.new()
	ride.set_script(RideScript)
	ride.game = self
	add_child(ride)

	sky = Node2D.new()
	sky.set_script(SkyScript)
	sky.game = self
	add_child(sky)

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

	set_mount("spirit")

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
	mini = Control.new()
	mini.set_script(MiniScript)
	mini.game = self
	layer.add_child(mini)
	shop = Control.new()
	shop.set_script(ShopScript)
	shop.game = self
	layer.add_child(shop)
	layer.move_child(mini, hud.get_index())  # under the menu button and the speech box
	# Snow, at Christmas, over the scene but under everything that is read or pressed.
	var snow := Control.new()
	snow.set_script(preload("res://scripts/snow.gd"))
	snow.game = self
	layer.add_child(snow)
	layer.move_child(snow, hud.get_index())
	for above in [hud, controls, dialog]:
		above.z_index = 4050
	var curtain := Control.new()
	curtain.set_script(preload("res://scripts/curtain.gd"))
	curtain.game = self
	curtain.z_index = 4090
	layer.add_child(curtain)

	# Everything in the world stops when a menu is open. The menu itself, drawn by the
	# heads-up display, and the sound do not.
	for child in get_children():
		if child != layer and child != sound:
			child.process_mode = Node.PROCESS_MODE_PAUSABLE
	for child in [indoors, controls, dialog, mini]:
		child.process_mode = Node.PROCESS_MODE_PAUSABLE
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
	ground_art = Season.tex("res://art/props/ground.png")
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED


## A long picture that repeats sideways, standing on the given line.
func _add_strip(art: String, world_height: float, bottom_y: float, depth: int) -> Sprite2D:
	var sprite := Sprite2D.new()
	var tex: Texture2D = Season.tex("res://art/props/%s.png" % art)
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
	sprite.texture = Season.tex("res://art/props/%s.png" % art)
	sprite.centered = false
	sprite.scale = Vector2(ART_SCALE, ART_SCALE)
	var size := sprite.texture.get_size() * ART_SCALE
	sprite.position = Vector2(x - (size.x / 2.0 if centred else 0.0), GROUND_Y + 4.0 - size.y)
	add_child(sprite)
	return sprite


## Puts Spirit or the unicorn outside as the animal Adeline rides. Each is a horse with her
## own drawings, so changing over means making a fresh one in the old one's place.
func set_mount(kind: String) -> void:
	if horse != null and horse.kind == kind:
		horse.seat_at = MOUNTS[kind].get("seat", HorseScript.SEAT)
		return
	var spec: Dictionary = MOUNTS[kind]
	var fresh = Node2D.new()
	fresh.set_script(HorseScript)
	fresh.game = self
	fresh.kind = kind
	fresh.art = spec["art"]
	fresh.title = spec["title"]
	if spec.has("seat"):
		fresh.seat_at = spec["seat"]
		fresh.bit_at = spec["bit"]
		fresh.pommel_at = spec["pommel"]
		fresh.rein_colors = spec["reins"]
	fresh.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(fresh)
	if horse != null:
		fresh.position = horse.position
		move_child(fresh, horse.get_index())
		horse.queue_free()
	horse = fresh


func has_unicorn() -> bool:
	return str(data.get("m3", "")) == "done"


## Which animal is Adeline's to ride just now.
func mount_kind() -> String:
	return str(data.get("mount", "spirit")) if has_unicorn() else "spirit"


## Swaps the animal that is out with the one in the stable. The new one trots over.
func swap_mount() -> void:
	if not has_unicorn() or player.mounted:
		return
	data["mount"] = "spirit" if mount_kind() == "unicorn" else "unicorn"
	_save()
	set_mount(mount_kind())
	horse.place(STABLE_X)
	horse.come()
	toast("%s is coming!" % horse.title)
	sound.play("whinny", -5.0, 0.0, 1.3 if horse.kind == "unicorn" else 1.0)
	sound.play("chime", -6.0)


func snap_camera() -> void:
	_update_camera(0.0, true)


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
	return { "m1": "available", "cleared": 0, "shield": false, "checkpoint_x": START_X, "practice_round": 1, "ride_course": 1, "ride_stars": {}, "race_course": 1, "race_stars": {}, "ribbon": 0, "hair": 0, "m2": "available", "m2_step": 0, "m2_thanked": false, "m3": "available", "m3_step": 0, "m3_clues": 0, "m3_thanked": false, "mount": "spirit", "sky_course": 1, "sky_stars": {}, "mini_stars": {}, "advent": { "year": 0, "days": [] }, "purse": -1, "owned": [], "foal": { "name": "", "days": 0, "seen": 0, "last": 0, "day": 0, "milk": 0.0, "brush": 0.0, "love": 0.0 }, "look": { "cloak": "purple", "blanket": "purple", "hat": "", "neck": "" } }


func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


func _load() -> void:
	_load_settings()
	data = _default_data()
	if not has_save():
		_open_purse()
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		_open_purse()
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		for key in data:
			if parsed.has(key):
				data[key] = parsed[key]
	_open_purse()



## Stars to spend at Merlin's shop. An adventure from before there was a shop starts with
## every star it has already won; a new one starts with none. Then what is worn is put on.
func _open_purse() -> void:
	if int(data["purse"]) < 0:
		var won := 0
		for kind in ["ride_stars", "race_stars", "sky_stars", "mini_stars"]:
			for key in data[kind]:
				won += int(data[kind][key])
		data["purse"] = won
	Look.load_from(data["look"])


## Pays the stars of a game just finished into the purse, and saves.
func earn(stars: int) -> void:
	data["purse"] = int(data["purse"]) + maxi(stars, 0)
	earned = maxi(stars, 0)
	_save()


func _save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))


## Sound, music, button size and how hard the fights are. These are kept apart from the
## adventure, so starting a new adventure does not reset them.
func _load_settings() -> void:
	if FileAccess.file_exists(SETTINGS_PATH):
		var settings = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if settings is Dictionary:
			sound_on = bool(settings.get("sound", true))
			music_on = bool(settings.get("music", true))
			button_size = clampi(int(settings.get("buttons", 1)), 0, 2)
			easy_fights = bool(settings.get("easy", false))
	if sound != null:
		sound.set_muted(not sound_on)
		sound.set_music(music_on)
	if controls != null:
		controls._layout()


func _save_settings() -> void:
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({ "sound": sound_on, "music": music_on, "buttons": button_size, "easy": easy_fights, "season": Season.mode }))


## Whether the settings say Christmas is "on", "off" or left to the calendar ("auto").
func _saved_season() -> String:
	if FileAccess.file_exists(SETTINGS_PATH):
		var settings = JSON.parse_string(FileAccess.get_file_as_string(SETTINGS_PATH))
		if settings is Dictionary and str(settings.get("season", "auto")) in ["auto", "on", "off"]:
			return str(settings.get("season", "auto"))
	return "auto"


## How much bigger or smaller than usual the thumb buttons are drawn.
func button_scale() -> float:
	return [0.84, 1.0, 1.16][button_size]


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
		_open_purse()
	_save()
	new_game_armed = false
	mode = "play"
	_place_player()


func _place_player() -> void:
	_clear_goblins()
	ride.clear()
	sky.clear()
	set_mount(mount_kind())
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
	mission3.restore()
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
	return mode == "title" or mode == "games" or mode == "shop" or mode == "mini" or mode == "house" or mode == "stable" or mode == "sky" or dialog.active or defeated or (mode == "ride" and ride.finished) or (mode == "play" and (sister.busy() or mission2.fading()))


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
		if easy_fights:
			# The easy setting: a little over half the health, and longer warnings.
			g.max_health = int(ceil(g.max_health * 0.6))
			g.health = g.max_health
			g.swing_windup *= 1.3
		g.process_mode = Node.PROCESS_MODE_PAUSABLE
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
	var kind := encounter_kind
	if encounter_kind == "mission":
		data["cleared"] = cleared() + 1
		data["checkpoint_x"] = player.position.x
		toast("Goblins defeated! Progress saved.")
	elif encounter_kind == "m2" or encounter_kind == "m3":
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
	elif kind == "m3":
		mission3.on_fight_won()
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
			toast("%s waits back here, safe from the goblins." % horse.title)
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
	if player.position.y < GROUND_Y - 120.0:
		pass  # flying overhead
	elif absf(px - DOOR_X) <= 85.0:
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
	context_action = mission3.context(context_action)


func merlin_has_news() -> bool:
	if data["m1"] == "done":
		if data["m2"] == "active" or data["m3"] == "active":
			return false
		return data["m2"] == "available" or data["m3"] == "available" or (data["m2"] == "done" and not data["m2_thanked"]) or (data["m3"] == "done" and not data["m3_thanked"])
	return data["m1"] == "available" or (data["m1"] == "active" and cleared() >= ENCOUNTERS.size())


func _interact() -> void:
	controls.release_all()
	if context_action == "ride":
		_mount()
	elif context_action == "dismount":
		_dismount()
	elif context_action == "call":
		horse.come()
		sound.shout("adeline", "call_unicorn" if horse.kind == "unicorn" else "call", 1.0, true)
		var high := 1.3 if horse.kind == "unicorn" else 1.0
		get_tree().create_timer(0.7).timeout.connect(func(): sound.play("whinny", -5.0, 0.05, high))
	elif context_action == "talk":
		_dismount()
		_talk_to_merlin()
	elif context_action == "sister":
		_talk_to_sister()
	elif context_action in ["fly", "stay", "come", "open"]:
		mission2.interact(context_action)
	elif context_action in ["free", "unicorn"]:
		mission3.interact(context_action)
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
	if sister.want_aboard and horse.wings and sister.activity == "" and absf(sister.x - player.position.x) < 520.0:
		sister.board(sister.x)
		horse.seat_at = Vector2(-41.0, -33.0)  # further back, to leave room for her sister in front
		sound.shout("sister", "sister_whee", 1.0, true)


func _dismount() -> void:
	if not player.mounted:
		return
	if sister.mode == "aboard":
		sister.hop_off()
		horse.seat_at = MOUNTS[horse.kind].get("seat", HorseScript.SEAT)
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
	if data["m3"] == "active" and int(data["m3_step"]) == 0:
		rows.insert(0, { "id": "m3", "label": "Come and find the unicorn!", "status": "Mission", "enabled": true })
	var on_mission: bool = (data["m2"] == "active" and int(data["m2_step"]) >= 1) or mission3.with_sister()
	if horse.wings and not on_mission:
		rows.append({ "id": "aboard", "label": "Fly on %s with me!" % horse.title, "status": "Play", "enabled": true })
	if on_mission:
		pass  # she is on the mission and stays with Adeline
	elif sister.mode == "follow":
		rows.append({ "id": "play", "label": "Off you go and play", "status": "", "enabled": true })
	else:
		rows.append({ "id": "follow", "label": "Come with me", "status": "", "enabled": true })
	dialog.choose("Your little sister", rows, _on_sister_picked)


func _on_sister_picked(id: String) -> void:
	if id == "m2":
		mission2.sister_joins()
	elif id == "m3":
		mission3.sister_joins()
	elif id == "race":
		sister.start_race()
	elif id == "hair":
		sister.do_hair()
	elif id == "aboard":
		# She will climb up in front whenever Adeline gets on the unicorn.
		sister.follow()
		sister.want_aboard = true
		if absf(player.position.x - horse.position.x) <= RIDE_RANGE + 80.0:
			_mount()
		else:
			horse.come()
			toast("%s is coming. Hop on and your sister will climb up too!" % horse.title)
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
	elif data["m3"] == "done" and not data["m3_thanked"]:
		data["m3_thanked"] = true
		_save()
		dialog.say("Merlin", ["A unicorn in our own stable! The sky belongs to the two of you now."], _show_missions)
	elif data["m2"] == "active":
		dialog.say("Merlin", [
			"Fetch your little sister. Then take the flying boat at the river.",
			"Its gate only opens when two stones are pressed at the very same moment. Nobody can do that alone.",
		])
	elif data["m3"] == "active":
		dialog.say("Merlin", [
			"Her hoofprints lead east, past the signpost. Keep your sister close and she will spot them.",
			"Take your little sister. Only the very young can see a unicorn's hoofprints.",
		])
	else:
		_show_missions()


func _show_missions() -> void:
	var m1: String = data["m1"]
	var status := { "available": "Available", "active": "Active", "done": "Completed" }
	var rows := [
		{ "id": "m1", "label": "Goblin Trouble", "status": status[m1], "enabled": m1 == "available" },
		{ "id": "m2", "label": "Rescue Mom and Dad", "status": status[str(data["m2"])] if m1 == "done" else "Locked", "enabled": m1 == "done" and data["m2"] == "available" and data["m3"] != "active" },
		{ "id": "m3", "label": "The Missing Unicorn", "status": status[str(data["m3"])] if m1 == "done" else "Locked", "enabled": m1 == "done" and data["m3"] == "available" and data["m2"] != "active" },
	]
	if m1 == "done":
		var n := int(data["practice_round"])
		rows.append({ "id": "practice", "label": "Practice fight: %d goblin%s" % [n, "" if n == 1 else "s"], "status": "Ready", "enabled": true })
	rows.append({ "id": "shop", "label": "Merlin's shop", "status": "%d stars to spend" % int(data["purse"]), "enabled": true })
	dialog.choose("Merlin's missions", rows, _on_mission_picked)


func _on_mission_picked(id: String) -> void:
	if id == "shop":
		shop.open()
	elif id == "m1":
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
	elif id == "m3":
		data["m3"] = "active"
		data["m3_step"] = 0
		data["m3_clues"] = 0
		_save()
		mission3.restore()
		dialog.say("Merlin", [
			"A unicorn fell out of the sky last night. I saw her rainbow streak down over the eastern meadows.",
			"The goblins will want her magic. Find her before they do.",
			"Take your little sister. Only the very young can see a unicorn's hoofprints.",
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
	if data["m3"] == "active":
		return mission3.objective()
	if data["m2"] == "available" or data["m3"] == "available":
		return "Talk to Merlin"
	return "All missions complete"


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
	if data["m3"] == "active":
		return mission3.hint()
	if data["m2"] == "available":
		return "Merlin has a new mission: the rescue of Mom and Dad."
	if data["m3"] == "available":
		return "Merlin has a new mission: a unicorn has gone missing."
	if player.mounted and horse.wings:
		return "Tap JUMP in the air and %s beats her wings. Keep tapping to fly!" % horse.title
	return "Your family is home. Race your sister, do her hair, or go for a ride."


# --- Loop -------------------------------------------------------------------

# Where the on-screen buttons that are not thumb controls sit.
# --- The title screen --------------------------------------------------------------
# Four cards along the bottom: the adventure, and the three games that can be played on
# their own. Each of those three remembers which course was last chosen; the arrows at
# the ends of its card step back and forward through the ones that have been reached.

const GAMES := [
	{ "id": "adventure", "label": "Adventure", "color": Color(0.25, 0.42, 0.8) },
	{ "id": "ride", "label": "Riding course", "color": Color(0.26, 0.6, 0.36), "course": "ride_course", "stars": "ride_stars", "word": "Course" },
	{ "id": "race", "label": "Horse race", "color": Color(0.82, 0.5, 0.14), "course": "race_course", "stars": "race_stars", "word": "Race" },
	{ "id": "sky", "label": "Fly the unicorn", "color": Color(0.62, 0.36, 0.8), "course": "sky_course", "stars": "sky_stars", "word": "Sky" },
	{ "id": "games", "label": "Farm games", "color": Color(0.86, 0.34, 0.5) },
]
const CARD_ARROW := 50.0  # how wide the arrow at each end of a card is


func card_rect(i: int) -> Rect2:
	var s := get_viewport_rect().size
	var wide := (s.x - 72.0 - 12.0 * (GAMES.size() - 1)) / GAMES.size()
	return Rect2(36.0 + i * (wide + 12.0), s.y - 158.0, wide, 124.0)


## The furthest course of a game that may be chosen: one past the last one finished.
func reached(game_id: int) -> int:
	var best: Dictionary = data[GAMES[game_id]["stars"]]
	var furthest := 0
	for key in best:
		if int(best[key]) > 0:
			furthest = maxi(furthest, int(key))
	return furthest + 1


func chosen(game_id: int) -> int:
	return clampi(int(data[GAMES[game_id]["course"]]), 1, reached(game_id))


func _tap_card(i: int, pos: Vector2) -> void:
	var r := card_rect(i)
	if i == 0:
		_start(not has_save())
		return
	if str(GAMES[i]["id"]) == "games":
		mini.open_list()
		return
	var number := chosen(i)
	if pos.x < r.position.x + CARD_ARROW or pos.x > r.end.x - CARD_ARROW:
		var step := -1 if pos.x < r.position.x + CARD_ARROW else 1
		data[GAMES[i]["course"]] = clampi(number + step, 1, reached(i))
		_save()
		sound.play("pop", -8.0, 0.0, 1.2 if step > 0 else 0.9)
		return
	match str(GAMES[i]["id"]):
		"ride":
			start_ride(number)
		"race":
			start_ride(number, true)
		"sky":
			start_sky(number)


# The old names for the places to tap, kept for the scripted play-throughs.
func adventure_rect() -> Rect2:
	return card_rect(0)


func ride_rect() -> Rect2:
	return card_rect(1).grow_individual(-CARD_ARROW, 0.0, -CARD_ARROW, 0.0)


func race_rect() -> Rect2:
	return card_rect(2).grow_individual(-CARD_ARROW, 0.0, -CARD_ARROW, 0.0)


func settings_rect() -> Rect2:
	return Rect2(36.0, 30.0, 176.0, 54.0)


## The way into Merlin's shop from the title screen, beside Settings.
func shop_rect() -> Rect2:
	return Rect2(224.0, 30.0, 212.0, 54.0)


# --- Menus: settings on the title screen, and the pause menu everywhere else -------------

func open_menu(which: String) -> void:
	menu = which
	new_game_armed = false
	controls.release_all()
	mini.let_go()
	get_tree().paused = true
	sound.play("pop", -8.0)


func close_menu() -> void:
	menu = ""
	new_game_armed = false
	get_tree().paused = false


## The rows of the open menu: what each does, and what it says.
func menu_rows() -> Array:
	var rows := []
	if menu == "pause":
		rows.append(["resume", "Keep playing"])
	rows.append(["sound", "Sound: on" if sound_on else "Sound: off"])
	rows.append(["music", "Music: on" if music_on else "Music: off"])
	rows.append(["buttons", "Buttons: %s" % ["small", "medium", "large"][button_size]])
	rows.append(["fights", "Goblin fights: easy" if easy_fights else "Goblin fights: normal"])
	if menu == "pause":
		if mode == "mini":
			rows.append(["games", "Back to the farm games"])
		rows.append(["home", "Go to the title screen"])
	else:
		rows.append(["season", "Christmas: %s" % { "auto": "in December", "on": "on now", "off": "off" }[Season.mode]])
		if has_save():
			rows.append(["new", "Tap again to erase everything" if new_game_armed else "Start a new adventure"])
		rows.append(["resume", "Done"])
	return rows


func menu_panel() -> Rect2:
	var s := get_viewport_rect().size
	var tall := 96.0 + 66.0 * menu_rows().size()
	return Rect2(s.x / 2.0 - 290.0, maxf((s.y - tall) / 2.0, 8.0), 580.0, tall)


func menu_row_rect(i: int) -> Rect2:
	var p := menu_panel()
	return Rect2(p.position.x + 40.0, p.position.y + 78.0 + 66.0 * i, p.size.x - 80.0, 54.0)


func _tap_menu(pos: Vector2) -> void:
	var rows := menu_rows()
	var picked := ""
	for i in rows.size():
		if menu_row_rect(i).has_point(pos):
			picked = str(rows[i][0])
	if picked == "" and not menu_panel().has_point(pos):
		picked = "resume"  # a tap outside the menu closes it
	if picked != "new":
		new_game_armed = false
	match picked:
		"resume":
			close_menu()
		"sound":
			sound_on = not sound_on
			sound.set_muted(not sound_on)
			sound.play("chime", -4.0)
		"music":
			music_on = not music_on
			sound.set_music(music_on)
		"buttons":
			button_size = (button_size + 1) % 3
			controls._layout()
		"fights":
			easy_fights = not easy_fights
		"season":
			# In December by the calendar, on now, or off. The whole game is dressed again,
			# so it starts over from the title screen.
			Season.mode = { "auto": "on", "on": "off", "off": "auto" }[Season.mode]
			_save_settings()
			if get_tree().current_scene == self:
				get_tree().paused = false
				get_tree().reload_current_scene()
				return
		"home":
			close_menu()
			go_title()
		"games":
			close_menu()
			mini.open_list()
		"new":
			if new_game_armed:
				close_menu()
				_start(true)
			else:
				new_game_armed = true
	if picked in ["sound", "music", "buttons", "fights"]:
		_save_settings()


## Where the two buttons sit when a sky ride is over: beside the castle, not over it.
func sky_panel() -> Rect2:
	var s := get_viewport_rect().size
	return Rect2(s.x * 0.46, s.y * 0.2, s.x * 0.5, s.y * 0.6)


func sky_again_rect() -> Rect2:
	var p := sky_panel()
	return Rect2(p.position.x + 30.0, p.end.y - 106.0, p.size.x / 2.0 - 45.0, 76.0)


func sky_next_rect() -> Rect2:
	var p := sky_panel()
	return Rect2(p.position.x + p.size.x / 2.0 + 15.0, p.end.y - 106.0, p.size.x / 2.0 - 45.0, 76.0)


func sky_rect() -> Rect2:
	return card_rect(3).grow_individual(-CARD_ARROW, 0.0, -CARD_ARROW, 0.0)


## The button that swaps Spirit and the unicorn, under the hearts.
func swap_rect() -> Rect2:
	return Rect2(40.0, 84.0, 250.0, 46.0)


func can_swap() -> bool:
	return mode == "play" and has_unicorn() and not player.mounted and encounter.is_empty() and not dialog.active and not mission2.on_island and sister.activity == ""


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


# --- The sky ride -----------------------------------------------------------------

## Up into the sky on the unicorn, with her little sister on board. `story` is true for the
## flight that ends the unicorn mission.
func start_sky(number: int, story := false) -> void:
	_place_player()
	mode = "sky"
	new_game_armed = false
	if not story:
		data["sky_course"] = number
		_save()
	set_mount("unicorn")
	zoom = sky.ZOOM
	camera.zoom = Vector2(zoom, zoom)
	sky.start(number, story)
	player.reset(sky.at)
	player.min_x = -INF
	player.max_x = INF
	horse.place(sky.at.x)
	player.mounted = true
	horse.set_mounted(true)
	horse.seat_at = Vector2(-41.0, -33.0)  # further back, to leave room for her sister in front
	sister.board(sky.START_X - 420.0)
	_update_camera(0.0, true)
	sound.shout("adeline", "hold_on", 1.0, true)
	sound.play("whinny", -6.0, 0.0, 1.3)


func on_sky_finished(number: int, stars: int) -> void:
	if not sky.story:
		var best: Dictionary = data["sky_stars"]
		var key := str(number)
		if stars > int(best.get(key, 0)):
			best[key] = stars
		earn(stars)


func on_ride_finished(number: int, stars: int) -> void:
	var best: Dictionary = data["race_stars" if ride.racing else "ride_stars"]
	var key := str(number)
	if stars > int(best.get(key, 0)):
		best[key] = stars
	earn(stars)
	sound.play("fanfare", -5.0, 0.0)
	sound.shout("adeline", "we_did_it", 1.0, true)


func go_title() -> void:
	if not dialog.active:
		mini.close()
		shop.close()
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
	if menu != "":
		if has_pos:
			_tap_menu(pos)
		elif event is InputEventKey and event.physical_keycode == KEY_ESCAPE:
			close_menu()
		return
	if mode == "title":
		if clock < 0.5:
			return
		if not has_pos:
			_start(not has_save())
		elif settings_rect().has_point(pos):
			open_menu("settings")
		elif shop_rect().has_point(pos):
			shop.open()
		else:
			for i in GAMES.size():
				if card_rect(i).has_point(pos):
					_tap_card(i, pos)
	elif mode == "games" or mode == "shop":
		pass  # the list of farm games, and the shop, answer their own taps
	elif has_pos and menu_rect().has_point(pos):
		open_menu("pause")
	elif mode == "play" and place_action != "" and has_pos and enter_rect().has_point(pos) and not dialog.active:
		enter_place(place_action)
	elif has_pos and can_swap() and swap_rect().has_point(pos):
		swap_mount()
	elif mode == "sky":
		if sky.state == "done":
			if sky.state_time < 0.8:
				pass
			elif sky.story:
				mission3.flight_done()
			elif has_pos and sky_again_rect().has_point(pos):
				start_sky(sky.course)
			elif has_pos and sky_next_rect().has_point(pos):
				start_sky(sky.course + 1)
		else:
			sky.tap()
	elif mode == "ride":
		if ride.finished and ride.finish_time >= 0.8 and has_pos:
			if again_rect().has_point(pos):
				start_ride(ride.course, ride.racing)
			elif next_rect().has_point(pos):
				start_ride(ride.course + 1, ride.racing)
	elif defeated and defeat_time >= 1.0:
		_retry()


func _physics_process(delta: float) -> void:
	if get_tree().paused:
		return
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
	if mode == "sky":
		return sky.camera_target(view)
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
	# When she flies up on the unicorn the camera goes up with her.
	var rise := maxf(GROUND_Y - 80.0 - player.position.y, 0.0) if (player.mounted and horse.wings) else 0.0
	return Vector2(x, GROUND_Y - 0.24 * view.y - rise)


## Eases the camera toward Adeline and slides the hills behind it. With snap, it jumps
## straight there, for moments when she is placed somewhere new.
func _update_camera(delta: float, snap: bool) -> void:
	var target := _camera_target()
	if snap:
		cam_pos = target
	else:
		var ease := 1.0 - exp(-7.0 * delta)
		cam_pos.x = lerpf(cam_pos.x, target.x, ease)
		if mode == "ride":
			cam_pos.y = lerpf(cam_pos.y, target.y, 1.0 - exp(-4.0 * delta))
		elif mode == "sky":
			cam_pos.y = lerpf(cam_pos.y, target.y, 1.0 - exp(-6.0 * delta))
		else:
			cam_pos.y = lerpf(cam_pos.y, target.y, 1.0 - exp(-9.0 * delta))
	camera.position = cam_pos
	hills_far.position.x = STRIP_START + cam_pos.x * 0.85
	hills_near.position.x = STRIP_START + cam_pos.x * 0.6
	var boat_h := boat.texture.get_size().y * ART_SCALE
	boat.position.y = GROUND_Y + 34.0 - boat_h + sin(clock * 2.0) * 5.0
	if snap:
		for node in [camera, hills_far, hills_near, boat]:
			node.reset_physics_interpolation()


## The tune and the background sound for whatever is going on.
func _set_the_mood() -> void:
	var tune := "home"
	var air := "birds"
	match mode:
		"play":
			if not encounter.is_empty():
				tune = "fight"
		"ride":
			tune = "ride"
		"sky":
			tune = "sky" if sky.high_up() else "home"
			air = "wind" if sky.high_up() else "birds"
		"house", "stable":
			tune = "cozy"
			air = ""
		"shop":
			tune = "cozy"
			air = ""
		"games", "mini":
			tune = "play"
			if mini.which >= 0 and str(mini.LIST[mini.which]["scene"]) == "hut":
				tune = "cozy"
				air = ""
	if Season.festive():
		# Christmas has tunes of its own, and the birds have flown south.
		if sound.tunes.has("x_" + tune):
			tune = "x_" + tune
		if air == "birds":
			air = ""
	sound.want(tune, air)


## A word or a number that pops out of something and drifts up: the damage of a hit, say.
func pop_text(at: Vector2, text: String, color: Color) -> void:
	if fx.size() < 24:
		fx.append([at + Vector2(randf_range(-10.0, 10.0), 0.0), 0.0, text, color])


func _process(delta: float) -> void:
	_set_the_mood()
	if get_tree().paused:
		return
	for pop in fx:
		pop[1] = float(pop[1]) + delta
	fx = fx.filter(func(p): return float(p[1]) < 0.8)
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
	# At Christmas he calls a greeting when Adeline comes by.
	merry = maxf(merry - delta, 0.0)
	if Season.festive() and merry <= 0.0 and mode == "play" and not dialog.active and absf(player.position.x - MERLIN_X) < 230.0:
		merry = 90.0
		sound.shout("merlin", "merlin_merry", 1.0)
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
	for pop in fx:
		var age := float(pop[1]) / 0.8
		var at: Vector2 = pop[0] + Vector2(0.0, -50.0 * (1.0 - (1.0 - age) * (1.0 - age)))
		var ink: Color = pop[3]
		var size := int(26.0 + 10.0 * sin(minf(age * 5.0, 1.0) * PI))
		draw_string_outline(font, at + Vector2(-60.0, 0.0), str(pop[2]), HORIZONTAL_ALIGNMENT_CENTER, 120.0, size, 7, Color(0.0, 0.0, 0.0, 0.6 * (1.0 - age * age)))
		draw_string(font, at + Vector2(-60.0, 0.0), str(pop[2]), HORIZONTAL_ALIGNMENT_CENTER, 120.0, size, Color(ink.r, ink.g, ink.b, 1.0 - age * age))


func _draw_merlin_mark(g: float) -> void:
	# A bobbing mark over Merlin when he has something new to say.
	if mode == "play" and merlin_has_news():
		var bob := sin(clock * 4.0) * 5.0
		# It sits in a glow, and a ring spreads from it every second or so to catch the eye.
		var middle := Vector2(MERLIN_X, g - 208.0 + bob)
		var beat := fmod(clock * 0.9, 1.0)
		draw_arc(middle, 24.0 + beat * 34.0, 0.0, TAU, 40, Color(1.0, 0.85, 0.2, 0.7 * (1.0 - beat)), 4.0)
		draw_circle(middle, 30.0, Color(1.0, 0.9, 0.4, 0.22))
		draw_rect(Rect2(MERLIN_X - 5.0, g - 226.0 + bob, 10.0, 26.0), Color(1.0, 0.85, 0.2))
		draw_circle(Vector2(MERLIN_X, g - 188.0 + bob), 6.0, Color(1.0, 0.85, 0.2))


func _draw_river(g: float) -> void:
	if Season.festive():
		# Frozen over: pale ice with a white rim.
		draw_rect(Rect2(RIVER_X, g + 6.0, 800.0, 600.0), Color(0.62, 0.8, 0.93))
		draw_rect(Rect2(RIVER_X, g + 6.0, 800.0, 12.0), Color(0.93, 0.97, 1.0))
		return
	draw_rect(Rect2(RIVER_X, g + 6.0, 800.0, 600.0), Color(0.25, 0.55, 0.85))
	draw_rect(Rect2(RIVER_X, g + 6.0, 800.0, 10.0), Color(0.6, 0.82, 0.98))
