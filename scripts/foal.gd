extends Node
## Spirit's foal, who lives in the stable and grows up.
##
## Each day she wants three things: her milk, a brush and a cuddle. They are given with
## the things in the stable's tray, the same way Spirit is looked after: hold the bottle
## to her, brush her, stroke her with the heart. When all three are done she is cared for
## that day, and that is one day of growing. She does the growing overnight: the next day
## she is a little bigger, and Adeline sees it when she walks in. After two days of care
## she stands, after five she trots about, and after ten she is all grown up.
##
## A day that is missed costs nothing. She does not get hungry or sad; she just waits, and
## grows the day after she is next cared for. So it is always a nice thing to come back to
## and never a chore that has been failed.
##
## The first time Adeline meets her she is given a name, from a few to choose from. A day
## of care also pays a star into the purse for Merlin's shop.
##
## This is a child of the indoors scene and uses its stable, as the kitchen uses the house.

const Ui := preload("res://scripts/ui.gd")

const NAMES := ["Star", "Clover", "Maple", "Daisy", "Comet", "Honey"]
const GROWN := 10  # days of care until she is all grown up
const AT := Vector2(156.0, 646.0)  # where she lies in the straw, in front of the hay
const ROAM := [140.0, 470.0]  # how far along the stable she wanders once she can walk
const POSES := ["sleep", "lie", "stand", "walk_1", "walk_2", "eat", "buck"]
# what she wants: its name in the save, the picture for it, the word under it
const NEEDS := [["milk", "bottle", "Milk"], ["brush", "brush", "Brush"], ["love", "heart", "Cuddle"]]

var inn = null
var game = null
var sprite: Sprite2D = null
var art := {}
var pose := "lie"
var x := AT.x
var facing := 1
var goal_x := AT.x
var rest := 2.0  # seconds until she next thinks of wandering off
var stride := 0.0
var clock := 0.0
var shown := 0.0  # how many days of growing she is drawn with
var grew := 0.0  # counts down through the moment Adeline sees she has grown
var joy := 0.0  # counts down while she bucks for joy
var gulp := 0.0  # counts down while she is drinking
var last_spot := Vector2.ZERO
var on_her := false
var stroke := 0.0
var naming := false
var checked := 0.0


func kept() -> Dictionary:
	return game.data["foal"]


## Today as a plain number of days, by the tablet's own calendar.
func today() -> int:
	var date := Time.get_date_dict_from_system()
	return int(Time.get_unix_time_from_datetime_dict({ "year": date["year"], "month": date["month"], "day": date["day"], "hour": 12, "minute": 0, "second": 0 }) / 86400)


func stage_of(days: int) -> int:
	return 0 if days < 2 else (1 if days < 5 else (2 if days < 9 else 3))


func done_today() -> bool:
	var k := kept()
	return float(k["milk"]) >= 1.0 and float(k["brush"]) >= 1.0 and float(k["love"]) >= 1.0


func closed() -> void:
	if sprite != null and is_instance_valid(sprite):
		sprite.queue_free()
	sprite = null
	naming = false


## Is her milk (or, once she is big enough, something to eat) being held to her now?
func _being_fed() -> bool:
	if naming or inn.tool_node == null or not is_instance_valid(inn.tool_node):
		return false
	if not (inn.tool == "bottle" or (inn._tool_kind() == "food" and stage_of(int(shown)) >= 2)):
		return false
	return _box().grow(26.0).has_point(inn.tool_node.position)


## A new day: yesterday's milk, brushing and cuddles are forgotten.
func _new_day() -> void:
	var k := kept()
	if int(k["day"]) != today():
		k["day"] = today()
		for need in NEEDS:
			k[need[0]] = 0.0


