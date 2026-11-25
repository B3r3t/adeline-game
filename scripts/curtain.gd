extends Control
## The change from one place to another. Whenever the game moves somewhere new (into the
## house, through a door, off to a race, back to the title) the new place opens out of the
## dark from the middle of the screen, the way a storybook turns a page. It sits on top of
## everything and takes no touches; nothing waits for it.

const TIME := 0.55

var game = null
var where := ""
var age := TIME


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(delta: float) -> void:
	if game == null or game.indoors == null:
		return
	var now := "%s %s %s %d" % [game.mode, game.indoors.place, game.indoors.room if game.indoors.place == "house" else "", game.mini.which]
	if now != where:
		where = now
		age = 0.0
	if age < TIME:
		age += delta
		queue_redraw()


func _draw() -> void:
	if age >= TIME:
		return
	var s := get_viewport_rect().size
	var k := age / TIME
	var open := k * k * (3.0 - 2.0 * k)
	var hole := open * s.length() * 0.56
	var far := s.length()
	var dark := Color(0.05, 0.05, 0.13)
	# A ring of dark from the edge of the hole outward, in wedges.
	var steps := 40
	for i in steps:
		var a := Vector2.RIGHT.rotated(i * TAU / steps)
		var b := Vector2.RIGHT.rotated((i + 1) * TAU / steps)
		draw_colored_polygon(PackedVector2Array([s / 2.0 + a * hole, s / 2.0 + a * far, s / 2.0 + b * far, s / 2.0 + b * hole]), dark)
	# A soft golden rim on the hole.
	draw_arc(s / 2.0, hole, 0.0, TAU, 64, Color(1.0, 0.86, 0.45, 0.5 * (1.0 - open)), 6.0)
	if hole < 2.0:
		draw_rect(Rect2(Vector2.ZERO, s), dark)
