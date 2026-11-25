extends Control
## Simple text dialogue and Merlin's mission list.
## Tap anywhere to move to the next line. In a list, tap a row to choose it,
## or tap outside the rows to close.

const Ui := preload("res://scripts/ui.gd")
# Whose picture goes beside the words, by the name they speak under.
const FACES := { "Merlin": "merlin", "Little sister": "sister", "Mom": "mom", "Dad": "dad", "Adeline": "adeline" }

var game = null
var font: Font
var faces := {}
var active := false
var speaker := ""
var lines: Array = []
var index := 0
var done_callback: Callable = Callable()
var list_mode := false
var list_title := ""
var rows: Array = []
var pick_callback: Callable = Callable()
var opened := 0.0  # time since opening, so the tap that opened it is not also read as "next"
var shown := 0.0  # time since the box came up, for the way it pops open
var spoken := 0.0  # time since this line began, for the way its words arrive


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font


func say(who: String, what: Array, when_done: Callable = Callable()) -> void:
	var was := active
	active = true
	list_mode = false
	speaker = who
	lines = what
	index = 0
	done_callback = when_done
	if not was:
		shown = 0.0
	spoken = 0.0
	opened = 0.0
	_speak()
	queue_redraw()


func choose(title: String, options: Array, when_picked: Callable) -> void:
	active = true
	list_mode = true
	list_title = title
	rows = options
	pick_callback = when_picked
	shown = 0.0
	opened = 0.0
	queue_redraw()


## Says the line on screen out loud, if it has been recorded.
func _speak() -> void:
	if game != null and game.sound != null and index < lines.size():
		game.sound.say(str(lines[index]))


func close() -> void:
	if game != null and game.sound != null:
		game.sound.hush()
	active = false
	list_mode = false
	queue_redraw()


func _process(delta: float) -> void:
	if active:
		opened += delta
		shown += delta
		spoken += delta
		queue_redraw()


func _panel() -> Rect2:
	var s := get_viewport_rect().size
	var h := 210.0
	if list_mode:
		h = 96.0 + 84.0 * rows.size()
	return Rect2(s.x / 2.0 - 430.0, 96.0, 860.0, h)


func _row_rect(i: int) -> Rect2:
	var p := _panel()
	return Rect2(p.position.x + 30.0, p.position.y + 76.0 + 84.0 * i, p.size.x - 60.0, 70.0)


func _input(event: InputEvent) -> void:
	if not active:
		return
	var pressed := false
	var has_pos := false
	var pos := Vector2.ZERO
	if event is InputEventScreenTouch:
		if not event.pressed:
			return  # releases pass through so no button is left stuck
		pressed = true
		has_pos = true
		pos = event.position
	elif event is InputEventKey and event.pressed and not event.echo:
		pressed = true
	if not pressed:
		return
	get_viewport().set_input_as_handled()
	if opened < 0.3:
		return
	if list_mode:
		_tap_list(has_pos, pos)
	else:
		_next_line()


func _next_line() -> void:
	index += 1
	opened = 0.15
	spoken = 0.0
	if index >= lines.size():
		var callback := done_callback
		close()
		if callback.is_valid():
			callback.call()
	else:
		_speak()


func _tap_list(has_pos: bool, pos: Vector2) -> void:
	if not has_pos:
		close()
		return
	for i in rows.size():
		if _row_rect(i).has_point(pos):
			var row: Dictionary = rows[i]
			if row["enabled"]:
				var callback := pick_callback
				close()
				callback.call(row["id"])
			return
	if not _panel().has_point(pos):
		close()


func _face(who: String) -> Texture2D:
	if not FACES.has(who):
		return null
	if not faces.has(who):
		faces[who] = load("res://art/ui/face_%s.png" % FACES[who])
	return faces[who]


func _draw() -> void:
	if not active:
		return
	var p := _panel()
	# The box pops open; after that only what is in it changes.
	var k := maxf(Ui.pop(shown / 0.26), 0.001)
	draw_set_transform(p.get_center() * (1.0 - k), 0.0, Vector2(k, k))
	Ui.panel(self, p)
	if list_mode:
		draw_string(font, Vector2(p.position.x + 34.0, p.position.y + 52.0), list_title, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30, Color(1.0, 0.9, 0.5))
		draw_string(font, Vector2(p.position.x, p.position.y + 48.0), "Tap outside to close", HORIZONTAL_ALIGNMENT_RIGHT, p.size.x - 34.0, 16, Color(1.0, 1.0, 1.0, 0.6))
		for i in rows.size():
			var row: Dictionary = rows[i]
			var r := _row_rect(i)
			var on: bool = row["enabled"]
			Ui.button(self, font, r, "", 20, Color(0.25, 0.4, 0.75, 0.95) if on else Color(1.0, 1.0, 1.0, 0.08))
			draw_string(font, Vector2(r.position.x + 22.0, r.position.y + 44.0), str(row["label"]), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 26, Color.WHITE if on else Color(1.0, 1.0, 1.0, 0.55))
			draw_string(font, Vector2(r.position.x, r.position.y + 44.0), str(row["status"]), HORIZONTAL_ALIGNMENT_RIGHT, r.size.x - 22.0, 22, Color(1.0, 0.9, 0.5) if on else Color(1.0, 1.0, 1.0, 0.5))
		return
	# Whoever is speaking, with their picture. A line that begins "Dad: " is Dad's, whoever
	# started the conversation.
	var who := speaker
	var words := str(lines[index]) if index < lines.size() else ""
	for name in FACES:
		if words.begins_with(name + ": "):
			who = name
			words = words.substr(name.length() + 2)
	var left := p.position.x + 34.0
	var face := _face(who)
	if face != null:
		# The face nods as each line starts, as if taking a breath to speak.
		var bob := sin(opened * 3.0) * 2.0 - sin(clampf(spoken / 0.3, 0.0, 1.0) * PI) * 7.0
		draw_texture_rect(face, Rect2(p.position.x + 24.0, p.position.y + 34.0 + bob, 132.0, 132.0), false)
		left = p.position.x + 176.0
	var top := p.position.y + 50.0
	if who != "":
		draw_string(font, Vector2(left, top), who, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 27, Color(1.0, 0.9, 0.5))
		top += 42.0
	else:
		top += 10.0
	# The words arrive quickly, a word at a time, rather than all at once.
	var upto := int(spoken * 90.0)
	if upto < words.length():
		var cut := words.rfind(" ", upto)
		words = words.substr(0, cut if cut > 0 else 0)
	draw_multiline_string(font, Vector2(left, top), words, HORIZONTAL_ALIGNMENT_LEFT, p.end.x - 34.0 - left, 26, 4, Color.WHITE)
	if opened >= 0.3:
		draw_string(font, Vector2(p.position.x, p.end.y - 20.0), "Tap to continue", HORIZONTAL_ALIGNMENT_RIGHT, p.size.x - 34.0, 18, Color(1.0, 1.0, 1.0, 0.5 + 0.3 * sin(opened * 5.0)))
