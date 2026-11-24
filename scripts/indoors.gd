extends Control
## Indoors. Two places, both drawn over the outdoor world:
##   * Adeline's living room, which the player decorates.
##   * Spirit's stable, where the player feeds, brushes and pets her.
##
## Both rooms behave like real spaces. In the living room the floor has depth: things
## further back are smaller and sit behind things nearer the front. A thing let go in the
## air falls and lands with a bump. Furniture stands on the floor, pictures hang on the
## wall, and small things can sit on a table, a shelf or a seat and ride along with it.
## In the stable, each dusty patch on Spirit is cleaned where the brush actually goes,
## Spirit reaches for food, and anything dropped falls into the straw.
##
## Everything is placed in the units of the background picture (1344 x 752), and the whole
## room is scaled to fill whatever screen it is on.

const RigScript := preload("res://scripts/rig.gd")

const ROOM := Vector2(1344.0, 752.0)
const SAVE_PATH := "user://home.json"
const TRAY := 96.0  # height of the strip of things to pick from
const HUES := [0.0, 0.07, 0.15, 0.36, 0.5, 0.62, 0.76, 0.9]  # how far round the colour wheel
const SIZES := [0.75, 1.0, 1.3]
const MAX_THINGS := 30
const GRAVITY := 2800.0

# The living room floor runs from the foot of the wall (BACK) toward the player.
const BACK := 512.0
const NEAR := 650.0
const FAR_SIZE := 0.84  # how big things look at the back of the room
const NEAR_SIZE := 1.06

# name, size, how it sits (floor, rug or wall), where its top is for putting things on
# (as a share of its height from the top; 0 means nothing sits on it), and whether it is
# small enough to sit on other things
const FURNITURE := [
	["sofa", 1.0, "floor", 0.56, false], ["armchair", 0.95, "floor", 0.6, false], ["rug", 1.3, "rug", 0.0, false],
	["table", 0.85, "floor", 0.14, false], ["bookshelf", 1.0, "floor", 0.04, false], ["lamp", 0.95, "floor", 0.0, false],
	["plant", 0.7, "floor", 0.0, true], ["painting", 0.6, "wall", 0.0, false], ["clock", 0.45, "wall", 0.0, false],
	["flowers", 0.5, "floor", 0.0, true], ["rocking_horse", 0.7, "floor", 0.0, false], ["cushion", 0.55, "floor", 0.0, true],
]
const BEDROOM := [
	["bed", 1.15, "floor", 0.5, false], ["wardrobe", 1.1, "floor", 0.03, false], ["nightstand", 0.6, "floor", 0.06, false],
	["desk", 0.9, "floor", 0.06, false], ["chest", 0.7, "floor", 0.12, false], ["mirror", 0.9, "floor", 0.0, false],
	["heart_rug", 1.1, "rug", 0.0, false], ["bedside_lamp", 0.4, "floor", 0.0, true], ["teddy", 0.4, "floor", 0.0, true],
	["toy_horse", 0.45, "floor", 0.0, true], ["poster", 0.6, "wall", 0.0, false], ["bunting", 1.0, "wall", 0.0, false],
]
# name and what it is for
const CARE := [["apple", "food"], ["carrot", "food"], ["hay", "food"], ["oats", "food"], ["brush", "brush"], ["heart", "pet"]]

const SPIRIT_AT := Vector2(720.0, 632.0)
const SPIRIT_SIZE := 2.3
const BIT := Vector2(248.0, 72.0)  # the corner of Spirit's mouth, in pixels of her body picture
# Dusty patches, in pixels of her body picture.
const DIRT := [Vector2(42, 150), Vector2(76, 124), Vector2(112, 152), Vector2(142, 134), Vector2(62, 176), Vector2(104, 182), Vector2(150, 172), Vector2(182, 150)]

# Turns every colour in a picture round the colour wheel, leaving black outlines black.
const HUE_SHADER := "
shader_type canvas_item;
uniform float shift = 0.0;
void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec3 axis = vec3(0.57735);
	float a = shift * 6.28318;
	c.rgb = c.rgb * cos(a) + cross(axis, c.rgb) * sin(a) + axis * dot(axis, c.rgb) * (1.0 - cos(a));
	COLOR = c;
}
"

var game = null
var font: Font
var place := ""  # "", "house" or "stable"
var stage: Node2D = null
var overlay: Control = null
var shader: Shader = null
var textures := {}
var images := {}
var home := { "room": [], "bedroom": [], "teeth": { "clean": 0.0, "time": 0.0 }, "care": { "food": 0.0, "shine": 0.0, "love": 0.0, "time": 0.0 } }
var clock := 0.0
var finger := -1
var note := ""
var note_time := 0.0

# Adeline, who walks about in both rooms.
var adeline = null
var at := Vector2.ZERO  # where her feet are
var goal := Vector2.ZERO
var facing := 1
var walk := 0.0

# The house: the living room and the bedroom.
var room := "living"
var backdrop: Sprite2D = null
var things: Array = []  # each: { "data": what is saved, "node": its picture, and how it is falling }
var selected := -1
var dragging := false
var grab := Vector2.ZERO
var next_id := 1

# The stable.
var spirit = null
var tool := ""
var tool_node: Sprite2D = null
var last_touch := Vector2.ZERO
var stroke := 0.0
var on_her := false  # whether the tool was already on Spirit a moment ago
var munch := 0.0
var hop := 0.0
var lean := 0.0  # how far Spirit is reaching her head down (or up) for food
var dirt: Array = []  # each: { "node": the patch, "spot": where on her body, "level": how dusty }
var drops: Array = []  # things let go of, falling into the straw
var celebrated := false

# Sleeping: 0 awake, 1 on the way to bed, 2 asleep. Adeline sleeps in her bed, Spirit in her stable.
var sleep := 0
var night := 0.0  # how dark the room has got, from 0 to 1

# The bathroom: twelve teeth, each with its own grime, and toothpaste on the brush.
var teeth: Array = []
var paste := 0.0
var foam: Array = []  # bubbles: where, and how long each has left
var teeth_done := true


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	visible = false
	shader = Shader.new()
	shader.code = HUE_SHADER
	if FileAccess.file_exists(SAVE_PATH):
		var saved = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
		if saved is Dictionary:
			for key in ["room", "bedroom"]:
				if saved.get(key) is Array:
					home[key] = saved[key]
			if saved.get("care") is Dictionary:
				for key in home["care"]:
					home["care"][key] = float(saved["care"].get(key, 0.0))
			if saved.get("teeth") is Dictionary:
				for key in home["teeth"]:
					home["teeth"][key] = float(saved["teeth"].get(key, 0.0))


func _save() -> void:
	if place == "house":
		var list: Array = []
		for thing in things:
			list.append(thing["data"])
		if room == "bathroom":
			var grime := 0.0
			for level in teeth:
				grime += float(level)
			home["teeth"] = { "clean": 1.0 - grime / maxf(teeth.size(), 1.0), "time": Time.get_unix_time_from_system() }
		elif room != "":
			home["room" if room == "living" else "bedroom"] = list
	home["care"]["time"] = Time.get_unix_time_from_system()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(home))


