extends Node
## The kitchen, and the family in it.
##
## Somebody is usually cooking or eating here. It goes round on the clock: a while of
## cooking at the stove while the table is laid, a longer while of everyone sat down to
## the meal, then a short spell when the kitchen is empty. Each time round it is a
## different meal: breakfast, then lunch, then dinner. Grandma is always part of it; Mom
## and Dad join once they have been rescued; Adeline's sister sits down if she is in the
## house. When the meal is on the table Adeline can sit down too.
##
## The table is drawn so its top can be seen, and everything on it is a separate picture
## set down at a place: a plate, cutlery and a drink in front of each chair, serving
## dishes along the cloth down the middle, small things at the front.
##
## This is a child of the indoors scene and uses its room: the floor, the sizes, Adeline.

const Season := preload("res://scripts/season.gd")
const Ui := preload("res://scripts/ui.gd")

const ROUND := 200.0  # seconds for the whole round
const COOKING := 80.0  # the first part is cooking
const EATING := 170.0  # then eating until here; the rest is an empty kitchen
const TABLE_AT := 760.0  # where the table stands, across the room picture
const STOVE_AT := 160.0  # where the stove is in the picture
const POT_AT := Vector2(132.0, 350.0)  # the pot on it

# The table top, measured on its picture: how far down the far and near edges are (as a
# share of the picture's height) and how wide the top is at each (as a share of its width).
const TOP_FAR := 0.012
const TOP_NEAR := 0.474
const FAR_WIDE := 0.874
const NEAR_WIDE := 0.985

const KID := 1.12  # Adeline and her sister are drawn this much bigger in here, to match the grown-ups
const KID_SAT := 1.3  # and bigger again sat at the table, where only heads and shoulders show beside the family's
const GROWN := 2.3 / 2.2  # the family are single pictures, drawn at this size
const SEATS := [-285.0, -155.0, 5.0, 140.0, 268.0]  # chairs along the far side: Grandma, Mom, Dad, sister, Adeline
const SISTER_SEAT := 3
const ADELINE_SEAT := 4
const HIDDEN_SAT := ["leg_near_upper", "leg_near_lower", "leg_far_upper", "leg_far_lower", "cloak_back"]

const MEALS := ["breakfast", "lunch", "dinner"]
# What each meal puts on the table: the plate everyone gets, what is left of it at the end,
# and the serving dishes as [picture, how far across, how far toward the near edge, hot].
const MENU := {
	"breakfast": { "plate": "plate_pancakes", "done": "plate_done", "dishes": [
		["eggs", -218.0, 0.7, true], ["pancakes", -74.0, 0.74, true], ["toast", 70.0, 0.7, false],
		["berries", 196.0, 0.7, false], ["juice", 306.0, 0.72, false], ["jam", 136.0, 0.95, false]] },
	"lunch": { "plate": "bowl_soup", "done": "bowl_done", "dishes": [
		["loaf", -218.0, 0.72, false], ["tureen", -74.0, 0.76, true], ["salad", 70.0, 0.72, false],
		["cheese", 196.0, 0.7, false], ["fruit", 304.0, 0.74, false], ["jug", 136.0, 0.97, false]] },
	"dinner": { "plate": "plate_roast", "done": "plate_done", "dishes": [
		["mash", -218.0, 0.72, true], ["chicken", -70.0, 0.76, true], ["peas", 74.0, 0.7, true],
		["rolls", 196.0, 0.72, false], ["pie", 306.0, 0.72, false], ["gravy", 136.0, 0.95, false]] },
}
# At Christmas dinner is Christmas dinner, there is hot chocolate for the girls, and a
# candle burns in the middle of the table instead of the flowers.
const CHRISTMAS := { "plate": "plate_roast", "done": "plate_done", "dishes": [
	["mash", -218.0, 0.72, true], ["turkey", -70.0, 0.76, true], ["peas", 74.0, 0.7, true],
	["gingerbread", 196.0, 0.74, false], ["pudding", 306.0, 0.72, false], ["cookies", 136.0, 0.97, false]] }
