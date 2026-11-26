extends Node
## The Christmas tree in the living room, and the presents under it.
##
## At Christmas a tree stands in the living room with a nativity scene beside it and a
## pile of presents in front. There is one present for every day of December up to
## Christmas Day. Tap the pile to open the next one: it bursts into stars and a new light
## comes on in the tree. Days that were missed can still be opened, one after another, so
## by the 25th the tree can be lit from top to bottom, and on that day the star on top
## blazes. Which days have been opened is kept with the adventure.
##
## This is a child of the indoors scene and uses its room, as the kitchen does.

const Season := preload("res://scripts/season.gd")
const Ui := preload("res://scripts/ui.gd")

const TREE_AT := 950.0  # where the tree stands, across the room picture
const DAYS := 25
const GLOWS := [Color(1.0, 0.85, 0.3), Color(1.0, 0.4, 0.35), Color(0.45, 0.8, 1.0), Color(0.6, 1.0, 0.5), Color(1.0, 0.55, 0.9)]

var inn = null
var game = null
var tree: Sprite2D = null
var presents: Sprite2D = null
var nativity: Sprite2D = null
var lights: Node2D = null
var clock := 0.0
var opened_at := -9.0  # when the last present was opened, for the burst
var sparks: Array = []  # stars from an opened present: [where, which way, age, colour]


func closed() -> void:
	tree = null
	presents = null
	nativity = null
	lights = null
	sparks.clear()


## The days of this December that have been opened.
func opened() -> Array:
	var kept: Dictionary = game.data["advent"]
	var year := which_christmas()
	if int(kept.get("year", -1)) != year:
		# A new Christmas: last year's presents are forgotten.
		game.data["advent"] = { "year": year, "days": [] }
	return game.data["advent"]["days"]


## The year of the Christmas being kept: New Year's Day still belongs to the December
## before it. When Christmas has been switched on by hand at another time of year it is
## 0, so trying the presents out in summer does not open December's.
func which_christmas() -> int:
	var today := Time.get_date_dict_from_system()
	if not Season.in_season(int(today["month"]), int(today["day"])):
		return 0
	return int(today["year"]) - (1 if int(today["month"]) == 1 else 0)


## How many days' presents there are to open so far: the day of December, up to the 25th.
## Outside December (when Christmas has been switched on by hand) all of them.
func days_so_far() -> int:
	var today := Time.get_date_dict_from_system()
	return mini(int(today["day"]), DAYS) if int(today["month"]) == 12 else DAYS


func waiting() -> int:
	return maxi(days_so_far() - opened().size(), 0)


## Called whenever Adeline walks into a room.
func entered_room() -> void:
	for node in [tree, presents, nativity, lights]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	closed()
	if not Season.festive() or inn.room != "living":
		return
	var floor_y: float = inn.BACK + 46.0
	tree = _put("tree", Vector2(TREE_AT, floor_y), 250.0)
	nativity = _put("nativity", Vector2(TREE_AT - 210.0, floor_y + 4.0), 170.0)
	presents = _put("presents", Vector2(TREE_AT + 26.0, floor_y + 40.0), 170.0)
	presents.set_meta("size", presents.scale.x)
	lights = Node2D.new()
	lights.z_index = tree.z_index + 1
	lights.draw.connect(_draw_lights)
	inn.stage.add_child(lights)


func _put(name: String, feet: Vector2, wide: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(Season.WINTER + "extra/%s.png" % name)
	var k := wide / sprite.texture.get_width()
	sprite.scale = Vector2(k, k)
	sprite.offset = Vector2(0.0, -sprite.texture.get_height() / 2.0)
	sprite.position = feet
	sprite.z_index = int(feet.y)
	inn.stage.add_child(sprite)
	return sprite


## The presents on the screen, to be tapped.
func presents_rect() -> Rect2:
	var size := presents.texture.get_size() * float(presents.get_meta("size"))
	var corner: Vector2 = inn._to_screen(presents.position - Vector2(size.x / 2.0, size.y))
	return Rect2(corner, size * inn.stage.scale.x).grow(18.0)


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch) or not event.pressed or inn == null or presents == null:
		return
	if inn.place != "house" or inn.stage == null or inn.room != "living" or not is_instance_valid(presents):
		return
	if not presents_rect().has_point(event.position):
		return
	inn.get_viewport().set_input_as_handled()
	if waiting() <= 0:
		inn._say("Come back tomorrow for the next one!" if opened().size() < DAYS else "Every present is open. Merry Christmas!")
		game.sound.play("pop", -10.0)
		return
	open_next()


