extends Control
## Hearts, the current objective, hints, short messages, the title screen and the
## "try again" banner. Everything sits along the top so it stays clear of the thumbs.

const Ui := preload("res://scripts/ui.gd")

var game = null
var font: Font
var title_art: Texture2D = null
var logo: Texture2D = null

# Motion. Nothing on screen just appears: panels pop open, counters jump when they change,
# stars arrive one at a time. These keep the time for all of it.
var ages := {}  # how long each thing has been showing, by name
var drawn := {}  # the frame each was last drawn, so it starts again after being away
var seen := {}  # the last value of each thing that jumps when it changes
var since := {}  # and how long ago that was
var rung := 0  # how many of the stars on a results panel have chimed
var health_was := -1


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	for name in ages:
		ages[name] += delta
	for name in since:
		since[name] += delta
	queue_redraw()


## How long the thing called `name` has been on screen. Ask every frame it is drawn; when
## it has been away and comes back, it starts from nothing again.
func _age(name: String) -> float:
	var frame := Engine.get_process_frames()
	if not ages.has(name) or frame - int(drawn[name]) > 1:
		ages[name] = 0.0
	drawn[name] = frame
	return ages[name]


## How long ago `value` last changed. The first time, a long while.
func _changed(name: String, value) -> float:
	if not seen.has(name):
		seen[name] = value
		since[name] = 9.0
	elif str(seen[name]) != str(value):
		seen[name] = value
		since[name] = 0.0
	return since[name]


## A size for a number that has just changed: bigger for a moment, then back.
func _jump(name: String, value, text_size: int) -> int:
	return text_size + int(14.0 * maxf(1.0 - _changed(name, value) / 0.3, 0.0))


## From here until `_settle`, everything drawn grows out of `center`: a pop.
func _pop(center: Vector2, age: float, time := 0.3) -> void:
	var k := maxf(Ui.pop(age / time), 0.001)
	draw_set_transform(center * (1.0 - k), 0.0, Vector2(k, k))


func _settle() -> void:
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


## The three stars on a results panel. They arrive one at a time, each with a chime a
## little higher than the last.
func _stars(center: Vector2, won: int, age: float) -> void:
	if age < 0.2:
		rung = 0
	for i in 3:
		var at := center + Vector2((i - 1) * 110.0, 0.0)
		var mine := age - 0.45 - i * 0.32
		_star(at, 44.0, false)
		if i < won and mine > 0.0:
			if rung <= i:
				rung = i + 1
				game.sound.play("chime", -7.0, 0.0, 1.0 + i * 0.16)
			_pop(at, mine, 0.34)
			_star(at, 44.0, true)
			_settle()
			if mine < 0.5:
				# A ring of sparks as it lands.
				for n in 8:
					var out := Vector2.RIGHT.rotated(n * TAU / 8.0 + i) * (40.0 + mine * 90.0)
					draw_circle(at + out, 5.0 * (1.0 - mine / 0.5), Color(1.0, 0.92, 0.5, 1.0 - mine / 0.5))


func _text(pos: Vector2, text: String, text_size: int, color: Color, align: int = HORIZONTAL_ALIGNMENT_LEFT, width: float = -1.0) -> void:
	draw_string_outline(font, pos, text, align, width, text_size, 6, Color(0.0, 0.0, 0.0, 0.55))
	draw_string(font, pos, text, align, width, text_size, color)


func _heart(center: Vector2, full: bool) -> void:
	Ui.heart(self, center, 15.0, full)


func _button(r: Rect2, label: String, text_size: int, fill: Color) -> void:
	Ui.button(self, font, r, label, text_size, fill)


func _star(center: Vector2, radius: float, lit: bool) -> void:
	Ui.star(self, center, radius, lit)


func _draw() -> void:
	if game == null or game.player == null:
		return
	var s := get_viewport_rect().size
	_draw_screen(s)
	if game.menu != "":
		_draw_menu(s)


