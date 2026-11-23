extends Control
## Indoors. Two places, both drawn over the outdoor world:
##   * Adeline's living room, which the player decorates: add furniture, drag it about,
##     change its colour, flip it, resize it. The room is saved exactly as it was left.
##   * Spirit's stable, where the player feeds, brushes and pets her.
## Everything indoors is placed in the units of the background picture (1344 x 752), and
## the whole room is scaled to fill whatever screen it is on.

const RigScript := preload("res://scripts/rig.gd")

const ROOM := Vector2(1344.0, 752.0)
const SAVE_PATH := "user://home.json"
const TRAY := 96.0  # height of the strip of things to pick from
const BAR := 66.0  # height of the strip of colours and buttons above it
const HUES := [0.0, 0.07, 0.15, 0.36, 0.5, 0.62, 0.76, 0.9]  # how far round the colour wheel
const SIZES := [0.75, 1.0, 1.3]
const MAX_THINGS := 30
const FLOOR_Y := 622.0  # where feet stand

# name, size, and how it sits in the room: on the floor, flat on the floor, or on the wall
const FURNITURE := [
	["sofa", 1.0, "floor"], ["armchair", 0.95, "floor"], ["rug", 1.3, "rug"], ["table", 0.85, "floor"],
	["bookshelf", 1.0, "floor"], ["lamp", 0.95, "floor"], ["plant", 0.7, "floor"], ["painting", 0.6, "wall"],
	["clock", 0.45, "wall"], ["flowers", 0.5, "floor"], ["rocking_horse", 0.7, "floor"], ["cushion", 0.55, "floor"],
]
# name and what it is for
const CARE := [["apple", "food"], ["carrot", "food"], ["hay", "food"], ["oats", "food"], ["brush", "brush"], ["heart", "pet"]]

const SPIRIT_AT := Vector2(720.0, 632.0)
const SPIRIT_SIZE := 2.3
const MOUTH := Vector2(112.0, -268.0)  # from Spirit's feet
const DIRT := [Vector2(-130, -200), Vector2(-60, -236), Vector2(6, -176), Vector2(-158, -150), Vector2(-24, -126), Vector2(52, -214)]

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
var home := { "room": [], "care": { "food": 0.0, "shine": 0.0, "love": 0.0, "time": 0.0 } }
var clock := 0.0
var finger := -1
var note := ""
var note_time := 0.0

# The living room.
var things: Array = []  # each: { "data": what is saved, "node": its picture }
var selected := -1
var dragging := false
var grab := Vector2.ZERO
var adeline = null
var adeline_x := 0.0
var adeline_goal := 0.0
var adeline_face := 1
var walk := 0.0

# The stable.
var spirit = null
var tool := ""
var tool_node: Sprite2D = null
var last_touch := Vector2.ZERO
var stroke := 0.0
var munch := 0.0
var hop := 0.0
var dirt: Array = []
var celebrated := false


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
			if saved.get("room") is Array:
				home["room"] = saved["room"]
			if saved.get("care") is Dictionary:
				for key in home["care"]:
					home["care"][key] = float(saved["care"].get(key, 0.0))


func _save() -> void:
	if place == "house":
		var room: Array = []
		for thing in things:
			room.append(thing["data"])
		home["room"] = room
	home["care"]["time"] = Time.get_unix_time_from_system()
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(home))


func _tex(name: String) -> Texture2D:
	if not textures.has(name):
		var ext := "jpg" if name == "room" or name == "stable" else "png"
		textures[name] = load("res://art/room/%s.%s" % [name, ext])
	return textures[name]


# --- Coming and going --------------------------------------------------------

func open(which: String) -> void:
	close()
	place = which
	visible = true
	clock = 0.0
	note = ""
	stage = Node2D.new()
	add_child(stage)
	var backdrop := Sprite2D.new()
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
	if which == "house":
		_open_house()
	else:
		_open_stable()
	_layout()


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
	selected = -1
	dragging = false
	tool = ""
	tool_node = null
	finger = -1
	place = ""
	visible = false


func _layout() -> void:
	var s := get_viewport_rect().size
	var k := maxf(s.x / ROOM.x, s.y / ROOM.y)
	stage.scale = Vector2(k, k)
	# The floor matters most, so the room is lined up along the bottom of the screen.
	stage.position = Vector2((s.x - ROOM.x * k) / 2.0, s.y - ROOM.y * k)


