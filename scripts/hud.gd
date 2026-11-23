extends Control
## Hearts, the current objective, hints, short messages, the title screen and the
## "try again" banner. Everything sits along the top so it stays clear of the thumbs.

var game = null
var font: Font


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font


func _process(_delta: float) -> void:
	queue_redraw()


func _text(pos: Vector2, text: String, text_size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string_outline(font, pos, text, align, width, text_size, 6, Color(0.0, 0.0, 0.0, 0.55))
	draw_string(font, pos, text, align, width, text_size, color)


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
	_text(Vector2(0.0, 36.0), "build %d   %d fps" % [game.build_number(), int(Engine.get_frames_per_second())], 16, Color(1.0, 1.0, 1.0, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, s.x - 40.0)

	if game.mode == "title":
		_draw_title(s)
		return

	var p = game.player
	for i in p.MAX_HEALTH:
		_heart(Vector2(64.0 + i * 44.0, 52.0), i < p.health)

	if not game.dialog.active:
		_text(Vector2(0.0, 58.0), game.objective(), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s.x)
		var hint: String = game.hint()
		if hint != "":
			_text(Vector2(0.0, 98.0), hint, 21, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)
		if game.toast_time > 0.0:
			var alpha := clampf(game.toast_time / 0.5, 0.0, 1.0)
			var box := Rect2(s.x / 2.0 - 300.0, 124.0, 600.0, 54.0)
			draw_rect(box, Color(0.08, 0.1, 0.2, 0.75 * alpha))
			_text(Vector2(box.position.x, box.position.y + 37.0), game.toast_text, 24, Color(1.0, 0.92, 0.5, alpha), HORIZONTAL_ALIGNMENT_CENTER, box.size.x)

	if game.defeated:
		var banner := Rect2(s.x / 2.0 - 330.0, s.y * 0.26, 660.0, 170.0)
		draw_rect(banner, Color(0.08, 0.1, 0.2, 0.8))
		_text(Vector2(banner.position.x, banner.position.y + 76.0), "Adeline needs a rest", 46, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, banner.size.x)
		if game.defeat_time >= 1.0:
			_text(Vector2(banner.position.x, banner.position.y + 130.0), "Tap to try this fight again", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, banner.size.x)


func _draw_title(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.06, 0.09, 0.22, 0.6))
	_text(Vector2(0.0, s.y * 0.38), "ADELINE", 110, Color(1.0, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	_text(Vector2(0.0, s.y * 0.38 + 54.0), "A wand, a flying boat and a lot of goblins", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s.x)
	var saved: bool = game.has_save()
	var pulse := 0.75 + 0.25 * sin(game.clock * 3.0)
	_text(Vector2(0.0, s.y * 0.64), "Tap to continue" if saved else "Tap to start", 40, Color(1.0, 1.0, 1.0, pulse), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	if game.update_note != "":
		_text(Vector2(0.0, s.y * 0.64 + 44.0), game.update_note, 22, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	if saved:
		var r: Rect2 = game.new_game_rect()
		draw_rect(r, Color(0.6, 0.2, 0.2, 0.85) if game.new_game_armed else Color(1.0, 1.0, 1.0, 0.16))
		draw_rect(r, Color(1.0, 1.0, 1.0, 0.7), false, 2.0)
		var label := "Tap again to erase progress" if game.new_game_armed else "New game"
		_text(Vector2(r.position.x, r.position.y + 42.0), label, 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
