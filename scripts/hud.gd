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


func _button(r: Rect2, label: String, text_size: int, fill: Color) -> void:
	draw_rect(r, fill)
	draw_rect(r, Color(1.0, 1.0, 1.0, 0.75), false, 2.0)
	_text(Vector2(r.position.x, r.position.y + r.size.y / 2.0 + text_size * 0.36), label, text_size, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)


func _star(center: Vector2, radius: float, lit: bool) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := -PI / 2.0 + i * PI / 5.0
		pts.append(center + Vector2(cos(a), sin(a)) * (radius if i % 2 == 0 else radius * 0.45))
	draw_colored_polygon(pts, Color(1.0, 0.85, 0.2) if lit else Color(1.0, 1.0, 1.0, 0.18))


func _draw() -> void:
	if game == null or game.player == null:
		return
	var s := get_viewport_rect().size
	_text(Vector2(0.0, 36.0), "build %d   %d fps" % [game.build_number(), int(Engine.get_frames_per_second())], 16, Color(1.0, 1.0, 1.0, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, s.x - 40.0)

	if game.mode == "title":
		_draw_title(s)
		return
	if not game.dialog.active:
		_button(game.menu_rect(), "Home", 20, Color(0.08, 0.1, 0.2, 0.55))
	if game.mode == "ride":
		_draw_ride(s)
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


func _draw_ride(s: Vector2) -> void:
	var r = game.ride
	_text(Vector2(40.0, 62.0), "Course %d" % r.course, 26, Color(1.0, 0.92, 0.5))
	_text(Vector2(0.0, 58.0), "Rings %d of %d" % [r.rings_got, r.rings_total], 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s.x)
	# How far along the course Spirit is.
	var bar := Rect2(s.x / 2.0 - 220.0, 76.0, 440.0, 10.0)
	var done := clampf((game.player.position.x - r.START_X) / (r.finish_x - r.START_X), 0.0, 1.0)
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.3))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * done, bar.size.y)), Color(1.0, 0.85, 0.2))
	if not r.finished and r.run_time < 7.0:
		_text(Vector2(0.0, 122.0), "Tap JUMP to leap, hold it to jump higher. Ride through the rings!", 21, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	if r.finished and r.finish_time >= 0.8:
		var panel := Rect2(s.x / 2.0 - 360.0, s.y * 0.16, 720.0, s.y * 0.6)
		draw_rect(panel, Color(0.08, 0.1, 0.2, 0.85))
		draw_rect(panel, Color(1.0, 0.9, 0.5, 0.9), false, 3.0)
		_text(Vector2(panel.position.x, panel.position.y + 64.0), "Course %d finished!" % r.course, 42, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		for i in 3:
			_star(Vector2(s.x / 2.0 + (i - 1) * 110.0, panel.position.y + 140.0), 44.0, i < r.stars)
		var line := "Rings %d of %d     Clean jumps %d     Bumps %d" % [r.rings_got, r.rings_total, r.jumps_clean, r.stumbles]
		_text(Vector2(panel.position.x, panel.position.y + 226.0), line, 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		_button(game.again_rect(), "Ride again", 28, Color(0.25, 0.4, 0.75, 0.95))
		_button(game.next_rect(), "Next course", 28, Color(0.3, 0.6, 0.35, 0.95))


func _draw_title(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.06, 0.09, 0.22, 0.6))
	_text(Vector2(0.0, s.y * 0.36), "ADELINE", 110, Color(1.0, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	_text(Vector2(0.0, s.y * 0.36 + 54.0), "A wand, a flying boat and a lot of goblins", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s.x)
	var saved: bool = game.has_save()
	_button(game.adventure_rect(), "Continue the adventure" if saved else "Start the adventure", 28, Color(0.25, 0.4, 0.75, 0.95))
	_button(game.ride_rect(), "Ride with Spirit", 28, Color(0.3, 0.6, 0.35, 0.95))
	if saved:
		var armed: bool = game.new_game_armed
		_button(game.new_game_rect(), "Tap again to erase progress" if armed else "New adventure", 22, Color(0.6, 0.2, 0.2, 0.85) if armed else Color(1.0, 1.0, 1.0, 0.16))
	if game.update_note != "":
		_text(Vector2(0.0, s.y * 0.56 + 230.0), game.update_note, 22, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, s.x)