func _to_room(screen: Vector2) -> Vector2:
	return (screen - stage.position) / stage.scale.x


func _to_screen(room: Vector2) -> Vector2:
	return room * stage.scale.x + stage.position


func _say(text: String) -> void:
	note = text
	note_time = 2.6


# --- The living room ---------------------------------------------------------

func _open_house() -> void:
	adeline_x = 1130.0
	adeline_goal = adeline_x
	adeline_face = -1
	for data in home["room"]:
		if data is Dictionary and _furniture(str(data.get("t", ""))) >= 0:
			_spawn(data)


func _furniture(name: String) -> int:
	for i in FURNITURE.size():
		if FURNITURE[i][0] == name:
			return i
	return -1


func _spawn(data: Dictionary) -> int:
	var node := Sprite2D.new()
	node.texture = _tex(str(data["t"]))
	var material := ShaderMaterial.new()
	material.shader = shader
	node.material = material
	stage.add_child(node)
	things.append({ "data": data, "node": node })
	_refresh(things.size() - 1)
	return things.size() - 1


## Makes a thing's picture match what is written down about it.
func _refresh(index: int) -> void:
	var data: Dictionary = things[index]["data"]
	var node: Sprite2D = things[index]["node"]
	var spec: Array = FURNITURE[_furniture(str(data["t"]))]
	var size: float = float(spec[1]) * float(SIZES[clampi(int(data["s"]), 0, SIZES.size() - 1)])
	node.position = Vector2(float(data["x"]), float(data["y"]))
	node.scale = Vector2(-size if bool(data["f"]) else size, size)
	(node.material as ShaderMaterial).set_shader_parameter("shift", float(HUES[clampi(int(data["h"]), 0, HUES.size() - 1)]))
	# Things lower down the screen are nearer, so they are drawn in front.
	var foot := node.position.y + node.texture.get_height() * size / 2.0
	match str(spec[2]):
		"rug":
			node.z_index = -2000 + int(foot)
		"wall":
			node.z_index = -1000
		_:
			node.z_index = int(foot)


func _add(kind: int) -> void:
	if things.size() >= MAX_THINGS:
		_say("The room is full! Take something out first.")
		return
	var spec: Array = FURNITURE[kind]
	var tex := _tex(str(spec[0]))
	var half: float = tex.get_height() * float(spec[1]) / 2.0
	var at := Vector2(ROOM.x * 0.5 + randf_range(-200.0, 200.0), FLOOR_Y - half - randf_range(0.0, 40.0))
	if spec[2] == "wall":
		at = Vector2(ROOM.x * randf_range(0.15, 0.32), 250.0)
	elif spec[2] == "rug":
		at = Vector2(ROOM.x * 0.5, FLOOR_Y - 10.0)
	selected = _spawn({ "t": spec[0], "x": at.x, "y": at.y, "h": 0, "f": false, "s": 1 })
	game.sound.play("thump", -8.0, 0.1)
	_save()


func _thing_rect(index: int) -> Rect2:
	var node: Sprite2D = things[index]["node"]
	var size := node.texture.get_size() * absf(node.scale.y)
	return Rect2(node.position - size / 2.0, size)


func _thing_at(at: Vector2) -> int:
	var best := -1
	for i in things.size():
		if _thing_rect(i).has_point(at) and (best < 0 or things[i]["node"].z_index >= things[best]["node"].z_index):
			best = i
	return best


func _visible_room() -> Rect2:
	var s := get_viewport_rect().size
	var from := _to_room(Vector2(0.0, 110.0))
	var to := _to_room(Vector2(s.x, s.y - TRAY))
	return Rect2(from, to - from)


# --- The stable --------------------------------------------------------------