## The settings and pause menus: a panel of big rows over a dimmed screen.
func _draw_menu(s: Vector2) -> void:
	var age := _age("menu")
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.03, 0.04, 0.12, 0.6 * minf(age / 0.18, 1.0)))
	var panel: Rect2 = game.menu_panel()
	_pop(panel.get_center(), age)
	Ui.panel(self, panel)
	_text(Vector2(panel.position.x, panel.position.y + 52.0), "Paused" if game.menu == "pause" else "Settings", 34, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
	var rows: Array = game.menu_rows()
	for i in rows.size():
		var what := str(rows[i][0])
		var fill := Color(0.25, 0.4, 0.75, 0.95)
		if what == "resume":
			fill = Color(0.26, 0.6, 0.36, 0.95)
		elif what == "home":
			fill = Color(0.45, 0.45, 0.55, 0.95)
		elif what == "new":
			fill = Color(0.75, 0.22, 0.22, 0.95) if game.new_game_armed else Color(0.45, 0.45, 0.55, 0.95)
		_button(game.menu_row_rect(i), str(rows[i][1]), 24, fill)
	_settle()


func _draw_screen(s: Vector2) -> void:
	if game.mode == "sky" and game.sky.white > 0.0:
		draw_rect(Rect2(Vector2.ZERO, s), Color(1.0, 1.0, 1.0, game.sky.white))  # flying through cloud

	if game.mode == "title":
		_draw_title(s)
		return
	if not game.dialog.active:
		# The menu button: two bars, as on a music player.
		var m: Rect2 = game.menu_rect()
		_button(m, "", 20, Color(0.09, 0.11, 0.24, 0.6))
		for i in 2:
			draw_rect(Rect2(m.position.x + 22.0 + i * 14.0, m.position.y + 12.0, 8.0, m.size.y - 24.0), Color(1.0, 1.0, 1.0, 0.95))
		_text(Vector2(m.position.x + 54.0, m.position.y + m.size.y / 2.0 + 8.0), "Menu", 20, Color.WHITE)
	if game.mode == "ride":
		_draw_ride(s)
		return
	if game.mode == "sky":
		_draw_sky(s)
		return
	if game.mode == "house" or game.mode == "stable":
		return
	if game.place_action != "" and not game.dialog.active:
		_pop(game.enter_rect().get_center(), _age("enter"))
		_button(game.enter_rect(), "Go into the house" if game.place_action == "house" else "Visit the stable", 26, Color(0.3, 0.6, 0.35, 0.95))
		_settle()

	var p = game.player
	# Hearts shake when one is lost, and the one that changed jumps.
	if health_was < 0:
		health_was = p.health
	var hurt := _changed("health", p.health)
	if hurt > 0.5:
		health_was = p.health
	for i in p.MAX_HEALTH:
		var at := Vector2(64.0 + i * 44.0, 52.0)
		if hurt < 0.5:
			var lost: bool = p.health < health_was
			if lost:
				at.x += sin(hurt * 60.0 + i) * 5.0 * (1.0 - hurt / 0.5)
			if i == (p.health if lost else p.health - 1):
				_pop(at, hurt + 0.1, 0.4)
				_heart(at, i < p.health)
				_settle()
				if lost:
					Ui.heart(self, at + Vector2(0.0, -hurt * 70.0), 15.0 + hurt * 20.0, true)  # the lost one floats away
				continue
		_heart(at, i < p.health)
	if game.can_swap():
		var other := "Spirit" if game.mount_kind() == "unicorn" else str(game.MOUNTS["unicorn"]["title"])
		_button(game.swap_rect(), "Swap to %s" % other, 20, Color(0.55, 0.3, 0.7, 0.85))

	if not game.dialog.active:
		# The goal and the hint sit on a soft plate, so clouds behind them do not get in the way.
		var goal: String = game.objective()
		var hint: String = game.hint()
		var across := font.get_string_size(goal, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 30).x
		if hint != "":
			across = maxf(across, font.get_string_size(hint, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 21).x)
		across = minf(across + 56.0, s.x - 40.0)
		# A new goal swells for a moment and its plate lights up, so it is noticed.
		var fresh := maxf(1.0 - _changed("goal", goal) / 0.5, 0.0)
		var swell := 1.0 + 0.1 * sin(fresh * PI)
		draw_set_transform(Vector2(s.x / 2.0, 46.0) * (1.0 - swell), 0.0, Vector2(swell, swell))
		Ui.plate(self, Rect2(s.x / 2.0 - across / 2.0, 24.0, across, 86.0 if hint != "" else 46.0), Color(0.09, 0.11, 0.24, 0.42).lerp(Color(0.5, 0.4, 0.1, 0.7), fresh))
		_text(Vector2(0.0, 58.0), goal, 30, Color.WHITE.lerp(Color(1.0, 0.92, 0.5), fresh), HORIZONTAL_ALIGNMENT_CENTER, s.x)
		_settle()
		if hint != "":
			_text(Vector2(0.0, 96.0), hint, 21, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)
		if game.toast_time > 0.0:
			var alpha := clampf(game.toast_time / 0.5, 0.0, 1.0)
			var wide := clampf(font.get_string_size(game.toast_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 24).x + 60.0, 420.0, s.x - 80.0)
			var drop := (1.0 - Ui.ease(_changed("toast", game.toast_text) / 0.25)) * 34.0  # it slides down into place
			alpha *= 1.0 - drop / 34.0
			var box := Rect2(s.x / 2.0 - wide / 2.0, 124.0 - drop, wide, 54.0)
			Ui.plate(self, box, Color(0.09, 0.11, 0.24, 0.8 * alpha))
			_text(Vector2(box.position.x, box.position.y + 37.0), game.toast_text, 24, Color(1.0, 0.92, 0.5, alpha), HORIZONTAL_ALIGNMENT_CENTER, box.size.x)

	if game.defeated:
		var banner := Rect2(s.x / 2.0 - 330.0, s.y * 0.26, 660.0, 170.0)
		_pop(banner.get_center(), _age("defeat"))
		Ui.panel(self, banner)
		_text(Vector2(banner.position.x, banner.position.y + 76.0), "Adeline needs a rest", 46, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, banner.size.x)
		if game.defeat_time >= 1.0:
			_text(Vector2(banner.position.x, banner.position.y + 130.0), "Tap to try this fight again", 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, banner.size.x)
		_settle()


func _draw_ride(s: Vector2) -> void:
	var r = game.ride
	var places := ["1st", "2nd", "3rd", "4th"]
	_text(Vector2(40.0, 62.0), ("Race %d" if r.racing else "Course %d") % r.course, 26, Color(1.0, 0.92, 0.5))
	if r.racing:
		_text(Vector2(0.0, 58.0), "%s of 4" % places[clampi(r.rank() - 1, 0, 3)], _jump("rank", r.rank(), 34), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s.x)
	else:
		_text(Vector2(0.0, 58.0), "Rings %d of %d" % [r.rings_got, r.rings_total], _jump("rings", r.rings_got, 30), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s.x)
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
	if r.holding():
		# Three, two, one, before a race.
		var n := int(ceil(r.countdown))
		var beat: float = r.countdown - floorf(r.countdown)
		if n >= 1 and n <= 3:
			_text(Vector2(0.0, s.y * 0.46), str(n), int(120.0 + 60.0 * beat), Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	elif r.racing and r.run_time < 0.9:
		var fade: float = 1.0 - r.run_time / 0.9
		draw_string_outline(font, Vector2(0.0, s.y * 0.46), "GO!", HORIZONTAL_ALIGNMENT_CENTER, s.x, 130, 10, Color(0.0, 0.0, 0.0, 0.55 * fade))
		draw_string(font, Vector2(0.0, s.y * 0.46), "GO!", HORIZONTAL_ALIGNMENT_CENTER, s.x, 130, Color(0.6, 1.0, 0.6, fade))
	if not r.finished and r.run_time < 7.0:
		var tip := "Jump cleanly and collect rings to save up BOOST. Be first to the finish!" if r.racing else "Tap JUMP to leap, hold it to jump higher. Ride through the rings! BOOST gives a burst of speed."
		_text(Vector2(0.0, 132.0), tip, 21, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	if r.finished and r.finish_time >= 0.8:
		var panel := Rect2(s.x / 2.0 - 360.0, s.y * 0.16, 720.0, s.y * 0.6)
		var age := _age("ride done")
		_pop(panel.get_center(), age)
		Ui.panel(self, panel)
		var headline := "Course %d finished!" % r.course
		if r.racing:
			var name: String = game.horse.title
			headline = "%s won the race!" % name if r.place == 1 else "%s came %s!" % [name, places[clampi(r.place - 1, 0, 3)]]
		_text(Vector2(panel.position.x, panel.position.y + 64.0), headline, 42, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		_settle()
		_stars(Vector2(s.x / 2.0, panel.position.y + 140.0), r.stars, age)
		_pop(panel.get_center(), age)
		var line := "Rings %d of %d     Clean jumps %d     Bumps %d" % [r.rings_got, r.rings_total, r.jumps_clean, r.stumbles]
		_text(Vector2(panel.position.x, panel.position.y + 226.0), line, 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		_button(game.again_rect(), "Race again" if r.racing else "Ride again", 28, Color(0.25, 0.4, 0.75, 0.95))
		_button(game.next_rect(), "Next race" if r.racing else "Next course", 28, Color(0.3, 0.6, 0.35, 0.95))


## A feather: what the unicorn has left before she tumbles out of the sky.
func _feather(center: Vector2, full: bool) -> void:
	# A leaf-shaped vane with a rainbow tip, and the quill down its middle.
	var lean := 0.5
	var edge := PackedVector2Array()
	var vane := PackedVector2Array()
	for i in 21:
		var k := i / 20.0
		var half := sin(k * PI) * (0.55 + 0.45 * k)  # wider toward the tip
		var along := lerpf(22.0, -24.0, k)
		edge.append(center + Vector2(-half * 13.0, along).rotated(lean))
		vane.append(center + Vector2(-half * 10.5, lerpf(19.0, -21.0, k)).rotated(lean))
	for i in 21:
		var k := 1.0 - i / 20.0
		var half := sin(k * PI) * (0.55 + 0.45 * k)
		edge.append(center + Vector2(half * 13.0, lerpf(22.0, -24.0, k)).rotated(lean))
		vane.append(center + Vector2(half * 10.5, lerpf(19.0, -21.0, k)).rotated(lean))
	draw_colored_polygon(edge, Color(0.25, 0.2, 0.4, 0.9) if full else Color(0.0, 0.0, 0.0, 0.3))
	draw_colored_polygon(vane, Color(1.0, 1.0, 1.0) if full else Color(1.0, 1.0, 1.0, 0.14))
	if full:
		for band in 3:
			var at := center + Vector2(0.0, -18.0 + band * 6.0).rotated(lean)
			draw_circle(at, 6.5 - band * 1.2, [Color(1.0, 0.5, 0.75), Color(1.0, 0.85, 0.4), Color(0.5, 0.85, 1.0)][band])
		draw_line(center + Vector2(0.0, 24.0).rotated(lean), center + Vector2(0.0, -16.0).rotated(lean), Color(0.6, 0.6, 0.75), 2.0)


func _draw_sky(s: Vector2) -> void:
	var k = game.sky
	_text(Vector2(40.0, 62.0), "Fly %s home" % game.horse.title if k.story else "Sky %d: %s" % [k.course, k.title()], 26, Color(1.0, 0.92, 0.5))
	for i in k.FEATHERS:
		_feather(Vector2(64.0 + i * 44.0, 108.0), i < k.feathers)
	_text(Vector2(0.0, 58.0), "Stars %d of %d" % [k.stars_got, k.stars_total], _jump("sky stars", k.stars_got, 30), Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, s.x)
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
		Ui.plate(self, box, Color(0.09, 0.11, 0.24, 0.8 * alpha))
		_text(Vector2(box.position.x, box.position.y + 37.0), game.toast_text, 24, Color(1.0, 0.92, 0.5, alpha), HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
	if k.state == "landed" and k.state_time > 0.6:
		var panel := Rect2(s.x / 2.0 - 330.0, s.y * 0.2, 660.0, 150.0)
		_pop(panel.get_center(), _age("landed"))
		Ui.panel(self, panel)
		_text(Vector2(panel.position.x, panel.position.y + 62.0), "Back down to earth!", 42, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		var where := "Tap to fly back up to the rainbow arch" if k.leg > 0 else "Tap to fly up and try again"
		_text(Vector2(panel.position.x, panel.position.y + 116.0), where, 26, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		_settle()
	if k.state == "done" and k.state_time >= 0.8:
		var panel: Rect2 = game.sky_panel()
		var age := _age("sky done")
		_pop(panel.get_center(), age)
		Ui.panel(self, panel)
		var headline := "%s is home!" % game.horse.title if k.story else "The cloud castle!"
		_text(Vector2(panel.position.x, panel.position.y + 64.0), headline, 42, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		_settle()
		_stars(panel.position + Vector2(panel.size.x / 2.0, 140.0), k.stars, age)
		_pop(panel.get_center(), age)
		var line := "Stars %d of %d    Rings %d of %d    Tumbles %d" % [k.stars_got, k.stars_total, k.rings_got, k.rings_total, k.falls]
		_text(Vector2(panel.position.x, panel.position.y + 226.0), line, 23, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		if k.story:
			_text(Vector2(panel.position.x, panel.position.y + 310.0), "Tap to go on", 30, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, panel.size.x)
		else:
			_button(game.sky_again_rect(), "Fly again", 28, Color(0.25, 0.4, 0.75, 0.95))
			_button(game.sky_next_rect(), "Next sky", 28, Color(0.3, 0.6, 0.35, 0.95))


func _draw_title(s: Vector2) -> void:
	if title_art == null:
		title_art = load("res://art/ui/title.jpg")
		logo = load("res://art/ui/logo.png")
	# The painting fills the screen, cut to fit, with its top kept in view.
	var size := title_art.get_size()
	# It drifts very slowly, as if the camera were breathing, and a few stars twinkle on it.
	var age := _age("title")
	var now := Time.get_ticks_msec() / 1000.0
	var k := maxf(s.x / size.x, s.y / size.y) * (1.05 + 0.012 * sin(now * 0.21))
	var shown := s / k
	var room := size - shown
	var slide := Vector2(minf(room.x / 2.0, shown.x * 0.02) * sin(now * 0.13), minf(room.y, shown.y * 0.03) * (0.5 + 0.5 * sin(now * 0.17 + 1.0)))
	draw_texture_rect_region(title_art, Rect2(Vector2.ZERO, s), Rect2(room.x / 2.0 + slide.x, slide.y, shown.x, shown.y))
	for i in 16:
		var at := Vector2(fmod(i * 397.3 + 60.0, s.x), fmod(i * 211.7 + 30.0, s.y * 0.55))
		var glow := maxf(sin(now * (1.1 + fmod(i * 0.37, 0.9)) + i * 2.1), 0.0)
		var ray := 3.0 + 9.0 * glow
		draw_line(at - Vector2(ray, 0.0), at + Vector2(ray, 0.0), Color(1.0, 1.0, 0.9, 0.75 * glow), 2.0)
		draw_line(at - Vector2(0.0, ray), at + Vector2(0.0, ray), Color(1.0, 1.0, 0.9, 0.75 * glow), 2.0)
		draw_circle(at, 2.0 + 1.5 * glow, Color(1.0, 1.0, 0.9, 0.85 * glow))
	# It darkens toward the bottom, where the cards sit.
	for i in 12:
		draw_rect(Rect2(0.0, s.y - 250.0 + i * 21.0, s.x, 22.0), Color(0.04, 0.05, 0.16, 0.055 * (i + 1)))
	var wide := minf(470.0, s.x * 0.4)
	var bob := sin(Time.get_ticks_msec() / 1000.0 * 1.4) * 4.0
	var fall := (1.0 - Ui.pop((age - 0.1) / 0.6)) * -300.0  # the name drops in from above and settles
	draw_texture_rect(logo, Rect2(s.x / 2.0 - wide / 2.0, 18.0 + bob + fall, wide, wide * logo.get_height() / logo.get_width()), false)

	var saved: bool = game.has_save()
	for i in game.GAMES.size():
		var info: Dictionary = game.GAMES[i]
		var r: Rect2 = game.card_rect(i)
		r.position.y += (1.0 - Ui.pop((age - 0.3 - i * 0.09) / 0.5)) * 300.0  # the cards come up one after another
		Ui.button(self, font, r, "", 20, Color(info["color"].r, info["color"].g, info["color"].b, 0.96))
		_text(Vector2(r.position.x, r.position.y + 46.0), str(info["label"]), 27, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		if i == 0:
			var line := "Start here" if not saved else str(game.objective())
			_text(Vector2(r.position.x + 12.0, r.position.y + 90.0), line, 19, Color(1.0, 0.95, 0.7), HORIZONTAL_ALIGNMENT_CENTER, r.size.x - 24.0)
			continue
		# Which course is chosen, the stars won on it, and arrows to the others reached.
		var number: int = game.chosen(i)
		var most: int = game.reached(i)
		var best := int(game.data[info["stars"]].get(str(number), 0))
		_text(Vector2(r.position.x, r.position.y + 82.0), "%s %d" % [info["word"], number], 20, Color(1.0, 0.95, 0.7), HORIZONTAL_ALIGNMENT_CENTER, r.size.x)
		for n in 3:
			Ui.star(self, Vector2(r.get_center().x + (n - 1) * 26.0, r.position.y + 103.0), 10.0, n < best)
		for side in [-1.0, 1.0]:
			var can := (number > 1) if side < 0.0 else (number < most)
			var c := Vector2(r.get_center().x + side * (r.size.x / 2.0 - 26.0), r.get_center().y + 4.0)
			draw_colored_polygon(PackedVector2Array([c + Vector2(side * 11.0, 0.0), c + Vector2(-side * 8.0, -15.0), c + Vector2(-side * 8.0, 15.0)]), Color(1.0, 1.0, 1.0, 0.95 if can else 0.22))

	_button(game.settings_rect(), "Settings", 22, Color(0.09, 0.11, 0.24, 0.6))
	_text(Vector2(0.0, 30.0), "build %d" % game.build_number(), 15, Color(1.0, 1.0, 1.0, 0.75), HORIZONTAL_ALIGNMENT_RIGHT, s.x - 24.0)
	if game.update_note != "":
		var wide_note := font.get_string_size(game.update_note, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 20).x + 44.0
		var box := Rect2(s.x / 2.0 - wide_note / 2.0, s.y - 214.0, wide_note, 42.0)
		Ui.plate(self, box)
		_text(Vector2(box.position.x, box.position.y + 29.0), game.update_note, 20, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, box.size.x)