const FLAT := ["plate", "plate_roast", "plate_pancakes", "plate_done", "bowl_soup", "bowl_done"]  # lie on the table rather than stand on it
const SERVE := 0.9  # serving dishes are drawn a little under their full size, so the plates show

var inn = null
var game = null
var table: Sprite2D = null
var shade: Polygon2D = null
var chairs: Array = []
var ware := {}  # everything on the table, by what it is: "plate2", "drink0", "dish3"...
var sizes := {}
var people: Array = []  # each: [sprite, seat number, where they stand to cook, a phase]
var steam: Node2D = null
var clock := 0.0
var munch := 0.0
var bubble := 0.0
var seated := false  # Adeline has sat down to eat
var told := ""
var laid := ""  # what the table was last set for, so it is only set again when that changes

var forced := ""  # set by tests, to look at one part of the round
var forced_meal := ""
var forced_progress := 0.3


func phase() -> String:
	if forced != "":
		return forced
	var t := fmod(Time.get_unix_time_from_system(), ROUND)
	return "cook" if t < COOKING else ("eat" if t < EATING else "away")


## How far through this part of the round it is, from 0 to 1.
func progress() -> float:
	if forced != "":
		return forced_progress
	var t := fmod(Time.get_unix_time_from_system(), ROUND)
	if t < COOKING:
		return t / COOKING
	return (t - COOKING) / (EATING - COOKING) if t < EATING else (t - EATING) / (ROUND - EATING)


func meal() -> String:
	if forced_meal != "":
		return forced_meal
	return MEALS[int(Time.get_unix_time_from_system() / ROUND) % MEALS.size()]


## What this meal puts on the table.
func menu() -> Dictionary:
	if Season.festive() and meal() == "dinner":
		return CHRISTMAS
	return MENU[meal()]


## What the meal is called: "breakfast", "lunch", "dinner", or at Christmas "Christmas dinner".
func meal_name() -> String:
	return "Christmas dinner" if (Season.festive() and meal() == "dinner") else meal().capitalize()


func closed() -> void:
	_stand_up()
	table = null
	shade = null
	steam = null
	chairs.clear()
	ware.clear()
	people.clear()
	seated = false
	laid = ""


## Puts back the legs and cloak hidden while sitting, and lets Adeline's sister go.
func _stand_up() -> void:
	if inn == null:
		return
	var rigs := [inn.adeline]
	if inn.playmate != null:
		inn.playmate.hold = false
		rigs.append(inn.playmate.rig)
	for rig in rigs:
		if rig != null and is_instance_valid(rig):
			for part in HIDDEN_SAT:
				rig.info[part]["sprite"].visible = true