func _tex(name: String) -> Texture2D:
	if not textures.has(name):
		var ext := "jpg" if name == "room" or name == "stable" or name == "bedroom" or name == "bathroom" else "png"
		textures[name] = load("res://art/room/%s.%s" % [name, ext])
	return textures[name]


## Whether a picture is solid at a pixel, so a touch lands on the thing itself and not
## on the empty corner of its box.
func _solid(key: String, tex: Texture2D, pixel: Vector2) -> bool:
	if not images.has(key):
		var img := tex.get_image()
		if img != null and img.is_compressed():
			img.decompress()
		images[key] = img
	var image: Image = images[key]
	if image == null:
		return true
	var x := int(pixel.x)
	var y := int(pixel.y)
	if x < 0 or y < 0 or x >= image.get_width() or y >= image.get_height():
		return false
	return image.get_pixel(x, y).a > 0.15


# --- Coming and going --------------------------------------------------------

func open(which: String) -> void:
	close()
	place = which
	visible = true
	finger = -1
	clock = 0.0
	note = ""
	stage = Node2D.new()
	add_child(stage)
	backdrop = Sprite2D.new()
	backdrop.texture = _tex("room" if which == "house" else "stable")
	backdrop.centered = false
	backdrop.z_index = -4000
	stage.add_child(backdrop)
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.z_index = 4000  # the buttons and tray stay in front of everything in the room
	overlay.draw.connect(_draw_ui)
	add_child(overlay)
	adeline = Node2D.new()
	adeline.set_script(RigScript)
	stage.add_child(adeline)
	adeline.build("res://art/adeline")
	_layout()
	if which == "house":
		_open_house()
	else:
		_open_stable()


func close() -> void:
	if place == "":
		return
	_save()
	if stage != null:
		stage.queue_free()
	if overlay != null:
		overlay.queue_free()
	stage = null
	overlay = null
	things.clear()
	dirt.clear()
	drops.clear()
	selected = -1
	dragging = false
	tool = ""
	tool_node = null
	finger = -1
	sleep = 0
	night = 0.0
	place = ""
	visible = false


func _layout() -> void:
	var s := get_viewport_rect().size
	var k := maxf(s.x / ROOM.x, s.y / ROOM.y)
	stage.scale = Vector2(k, k)
	# The floor matters most, so the room is lined up along the bottom of the screen.
	stage.position = Vector2((s.x - ROOM.x * k) / 2.0, s.y - ROOM.y * k)
	if place == "house" and room == "bathroom":
		stage.position.y -= TRAY  # the bathroom floor is low in its picture, so the room is lifted clear of the tray


func _to_room(screen: Vector2) -> Vector2:
	return (screen - stage.position) / stage.scale.x


func _to_screen(room: Vector2) -> Vector2:
	return room * stage.scale.x + stage.position


## The part of the room that can be seen above the tray.
func _seen() -> Rect2:
	var s := get_viewport_rect().size
	var from := _to_room(Vector2(0.0, 110.0))
	var to := _to_room(Vector2(s.x, s.y - TRAY))
	return Rect2(from, to - from)


func _say(text: String) -> void:
	note = text
	note_time = 2.6


# --- The living room ---------------------------------------------------------

func _open_house() -> void:
	room = ""
	_enter_room("living")


## Walks through the door into the other room. Each room keeps its own things.
func _enter_room(which: String) -> void:
	if room != "":
		_save()
	for thing in things:
		thing["node"].queue_free()
	things.clear()
	selected = -1
	dragging = false
	sleep = 0
	_drop_tool(false)
	room = which
	backdrop.texture = _tex({ "living": "room", "bedroom": "bedroom", "bathroom": "bathroom" }[which])
	_layout()
	# She comes in by the door: on the right of the living room, on the left of the bedroom.
	at = Vector2(_seen().end.x - 190.0 if which == "living" else _seen().position.x + 190.0, _front() - 14.0)
	goal = at
	facing = -1 if which == "living" else 1
	clock = 0.0
	next_id = 1
	if which == "bathroom":
		_open_bathroom()
		return
	for data in home["room" if which == "living" else "bedroom"]:
		if not (data is Dictionary) or _named(str(data.get("t", ""))).is_empty():
			continue
		if int(data.get("v", 1)) < 2:
			# Rooms saved by the first version kept the middle of each thing, not its foot.
			var spec: Array = _named(str(data["t"]))
			data["y"] = float(data["y"]) + _tex(str(data["t"])).get_height() * float(spec[1]) * float(SIZES[clampi(int(data.get("s", 1)), 0, 2)]) / 2.0
			data["on"] = -1
			data["v"] = 2
			data["id"] = next_id
		next_id = maxi(next_id, int(data.get("id", 0)) + 1)
		_spawn(data)
	for i in things.size():
		_refresh(i)


## The things that can be put in the room she is in. Nothing is put in the bathroom.
func _list() -> Array:
	if room == "bathroom":
		return []
	return FURNITURE if room == "living" else BEDROOM


## What the strip along the bottom shows.
func _tray_name(i: int) -> String:
	if place == "stable":
		return str(CARE[i][0])
	return ["toothpaste", "toothbrush"][i] if room == "bathroom" else str(_list()[i][0])


## The doors out of the room she is in: where the button is, where it leads, what it says.
func _doors() -> Array:
	var s := get_viewport_rect().size
	var left := Rect2(24.0, 124.0, 212.0, 52.0)
	var right := Rect2(s.x - 236.0, 124.0, 212.0, 52.0)
	match room:
		"living":
			return [[right, "bedroom", "To the bedroom"], [left, "bathroom", "To the bathroom"]]
		"bedroom":
			return [[left, "living", "To the living room"]]
	return [[right, "living", "To the living room"]]


## The button for going to sleep and waking up: in the bedroom, and in the stable for Spirit.
func _sleep_rect() -> Rect2:
	return Rect2(get_viewport_rect().size.x - 236.0, 124.0, 212.0, 52.0)


func _bed() -> int:
	for i in things.size():
		if things[i]["data"]["t"] == "bed":
			return i
	return -1


func _toggle_sleep() -> void:
	if sleep > 0:
		# Waking up.
		if place == "house" and sleep == 2 and _bed() >= 0:
			var bed: Dictionary = things[_bed()]["data"]
			at = Vector2(clampf(float(bed["x"]) + _half_width(_bed()) + 70.0, 120.0, ROOM.x - 120.0), clampf(float(bed["y"]) + 6.0, BACK + 24.0, _front()))
			goal = at
		sleep = 0
		game.sound.play("pop", -6.0)
		return
	if place == "stable":
		_drop_tool(false)
		sleep = 2
		game.sound.shout("adeline", "goodnight", 1.0, true)
		game.sound.play("snort", -8.0)
		return
	if _bed() < 0:
		_say("Put a bed in the room first.")
		return
	selected = -1
	sleep = 1
	var bed: Dictionary = things[_bed()]["data"]
	goal = Vector2(float(bed["x"]), clampf(float(bed["y"]) + 6.0, BACK + 24.0, _front()))


# --- The bathroom ------------------------------------------------------------