func _open_stable() -> void:
	adeline_x = 330.0
	adeline_goal = adeline_x
	adeline_face = 1
	spirit = Node2D.new()
	spirit.set_script(RigScript)
	spirit.position = SPIRIT_AT
	spirit.scale = Vector2(SPIRIT_SIZE, SPIRIT_SIZE)
	spirit.z_index = int(SPIRIT_AT.y)
	stage.add_child(spirit)
	spirit.build("res://art/spirit")
	for part in ["leg_front_far_upper", "leg_front_far_lower", "leg_hind_far_upper", "leg_hind_far_lower"]:
		spirit.tint(part, Color(0.72, 0.72, 0.78))
	# Dusty patches that brushing clears away.
	for spot in DIRT:
		var smudge := Sprite2D.new()
		smudge.texture = game.spark
		smudge.position = SPIRIT_AT + spot
		smudge.scale = Vector2(1.5, 1.0) * randf_range(0.8, 1.2)
		smudge.z_index = int(SPIRIT_AT.y) + 1
		stage.add_child(smudge)
		dirt.append(smudge)
	# Since the last visit Spirit has got a little hungry, dusty and lonely again.
	var care: Dictionary = home["care"]
	var away := maxf(Time.get_unix_time_from_system() - float(care["time"]), 0.0) if float(care["time"]) > 0.0 else 99999.0
	for key in ["food", "shine", "love"]:
		care[key] = clampf(float(care[key]) - away / 1200.0, 0.0, 1.0)
	celebrated = _all_full()


func _all_full() -> bool:
	var care: Dictionary = home["care"]
	return float(care["food"]) >= 0.999 and float(care["shine"]) >= 0.999 and float(care["love"]) >= 0.999


func _on_body(at: Vector2) -> bool:
	return Rect2(SPIRIT_AT + Vector2(-200.0, -300.0), Vector2(340.0, 250.0)).has_point(at)


func _on_spirit(at: Vector2) -> bool:
	return _on_body(at) or at.distance_to(SPIRIT_AT + Vector2(95.0, -300.0)) < 120.0


func _pick_tool(index: int, at: Vector2) -> void:
	_drop_tool()
	tool = str(CARE[index][0])
	tool_node = Sprite2D.new()
	tool_node.texture = _tex(tool)
	tool_node.scale = Vector2(0.45, 0.45)
	tool_node.z_index = 3500
	tool_node.position = _to_room(at)
	stage.add_child(tool_node)
	last_touch = _to_room(at)
	stroke = 0.0


func _drop_tool() -> void:
	if tool_node != null:
		tool_node.queue_free()
	tool_node = null
	tool = ""


func _tool_kind() -> String:
	for entry in CARE:
		if entry[0] == tool:
			return str(entry[1])
	return ""


func _use_tool(at: Vector2) -> void:
	var moved := at.distance_to(last_touch)
	last_touch = at
	var care: Dictionary = home["care"]
	match _tool_kind():
		"food":
			if at.distance_to(SPIRIT_AT + MOUTH) < 100.0:
				care["food"] = minf(float(care["food"]) + 0.34, 1.0)
				munch = 1.3
				game.sound.play("munch", -2.0, 0.06)
				game.sound.shout("adeline", "feed", 0.6)
				_float("heart", SPIRIT_AT + MOUTH + Vector2(0.0, -70.0), 0.3)
				_drop_tool()
				_check_happy()
		"brush":
			if _on_body(at) and moved > 0.0:
				var before := float(care["shine"])
				care["shine"] = minf(before + moved / 2400.0, 1.0)
				if int((stroke + moved) / 60.0) != int(stroke / 60.0):
					_sparkle(at + Vector2(randf_range(-30.0, 30.0), randf_range(-30.0, 30.0)))
				if int((stroke + moved) / 130.0) != int(stroke / 130.0):
					game.sound.play("brush", -5.0, 0.12)
				stroke += moved
				if before < 1.0 and float(care["shine"]) >= 1.0:
					game.sound.shout("adeline", "shiny", 1.0, true)
				_check_happy()
		"pet":
			if _on_spirit(at) and moved > 0.0:
				_pet(at, moved / 1700.0, int((stroke + moved) / 90.0) != int(stroke / 90.0))
				stroke += moved


func _pet(at: Vector2, amount: float, show := true) -> void:
	var care: Dictionary = home["care"]
	var before := float(care["love"])
	care["love"] = minf(before + amount, 1.0)
	if show:
		_float("heart", at + Vector2(randf_range(-30.0, 30.0), -40.0), 0.22)
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
func _float(name: String, at: Vector2, size: float) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = _tex(name)
	sprite.position = at
	sprite.scale = Vector2(size, size)
	sprite.z_index = 3400
	stage.add_child(sprite)
	var tween := sprite.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "position:y", at.y - 110.0, 1.0)
	tween.tween_property(sprite, "modulate:a", 0.0, 1.0).set_delay(0.3)
	tween.chain().tween_callback(sprite.queue_free)