## Opens the next day's present.
func open_next() -> void:
	var days := opened()
	var day := 1
	while day in days:
		day += 1
	days.append(day)
	game._save()
	opened_at = clock
	for i in 26:
		sparks.append([presents.position + Vector2(0.0, -60.0), Vector2.RIGHT.rotated(randf() * TAU) * randf_range(120.0, 380.0) + Vector2(0.0, -160.0), 0.0, GLOWS[i % GLOWS.size()]])
	game.sound.play("fanfare", -9.0, 0.0, 1.15)
	game.sound.play("chime", -6.0, 0.0, 0.9 + day * 0.02)
	game.sound.shout("adeline", "merry" if day >= DAYS else "present", 1.0, true)
	if day >= DAYS:
		inn._say("The star is lit. Merry Christmas!")
	else:
		inn._say("Day %d: a new light on the tree!" % day)


## Where the light for a day sits on the tree: they wind up it from the bottom, the 25th
## being the star at the top.
func _light_spot(day: int) -> Vector2:
	var tall := tree.texture.get_height() * tree.scale.y
	var up := 0.2 + 0.62 * float(day - 1) / float(DAYS - 2)  # share of the way up, clear of the pot
	var half := tree.texture.get_width() * tree.scale.x * 0.46 * (1.0 - up) * 1.05
	var across := sin(day * 2.4) * half
	return tree.position + Vector2(across, -tall * up)


func frame(delta: float) -> void:
	if tree == null or not is_instance_valid(tree):
		return
	clock += delta
	for s in sparks:
		s[2] = float(s[2]) + delta
		s[1] = s[1] + Vector2(0.0, 420.0 * delta)
		s[0] = s[0] + s[1] * delta
	sparks = sparks.filter(func(s): return float(s[2]) < 1.1)
	# The pile jumps when one is opened, and rocks a little while there is one waiting.
	var k := float(presents.get_meta("size"))
	var since := clock - opened_at
	var jump := sin(clampf(since / 0.4, 0.0, 1.0) * PI) * 0.22
	presents.scale = Vector2(k * (1.0 + jump), k * (1.0 + jump))
	presents.rotation = sin(clock * 6.0) * 0.035 if waiting() > 0 else 0.0
	lights.queue_redraw()


func _draw_lights() -> void:
	var days := opened()
	for day in days:
		if int(day) >= DAYS:
			continue
		var at := _light_spot(int(day)) - lights.position
		var c: Color = GLOWS[int(day) % GLOWS.size()]
		var twinkle := 0.7 + 0.3 * sin(clock * 3.0 + int(day) * 1.7)
		lights.draw_circle(at, 24.0 * twinkle, Color(c.r, c.g, c.b, 0.28))
		lights.draw_circle(at, 10.5, Color(1.0, 1.0, 1.0, 0.95))
		lights.draw_circle(at, 8.5, c)
		lights.draw_circle(at + Vector2(-2.5, -2.5), 3.0, Color(1.0, 1.0, 1.0, 0.9))
	if DAYS in days or float(DAYS) in days:
		# Christmas Day: the star on top blazes.
		var tall := tree.texture.get_height() * tree.scale.y
		var top := tree.position + Vector2(0.0, -tall * 0.94) - lights.position
		for i in 8:
			var ray := Vector2.RIGHT.rotated(i * TAU / 8.0 + clock * 0.4) * (46.0 + 10.0 * sin(clock * 4.0 + i))
			lights.draw_line(top, top + ray, Color(1.0, 0.95, 0.6, 0.75), 4.0)
		lights.draw_circle(top, 30.0 + 4.0 * sin(clock * 5.0), Color(1.0, 0.95, 0.6, 0.4))
	for s in sparks:
		var fade := 1.0 - float(s[2]) / 1.1
		var c: Color = s[3]
		Ui.star(lights, (s[0] as Vector2) - lights.position, 11.0 * fade + 3.0, true)
		lights.draw_circle((s[0] as Vector2) - lights.position, 5.0 * fade, Color(c.r, c.g, c.b, fade))


func draw_ui(s: Vector2) -> void:
	if tree == null or not is_instance_valid(tree):
		return
	# Over the presents: how many are waiting, or how the tree is coming along.
	var r := presents_rect()
	var left := waiting()
	var words := "%d to open!" % left if left > 1 else ("Open me!" if left == 1 else "%d of %d lit" % [opened().size(), DAYS])
	var wide: float = inn.font.get_string_size(words, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x + 34.0
	var bob := sin(clock * 4.0) * 4.0 if left > 0 else 0.0
	var plate := Rect2(r.get_center().x - wide / 2.0, r.end.y - 6.0 + bob, wide, 34.0)
	if left > 0:
		Ui.button(inn.overlay, inn.font, plate, words, 20, Color(0.78, 0.13, 0.15, 0.96), Color(1.0, 0.97, 0.85))
	else:
		Ui.plate(inn.overlay, plate, Color(0.09, 0.11, 0.24, 0.7))
		inn._text(Vector2(plate.position.x, plate.position.y + 24.0), words, 18, Color(1.0, 0.95, 0.75), HORIZONTAL_ALIGNMENT_CENTER, plate.size.x)