func _open_bathroom() -> void:
	at = Vector2(_to_room(Vector2(150.0, 0.0)).x, 712.0)  # beside the mirror, where she can be seen
	goal = at
	facing = 1
	paste = 0.0
	foam.clear()
	# Teeth get a little grubby again between visits.
	var saved: Dictionary = home["teeth"]
	var away := maxf(Time.get_unix_time_from_system() - float(saved["time"]), 0.0) if float(saved["time"]) > 0.0 else 99999.0
	var grime := clampf(1.0 - float(saved["clean"]) + away / 1500.0, 0.0, 1.0)
	teeth.clear()
	for i in 12:
		teeth.append(clampf(grime * randf_range(0.75, 1.0), 0.0, 1.0))
	teeth_done = grime < 0.02
	if not teeth_done:
		game.sound.shout("adeline", "brush_teeth", 1.0, true)


## Where the big mirror is drawn on screen, and the twelve teeth in it.
func _mirror() -> Rect2:
	var s := get_viewport_rect().size
	var size := Vector2(minf(660.0, s.x * 0.52), minf(400.0, (s.y - TRAY) * 0.6))
	return Rect2(Vector2(s.x / 2.0 - size.x / 2.0, 150.0), size)


func _tooth(i: int) -> Rect2:
	var m := _mirror()
	var w := m.size.x * 0.105
	var upper := i < 6
	var col := i % 6
	var h := m.size.y * (0.2 if upper else 0.16)
	# The middle teeth are a little bigger, as real front teeth are.
	var grow := 1.0 + 0.12 * (1.0 - absf(col - 2.5) / 2.5)
	var x := m.get_center().x + (col - 3) * w * 1.04
	var y := m.get_center().y + (m.size.y * 0.02 - h * grow if upper else m.size.y * 0.06)
	return Rect2(x, y, w, h * grow)


## The end of the brush that does the work, on screen.
func _bristles() -> Vector2:
	return _to_screen(tool_node.position + Vector2(92.0, -22.0) * tool_node.scale.x)


func _brush_teeth(moved: float) -> void:
	if moved <= 0.0:
		return
	var tip := _bristles()
	var touched := false
	for i in teeth.size():
		if _tooth(i).grow(10.0).has_point(tip):
			touched = true
	# Only scrubbing counts: the brush has to be on the teeth before and after it moves.
	var scrub := minf(moved, 40.0) if touched and on_her else 0.0
	on_her = touched
	if scrub <= 0.0:
		return
	moved = scrub
	for i in teeth.size():
		if _tooth(i).grow(10.0).has_point(tip) and float(teeth[i]) > 0.0:
			# Toothpaste does the work. A dry brush hardly helps.
			teeth[i] = maxf(float(teeth[i]) - moved / (150.0 if paste > 0.0 else 6000.0), 0.0)
	if paste > 0.0:
		paste = maxf(paste - moved / 2600.0, 0.0)
		if int((stroke + moved) / 26.0) != int(stroke / 26.0):
			foam.append([tip + Vector2(randf_range(-22.0, 22.0), randf_range(-16.0, 16.0)), randf_range(0.5, 1.0)])
		if int((stroke + moved) / 150.0) != int(stroke / 150.0):
			game.sound.play("brush", -4.0, 0.15, 1.3)
	elif note_time <= 0.0:
		_say("Tap the toothpaste first.")
	stroke += moved
	if not teeth_done:
		var grime := 0.0
		for level in teeth:
			grime += float(level)
		if grime <= 0.0:
			teeth_done = true
			_say("Sparkling!")
			game.sound.play("chime", -3.0, 0.0, 1.2)
			game.sound.play("fanfare", -7.0, 0.0)
			game.sound.shout("adeline", "all_clean", 1.0, true)
			_save()


func _draw_bathroom(s: Vector2) -> void:
	var m := _mirror()
	var c := m.get_center()
	# The mirror, with Adeline's smile in it.
	var rim := PackedVector2Array()
	var glass := PackedVector2Array()
	for k in 48:
		var a := TAU * k / 48.0
		rim.append(c + Vector2(cos(a) * (m.size.x / 2.0 + 16.0), sin(a) * (m.size.y / 2.0 + 16.0)))
		glass.append(c + Vector2(cos(a) * m.size.x / 2.0, sin(a) * m.size.y / 2.0))
	overlay.draw_colored_polygon(rim, Color(0.85, 0.6, 0.2))
	overlay.draw_colored_polygon(glass, Color(0.99, 0.82, 0.7))
	overlay.draw_polyline(rim + PackedVector2Array([rim[0]]), Color(0.2, 0.12, 0.05), 4.0)
	overlay.draw_circle(c + Vector2(-m.size.x * 0.33, -m.size.y * 0.08), m.size.y * 0.1, Color(1.0, 0.6, 0.6, 0.45))
	overlay.draw_circle(c + Vector2(m.size.x * 0.33, -m.size.y * 0.08), m.size.y * 0.1, Color(1.0, 0.6, 0.6, 0.45))
	overlay.draw_arc(c + Vector2(0.0, -m.size.y * 0.36), m.size.y * 0.06, 0.3, PI - 0.3, 12, Color(0.75, 0.5, 0.4), 4.0)
	var mouth := PackedVector2Array()
	for k in 40:
		var a := TAU * k / 40.0
		mouth.append(c + Vector2(cos(a) * m.size.x * 0.36, m.size.y * 0.04 + sin(a) * m.size.y * 0.27))
	overlay.draw_colored_polygon(mouth, Color(0.45, 0.1, 0.14))
	overlay.draw_polyline(mouth + PackedVector2Array([mouth[0]]), Color(0.85, 0.25, 0.3), 9.0)
	for i in teeth.size():
		var t := _tooth(i)
		overlay.draw_rect(t, Color.WHITE)
		var grime: float = teeth[i]
		if grime > 0.0:
			overlay.draw_rect(t, Color(0.86, 0.74, 0.25, grime * 0.8))
			if grime > 0.45:
				overlay.draw_circle(t.position + t.size * Vector2(0.3, 0.4), t.size.x * 0.12, Color(0.5, 0.36, 0.12, grime * 0.8))
				overlay.draw_circle(t.position + t.size * Vector2(0.68, 0.66), t.size.x * 0.09, Color(0.5, 0.36, 0.12, grime * 0.8))
		elif int(clock * 2.0 + i * 0.37) % 5 == 0:
			var p := t.position + t.size * Vector2(0.7, 0.28)
			overlay.draw_line(p + Vector2(-7.0, 0.0), p + Vector2(7.0, 0.0), Color(0.6, 0.9, 1.0), 2.0)
			overlay.draw_line(p + Vector2(0.0, -7.0), p + Vector2(0.0, 7.0), Color(0.6, 0.9, 1.0), 2.0)
		overlay.draw_rect(t, Color(0.25, 0.2, 0.25), false, 2.0)
	for bubble in foam:
		overlay.draw_circle(bubble[0], 5.0 + 9.0 * float(bubble[1]), Color(1.0, 1.0, 1.0, 0.75 * float(bubble[1])))
	# Toothpaste on the brush.
	if tool_node != null and paste > 0.0:
		overlay.draw_circle(_bristles() + Vector2(0.0, -10.0), 6.0 + 9.0 * paste, Color(0.7, 0.95, 1.0))
		overlay.draw_circle(_bristles() + Vector2(0.0, -10.0), 6.0 + 9.0 * paste, Color(0.2, 0.4, 0.6), false, 2.0)
	if paste > 0.0:
		var cell := _cell_rect(1)
		overlay.draw_circle(cell.position + Vector2(cell.size.x * 0.76, cell.size.y * 0.3), 8.0, Color(0.7, 0.95, 1.0))
	if clock < 10.0 and not teeth_done:
		_text(Vector2(0.0, 132.0), "Tap the toothpaste, then drag the toothbrush over every tooth.", 22, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)