## Called whenever Adeline walks into a room. Sets the kitchen out, or clears it away.
func entered_room() -> void:
	for node in [table, shade, steam] + chairs + ware.values():
		if node != null and is_instance_valid(node):
			node.queue_free()
	for person in people:
		if is_instance_valid(person[0]):
			person[0].queue_free()
	closed()
	if inn.room != "kitchen":
		return
	if sizes.is_empty():
		sizes = JSON.parse_string(FileAccess.get_file_as_string("res://art/room/kitchen/sizes.json"))
	told = ""
	var floor_y: float = inn._front() - 26.0
	table = Sprite2D.new()
	table.texture = Season.tex("res://art/room/kitchen/table.png")
	var k: float = float(sizes["table"]) / table.texture.get_width()
	table.scale = Vector2(k, k)
	table.offset = Vector2(0.0, -table.texture.get_height() / 2.0)
	table.position = Vector2(TABLE_AT, floor_y)
	table.z_index = int(floor_y)
	inn.stage.add_child(table)
	# The table's shadow on the floor, so it stands on the boards and does not float.
	shade = Polygon2D.new()
	var ring := PackedVector2Array()
	for i in 24:
		ring.append(Vector2(cos(i * TAU / 24.0) * float(sizes["table"]) * 0.52, sin(i * TAU / 24.0) * 26.0))
	shade.polygon = ring
	shade.color = Color(0.2, 0.08, 0.0, 0.3)
	shade.position = Vector2(TABLE_AT, floor_y - 20.0)
	shade.z_index = 1
	inn.stage.add_child(shade)
	for seat in SEATS:
		var chair := Sprite2D.new()
		chair.texture = Season.tex("res://art/room/kitchen/chair.png")
		var c: float = float(sizes["chair"]) / chair.texture.get_width() * _far_size()
		chair.scale = Vector2(c, c)
		# Only the back of the chair shows, over the far edge of the table.
		chair.region_enabled = true
		chair.region_rect = Rect2(0.0, 0.0, chair.texture.get_width(), chair.texture.get_height() * 0.5)
		chair.offset = Vector2(0.0, -chair.region_rect.size.y / 2.0)
		chair.position = Vector2(TABLE_AT + float(seat), _far_edge() + 6.0)
		chair.z_index = table.z_index - 6
		inn.stage.add_child(chair)
		chairs.append(chair)
	var family := [["res://art/props/crowd_4.png", 0]]
	if str(game.data.get("m2", "")) == "done":
		family.append(["res://art/props/mum.png", 1])
		family.append(["res://art/props/dad.png", 2])
	for i in family.size():
		var who := _put(str(family[i][0]), Vector2(TABLE_AT + float(SEATS[int(family[i][1])]), floor_y - 30.0), GROWN)
		people.append([who, int(family[i][1]), STOVE_AT + 40.0 + i * 150.0, randf() * TAU])
	steam = Node2D.new()
	steam.z_index = 3300
	steam.draw.connect(_draw_steam.bind(steam))
	inn.stage.add_child(steam)


## How tall the table stands in the room, top edge to feet.
func _tall() -> float:
	return table.texture.get_height() * table.scale.y


## Where the far edge of the table top is, in the room.
func _far_edge() -> float:
	return table.position.y - _tall() * (1.0 - TOP_FAR)


## How big someone sat on the far side looks: they are further off than the near edge.
func _far_size() -> float:
	return inn._depth(table.position.y - 84.0)


## A place on the table top: `across` in room pixels from the middle (measured along the
## far edge) and `near` from 0 at the far edge to 1 at the near one.
func _spot(across: float, near: float) -> Vector2:
	var spread := lerpf(1.0, NEAR_WIDE / FAR_WIDE, near)  # the top is wider toward us
	return Vector2(TABLE_AT + across * spread, table.position.y - _tall() * (1.0 - lerpf(TOP_FAR, TOP_NEAR, near)))


