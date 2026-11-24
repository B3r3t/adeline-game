extends Node
## The kitchen, and the family in it.
##
## Somebody is usually cooking or eating here. It goes round on the clock: a while of
## cooking at the stove, a longer while of everyone sat at the table with dinner on it,
## then a short spell when the kitchen is empty. Grandma is always part of it; Mom and Dad
## join once they have been rescued. When dinner is on the table Adeline can sit down too.
##
## This is a child of the indoors scene and uses its room: the floor, the sizes, Adeline.

const ROUND := 200.0  # seconds for the whole round
const COOKING := 80.0  # the first part is cooking
const EATING := 170.0  # then eating until here; the rest is an empty kitchen
const TABLE_AT := 760.0  # where the table stands, across the room picture
const TABLE_SIZE := 1.3
const STOVE_AT := 160.0  # where the stove is in the picture
const POT_AT := Vector2(132.0, 350.0)  # the pot on it

var inn = null
var game = null
var table: Sprite2D = null
var food: Sprite2D = null
var people: Array = []  # each: [sprite, seat across the table, where they stand to cook, a phase]
var steam: Node2D = null
var clock := 0.0
var munch := 0.0
var bubble := 0.0
var seated := false  # Adeline has sat down to eat
var told := ""


var forced := ""  # set by tests, to look at one part of the round


func phase() -> String:
	if forced != "":
		return forced
	var t := fmod(Time.get_unix_time_from_system(), ROUND)
	return "cook" if t < COOKING else ("eat" if t < EATING else "away")


func closed() -> void:
	if inn != null and inn.adeline != null and is_instance_valid(inn.adeline):
		for part in ["leg_near_upper", "leg_near_lower", "leg_far_upper", "leg_far_lower", "cloak_back"]:
			inn.adeline.info[part]["sprite"].visible = true
	table = null
	food = null
	steam = null
	people.clear()
	seated = false


## Called whenever Adeline walks into a room. Sets the kitchen out, or clears it away.
func entered_room() -> void:
	for node in [table, food, steam]:
		if node != null and is_instance_valid(node):
			node.queue_free()
	for person in people:
		if is_instance_valid(person[0]):
			person[0].queue_free()
	closed()
	if inn.room != "kitchen":
		return
	told = ""
	var floor_y: float = inn._front() - 26.0
	table = _put("res://art/room/table.png", Vector2(TABLE_AT, floor_y), TABLE_SIZE)
	food = _put("res://art/room/food.png", Vector2(TABLE_AT - 40.0, _table_top() + 20.0), TABLE_SIZE)
	food.z_index = table.z_index + 1
	var family := [["res://art/props/crowd_4.png", -210.0]]
	if str(game.data.get("m2", "")) == "done":
		family.append(["res://art/props/mum.png", -20.0])
		family.append(["res://art/props/dad.png", 160.0])
	for i in family.size():
		var who := _put(str(family[i][0]), Vector2(TABLE_AT + float(family[i][1]), floor_y - 30.0), 2.3 / 2.2)
		people.append([who, TABLE_AT + float(family[i][1]), STOVE_AT + 40.0 + i * 150.0, randf() * TAU])
	steam = Node2D.new()
	steam.z_index = 3300
	steam.draw.connect(_draw_steam.bind(steam))
	inn.stage.add_child(steam)


## How high the table top is, in the room.
func _table_top() -> float:
	return table.position.y - table.texture.get_height() * table.scale.y


## Sits someone at the table or stands them up. Sat down, only the top of them is drawn,
## as if the rest were under the table, since the table is open underneath.
func _seat(who: Sprite2D, sat: bool) -> void:
	var size := who.texture.get_size()
	who.region_enabled = sat
	var tall := size.y * (0.56 if sat else 1.0)
	who.region_rect = Rect2(0.0, 0.0, size.x, tall)
	who.set_meta("tall", tall)


## A picture standing on the floor at `feet`, sized for how far back it is.
func _put(path: String, feet: Vector2, size: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = load(path)
	var k: float = size * inn._depth(feet.y)
	sprite.scale = Vector2(k, k)
	sprite.offset = Vector2(0.0, -sprite.texture.get_height() / 2.0)
	sprite.position = feet
	sprite.z_index = int(feet.y)
	inn.stage.add_child(sprite)
	return sprite


func _sit_rect() -> Rect2:
	var s: Vector2 = inn.get_viewport_rect().size
	return Rect2(s.x - 236.0, 196.0, 212.0, 52.0)


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch) or not event.pressed or inn == null:
		return
	if inn.place != "house" or inn.stage == null or inn.room != "kitchen" or table == null:
		return
	if phase() == "eat" and _sit_rect().has_point(event.position):
		seated = not seated
		if seated:
			# Round the back of the table, to the empty place at the end.
			inn.goal = Vector2(TABLE_AT + 300.0, table.position.y - 22.0)
			game.sound.shout("adeline", "woohoo", 0.4)
		else:
			inn.goal = Vector2(TABLE_AT + 300.0, table.position.y + 30.0)
		inn.get_viewport().set_input_as_handled()
	elif seated:
		seated = false  # a tap anywhere else and she gets up