## What is known about a kind of furniture, from either room's list.
func _named(name: String) -> Array:
	for entry in FURNITURE + BEDROOM:
		if entry[0] == name:
			return entry
	return []


func _spec(index: int) -> Array:
	return _named(str(things[index]["data"]["t"]))


## The nearest the floor comes to the player before the tray hides it.
func _front() -> float:
	return minf(_seen().end.y - 8.0, 700.0)


## How big something looks when its foot is this far down the room.
func _depth(foot: float) -> float:
	return lerpf(FAR_SIZE, NEAR_SIZE, clampf((foot - BACK) / (NEAR - BACK), 0.0, 1.0))


func _find(id: int) -> int:
	for i in things.size():
		if int(things[i]["data"]["id"]) == id:
			return i
	return -1


## Where a thing's weight rests: its own foot on the floor, or the foot of whatever it sits on.
func _ground(index: int) -> float:
	var under := _find(int(things[index]["data"]["on"]))
	return float(things[under]["data"]["y"]) if under >= 0 else float(things[index]["data"]["y"])


func _size(index: int) -> float:
	var data: Dictionary = things[index]["data"]
	var spec := _spec(index)
	var size: float = float(spec[1]) * float(SIZES[clampi(int(data["s"]), 0, SIZES.size() - 1)])
	return size if spec[2] == "wall" else size * _depth(_ground(index))


func _height(index: int) -> float:
	return things[index]["node"].texture.get_height() * _size(index)


func _half_width(index: int) -> float:
	return things[index]["node"].texture.get_width() * _size(index) / 2.0


## The line on a piece of furniture where a small thing can sit.
func _top(index: int) -> float:
	return float(things[index]["data"]["y"]) - _height(index) * (1.0 - float(_spec(index)[3]))


func _spawn(data: Dictionary) -> int:
	var node := Sprite2D.new()
	node.texture = _tex(str(data["t"]))
	var material := ShaderMaterial.new()
	material.shader = shader
	node.material = material
	stage.add_child(node)
	things.append({ "data": data, "node": node, "falling": false, "vy": 0.0, "target": 0.0, "bounces": 0 })
	return things.size() - 1


## Makes a thing's picture match what is written down about it.
func _refresh(index: int) -> void:
	var data: Dictionary = things[index]["data"]
	var node: Sprite2D = things[index]["node"]
	var spec := _spec(index)
	var size := _size(index)
	node.scale = Vector2(-size if bool(data["f"]) else size, size)
	node.position = Vector2(float(data["x"]), float(data["y"]) - node.texture.get_height() * size / 2.0)
	(node.material as ShaderMaterial).set_shader_parameter("shift", float(HUES[clampi(int(data["h"]), 0, HUES.size() - 1)]))
	# Things nearer the front are drawn over things further back.
	if dragging and index == selected:
		node.z_index = 3000
	elif spec[2] == "rug":
		node.z_index = -2000 + int(float(data["y"]))
	elif spec[2] == "wall":
		node.z_index = -1000
	else:
		node.z_index = int(_ground(index)) + (1 if int(data["on"]) >= 0 else 0)


## Moves whatever is sitting on a thing along with it. Anything left hanging over the
## edge falls off onto the floor.
func _carry(index: int, dx: float) -> void:
	var id := int(things[index]["data"]["id"])
	for i in things.size():
		var data: Dictionary = things[i]["data"]
		if int(data["on"]) != id:
			continue
		data["x"] = float(data["x"]) + dx
		if absf(float(data["x"]) - float(things[index]["data"]["x"])) > _half_width(index) * 0.8:
			data["on"] = -1
			_drop(i, float(things[index]["data"]["y"]))
		else:
			data["y"] = _top(index)
			things[i]["falling"] = false
		_refresh(i)


func _drop(index: int, target: float) -> void:
	var thing: Dictionary = things[index]
	thing["target"] = clampf(target, BACK + 8.0, _front())
	thing["falling"] = true
	thing["vy"] = 0.0
	thing["bounces"] = 0


func _add(kind: int) -> void:
	if things.size() >= MAX_THINGS:
		_say("The room is full! Take something out first.")
		return
	var spec: Array = _list()[kind]
	var x := clampf(ROOM.x * 0.5 + randf_range(-220.0, 220.0), _seen().position.x + 80.0, _seen().end.x - 80.0)
	var data := { "id": next_id, "t": spec[0], "x": x, "y": 250.0, "h": 0, "f": false, "s": 1, "on": -1, "v": 2 }
	next_id += 1
	selected = _spawn(data)
	if spec[2] == "wall":
		data["x"] = ROOM.x * randf_range(0.18, 0.34)
		data["y"] = 330.0
	elif spec[2] == "rug":
		data["x"] = ROOM.x * 0.5
		data["y"] = _front() - 6.0
	else:
		# New furniture is let go just above the floor and drops into place.
		data["y"] = BACK - 60.0
		_drop(selected, randf_range(BACK + 50.0, _front() - 10.0))
	_refresh(selected)
	game.sound.play("pop", -6.0, 0.1)
	_save()


func _thing_at(spot: Vector2) -> int:
	var best := -1
	var in_box := -1
	for i in things.size():
		var node: Sprite2D = things[i]["node"]
		var size := node.texture.get_size() * absf(node.scale.y)
		if not Rect2(node.position - size / 2.0, size).has_point(spot):
			continue
		if in_box < 0 or node.z_index >= things[in_box]["node"].z_index:
			in_box = i
		var pixel := (spot - node.position) / node.scale + node.texture.get_size() / 2.0
		if _solid(str(things[i]["data"]["t"]), node.texture, pixel) and (best < 0 or node.z_index >= things[best]["node"].z_index):
			best = i
	return best if best >= 0 else in_box


## While a thing is held: floor things can be lifted anywhere, pictures stay on the wall,
## rugs stay on the floor.
func _hold(spot: Vector2) -> void:
	var data: Dictionary = things[selected]["data"]
	var seen := _seen()
	var kind: String = _spec(selected)[2]
	var before := float(data["x"])
	data["x"] = clampf(spot.x, seen.position.x + 30.0, seen.end.x - 30.0)
	var tall := _height(selected)
	if kind == "wall":
		data["y"] = clampf(spot.y, maxf(seen.position.y, 40.0) + tall, BACK - 96.0)
	elif kind == "rug":
		data["y"] = clampf(spot.y, BACK + tall * 0.7, _front())
	else:
		data["y"] = clampf(spot.y, seen.position.y + tall * 0.5, _front())
	_refresh(selected)
	_carry(selected, float(data["x"]) - before)