## A picture standing on the floor at `feet`, sized for how far back it is.
func _put(path: String, feet: Vector2, size: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = Season.tex(path)
	var k: float = size * inn._depth(feet.y)
	sprite.scale = Vector2(k, k)
	sprite.offset = Vector2(0.0, -sprite.texture.get_height() / 2.0)
	sprite.position = feet
	sprite.z_index = int(feet.y)
	inn.stage.add_child(sprite)
	return sprite


## Sits someone at the table or stands them up. Sat down, only the top of them is drawn:
## the rest is behind the table.
func _seat(who: Sprite2D, sat: bool) -> void:
	var size := who.texture.get_size()
	who.region_enabled = sat
	# Enough of them to show head, shoulders and arms, whoever they are.
	var tall := size.y * 0.36 + 44.0 if sat else size.y
	who.region_rect = Rect2(0.0, 0.0, size.x, tall)
	who.set_meta("tall", tall)


# --- What is on the table -----------------------------------------------------

## Who has a place laid: the seat numbers, in the order the places are laid.
func _places() -> Array:
	var out := []
	for person in people:
		out.append(int(person[1]))
	if inn.playmate.here:
		out.append(SISTER_SEAT)
	out.append(ADELINE_SEAT)
	return out


## Everything that should be on the table right now: what it is -> [picture, where, how
## far toward the near edge]. The flowers and the salt and pepper never leave it.
func _wanted() -> Dictionary:
	var now := phase()
	var p := progress()
	var out := { "vase": ["candle" if Season.festive() else "vase", -322.0, 0.62], "salt": ["salt", -128.0, 0.95] }
	if now == "away":
		return out
	var fare: Dictionary = menu()
	var places := _places()
	# While the cooking is going on the table is laid a place at a time, then the dishes
	# come out one by one. By the time everyone sits down it is all there.
	var set_out := places.size() if now == "eat" else int(clampf(p / 0.55, 0.0, 1.0) * places.size())
	var dishes: Array = fare["dishes"]
	var out_now := dishes.size() if now == "eat" else int(clampf((p - 0.6) / 0.4, 0.0, 1.0) * dishes.size())
	for i in set_out:
		var seat := int(places[i])
		var plate := "plate"
		if now == "eat":
			plate = str(fare["plate"] if p < 0.72 else fare["done"])
		elif str(fare["plate"]).begins_with("bowl"):
			plate = "bowl_done"  # soup bowls go out empty
		out["plate%d" % seat] = [plate, float(SEATS[seat]), 0.2]
		var drink := "milk" if seat >= SISTER_SEAT else "mug"
		if Season.festive() and seat >= SISTER_SEAT:
			drink = "cocoa"
		out["drink%d" % seat] = [drink, float(SEATS[seat]) + 57.0, 0.07]
	for i in out_now:
		out["dish%d" % i] = [str(dishes[i][0]), float(dishes[i][1]), float(dishes[i][2])]
	return out


## Sets the table to match `_wanted`: takes away what should not be there, puts down what
## is missing. New things land with a little bounce.
func _lay() -> void:
	var want := _wanted()
	for id in ware.keys():
		if not want.has(id) or str(want[id][0]) != str(ware[id].get_meta("picture")):
			ware[id].queue_free()
			ware.erase(id)
	for id in want:
		if ware.has(id):
			continue
		var picture := str(want[id][0])
		var near := float(want[id][2])
		var thing := Sprite2D.new()
		thing.texture = Season.tex("res://art/room/kitchen/%s.png" % picture)
		var flat := picture in FLAT
		var wide := float(sizes[picture]) * (SERVE if str(id).begins_with("dish") else 1.0)
		var k: float = wide / thing.texture.get_width() * lerpf(0.9, 1.0, near)
		# Plates lie with their middle on the spot; anything standing has its foot there.
		thing.offset = Vector2(0.0, 0.0 if flat else -thing.texture.get_height() * 0.38)
		thing.position = _spot(float(want[id][1]), near)
		thing.z_index = table.z_index + 1 + int(near * 20.0)
		thing.set_meta("picture", picture)
		thing.set_meta("size", k)
		thing.set_meta("born", clock)
		thing.scale = Vector2(k, k) if told == "" else Vector2.ZERO  # walking in, it is simply there
		if told == "":
			thing.set_meta("born", -9.0)
		elif not str(id).begins_with("drink"):
			game.sound.play("clatter" if flat else "thump", -22.0, 0.25, 1.5)
		inn.stage.add_child(thing)
		ware[id] = thing


func _sit_rect() -> Rect2:
	var s: Vector2 = inn.get_viewport_rect().size
	return Rect2(s.x - 236.0, 196.0, 212.0, 52.0)


## Where Adeline or her sister walks to before sitting down: just behind their chair.
func _behind(seat: int) -> Vector2:
	return Vector2(TABLE_AT + float(SEATS[seat]), table.position.y - 44.0)


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch) or not event.pressed or inn == null:
		return
	if inn.place != "house" or inn.stage == null or inn.room != "kitchen" or table == null:
		return
	if phase() == "eat" and _sit_rect().has_point(event.position):
		seated = not seated
		if seated:
			# Round the back of the table, to her own place at the end.
			inn.goal = _behind(ADELINE_SEAT)
			if Season.festive():
				game.sound.shout("adeline", "merry", 1.0)
			else:
				game.sound.shout("adeline", "woohoo", 0.4)
		else:
			inn.goal = Vector2(TABLE_AT + 420.0, table.position.y + 14.0)
		inn.get_viewport().set_input_as_handled()
	elif seated:
		seated = false  # a tap anywhere else and she gets up