## Called when Adeline walks into the stable.
func opened() -> void:
	closed()
	if inn.place != "stable":
		return
	if art.is_empty():
		for name in POSES:
			art[name] = load("res://art/foal/%s.png" % name)
	var k := kept()
	_new_day()
	shown = float(k["seen"])
	grew = 0.0
	joy = 0.0
	gulp = 0.0
	x = AT.x
	goal_x = x
	rest = 2.5
	facing = 1
	on_her = false
	sprite = Sprite2D.new()
	sprite.z_index = int(AT.y)
	inn.stage.add_child(sprite)
	_show(0.0)
	if str(k["name"]) == "":
		naming = true
		game.sound.play("foal", -4.0)
		game.sound.shout("adeline", "see_foal", 1.0, true)
	elif int(k["days"]) > int(k["seen"]) and today() > int(k["last"]):
		# She has grown in the night.
		grew = 2.6
		k["seen"] = int(k["days"])
		game._save()
		inn._say("Look how %s has grown!" % str(k["name"]))
		game.sound.play("chime", -5.0)
		game.sound.play("foal", -4.0)
		get_tree().create_timer(0.7).timeout.connect(func(): game.sound.shout("adeline", "grown", 1.0, true))


## How big she is drawn: small at first, nearly Spirit's size when she is grown.
func size() -> float:
	return 0.5 + 0.034 * minf(shown, float(GROWN))


func _box() -> Rect2:
	var tex: Texture2D = sprite.texture
	var wide := tex.get_width() * size()
	var tall := tex.get_height() * size()
	return Rect2(x - wide / 2.0, AT.y - tall, wide, tall)


## A tool from the tray is being held at this spot. True if it is the foal it is being
## used on, so that Spirit leaves it alone.
func use_tool(kind: String, tool: String, spot: Vector2) -> bool:
	if sprite == null or not is_instance_valid(sprite) or naming:
		return false
	var touching := _box().grow(26.0).has_point(spot)
	var moved := spot.distance_to(last_spot) if touching and on_her else 0.0
	on_her = touching
	last_spot = spot
	if not touching:
		return false
	var k := kept()
	var before := done_today()
	if kind == "brush" and moved > 0.0:
		if float(k["brush"]) < 1.0:
			k["brush"] = minf(float(k["brush"]) + moved / 900.0, 1.0)
		if int((stroke + moved) / 70.0) != int(stroke / 70.0):
			inn._sparkle(spot + Vector2(randf_range(-20.0, 20.0), randf_range(-20.0, 20.0)))
		if int((stroke + moved) / 130.0) != int(stroke / 130.0):
			game.sound.play("brush", -6.0, 0.12, 1.2)
		stroke += moved
	elif kind == "pet" and moved > 0.0:
		if float(k["love"]) < 1.0:
			k["love"] = minf(float(k["love"]) + moved / 800.0, 1.0)
		if int((stroke + moved) / 90.0) != int(stroke / 90.0):
			inn._float("heart", spot + Vector2(randf_range(-26.0, 26.0), -30.0), 0.2)
			game.sound.play("pop", -7.0, 0.15, 1.2, 0.12)
		stroke += moved
	if not before and done_today():
		_cared_for()
	return true


## All three done: that is today's care, and one more day of growing.
func _cared_for() -> void:
	var k := kept()
	k["days"] = int(k["days"]) + 1
	k["last"] = today()
	joy = 2.2
	var all_grown := int(k["days"]) == GROWN
	game.earn(5 if all_grown else 1)
	inn._say("%s is all grown up! Five stars for you." % str(k["name"]) if all_grown else "%s is happy! A star for you. She grows while she sleeps." % str(k["name"]))
	game.sound.play("foal", -3.0)
	game.sound.play("fanfare", -7.0, 0.0, 1.2)
	for i in 7:
		inn._float("heart", Vector2(x + randf_range(-110.0, 110.0), AT.y - randf_range(60.0, 240.0)), 0.28)
	get_tree().create_timer(1.6).timeout.connect(func(): game.sound.shout("adeline", "sleep_tight", 1.0, true))