## When a thing is let go it comes to rest: on a table, shelf or seat under it if it is
## small enough, and otherwise on the floor.
func _let_go() -> void:
	var data: Dictionary = things[selected]["data"]
	var spec := _spec(selected)
	if spec[2] == "floor":
		var foot := float(data["y"])
		var rest := -1
		if bool(spec[4]):
			for i in things.size():
				if i == selected or float(_spec(i)[3]) <= 0.0 or int(things[i]["data"]["on"]) >= 0 or things[i]["falling"]:
					continue
				var top := _top(i)
				if absf(float(data["x"]) - float(things[i]["data"]["x"])) <= _half_width(i) * 0.76 and foot <= top + 36.0:
					if rest < 0 or top < _top(rest):
						rest = i
		if rest >= 0:
			data["on"] = int(things[rest]["data"]["id"])
			things[selected]["target"] = _top(rest)
			things[selected]["falling"] = true
			things[selected]["vy"] = 0.0
			things[selected]["bounces"] = 0
		else:
			data["on"] = -1
			_drop(selected, foot if foot >= BACK + 8.0 else BACK + 30.0)
	_refresh(selected)
	# Adeline comes over to look.
	var side := -1.0 if at.x < float(data["x"]) else 1.0
	var floor_y := clampf(_ground(selected), BACK + 20.0, _front()) if spec[2] != "wall" else BACK + 60.0
	_walk_to(Vector2(float(data["x"]) + side * (_half_width(selected) + 60.0), floor_y + 6.0))
	game.sound.shout("adeline", "lovely", 0.3)
	_save()


func _fall(delta: float) -> void:
	for i in things.size():
		var thing: Dictionary = things[i]
		if not thing["falling"] or (dragging and i == selected):
			continue
		var data: Dictionary = thing["data"]
		var under := _find(int(data["on"]))
		if under >= 0:
			thing["target"] = _top(under)
		var target: float = thing["target"]
		var before := float(data["y"])
		if before > target:
			data["y"] = target  # it was below where it belongs: put it back
			thing["falling"] = false
		else:
			thing["vy"] = float(thing["vy"]) + GRAVITY * delta
			data["y"] = before + float(thing["vy"]) * delta
			if float(data["y"]) >= target:
				data["y"] = target
				var speed: float = thing["vy"]
				if speed > 240.0 and int(thing["bounces"]) < 2:
					thing["vy"] = -speed * 0.26  # a little bounce
					thing["bounces"] = int(thing["bounces"]) + 1
					game.sound.play("thump", clampf(-16.0 + speed / 90.0, -16.0, -3.0), 0.1)
				else:
					thing["falling"] = false
					_save()
		_refresh(i)
		_carry(i, 0.0)


func _walk_to(spot: Vector2) -> void:
	var seen := _seen()
	goal = Vector2(clampf(spot.x, seen.position.x + 70.0, seen.end.x - 70.0), clampf(spot.y, BACK + 24.0, _front()))


# --- The stable --------------------------------------------------------------

func _open_stable() -> void:
	at = Vector2(300.0, SPIRIT_AT.y + 14.0)
	goal = at
	facing = 1
	spirit = Node2D.new()
	spirit.set_script(RigScript)
	spirit.position = SPIRIT_AT
	spirit.scale = Vector2(SPIRIT_SIZE, SPIRIT_SIZE)
	spirit.z_index = int(SPIRIT_AT.y)
	stage.add_child(spirit)
	spirit.build("res://art/spirit")
	for part in ["leg_front_far_upper", "leg_front_far_lower", "leg_hind_far_upper", "leg_hind_far_lower"]:
		spirit.tint(part, Color(0.72, 0.72, 0.78))
	# Since the last visit Spirit has got a little hungry, dusty and lonely again.
	var care: Dictionary = home["care"]
	var away := maxf(Time.get_unix_time_from_system() - float(care["time"]), 0.0) if float(care["time"]) > 0.0 else 99999.0
	for key in ["food", "shine", "love"]:
		care[key] = clampf(float(care[key]) - away / 1200.0, 0.0, 1.0)
	# Dusty patches on her coat. Each one is brushed away where it is.
	for spot in DIRT:
		var smudge := Sprite2D.new()
		smudge.texture = game.spark
		smudge.scale = Vector2(1.5, 1.05) * randf_range(0.85, 1.2)
		smudge.z_index = int(SPIRIT_AT.y) + 1
		stage.add_child(smudge)
		dirt.append({ "node": smudge, "spot": spot, "level": 1.0 - float(care["shine"]) })
	celebrated = _all_full()


func _all_full() -> bool:
	var care: Dictionary = home["care"]
	return float(care["food"]) >= 0.999 and float(care["shine"]) >= 0.999 and float(care["love"]) >= 0.999


## Where a pixel of Spirit's body picture is in the room right now, as she leans and bobs.
func _on_spirit(pixel: Vector2) -> Vector2:
	var body: Sprite2D = spirit.info["body"]["sprite"]
	return spirit.position + (body.position + ((pixel + body.offset) * spirit.tex_scale).rotated(body.rotation)) * SPIRIT_SIZE


## The other way round: which pixel of her body picture a spot in the room touches.
func _spirit_pixel(spot: Vector2) -> Vector2:
	var body: Sprite2D = spirit.info["body"]["sprite"]
	return ((spot - spirit.position) / SPIRIT_SIZE - body.position).rotated(-body.rotation) / spirit.tex_scale - body.offset


## Is this spot on Spirit: her body, neck and head, or her legs?
func _touching(spot: Vector2) -> bool:
	if _solid("spirit_body", spirit.info["body"]["sprite"].texture, _spirit_pixel(spot)):
		return true
	return Rect2(SPIRIT_AT + Vector2(-150.0, -175.0), Vector2(250.0, 175.0)).has_point(spot)


func _pick_tool(index: int, pos: Vector2) -> void:
	_drop_tool(false)
	tool = str(CARE[index][0])
	tool_node = Sprite2D.new()
	tool_node.texture = _tex(tool)
	tool_node.scale = Vector2(0.45, 0.45)
	tool_node.z_index = 3500
	stage.add_child(tool_node)
	tool_node.position = _tool_spot(pos)
	last_touch = tool_node.position
	stroke = 0.0
	on_her = false
	# Adeline steps up to Spirit: by her head to feed or pet her, by her side to brush her.
	goal = Vector2(SPIRIT_AT.x - 300.0 if _tool_kind() == "brush" else SPIRIT_AT.x + 350.0, at.y)


## The tool floats a little above the finger, so the finger does not hide it.
func _tool_spot(pos: Vector2) -> Vector2:
	return _to_room(pos + Vector2(0.0, -64.0))


## Lets go of the tool. Unless it was eaten, it falls into the straw.
func _drop_tool(falls := true) -> void:
	if tool_node != null:
		if falls and tool_node.position.y < SPIRIT_AT.y:
			drops.append({ "node": tool_node, "vy": 0.0, "rest": 0.0, "bounces": 0 })
		else:
			tool_node.queue_free()
	tool_node = null
	tool = ""


func _tool_kind() -> String:
	for entry in CARE:
		if entry[0] == tool:
			return str(entry[1])
	return ""