func draw_ui(s: Vector2) -> void:
	if table == null:
		return
	var now := phase()
	var line := "Something smells good. %s is nearly ready." % meal_name()
	if now == "eat":
		line = "%s is on the table!" % meal_name()
	elif now == "away":
		line = "The kitchen is quiet. Somebody will be cooking again soon."
	var wide: float = inn.font.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 24).x + 56.0
	Ui.plate(inn.overlay, Rect2((s.x - wide) / 2.0, 126.0, wide, 44.0))
	inn._text(Vector2(0.0, 156.0), line, 24, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	if now == "eat":
		inn._button(_sit_rect(), "Get up" if seated else "Sit down and eat", 20, Color(0.75, 0.45, 0.2, 0.92))


## Steam: from the pot while it cooks, and from the hot dishes once they are out.
func _draw_steam(on: Node2D) -> void:
	var now := phase()
	if now == "away" or table == null:
		return
	var from: Array = []
	if now == "cook":
		from.append(POT_AT)
	var dishes: Array = menu()["dishes"]
	for i in dishes.size():
		if bool(dishes[i][3]) and ware.has("dish%d" % i):
			var dish: Sprite2D = ware["dish%d" % i]
			from.append(dish.position + Vector2(0.0, -dish.texture.get_height() * dish.scale.y * 0.8))
	for n in from.size():
		for i in 4:
			var k := fmod(clock * 0.45 + i / 4.0 + n * 0.37, 1.0)
			var at: Vector2 = from[n] + Vector2(sin(k * 6.0 + i + n) * 11.0 + i * 7.0 - 10.0, -70.0 * k)
			on.draw_circle(at, 6.0 + 10.0 * k, Color(1.0, 1.0, 1.0, 0.3 * (1.0 - k) * minf(k * 6.0, 1.0)))


## How far into a mouthful someone is, from 0 (sat back) to 1 (leaning in for a bite).
## Everyone has their own rhythm, so the table never moves all at once.
func _bite(offset: float) -> float:
	var t := fmod(clock * 0.42 + offset, 1.0)
	return smoothstep(0.0, 0.14, t) * (1.0 - smoothstep(0.26, 0.42, t))


func frame(delta: float) -> void:
	if table == null or not is_instance_valid(table):
		return
	clock += delta
	var now := phase()
	var setting := "%s %s %d %s %d" % [now, meal(), int(progress() * 40.0), str(inn.playmate.here), people.size()]
	if setting != laid:
		laid = setting
		_lay()
	if now != told:
		if told != "" and now == "eat":
			inn._say("%s is ready!" % meal_name())
			game.sound.play("chime", -6.0)
		told = now
	# Things just put down land with a small bounce.
	for id in ware:
		var thing: Sprite2D = ware[id]
		var age := (clock - float(thing.get_meta("born"))) / 0.32
		if age < 1.3:
			var k := float(thing.get_meta("size")) * Ui.pop(age)
			thing.scale = Vector2(k, k)
	steam.queue_redraw()
	var floor_y: float = table.position.y
	for i in people.size():
		var who: Sprite2D = people[i][0]
		var wobble: float = people[i][3]
		who.visible = now != "away"
		var want: Vector2
		var sat := now == "eat" or (now == "cook" and i > 0 and i < people.size() - 1 and people.size() > 2)
		if sat:
			# Sat at the table, on the far side of it.
			want = Vector2(TABLE_AT + float(SEATS[int(people[i][1])]), _far_edge() + 8.0)
		elif i == people.size() - 1 or people.size() == 1:
			# The cook, at the stove. With the whole family home that is the last one in.
			want = Vector2(STOVE_AT + 70.0, floor_y - 40.0)
		else:
			# Laying the table: to and fro between the counter and the table.
			want = Vector2(lerpf(float(people[i][2]) + 120.0, TABLE_AT - 430.0, 0.5 + 0.5 * sin(clock * 0.5 + wobble)), floor_y + 18.0)
		var to := want - who.position
		var there := to.length() <= 3.0
		# They sit once they have reached their place, and stand to walk anywhere.
		_seat(who, sat and absf(to.x) < 40.0)
		var tall := float(who.get_meta("tall"))
		who.rotation = 0.0
		if not there:
			who.position += to.normalized() * minf(170.0 * delta, to.length())
			who.flip_h = to.x < 0.0 and not who.region_enabled
			who.offset.y = -tall / 2.0 - absf(sin(clock * 9.0 + wobble)) * 5.0  # a walking bob
		elif now == "eat":
			# Eating: sat back and chatting, then leaning in over the plate for a mouthful.
			var bite := _bite(wobble / TAU)
			who.flip_h = false
			who.offset.y = -tall / 2.0 - (0.5 + 0.5 * sin(clock * 2.6 + wobble)) * 2.5 + bite * 9.0
			who.rotation = sin(clock * 1.3 + wobble) * 0.02 * (1.0 - bite) + bite * 0.05
		else:
			who.offset.y = -tall / 2.0 - (0.5 + 0.5 * sin(clock * 2.0 + wobble)) * 3.0
			who.rotation = sin(clock * 1.7 + wobble) * 0.02
		who.z_index = table.z_index - 3 if who.region_enabled else int(who.position.y)
		# Sat down they are the size of someone on the far side of the table.
		var k: float = GROWN * (_far_size() if who.region_enabled else inn._depth(who.position.y))
		who.scale = Vector2(k, k)
	if now == "eat":
		munch -= delta
		if munch <= 0.0:
			munch = randf_range(1.6, 3.2) if not seated else randf_range(0.9, 1.6)
			game.sound.play("munch", -15.0 if not seated else -9.0, 0.12)
	elif now == "cook":
		bubble -= delta
		if bubble <= 0.0:
			bubble = randf_range(0.5, 1.1)
			game.sound.play("pop", -19.0, 0.2, 0.7)  # the pot bubbling
	if seated and now != "eat":
		seated = false
		inn.goal = Vector2(TABLE_AT + 420.0, table.position.y + 14.0)  # the meal is over: she comes out from behind the table
	# Adeline at the table: once she is behind her chair she sits.
	_sit(inn.adeline, seated and inn.at.distance_to(inn.goal) < 6.0, 0.0)
	# Her sister comes to the table by herself when the meal is on it, unless they are in
	# the middle of a game.
	var mate = inn.playmate
	if mate.here and mate.rig != null and is_instance_valid(mate.rig):
		mate.hold = now == "eat" and mate.play == "" and mate.styling < 0
		if mate.hold:
			mate.goal = _behind(SISTER_SEAT)
		_sit(mate.rig, mate.hold and mate.at.distance_to(mate.goal) < 7.0, 0.5, 48.0)  # she is small: a cushion on her chair


## Sits one of the girls down in her chair, or stands her up again. Sat, her legs and cloak
## are out of sight behind the table, which comes to her waist, and she eats.
func _sit(rig, down: bool, rhythm: float, cushion := 0.0) -> void:
	for part in HIDDEN_SAT:
		rig.info[part]["sprite"].visible = not down
	if not down:
		return
	var size: float = 2.3 * KID_SAT
	var bite := _bite(rhythm)
	# The hand comes up to the mouth and goes back down to the plate.
	rig.pose["arm_upper"] = lerpf(-22.0, -58.0, bite)
	rig.pose["arm_lower"] = lerpf(-64.0, -128.0, bite)
	rig.pose["torso"] = 3.0 + bite * 5.0
	rig.root_offset = Vector2.ZERO
	rig.apply()
	rig.position.y = _far_edge() + 52.0 - cushion + 47.0 * size  # her hips are 47 above her feet
	rig.z_index = table.z_index - 2
	rig.scale = Vector2(-size, size)  # facing the family