func frame(delta: float) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	clock += delta
	checked += delta
	if checked > 2.0:
		checked = 0.0
		_new_day()  # the game was left open past midnight
	joy = maxf(joy - delta, 0.0)
	gulp = maxf(gulp - delta, 0.0)
	if _being_fed():
		# She drinks for as long as the bottle is held to her: about two seconds in all.
		var k := kept()
		gulp = 0.25
		if float(k["milk"]) < 1.0:
			var before := done_today()
			if fmod(clock, 0.55) < delta:
				game.sound.play("suckle", -5.0, 0.1)
			k["milk"] = minf(float(k["milk"]) + delta / 2.0, 1.0)
			if float(k["milk"]) >= 1.0:
				inn._float("heart", Vector2(x, AT.y - _box().size.y - 10.0), 0.3)
				game.sound.play("pop", -6.0, 0.0, 1.3)
				inn._drop_tool(false)
				if not before and done_today():
					_cared_for()
	if grew > 0.0:
		grew = maxf(grew - delta, 0.0)
		# She swells up to her new size over the first second and a half.
		var k := clampf((2.6 - grew) / 1.5, 0.0, 1.0)
		shown = lerpf(shown, float(kept()["seen"]), k * k)
		if fmod(clock, 0.16) < delta:
			inn._sparkle(Vector2(x + randf_range(-90.0, 90.0), AT.y - randf_range(20.0, 220.0)))
	else:
		shown = float(kept()["seen"])
	_show(delta)


## Chooses what she is doing and draws her that way.
func _show(delta: float) -> void:
	var stage := stage_of(int(kept()["seen"]))
	var asleep: bool = inn.sleep > 0 or (done_today() and joy <= 0.0 and stage < 2)
	var lean := 0.0
	var lift := 0.0
	if naming or grew > 0.0:
		pose = "lie" if stage == 0 else "stand"
	elif joy > 0.0:
		pose = "lie" if stage == 0 else "buck"
		lift = absf(sin(joy * 7.0)) * (8.0 if stage == 0 else 22.0)
		lean = sin(joy * 7.0) * 0.06
	elif gulp > 0.0:
		pose = "lie" if stage == 0 else "stand"
		lean = -0.05 + sin(clock * 18.0) * 0.012
	elif asleep:
		pose = "sleep"
	elif stage == 0:
		pose = "lie"
	elif stage == 1 or on_her:
		pose = "stand"
		lean = sin(clock * 3.1) * 0.022  # still unsteady on her legs
	else:
		# Old enough to wander: a few steps along the stable, a stop, a nibble of straw.
		rest -= delta
		if absf(goal_x - x) > 3.0:
			facing = 1 if goal_x > x else -1
			x += facing * minf(92.0 * delta, absf(goal_x - x))
			stride += delta
			pose = "walk_1" if fmod(stride, 0.44) < 0.22 else "walk_2"
			lift = absf(sin(stride / 0.22 * PI)) * 4.0
		else:
			pose = "eat" if (rest > 1.0 and rest < 3.4) else "stand"
			if rest <= 0.0:
				goal_x = randf_range(float(ROAM[0]), float(ROAM[1]))
				rest = randf_range(3.5, 7.0)
	var tex: Texture2D = art[pose]
	sprite.texture = tex
	sprite.flip_h = facing < 0
	var k := size()
	var breath := 1.0 + sin(clock * (1.4 if pose == "sleep" else 2.2)) * 0.014
	sprite.scale = Vector2(k, k * breath)
	sprite.offset = Vector2(0.0, -tex.get_height() / 2.0)
	sprite.position = Vector2(x, AT.y - lift)
	sprite.rotation = lean


# --- Her name ---------------------------------------------------------------------------

func _name_panel() -> Rect2:
	var s: Vector2 = inn.get_viewport_rect().size
	return Rect2(s.x / 2.0 - 330.0, s.y / 2.0 - 190.0, 660.0, 340.0)


func _name_rect(i: int) -> Rect2:
	var p := _name_panel()
	return Rect2(p.position.x + 30.0 + (i % 3) * 204.0, p.position.y + 150.0 + (i / 3) * 84.0, 192.0, 68.0)


