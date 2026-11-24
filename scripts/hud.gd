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
	if game.mode == "sky" and game.sky.white > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 1.0, 1.0, game.sky.white))  # flying through cloud
	_text(Vector2(0.0, 36.0), "build %d   %d fps" % [game.build_number(), int(Engine.get_frames_per_second())], 16, Color(1.0, 1.0, 1.0, 0.8), HORIZONTAL_ALIGNMENT_RIGHT, s.x - 40.0)

	if game.mode == "title":
		_draw_title(s)
		return
	if not game.dialog.active:
		_button(game.menu_rect(), "Home", 20, Color(0.08, 0.1, 0.2, 0.55))
	if game.mode == "ride":
		_draw_ride(s)
		return
	if game.mode == "sky":
		_draw_sky(s)
		return
	if game.mode == "house" or game.mode == "stable":
		return
	if game.place_action != "" and not game.dialog.active:
		_button(game.enter_rect(), "Go into the house" if game.place_action == "house" else "Visit the stable", 26, Color(0.3, 0.6, 0.35, 0.95))

	var p = game.player
	for i in p.MAX_HEALTH:
		_heart(Vector2(64.0 + i * 44.0, 52.0), i < p.health)
	if game.can_swap():
		var other := "Spirit" if game.mount_kind() == "unicorn" else str(game.MOUNTS["unicorn"]["title"])
		_button(game.swap_rect(), "Swap to %s" % other, 20, Color(0.55, 0.3, 0.7, 0.85))

	if not game.dialog.active:
		_text(Vector2(0.0, 58.0), game.objective(), 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s.x)
		var hint: String = game.hint()
		if hint != "":
			_text(Vector2(0.0, 98.0), hint, 21, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)
		if game.toast_time > 0.0:
			var alpha := clampf(game.toast_time / 0.5, 0.0, 1.0)
			var wide := clampf(font.get_string_size(game.toast_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24).x + 60.0, 420.0, s.x - 80.0)
			var box := Rect2(s.x / 2.0 - wide / 2.0, 124.0, wide, 54.0)
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
	var places := ["1st", "2nd", "3rd", "4th"]
	_text(Vector2(40.0, 62.0), ("Race %d" if r.racing else "Course %d") % r.course, 26, Color(1.0, 0.92, 0.5))
	if r.racing:
		_text(Vector2(0.0, 58.0), "%s of 4" % places[clampi(r.rank() - 1, 0, 3)], 34, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s.x)
	else:
		_text(Vector2(0.0, 58.0), "Rings %d of %d" % [r.rings_got, r.rings_total], 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s.x)
	# Bursts of speed saved up: three to a full bar.
	_text(Vector2(40.0, 98.0), "Boost", 18, Color.WHITE)
	for i in 3:
		var cell := Rect2(104.0 + i * 46.0, 84.0, 40.0, 14.0)
		draw_rect(cell, Color(0.0, 0.0, 0.0, 0.35))
		draw_rect(Rect2(cell.position, Vector2(cell.size.x * clampf(r.boost * 3.0 - i, 0.0, 1.0), cell.size.y)), Color(1.0, 0.85, 0.2))
		draw_rect(cell, Color(1.0, 1.0, 1.0, 0.6), false, 1.5)
	# How far along the course Spirit is.
	var bar := Rect2(s.x / 2.0 - 220.0, 76.0, 440.0, 10.0)
	var done := clampf((game.player.position.x - r.START_X) / (r.finish_x - r.START_X), 0.0, 1.0)
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.3))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * done, bar.size.y)), Color(1.0, 0.85, 0.2))
	if not r.finished and r.run_time < 7.0:
		var tip := "Jump cleanly and collect rings to save up BOOST. Be first to the finish!" if r.racing else "Tap JUMP to leap, hold it to jump higher. Ride through the rings! BOOST gives a burst of speed."
		_text(Vector2(0.0, 132.0), tip, 21, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	if r.finished and r.finish_time >= 0.8:
		var panel := Rect2(s.x / 2.0 - 360.0, s.y * 0.16, 720.0, s.y * 0.6)
		draw_rect(panel, Color(0.08, 0.1, 0.2, 0.85))
		draw_rect(panel, Color(1.0, 0.9, 0.5, 0.9), false, 3.0)
		var headline := "Course %d finished!" % r.course
		if r.racing:
			var name: String = game.horse.title
			headline = "%s won the race!" % name if r.place == 1 else "%s came %s!" % [name, places[clampi(r.place - 1, 0, 3)]]
		_text(Vector2(panel.position.x, panel.position.y + 64.0), headline, 42, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		for i in 3:
			_star(Vector2(s.x / 2.0 + (i - 1) * 110.0, panel.position.y + 140.0), 44.0, i < r.stars)
		var line := "Rings %d of %d     Clean jumps %d     Bumps %d" % [r.rings_got, r.rings_total, r.jumps_clean, r.stumbles]
		_text(Vector2(panel.position.x, panel.position.y + 226.0), line, 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		_button(game.again_rect(), "Race again" if r.racing else "Ride again", 28, Color(0.25, 0.4, 0.75, 0.95))
		_button(game.next_rect(), "Next race" if r.racing else "Next course", 28, Color(0.3, 0.6, 0.35, 0.95))


## A feather: what the unicorn has left before she tumbles out of the sky.
func _feather(center: Vector2, full: bool) -> void:
	var c := Color(1.0, 1.0, 1.0) if full else Color(0.0, 0.0, 0.0, 0.28)
	var pts := PackedVector2Array()
	for i in 13:
		var a := i / 12.0 * TAU
		pts.append(center + Vector2(cos(a) * 9.0, sin(a) * 20.0).rotated(0.5))
	draw_colored_polygon(pts, c)
	if full:
		draw_circle(center + Vector2(-8.0, -15.0), 6.0, Color(1.0, 0.6, 0.85))
	draw_line(center + Vector2(9.0, 17.0), center + Vector2(-9.0, -17.0), Color(0.0, 0.0, 0.0, 0.25), 2.0)


func _draw_sky(s: Vector2) -> void:
	var k = game.sky
	_text(Vector2(40.0, 62.0), "Fly %s home" % game.horse.title if k.story else "Sky %d: %s" % [k.course, k.title()], 26, Color(1.0, 0.92, 0.5))
	for i in k.FEATHERS:
		_feather(Vector2(62.0 + i * 40.0, 102.0), i < k.feathers)
	_text(Vector2(0.0, 58.0), "Stars %d of %d" % [k.stars_got, k.stars_total], 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s.x)
	# How far along the sky she is, with a mark at each rainbow arch.
	var bar := Rect2(s.x / 2.0 - 220.0, 76.0, 440.0, 10.0)
	var length: float = maxf(k.finish_x - k.SKY_START, 1.0)
	var done: float = (float(k.legs[k.leg]) - k.SKY_START) / length
	if k.high_up():
		done = clampf((k.at.x - k.SKY_START) / length, 0.0, 1.0)
	draw_rect(bar, Color(0.0, 0.0, 0.0, 0.3))
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * done, bar.size.y)), Color(1.0, 0.7, 0.9))
	for i in range(1, k.legs.size()):
		var mark: float = bar.position.x + bar.size.x * (float(k.legs[i]) - k.SKY_START) / length
		draw_rect(Rect2(mark - 2.0, bar.position.y - 4.0, 4.0, 18.0), Color(1.0, 1.0, 1.0, 0.9))
	if k.state == "fly" and not k.tapped:
		var pulse := 0.75 + 0.25 * sin(k.clock * 7.0)
		_text(Vector2(0.0, s.y * 0.72), "TAP to flap her wings!", 44, Color(1.0, 0.95, 0.6, pulse), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	elif k.state == "fly" and k.clock < 14.0 and k.falls == 0:
		_text(Vector2(0.0, 132.0), "Each tap is one beat of her wings. Fly between the storm clouds and through the rings.", 21, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	if game.toast_time > 0.0 and k.state != "done" and k.state != "landed":
		var alpha := clampf(game.toast_time / 0.5, 0.0, 1.0)
		var wide := clampf(font.get_string_size(game.toast_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24).x + 60.0, 420.0, s.x - 80.0)
		var box := Rect2(s.x / 2.0 - wide / 2.0, 150.0, wide, 54.0)
		draw_rect(box, Color(0.08, 0.1, 0.2, 0.75 * alpha))
		_text(Vector2(box.position.x, box.position.y + 37.0), game.toast_text, 24, Color(1.0, 0.92, 0.5, alpha), HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
	if k.state == "landed" and k.state_time > 0.6:
		var panel := Rect2(s.x / 2.0 - 330.0, s.y * 0.2, 660.0, 150.0)
		draw_rect(panel, Color(0.08, 0.1, 0.2, 0.8))
		draw_rect(panel, Color(1.0, 0.9, 0.5, 0.9), false, 3.0)
		_text(Vector2(panel.position.x, panel.position.y + 62.0), "Back down to earth!", 42, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		var where := "Tap to fly back up to the rainbow arch" if k.leg > 0 else "Tap to fly up and try again"
		_text(Vector2(panel.position.x, panel.position.y + 116.0), where, 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	if k.state == "done" and k.state_time >= 0.8:
		var panel: Rect2 = game.sky_panel()
		draw_rect(panel, Color(0.08, 0.1, 0.2, 0.85))
		draw_rect(panel, Color(1.0, 0.9, 0.5, 0.9), false, 3.0)
		var headline := "%s is home!" % game.horse.title if k.story else "The cloud castle!"
		_text(Vector2(panel.position.x, panel.position.y + 64.0), headline, 42, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		for i in 3:
			_star(panel.position + Vector2(panel.size.x / 2.0 + (i - 1) * 110.0, 140.0), 44.0, i < k.stars)
		var line := "Stars %d of %d    Rings %d of %d    Tumbles %d" % [k.stars_got, k.stars_total, k.rings_got, k.rings_total, k.falls]
		_text(Vector2(panel.position.x, panel.position.y + 226.0), line, 23, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		if k.story:
			_text(Vector2(panel.position.x, panel.position.y + 310.0), "Tap to go on", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		else:
			_button(game.sky_again_rect(), "Fly again", 28, Color(0.25, 0.4, 0.75, 0.95))
			_button(game.sky_next_rect(), "Next sky", 28, Color(0.3, 0.6, 0.35, 0.95))


func _draw_title(s: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.06, 0.09, 0.22, 0.6))
	_text(Vector2(0.0, s.y * 0.36), "ADELINE", 110, Color(1.0, 0.9, 0.5), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	_text(Vector2(0.0, s.y * 0.36 + 54.0), "A wand, a flying boat and a lot of goblins", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s.x)
	var saved: bool = game.has_save()
	_button(game.adventure_rect(), "Continue the adventure" if saved else "Start the adventure", 28, Color(0.25, 0.4, 0.75, 0.95))
	_button(game.ride_rect(), "Ride with Spirit", 28, Color(0.3, 0.6, 0.35, 0.95))
	_button(game.race_rect(), "Horse race", 24, Color(0.75, 0.5, 0.15, 0.95))
	_button(game.sky_rect(), "Fly the unicorn", 24, Color(0.6, 0.35, 0.75, 0.95))
	if saved:
		var armed: bool = game.new_game_armed
		_button(game.new_game_rect(), "Tap again to erase progress" if armed else "New adventure", 22, Color(0.6, 0.2, 0.2, 0.85) if armed else Color(1.0, 1.0, 1.0, 0.16))
	_button(game.sound_rect(), "Sound: on" if game.sound_on else "Sound: off", 22, Color(1.0, 1.0, 1.0, 0.16))
	if game.update_note != "":
		_text(Vector2(0.0, 84.0), game.update_note, 22, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, s.x)