func _use_tool(spot: Vector2) -> void:
	# Only movement across Spirit counts, not the trip from the tray to her.
	var touching := _touching(spot)
	var moved := spot.distance_to(last_touch) if touching and on_her else 0.0
	on_her = touching
	last_touch = spot
	var care: Dictionary = home["care"]
	match _tool_kind():
		"food":
			if spot.distance_to(_on_spirit(BIT)) < 82.0:
				care["food"] = minf(float(care["food"]) + 0.34, 1.0)
				munch = 1.3
				game.sound.play("munch", -2.0, 0.06)
				game.sound.shout("adeline", "feed", 0.6)
				_float("heart", _on_spirit(BIT) + Vector2(0.0, -70.0), 0.3)
				_drop_tool(false)
				_check_happy()
		"brush":
			if moved > 0.0:
				var was_clean := float(care["shine"]) >= 0.999
				var total := 0.0
				for patch in dirt:
					# Only the dust under the brush comes off.
					if spot.distance_to(_on_spirit(patch["spot"])) < 86.0:
						patch["level"] = maxf(float(patch["level"]) - moved / 520.0, 0.0)
					total += float(patch["level"])
				care["shine"] = 1.0 - total / dirt.size()
				if int((stroke + moved) / 60.0) != int(stroke / 60.0):
					_sparkle(spot + Vector2(randf_range(-26.0, 26.0), randf_range(-26.0, 26.0)))
				if int((stroke + moved) / 130.0) != int(stroke / 130.0):
					game.sound.play("brush", -5.0, 0.12)
				stroke += moved
				if not was_clean and float(care["shine"]) >= 0.999:
					game.sound.shout("adeline", "shiny", 1.0, true)
					for patch in dirt:
						_sparkle(_on_spirit(patch["spot"]))
				_check_happy()
		"pet":
			if moved > 0.0:
				# She likes her neck and face stroked best.
				var favourite := _spirit_pixel(spot).x > 150.0
				_pet(spot, moved / (1100.0 if favourite else 2000.0), int((stroke + moved) / 90.0) != int(stroke / 90.0))
				stroke += moved


func _pet(spot: Vector2, amount: float, show := true) -> void:
	var care: Dictionary = home["care"]
	var before := float(care["love"])
	care["love"] = minf(before + amount, 1.0)
	if show:
		_float("heart", spot + Vector2(randf_range(-30.0, 30.0), -40.0), 0.22)
		game.sound.play("pop", -6.0, 0.15, 1.0, 0.12)
	if before < 1.0 and float(care["love"]) >= 1.0:
		game.sound.shout("adeline", "love", 1.0, true)
		game.sound.play("snort", -6.0)
	_check_happy()


func _check_happy() -> void:
	if _all_full() and not celebrated:
		celebrated = true
		hop = 1.7
		_say("Spirit is happy!")
		game.sound.play("whinny", -3.0)
		game.sound.play("fanfare", -6.0, 0.0)
		get_tree().create_timer(0.9).timeout.connect(func(): game.sound.shout("adeline", "happy", 1.0, true))
		for i in 6:
			_float("heart", SPIRIT_AT + Vector2(randf_range(-160.0, 140.0), randf_range(-330.0, -150.0)), 0.3)


## A little picture that drifts up and fades: a heart, usually.
func _float(name: String, spot: Vector2, size: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _tex(name)
	sprite.position = spot
	sprite.scale = Vector2(size, size)
	sprite.z_index = 3400
	stage.add_child(sprite)
	var tween := sprite.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "position:y", spot.y - 110.0, 1.0)
	tween.tween_property(sprite, "modulate:a", 0.0, 1.0).set_delay(0.3)
	tween.chain().tween_callback(sprite.queue_free)


func _sparkle(spot: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = game.spark
	sprite.material = game.additive
	sprite.modulate = Color(1.0, 0.95, 0.6)
	sprite.position = spot
	sprite.scale = Vector2(0.3, 0.3)
	sprite.z_index = 3300
	stage.add_child(sprite)
	var tween := sprite.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.6, 1.6), 0.4)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(sprite.queue_free)


func _stable_frame(delta: float) -> void:
	munch = maxf(munch - delta, 0.0)
	hop = maxf(hop - delta, 0.0)
	# Spirit stretches her head toward food that is held near her.
	var want := 0.0
	if tool_node != null and _tool_kind() == "food":
		var rest := SPIRIT_AT + Vector2(112.0, -268.0)
		if tool_node.position.distance_to(rest) < 430.0:
			want = clampf((tool_node.position.y - rest.y) / 60.0, -0.7, 1.4)
	lean = lerpf(lean, want, 1.0 - exp(-6.0 * delta))
	var pose := { "tail": sin(clock * 2.0) * 6.0 + (22.0 if hop > 0.0 else 0.0), "body": sin(clock * 1.3) * 1.0 + lean * 7.0 }
	if munch > 0.0:
		pose["body"] = 9.0 + sin(clock * 16.0) * 3.0  # head down, chewing
	if sleep == 2:
		# Horses doze standing up, head low and tail still.
		pose = { "tail": 0.0, "body": 8.0 + sin(clock * 1.1) * 0.8 }
	spirit.pose = pose
	spirit.root_offset = Vector2(lean * 2.0, -absf(sin(clock * 11.0)) * 8.0 if hop > 0.0 else 0.0)
	spirit.apply()
	for patch in dirt:
		patch["node"].position = _on_spirit(patch["spot"])
		patch["node"].modulate = Color(0.86, 0.8, 0.66, float(patch["level"]) * 0.75)  # pale dust, to show on a dark coat
	# Things that were let go of fall into the straw, bounce, and fade.
	var floor_y := SPIRIT_AT.y + 8.0
	for drop in drops:
		var node: Sprite2D = drop["node"]
		if node.position.y < floor_y or float(drop["vy"]) < 0.0:
			drop["vy"] = float(drop["vy"]) + GRAVITY * delta
			node.position.y += float(drop["vy"]) * delta
			node.rotation += delta * 3.0
			if node.position.y >= floor_y:
				node.position.y = floor_y
				if float(drop["vy"]) > 260.0 and int(drop["bounces"]) < 2:
					game.sound.play("thump", -12.0, 0.1)
					drop["vy"] = -float(drop["vy"]) * 0.3
					drop["bounces"] = int(drop["bounces"]) + 1
				else:
					drop["vy"] = 0.0
		else:
			drop["rest"] = float(drop["rest"]) + delta
			node.modulate.a = clampf(1.6 - float(drop["rest"]) * 1.6, 0.0, 1.0)
			if float(drop["rest"]) > 1.0:
				node.queue_free()
	drops = drops.filter(func(d): return float(d["rest"]) <= 1.0)


# --- Every frame -------------------------------------------------------------

func _process(delta: float) -> void:
	if place == "":
		return
	if game.mode != place:
		close()  # the player went back to the title screen
		return
	clock += delta
	note_time = maxf(note_time - delta, 0.0)
	_layout()
	night = move_toward(night, 1.0 if sleep == 2 else 0.0, delta * 1.6)
	for bubble in foam:
		bubble[1] = float(bubble[1]) - delta * 1.1
	foam = foam.filter(func(b): return float(b[1]) > 0.0)
	if place == "house":
		_fall(delta)
	else:
		_stable_frame(delta)
	_animate_adeline(delta)
	overlay.queue_redraw()