func draw_ui(s: Vector2) -> void:
	if table == null:
		return
	var now := phase()
	var line := "Something smells good. Dinner is nearly ready." if now == "cook" else ("Dinner is on the table!" if now == "eat" else "The kitchen is quiet. Somebody will be cooking again soon.")
	inn._text(Vector2(0.0, 216.0), line, 24, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)
	if now == "eat":
		inn._button(_sit_rect(), "Get up" if seated else "Sit down and eat", 20, Color(0.75, 0.45, 0.2, 0.92))


func _draw_steam(on: Node2D) -> void:
	var now := phase()
	if now == "away" or table == null:
		return
	# Steam from the pot while it cooks, and from the dishes once they are on the table.
	var from := POT_AT if now == "cook" else Vector2(TABLE_AT - 90.0, food.position.y - food.texture.get_height() * food.scale.y)
	for i in 5:
		var k := fmod(clock * 0.5 + i / 5.0, 1.0)
		var at := from + Vector2(sin(k * 6.0 + i) * 14.0 + i * 9.0 - 18.0, -90.0 * k)
		on.draw_circle(at, 9.0 + 12.0 * k, Color(1.0, 1.0, 1.0, 0.35 * (1.0 - k)))


func frame(delta: float) -> void:
	if table == null or not is_instance_valid(table):
		return
	clock += delta
	var now := phase()
	if now != told:
		if told != "" and now == "eat":
			inn._say("Dinner is ready!")
			game.sound.play("chime", -6.0)
		told = now
	food.visible = now == "eat"
	steam.queue_redraw()
	var floor_y: float = table.position.y
	for i in people.size():
		var who: Sprite2D = people[i][0]
		var wobble: float = people[i][3]
		who.visible = now != "away"
		var want: Vector2
		var sat := now == "eat" or (now == "cook" and i > 0 and i < people.size() - 1 and people.size() > 2)
		if sat:
			# Sat at the table, behind it.
			want = Vector2(float(people[i][1]), _table_top() + 14.0)
		elif i == people.size() - 1 or people.size() == 1:
			# The cook, at the stove. With the whole family home that is the last one in.
			want = Vector2(STOVE_AT + 70.0, floor_y - 40.0)
		else:
			# Laying the table: to and fro between the counter and the table.
			want = Vector2(lerpf(float(people[i][2]) + 120.0, TABLE_AT - 250.0, 0.5 + 0.5 * sin(clock * 0.5 + wobble)), floor_y + 18.0)
		var to := want - who.position
		var there := to.length() <= 3.0
		# They sit once they have reached their place, and stand to walk anywhere.
		_seat(who, sat and absf(to.x) < 40.0)
		var tall := float(who.get_meta("tall"))
		if not there:
			who.position += to.normalized() * minf(170.0 * delta, to.length())
			who.flip_h = to.x < 0.0 and not who.region_enabled
			who.offset.y = -tall / 2.0 - absf(sin(clock * 9.0 + wobble)) * 5.0  # a walking bob
		else:
			var lively := 3.0 if now == "eat" else 2.0
			who.offset.y = -tall / 2.0 - (0.5 + 0.5 * sin(clock * lively + wobble)) * 3.0
			who.rotation = sin(clock * 1.7 + wobble) * 0.02
		who.z_index = table.z_index - 2 if who.region_enabled else int(who.position.y)
		# Sat down they are the size of someone at the table, not of someone far up the wall.
		var k: float = (2.3 / 2.2) * inn._depth(floor_y - 30.0 if who.region_enabled else who.position.y)
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
	# Adeline at the table: once she is round the back of it she sits, which means her legs
	# and cloak are tucked out of sight and she is set down so the table comes to her waist.
	var down: bool = seated and inn.at.distance_to(inn.goal) < 6.0
	for part in ["leg_near_upper", "leg_near_lower", "leg_far_upper", "leg_far_lower", "cloak_back"]:
		inn.adeline.info[part]["sprite"].visible = not down
	if down:
		var size: float = absf(inn.adeline.scale.y)
		inn.adeline.position.y = _table_top() + 16.0 + 47.0 * size  # her hips are 47 above her feet
		inn.adeline.z_index = table.z_index - 1
		inn.adeline.scale.x = -size  # facing the family
