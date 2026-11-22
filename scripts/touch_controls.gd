extends Control
## On-screen buttons for two thumbs. Each finger is tracked on its own, so
## moving and attacking at the same time works. The buttons sit in the bottom
## corners with a margin, because a kids' case covers the screen edge.

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
	buttons = {
		"left": { "center": Vector2(m + 82.0, s.y - m - 82.0), "radius": 82.0, "action": "move_left" },
		"right": { "center": Vector2(m + 82.0 + 180.0, s.y - m - 82.0), "radius": 82.0, "action": "move_right" },
		"jump": { "center": Vector2(s.x - m - 80.0, s.y - m - 80.0), "radius": 80.0, "action": "jump" },
		"strike": { "center": Vector2(s.x - m - 80.0 - 176.0, s.y - m - 72.0), "radius": 72.0, "action": "strike" },
		"fireball": { "center": Vector2(s.x - m - 80.0 - 70.0, s.y - m - 80.0 - 170.0), "radius": 72.0, "action": "fireball" },
	}
	queue_redraw()


func _button_at(pos: Vector2) -> String:
	var best := ""
	var best_d := INF
	for id in buttons:
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


func _release_all() -> void:
	fingers.clear()
	_sync()


func _notification(what: int) -> void:
	# Leaving the app or losing focus must never leave a button stuck down.
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_WINDOW_FOCUS_OUT:
		_release_all()


func _process(_delta: float) -> void:
	queue_redraw()  # keeps the fireball cooldown ring moving


func _draw() -> void:
	for id in buttons:
		var b: Dictionary = buttons[id]
		var c: Vector2 = b["center"]
		var r: float = b["radius"]
		var down: bool = held.has(id)
		draw_circle(c, r, Color(1.0, 1.0, 1.0, 0.42 if down else 0.2))
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
				if game != null and game.player != null:
					var cd: float = game.player.fireball_cd / game.player.FIREBALL_COOLDOWN
					if cd > 0.0:
						draw_circle(c, r, Color(0.0, 0.0, 0.0, 0.35))
						draw_arc(c, r - 8.0, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - cd), 32, Color(1.0, 0.8, 0.3), 8.0)


func _triangle(c: Vector2, dir: float, half: float) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(dir * half, 0.0),
		c + Vector2(-dir * half * 0.7, -half),
		c + Vector2(-dir * half * 0.7, half),
	]), Color(1.0, 1.0, 1.0, 0.9))


func _label(pos: Vector2, text: String) -> void:
	draw_string(font, Vector2(pos.x - 60.0, pos.y + 6.0), text, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 18, Color(1.0, 1.0, 1.0, 0.95))
