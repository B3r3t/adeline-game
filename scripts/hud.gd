extends Control
## Hearts, the current objective, short hints, and the win or lose banner.
## Everything sits along the top so it stays clear of the thumbs.

var game = null
var font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()


func _text(pos: Vector2, text: String, size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string_outline(font, pos, text, align, width, size, 6, Color(0.0, 0.0, 0.0, 0.55))
	draw_string(font, pos, text, align, width, size, color)


func _heart(center: Vector2, full: bool) -> void:
	var c := Color(0.92, 0.2, 0.28) if full else Color(0.0, 0.0, 0.0, 0.3)
	draw_circle(center + Vector2(-8.0, -5.0), 10.0, c)
	draw_circle(center + Vector2(8.0, -5.0), 10.0, c)
	draw_colored_polygon(PackedVector2Array([
		center + Vector2(-17.0, -1.0),
		center + Vector2(17.0, -1.0),
		center + Vector2(0.0, 19.0),
	]), c)


func _draw() -> void:
	if game == null or game.player == null:
		return
	var s := get_viewport_rect().size
	var p = game.player

	for i in p.MAX_HEALTH:
		_heart(Vector2(64.0 + i * 44.0, 52.0), i < p.health)

	var left: int = game.goblins_left()
	var objective := "Defeat the goblin"
	if game.round_number > 1:
		objective = "Defeat the goblins: %d left" % left
	_text(Vector2(0.0, 58.0), objective, 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s.x)

	if game.round_number == 1 and game.state == "fighting":
		_text(Vector2(0.0, 98.0), "Club goes up: step back.   Goblin crouches: jump over it.   Stars: hit back!", 20, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)

	var version := str(ProjectSettings.get_setting("application/config/version", ""))
	_text(Vector2(0.0, 40.0), "build %s   %d fps" % [version, int(Engine.get_frames_per_second())], 16, Color(1.0, 1.0, 1.0, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, s.x - 40.0)

	if game.state != "fighting":
		var title := "Goblin defeated!"
		var sub := "Tap to fight again"
		var next: int = mini(game.round_number + 1, game.MAX_GOBLINS)
		if game.state == "won":
			if game.round_number > 1:
				title = "Goblins defeated!"
			sub = "Tap for the next round: %d goblin%s" % [next, "" if next == 1 else "s"]
		else:
			title = "Adeline needs a rest"
			sub = "Tap to try again"
		var box := Rect2(s.x / 2.0 - 330.0, s.y * 0.26, 660.0, 170.0)
		draw_rect(box, Color(0.08, 0.1, 0.2, 0.78))
		_text(Vector2(box.position.x, box.position.y + 76.0), title, 46, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
		if game.state_time >= 1.0:
			_text(Vector2(box.position.x, box.position.y + 130.0), sub, 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