func _animate_adeline(delta: float) -> void:
	var sway := sin(clock * 2.4)
	var pose := { "cloak_back": 2.0 + sway * 2.0, "ponytail": sway * 3.0, "torso": sway * 0.6, "arm_upper": sway * 1.5, "head": -sway * 0.6 }
	var lift := 0.0
	var to := goal - at
	if to.length() > 5.0:
		at += to.normalized() * minf(260.0 * delta, to.length())
		if absf(to.x) > 3.0:
			facing = 1 if to.x > 0.0 else -1
		walk += 260.0 * delta * 0.026
		pose["leg_near_upper"] = sin(walk) * 28.0
		pose["leg_near_lower"] = maxf(0.0, -cos(walk)) * 50.0
		pose["leg_far_upper"] = sin(walk + PI) * 28.0
		pose["leg_far_lower"] = maxf(0.0, -cos(walk + PI)) * 50.0
		pose["arm_upper"] = -sin(walk) * 10.0
		pose["torso"] = 4.0
		pose["cloak_back"] = 14.0
		lift = -absf(sin(walk)) * 2.5
	elif place == "stable":
		facing = 1 if at.x < SPIRIT_AT.x else -1
		if tool != "":
			# Reaching out toward Spirit.
			pose["arm_upper"] = -78.0 + sin(clock * 7.0) * 8.0
			pose["arm_lower"] = -18.0
			pose["torso"] = 5.0
	if place == "house" and sleep == 1 and to.length() <= 5.0:
		sleep = 2  # she has reached her bed
		game.sound.shout("adeline", "goodnight", 1.0, true)
	var size := 2.3 * (_depth(at.y) if place == "house" else 1.0)
	adeline.root_angle = 0.0
	if place == "house" and sleep == 2 and _bed() >= 0:
		# Lying on her bed, head on the pillow, breathing slowly.
		var bed := _bed()
		var flipped := bool(things[bed]["data"]["f"])
		facing = -1 if flipped else 1
		adeline.pose = { "arm_upper": 12.0, "arm_lower": 6.0, "torso": sin(clock * 1.4) * 1.2, "cloak_back": 0.0 }
		adeline.root_angle = -PI / 2.0
		adeline.root_offset = -adeline.rest_pos("torso")
		adeline.apply()
		size = 2.3 * _depth(float(things[bed]["data"]["y"])) * 0.92
		adeline.position = Vector2(float(things[bed]["data"]["x"]) + (20.0 if flipped else -20.0), _top(bed) - 14.0)
		adeline.scale = Vector2(size * facing, size)
		adeline.z_index = things[bed]["node"].z_index + 2
		return
	adeline.pose = pose
	adeline.root_offset = Vector2(0.0, lift)
	adeline.apply()
	adeline.position = at
	adeline.scale = Vector2(size * facing, size)
	adeline.z_index = int(at.y)


# --- Touch -------------------------------------------------------------------

func _input(event: InputEvent) -> void:
	if place == "" or stage == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			if finger != -1:
				return
			if not _press(event.position):
				return  # not ours: let the Home button have it
			# If that touch took her back outside, there is no finger left to follow.
			finger = event.index if place != "" else -1
		elif event.index == finger:
			_release()
			finger = -1
		else:
			return
		get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == finger:
		_move(event.position)
		get_viewport().set_input_as_handled()


func _press(pos: Vector2) -> bool:
	if game.menu_rect().has_point(pos):
		return false
	if _back_rect().has_point(pos):
		game.leave_place()
		return true
	var cell := -1
	for i in _tray_count():
		if _cell_rect(i).has_point(pos):
			cell = i
	var spot := _to_room(pos)
	if place == "house":
		for door in _doors():
			if (door[0] as Rect2).has_point(pos):
				_enter_room(str(door[1]))
				game.sound.play("thump", -8.0)
				return true
		if room == "bedroom" and (_sleep_rect().has_point(pos) or sleep > 0):
			_toggle_sleep()  # the button, or a tap anywhere to wake her
		elif room == "bathroom":
			if cell == 0:
				paste = 1.0
				game.sound.play("squirt", -3.0, 0.08)
			elif cell == 1:
				tool = "toothbrush"
				tool_node = Sprite2D.new()
				tool_node.texture = _tex("toothbrush")
				tool_node.scale = Vector2(0.8, 0.8)
				tool_node.z_index = 3500
				stage.add_child(tool_node)
				tool_node.position = _tool_spot(pos)
				last_touch = tool_node.position
				stroke = 0.0
				on_her = false
		elif cell >= 0:
			_add(cell)
		elif selected >= 0 and _bar_press(pos):
			pass  # a colour or a button was tapped
		elif pos.y < get_viewport_rect().size.y - TRAY:
			selected = _thing_at(spot)
			if selected >= 0:
				dragging = true
				var data: Dictionary = things[selected]["data"]
				grab = Vector2(float(data["x"]), float(data["y"])) - spot
				data["on"] = -1  # picked up off whatever it was sitting on
				things[selected]["falling"] = false
				_refresh(selected)
			elif spot.y > BACK - 30.0:
				_walk_to(spot)  # a tap on the bare floor: Adeline walks there
	else:
		if _sleep_rect().has_point(pos) or (sleep > 0 and _touching(spot)):
			_toggle_sleep()
		elif sleep > 0:
			_say("Shh. Spirit is asleep.")
		elif cell >= 0:
			_pick_tool(cell, pos)
		elif _touching(spot):
			_pet(spot, 0.12)
	return true


func _move(pos: Vector2) -> void:
	if place == "house":
		if dragging and selected >= 0:
			_hold(_to_room(pos) + grab)
		elif tool == "toothbrush" and tool_node != null:
			var spot := _tool_spot(pos)
			var moved: float = spot.distance_to(last_touch) * stage.scale.x
			tool_node.position = spot
			last_touch = spot
			_brush_teeth(moved)
	elif tool != "" and tool_node != null:
		tool_node.position = _tool_spot(pos)
		_use_tool(tool_node.position)


func _release() -> void:
	if place == "house":
		if dragging and selected >= 0:
			dragging = false
			_let_go()
		dragging = false
		if tool == "toothbrush":
			_drop_tool(false)
			_save()
	else:
		_drop_tool()
		_save()


## The colours and buttons for the chosen thing sit along the top of the screen, over the
## wall, so they never cover the floor. Returns whether the touch landed on one of them.
func _bar_press(pos: Vector2) -> bool:
	var data: Dictionary = things[selected]["data"]
	var hit := false
	for i in HUES.size():
		if pos.distance_to(_swatch(i)) < 27.0:
			data["h"] = i
			hit = true
			game.sound.play("pop", -6.0, 0.1)
	if _bar_button(0).has_point(pos):
		# Whatever was sitting on it drops to the floor.
		for i in things.size():
			if int(things[i]["data"]["on"]) == int(data["id"]):
				things[i]["data"]["on"] = -1
				_drop(i, float(data["y"]))
		things[selected]["node"].queue_free()
		things.remove_at(selected)
		selected = -1
		game.sound.play("swish", -8.0)
		_save()
		return true
	if _bar_button(1).has_point(pos):
		data["s"] = (int(data["s"]) + 1) % SIZES.size()
		hit = true
	if _bar_button(2).has_point(pos):
		data["f"] = not bool(data["f"])
		hit = true
	if hit:
		_refresh(selected)
		_carry(selected, 0.0)
		_save()
	return hit