func _sparkle(at: Vector2) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = game.spark
	sprite.material = game.additive
	sprite.modulate = Color(1.0, 0.95, 0.6)
	sprite.position = at
	sprite.scale = Vector2(0.3, 0.3)
	sprite.z_index = 3300
	stage.add_child(sprite)
	var tween := sprite.create_tween()
	tween.set_parallel(true)
	tween.tween_property(sprite, "scale", Vector2(1.6, 1.6), 0.4)
	tween.tween_property(sprite, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(sprite.queue_free)


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
	_animate_adeline(delta)
	if place == "stable":
		munch = maxf(munch - delta, 0.0)
		hop = maxf(hop - delta, 0.0)
		var pose := { "tail": sin(clock * 2.0) * 6.0 + (22.0 if hop > 0.0 else 0.0), "body": sin(clock * 1.3) * 1.0 }
		if munch > 0.0:
			pose["body"] = 10.0 + sin(clock * 16.0) * 3.0  # head down, chewing
		spirit.pose = pose
		spirit.root_offset = Vector2(0.0, -absf(sin(clock * 11.0)) * 8.0 if hop > 0.0 else 0.0)
		spirit.apply()
		for smudge in dirt:
			smudge.modulate = Color(0.35, 0.25, 0.15, (1.0 - float(home["care"]["shine"])) * 0.6)
	overlay.queue_redraw()


func _animate_adeline(delta: float) -> void:
	var sway := sin(clock * 2.4)
	var pose := { "cloak_back": 2.0 + sway * 2.0, "ponytail": sway * 3.0, "torso": sway * 0.6, "arm_upper": sway * 1.5, "head": -sway * 0.6 }
	var lift := 0.0
	if absf(adeline_goal - adeline_x) > 6.0:
		adeline_face = 1 if adeline_goal > adeline_x else -1
		adeline_x += adeline_face * 260.0 * delta
		walk += 260.0 * delta * 0.026
		pose["leg_near_upper"] = sin(walk) * 28.0
		pose["leg_near_lower"] = maxf(0.0, -cos(walk)) * 50.0
		pose["leg_far_upper"] = sin(walk + PI) * 28.0
		pose["leg_far_lower"] = maxf(0.0, -cos(walk + PI)) * 50.0
		pose["arm_upper"] = -sin(walk) * 10.0
		pose["torso"] = 4.0
		pose["cloak_back"] = 14.0
		lift = -absf(sin(walk)) * 2.5
	adeline.pose = pose
	adeline.root_offset = Vector2(0.0, lift)
	adeline.apply()
	var feet := FLOOR_Y if place == "house" else SPIRIT_AT.y - 4.0
	adeline.position = Vector2(adeline_x, feet)
	adeline.scale = Vector2(2.3 * adeline_face, 2.3)
	adeline.z_index = int(feet)


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
			finger = event.index
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
	if place == "house":
		if cell >= 0:
			_add(cell)
		elif selected >= 0 and pos.y > get_viewport_rect().size.y - TRAY - BAR:
			_bar_press(pos)
		elif pos.y < get_viewport_rect().size.y - TRAY:
			var at := _to_room(pos)
			selected = _thing_at(at)
			if selected >= 0:
				dragging = true
				grab = things[selected]["node"].position - at
	else:
		if cell >= 0:
			_pick_tool(cell, pos)
		elif _on_spirit(_to_room(pos)):
			_pet(_to_room(pos), 0.12)
	return true


func _move(pos: Vector2) -> void:
	var at := _to_room(pos)
	if place == "house":
		if dragging and selected >= 0:
			var room := _visible_room()
			var spot := at + grab
			var data: Dictionary = things[selected]["data"]
			data["x"] = clampf(spot.x, room.position.x + 20.0, room.end.x - 20.0)
			data["y"] = clampf(spot.y, room.position.y, room.end.y - 10.0)
			_refresh(selected)
	elif tool != "" and tool_node != null:
		tool_node.position = at
		_use_tool(at)


func _release() -> void:
	if place == "house":
		if dragging and selected >= 0:
			var x: float = things[selected]["data"]["x"]
			adeline_goal = clampf(x + (150.0 if adeline_x > x else -150.0), 120.0, ROOM.x - 120.0)
			game.sound.play("thump", -10.0, 0.1)
			game.sound.shout("adeline", "lovely", 0.3)
			_save()
		dragging = false
	else:
		_drop_tool()
		_save()


func _bar_press(pos: Vector2) -> void:
	var data: Dictionary = things[selected]["data"]
	for i in HUES.size():
		if pos.distance_to(_swatch(i)) < 28.0:
			data["h"] = i
			game.sound.play("pop", -6.0, 0.1)
	if _bar_button(0).has_point(pos):
		things[selected]["node"].queue_free()
		things.remove_at(selected)
		selected = -1
		game.sound.play("swish", -8.0)
		_save()
		return
	if _bar_button(1).has_point(pos):
		data["s"] = (int(data["s"]) + 1) % SIZES.size()
	if _bar_button(2).has_point(pos):
		data["f"] = not bool(data["f"])
	_refresh(selected)
	_save()


# --- What is on screen besides the room ---------------------------------------

func _tray_count() -> int:
	return FURNITURE.size() if place == "house" else CARE.size()


func _cell_rect(i: int) -> Rect2:
	var s := get_viewport_rect().size
	var n := _tray_count()
	var w := minf(118.0, (s.x - 32.0) / n)
	return Rect2((s.x - n * w) / 2.0 + i * w + 4.0, s.y - TRAY + 8.0, w - 8.0, TRAY - 16.0)


func _back_rect() -> Rect2:
	return Rect2(24.0, 52.0, 196.0, 52.0)


func _swatch(i: int) -> Vector2:
	return Vector2(44.0 + i * 60.0, get_viewport_rect().size.y - TRAY - BAR / 2.0)


func _bar_button(from_right: int) -> Rect2:
	var s := get_viewport_rect().size
	return Rect2(s.x - 136.0 - from_right * 132.0, s.y - TRAY - BAR + 9.0, 122.0, BAR - 18.0)


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
	overlay.draw_rect(Rect2(0.0, s.y - TRAY, s.x, TRAY), Color(0.12, 0.08, 0.06, 0.86))
	for i in _tray_count():
		var r := _cell_rect(i)
		var name: String = FURNITURE[i][0] if place == "house" else CARE[i][0]
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
	if things.is_empty():
		_text(Vector2(0.0, 150.0), "Tap something below to put it in the room.", 26, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	elif selected < 0 and clock < 6.0:
		_text(Vector2(0.0, 150.0), "Drag things to move them. Tap one to change its colour.", 24, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	if selected < 0:
		return
	var box := _thing_rect(selected)
	var from := _to_screen(box.position)
	overlay.draw_rect(Rect2(from, _to_screen(box.end) - from).grow(4.0), Color(1.0, 0.9, 0.4, 0.9), false, 3.0)
	overlay.draw_rect(Rect2(0.0, s.y - TRAY - BAR, s.x, BAR), Color(0.12, 0.08, 0.06, 0.7))
	var chosen := int(things[selected]["data"]["h"])
	for i in HUES.size():
		var c := _swatch(i)
		overlay.draw_circle(c, 24.0, Color.from_hsv(fposmod(float(HUES[i]), 1.0), 0.78, 0.9))
		overlay.draw_arc(c, 24.0, 0.0, TAU, 28, Color.WHITE if i == chosen else Color(0.0, 0.0, 0.0, 0.6), 4.0 if i == chosen else 2.0)
	_button(_bar_button(0), "Remove", 20, Color(0.6, 0.2, 0.2, 0.85))
	_button(_bar_button(1), "Size", 20, Color(0.25, 0.4, 0.75, 0.9))
	_button(_bar_button(2), "Flip", 20, Color(0.25, 0.4, 0.75, 0.9))


func _draw_stable(s: Vector2) -> void:
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
	if clock < 9.0 and not _all_full():
		_text(Vector2(0.0, 150.0), "Drag food to Spirit's mouth. Brush her coat. Stroke her with the heart.", 23, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)