func _input(event: InputEvent) -> void:
	if not naming or inn == null or inn.place != "stable" or game.menu != "":
		return
	if not (event is InputEventScreenTouch):
		return
	inn.get_viewport().set_input_as_handled()  # nothing else in the stable until she has a name
	if not event.pressed or clock < 0.6:
		return
	for i in NAMES.size():
		if _name_rect(i).has_point(event.position):
			kept()["name"] = NAMES[i]
			naming = false
			joy = 1.6
			game._save()
			inn._say("Hello, %s! She wants her milk, a brush and a cuddle." % NAMES[i])
			game.sound.play("chime", -5.0)
			game.sound.play("foal", -4.0)
			return


# --- What is drawn over the stable ------------------------------------------------------

func draw_ui(s: Vector2) -> void:
	if sprite == null or not is_instance_valid(sprite):
		return
	var on: Control = inn.overlay
	var k := kept()
	if naming:
		on.draw_rect(Rect2(Vector2.ZERO, s), Color(0.04, 0.05, 0.14, 0.45))
		var p := _name_panel()
		Ui.panel(on, p)
		inn._text(Vector2(p.position.x, p.position.y + 62.0), "Spirit has a foal!", 40, Color(1.0, 0.92, 0.5), HORIZONTAL_ALIGNMENT_CENTER, p.size.x)
		inn._text(Vector2(p.position.x, p.position.y + 110.0), "What will you call her?", 24, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, p.size.x)
		for i in NAMES.size():
			Ui.button(on, inn.font, _name_rect(i), NAMES[i], 26, [Color(0.82, 0.5, 0.14, 0.97), Color(0.26, 0.6, 0.36, 0.97), Color(0.62, 0.36, 0.8, 0.97)][i % 3])
		return
	# A little plate over her: her name, how far along she is, and what she still wants.
	var box := _box()
	var top: Vector2 = inn._to_screen(Vector2(x, box.position.y))
	var wide := 236.0
	var plate := Rect2(clampf(top.x - wide / 2.0, 12.0, s.x - wide - 12.0), maxf(top.y - 104.0, 190.0), wide, 90.0)
	Ui.plate(on, plate, Color(0.09, 0.11, 0.24, 0.78))
	var days := int(k["days"])
	var line := "%s   day %d of %d" % [str(k["name"]), mini(days + 1, GROWN), GROWN] if days < GROWN else "%s   all grown up" % str(k["name"])
	inn._text(Vector2(plate.position.x, plate.position.y + 26.0), line, 19, Color(1.0, 0.95, 0.75), HORIZONTAL_ALIGNMENT_CENTER, plate.size.x)
	if done_today():
		inn._text(Vector2(plate.position.x, plate.position.y + 54.0), "Cared for today", 18, Color(0.7, 1.0, 0.75), HORIZONTAL_ALIGNMENT_CENTER, plate.size.x)
		inn._text(Vector2(plate.position.x, plate.position.y + 78.0), "Come back tomorrow!" if days < GROWN else "She loves a visit.", 16, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER, plate.size.x)
	else:
		for i in NEEDS.size():
			var cx := plate.position.x + 42.0 + i * 76.0
			var share := clampf(float(k[NEEDS[i][0]]), 0.0, 1.0)
			inn._fit(inn._tex(str(NEEDS[i][1])), Rect2(cx - 16.0, plate.position.y + 34.0, 32.0, 32.0))
			inn._meter(Rect2(cx - 28.0, plate.position.y + 70.0, 56.0, 10.0), share, Color(0.45, 0.9, 0.5) if share >= 1.0 else Color(1.0, 0.8, 0.25))
	# Asleep: a few z's drifting up.
	if pose == "sleep":
		for i in 3:
			var t := fmod(clock * 0.5 + i * 0.33, 1.0)
			var at: Vector2 = inn._to_screen(Vector2(x + 84.0 * facing + t * 30.0, box.position.y + 34.0 - t * 60.0))
			inn._text(at, "z", int(16 + t * 14.0), Color(1.0, 1.0, 1.0, 1.0 - t))