# --- What is on screen besides the room ---------------------------------------

func _tray_count() -> int:
	if place == "stable":
		return CARE.size()
	return 2 if room == "bathroom" else _list().size()


func _cell_rect(i: int) -> Rect2:
	var s := get_viewport_rect().size
	var n := _tray_count()
	var w := minf(118.0, (s.x - 32.0) / n)
	return Rect2((s.x - n * w) / 2.0 + i * w + 4.0, s.y - TRAY + 8.0, w - 8.0, TRAY - 16.0)


## The button by the door that leads to the other room.
func _room_rect() -> Rect2:
	var s := get_viewport_rect().size
	return Rect2(s.x - 236.0 if room == "living" else 24.0, 124.0, 212.0, 52.0)


func _back_rect() -> Rect2:
	return Rect2(24.0, 52.0, 196.0, 52.0)


func _swatch(i: int) -> Vector2:
	return Vector2(264.0 + i * 54.0, 78.0)


func _bar_button(from_right: int) -> Rect2:
	var s := get_viewport_rect().size
	return Rect2(s.x - 284.0 - from_right * 110.0, 52.0, 102.0, 52.0)


func _text(pos: Vector2, text: String, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	overlay.draw_string_outline(font, pos, text, align, width, size, 6, Color(0.0, 0.0, 0.0, 0.6))
	overlay.draw_string(font, pos, text, align, width, size, color)


func _button(r: Rect2, label: String, size: int, fill: Color) -> void:
	overlay.draw_rect(r, fill)
	overlay.draw_rect(r, Color(1.0, 1.0, 1.0, 0.75), false, 2.0)
	_text(Vector2(r.position.x, r.position.y + r.size.y / 2.0 + size * 0.36), label, size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _fit(tex: Texture2D, r: Rect2) -> void:
	var k := minf(r.size.x / tex.get_width(), r.size.y / tex.get_height()) * 0.86
	var size := tex.get_size() * k
	overlay.draw_texture_rect(tex, Rect2(r.get_center() - size / 2.0, size), false)


func _draw_ui() -> void:
	if place == "" or stage == null:
		return
	var s := get_viewport_rect().size
	if night > 0.0:
		# Night falls over the room, and little Z's drift up from the sleeper.
		overlay.draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.05, 0.2, 0.6 * night))
		if sleep == 2:
			var head := _to_screen(_on_spirit(Vector2(236.0, 24.0))) if place == "stable" else _to_screen(adeline.position + Vector2(-150.0 * facing, -70.0))
			for i in 3:
				var k := fmod(clock * 0.45 + i / 3.0, 1.0)
				_text(head + Vector2(26.0 * k + 12.0 * sin(k * 6.0), -30.0 - 110.0 * k), "z", int(22.0 + 26.0 * k), Color(1.0, 1.0, 1.0, 1.0 - k))
	overlay.draw_rect(Rect2(0.0, s.y - TRAY, s.x, TRAY), Color(0.12, 0.08, 0.06, 0.86))
	for i in _tray_count():
		var r := _cell_rect(i)
		var name := _tray_name(i)
		overlay.draw_rect(r, Color(1.0, 0.95, 0.85, 0.3 if name == tool else 0.13))
		_fit(_tex(name), r)
	_button(_back_rect(), "Back outside", 22, Color(0.08, 0.1, 0.2, 0.6))
	if place == "house":
		_draw_house(s)
	else:
		_draw_stable(s)
	if note_time > 0.0:
		_text(Vector2(0.0, s.y * 0.3), note, 44, Color(1.0, 0.92, 0.5, minf(note_time, 1.0)), HORIZONTAL_ALIGNMENT_CENTER, s.x)


func _draw_house(s: Vector2) -> void:
	for door in _doors():
		_button(door[0], str(door[2]), 20, Color(0.3, 0.6, 0.35, 0.9))
	if room == "bathroom":
		_draw_bathroom(s)
		return
	if room == "bedroom":
		_button(_sleep_rect(), "Wake up" if sleep > 0 else "Go to sleep", 20, Color(0.3, 0.3, 0.7, 0.9))
	if sleep > 0:
		return
	if things.is_empty():
		_text(Vector2(0.0, 216.0), "Tap something below to put it in the room.", 26, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	elif selected < 0 and clock < 7.0:
		_text(Vector2(0.0, 216.0), "Drag things to move them. Small things can sit on the furniture. Tap the floor and Adeline walks there.", 21, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	if selected < 0 or selected >= things.size():
		return
	var node: Sprite2D = things[selected]["node"]
	var size := node.texture.get_size() * absf(node.scale.y)
	var from := _to_screen(node.position - size / 2.0)
	overlay.draw_rect(Rect2(from, _to_screen(node.position + size / 2.0) - from).grow(4.0), Color(1.0, 0.9, 0.4, 0.9), false, 3.0)
	var chosen := int(things[selected]["data"]["h"])
	for i in HUES.size():
		var c := _swatch(i)
		overlay.draw_circle(c, 22.0, Color.from_hsv(fposmod(float(HUES[i]), 1.0), 0.78, 0.9))
		overlay.draw_arc(c, 22.0, 0.0, TAU, 28, Color.WHITE if i == chosen else Color(0.0, 0.0, 0.0, 0.6), 4.0 if i == chosen else 2.0)
	_button(_bar_button(0), "Remove", 20, Color(0.6, 0.2, 0.2, 0.85))
	_button(_bar_button(1), "Size", 20, Color(0.25, 0.4, 0.75, 0.9))
	_button(_bar_button(2), "Flip", 20, Color(0.25, 0.4, 0.75, 0.9))


func _draw_stable(s: Vector2) -> void:
	_button(_sleep_rect(), "Wake Spirit" if sleep > 0 else "Bedtime for Spirit", 20, Color(0.3, 0.3, 0.7, 0.9))
	var care: Dictionary = home["care"]
	var names := [["Food", "food", "apple"], ["Shine", "shine", "brush"], ["Love", "love", "heart"]]
	var width := 210.0
	var x0 := s.x / 2.0 - (width * 3.0 + 40.0) / 2.0
	for i in 3:
		var x := x0 + i * (width + 20.0)
		_fit(_tex(str(names[i][2])), Rect2(x, 46.0, 44.0, 44.0))
		var bar := Rect2(x + 50.0, 60.0, width - 50.0, 18.0)
		overlay.draw_rect(bar, Color(0.0, 0.0, 0.0, 0.45))
		overlay.draw_rect(Rect2(bar.position, Vector2(bar.size.x * float(care[names[i][1]]), bar.size.y)), Color(1.0, 0.8, 0.25))
		overlay.draw_rect(bar, Color(1.0, 1.0, 1.0, 0.7), false, 2.0)
		_text(Vector2(x + 50.0, 104.0), str(names[i][0]), 18, Color.WHITE)
	if clock < 10.0 and not _all_full() and sleep == 0:
		_text(Vector2(0.0, 214.0), "Hold food up to Spirit's mouth. Brush every dusty patch. Stroke her with the heart.", 22, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)
