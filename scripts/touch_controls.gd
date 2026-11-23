extends Control
## On-screen buttons for two thumbs. Each finger is tracked on its own, so
## moving and attacking at the same time works. The buttons sit in the bottom
## corners with a margin, because a kids' case covers the screen edge.
## New buttons (shield, talk) appear without moving the ones already learned.

const EDGE_MARGIN := 44.0
const TOUCH_FORGIVENESS := 1.3  # buttons react a little outside their drawn edge

var game = null
var font: Font
var buttons := {}  # id -> { center, radius, action }
var fingers := {}  # finger index -> button id
var held := {}  # button id -> true while pressed


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font
	get_viewport().size_changed.connect(_layout)
	_layout()


func _layout() -> void:
	var s := get_viewport_rect().size
	var m := EDGE_MARGIN
	var right := s.x - m
	var bottom := s.y - m
	buttons = {
		"left": { "center": Vector2(m + 70.0, bottom - 70.0), "radius": 70.0, "action": "move_left" },
		"right": { "center": Vector2(m + 70.0 + 156.0, bottom - 70.0), "radius": 70.0, "action": "move_right" },
		"jump": { "center": Vector2(right - 68.0, bottom - 68.0), "radius": 68.0, "action": "jump" },
		"strike": { "center": Vector2(right - 68.0 - 150.0, bottom - 62.0), "radius": 62.0, "action": "strike" },
		"fireball": { "center": Vector2(right - 68.0 - 58.0, bottom - 68.0 - 146.0), "radius": 62.0, "action": "fireball" },
		"shield": { "center": Vector2(right - 68.0 - 200.0, bottom - 62.0 - 138.0), "radius": 58.0, "action": "shield" },
		"interact": { "center": Vector2(m + 70.0 + 78.0, bottom - 70.0 - 150.0), "radius": 60.0, "action": "interact" },
	}
	queue_redraw()


func _visible(id: String) -> bool:
	if game == null or game.input_locked():
		return false
	if id == "shield":
		return game.has_shield() and not game.player.mounted
	if id == "interact":
		return game.context_action != ""
	if game.player.mounted and id == "strike":
		return false  # the wand strike needs her feet on the ground
	return true


func _button_at(pos: Vector2) -> String:
	var best := ""
	var best_d := INF
	for id in buttons:
		if not _visible(id):
			continue
		var b: Dictionary = buttons[id]
		var d: float = pos.distance_to(b["center"])
		if d <= b["radius"] * TOUCH_FORGIVENESS and d < best_d:
			best = id
			best_d = d
	return best


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			var id := _button_at(event.position)
			if id != "":
				fingers[event.index] = id
		else:
			fingers.erase(event.index)
		_sync()
	elif event is InputEventScreenDrag:
		if fingers.has(event.index):
			var current: String = fingers[event.index]
			# A thumb can slide between left and right without lifting.
			# If it drifts off the pad it keeps its last direction until released.
			if current == "left" or current == "right":
				var mid: float = (buttons["left"]["center"].x + buttons["right"]["center"].x) / 2.0
				fingers[event.index] = "left" if event.position.x < mid else "right"
				_sync()


func _sync() -> void:
	var now := {}
	for index in fingers:
		now[fingers[index]] = true
	for id in buttons:
		var action: String = buttons[id]["action"]
		if now.has(id) and not held.has(id):
			Input.action_press(action)
		elif held.has(id) and not now.has(id):
			Input.action_release(action)
	held = now
	queue_redraw()


## Lets go of every button. Used when a dialogue opens or the app loses focus.
func release_all() -> void:
	fingers.clear()
	_sync()


func _notification(what: int) -> void:
	# Leaving the app or losing focus must never leave a button stuck down.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		release_all()


func _process(_delta: float) -> void:
	# A button that disappears while held must be released.
	for index in fingers.keys():
		if not _visible(fingers[index]):
			fingers.erase(index)
			_sync()
	queue_redraw()  # keeps the cooldown rings moving


func _draw() -> void:
	for id in buttons:
		if not _visible(id):
			continue
		var b: Dictionary = buttons[id]
		var c: Vector2 = b["center"]
		var r: float = b["radius"]
		var down: bool = held.has(id)
		var fill := Color(1.0, 1.0, 1.0, 0.42 if down else 0.2)
		if id == "interact":
			fill = Color(1.0, 0.85, 0.3, 0.6 if down else 0.4)
		draw_circle(c, r, fill)
		draw_arc(c, r, 0.0, TAU, 48, Color(1.0, 1.0, 1.0, 0.75), 4.0)
		match id:
			"left":
				_triangle(c, -1.0, r * 0.42)
			"right":
				_triangle(c, 1.0, r * 0.42)
			"jump":
				draw_colored_polygon(PackedVector2Array([c + Vector2(0.0, -r * 0.45), c + Vector2(r * 0.42, r * 0.1), c + Vector2(-r * 0.42, r * 0.1)]), Color(1.0, 1.0, 1.0, 0.9))
				_label(c + Vector2(0.0, r * 0.55), "JUMP")
			"strike":
				draw_line(c + Vector2(-r * 0.3, r * 0.15), c + Vector2(r * 0.28, -r * 0.42), Color(0.55, 0.36, 0.2), 8.0)
				draw_circle(c + Vector2(r * 0.28, -r * 0.42), 9.0, Color(1.0, 0.9, 0.4))
				_label(c + Vector2(0.0, r * 0.6), "STRIKE")
			"fireball":
				draw_circle(c + Vector2(0.0, -r * 0.14), r * 0.3, Color(1.0, 0.45, 0.1))
				draw_circle(c + Vector2(0.0, -r * 0.14), r * 0.17, Color(1.0, 0.85, 0.3))
				_label(c + Vector2(0.0, r * 0.6), "FIRE")
				_cooldown(c, r, game.player.fireball_cd / game.player.FIREBALL_COOLDOWN, Color(1.0, 0.8, 0.3))
			"shield":
				draw_arc(c + Vector2(0.0, -r * 0.12), r * 0.32, 0.0, TAU, 24, Color(0.6, 0.85, 1.0), 6.0)
				_label(c + Vector2(0.0, r * 0.62), "SHIELD")
				_cooldown(c, r, game.player.shield_cd / game.player.SHIELD_COOLDOWN, Color(0.6, 0.85, 1.0))
			"interact":
				var words := { "talk": "TALK", "boat": "LOOK", "ride": "RIDE", "dismount": "HOP OFF", "call": "CALL" }
				var word: String = words.get(game.context_action, "")
				draw_string(font, Vector2(c.x - 60.0, c.y + 8.0), word, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 24 if word.length() <= 4 else 19, Color(1.0, 1.0, 1.0, 0.98))


## Darkens a button and draws a ring that fills as the spell becomes ready again.
func _cooldown(c: Vector2, r: float, left: float, color: Color) -> void:
	if left <= 0.0:
		return
	draw_circle(c, r, Color(0.0, 0.0, 0.0, 0.35))
	draw_arc(c, r - 8.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - left), 32, color, 8.0)


func _triangle(c: Vector2, dir: float, half: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(dir * half, 0.0),
		c + Vector2(-dir * half * 0.7, -half),
		c + Vector2(-dir * half * 0.7, half),
	]), Color(1.0, 1.0, 1.0, 0.9))


func _label(pos: Vector2, text: String) -> void:
	draw_string(font, Vector2(pos.x - 60.0, pos.y + 6.0), text, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 17, Color(1.0, 1.0, 1.0, 0.95))
