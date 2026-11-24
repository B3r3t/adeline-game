extends Node
## Adeline's little sister, indoors.
##
## She comes into the house with Adeline when she is close by (or following), and can be
## called in from inside. She trails after Adeline from room to room, lies down when
## Adeline goes to sleep, and there are two things to do together: keep a balloon off the
## floor, and do her hair (four styles and six ribbon colours).
##
## This is a child of the indoors scene and leans on it for the room: where the floor is,
## how big things look at each depth, and where Adeline is standing.

const RigScript := preload("res://scripts/rig.gd")
const Moves := preload("res://scripts/moves.gd")
const SisterScript := preload("res://scripts/sister.gd")

const STYLE_LABELS := ["Ponytail", "Braid", "Bun", "Pigtails"]
const BALLOON_SIZE := 46.0

var inn = null  # the indoors scene
var game = null
var here := false  # is she in the house
var rig = null
var look: ShaderMaterial = null
var at := Vector2.ZERO
var goal := Vector2.ZERO
var facing := 1
var walk := 0.0
var hop := 0.0
var idle := 0.0  # seconds until she next does something of her own
var clock := 0.0

var play := ""  # "", "balloon", "over" (the balloon has landed) or "hair"
var balloon: Node2D = null
var b_at := Vector2.ZERO
var b_speed := Vector2.ZERO
var bops := 0
var bop_wait := 0.0
var over_time := 0.0
var styling := -1  # the hairstyle being done right now, or -1
var style_time := 0.0
var strokes := 0


# --- Called by the indoors scene -----------------------------------------------

## Adeline has just come into the house. Her sister comes too if she was close behind.
func opened() -> void:
	var s = game.sister
	here = s.activity == "" and (s.mode == "follow" or absf(s.x - float(game.player.position.x)) < 380.0)
	play = ""
	styling = -1
	rig = null
	balloon = null


func closed() -> void:
	if here:
		game.sister.put(game.DOOR_X + 80.0)  # she comes back out with Adeline
	here = false
	rig = null
	balloon = null
	play = ""
	styling = -1


## Adeline has walked into a room. Her sister comes in just behind her.
func entered_room() -> void:
	_stop_balloon()
	play = ""
	styling = -1
	if not here or inn.room == "bathroom":
		if rig != null:
			rig.visible = false
		return
	_make()
	rig.visible = true
	at = _on_floor(inn.at + Vector2(-inn.facing * 95.0, 8.0))
	goal = at
	facing = inn.facing
	idle = 4.0


func _make() -> void:
	if rig != null and is_instance_valid(rig):
		return
	rig = Node2D.new()
	rig.set_script(RigScript)
	inn.stage.add_child(rig)
	rig.build("res://art/sister")
	var shader := Shader.new()
	shader.code = SisterScript.RIBBON_SHADER
	look = ShaderMaterial.new()
	look.shader = shader
	rig.info["ponytail"]["sprite"].material = look
	_dress()


## Gives her the hairstyle and ribbon that are saved.
func _dress() -> void:
	if rig == null:
		return
	SisterScript.wear_hair(rig, int(game.data.get("hair", 0)))
	look.set_shader_parameter("shift", float(SisterScript.RIBBONS[int(game.data.get("ribbon", 0))][1]))


func _on_floor(spot: Vector2) -> Vector2:
	var seen: Rect2 = inn._seen()
	return Vector2(clampf(spot.x, seen.position.x + 70.0, seen.end.x - 70.0), clampf(spot.y, inn.BACK + 24.0, inn._front() - 6.0))


func _active() -> bool:
	return inn.place == "house" and inn.stage != null and inn.room != "bathroom" and inn.sleep == 0


# --- Buttons -------------------------------------------------------------------

func _button(i: int) -> Rect2:
	return Rect2(24.0, 196.0 + i * 64.0, 212.0, 52.0)


func _card(i: int) -> Rect2:
	var s: Vector2 = inn.get_viewport_rect().size
	return Rect2((s.x - 4 * 166.0) / 2.0 + i * 166.0 + 4.0, 190.0, 158.0, 62.0)


func _ribbon(i: int) -> Vector2:
	var s: Vector2 = inn.get_viewport_rect().size
	return Vector2(s.x / 2.0 - 150.0 + i * 60.0, 296.0)


func _done() -> Rect2:
	var s: Vector2 = inn.get_viewport_rect().size
	return Rect2(s.x / 2.0 - 90.0, 336.0, 180.0, 48.0)


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch) or not event.pressed or inn == null or not _active():
		return
	var pos: Vector2 = event.position
	if game.menu_rect().has_point(pos) or inn._back_rect().has_point(pos):
		return
	var taken := true
	if play == "balloon":
		var spot: Vector2 = inn._to_room(pos)
		if spot.distance_to(b_at) < 125.0:
			_bop(Vector2(clampf((b_at.x - spot.x) * 3.2, -260.0, 260.0), -480.0))
			inn.goal = Vector2(_on_floor(b_at).x, inn._front() - 14.0)  # Adeline runs under it
	elif play == "over":
		pass
	elif play == "hair":
		if styling >= 0:
			pass  # wait for the brushing to finish
		elif _done().has_point(pos):
			play = ""
		else:
			for i in STYLE_LABELS.size():
				if _card(i).has_point(pos):
					_style(i)
			for i in SisterScript.RIBBONS.size():
				if _ribbon(i).distance_to(pos) < 28.0:
					game.data["ribbon"] = i
					game._save()
					game.sister.set_ribbon(i)
					_dress()
					game.sound.play("pop", -5.0, 0.0, 1.2)
	elif not here and _button(0).has_point(pos):
		here = true
		entered_room()
		# She comes in through the door, on the far side from where Adeline stands.
		at = _on_floor(Vector2(inn._seen().end.x if inn.room == "living" else inn._seen().position.x, inn._front() - 10.0))
		goal = _on_floor(inn.at + Vector2(-inn.facing * 95.0, 8.0))
		hop = 0.7
		game.sound.shout("sister", "sister_coming", 1.0, true)
	elif here and _button(0).has_point(pos):
		_start_balloon()
	elif here and _button(1).has_point(pos):
		play = "hair"
		inn.selected = -1
		goal = _on_floor(Vector2(inn._seen().get_center().x + 40.0, inn._front() - 40.0))
	elif here and _button(2).has_point(pos):
		here = false
		rig.visible = false
		game.sound.shout("sister", "sister_whee", 1.0, true)
	else:
		taken = false
	if taken:
		inn.get_viewport().set_input_as_handled()


func draw_ui(s: Vector2) -> void:
	if not _active():
		return
	var green := Color(0.75, 0.4, 0.6, 0.92)
	if play == "balloon" or play == "over":
		inn._text(Vector2(0.0, 150.0), "Bops: %d     Best: %d" % [bops, int(inn.home.get("balloon", 0))], 30, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)
		if play == "balloon" and bops == 0:
			inn._text(Vector2(0.0, 196.0), "Tap the balloon to keep it off the floor!", 24, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)
		return
	if play == "hair":
		inn._text(Vector2(0.0, 172.0), "Pick a hairstyle and a ribbon", 24, Color(1.0, 0.97, 0.8), HORIZONTAL_ALIGNMENT_CENTER, s.x)
		for i in STYLE_LABELS.size():
			var chosen := i == int(game.data.get("hair", 0))
			inn._button(_card(i), STYLE_LABELS[i], 22, Color(0.85, 0.45, 0.65, 0.95) if chosen else Color(0.4, 0.3, 0.5, 0.9))
		for i in SisterScript.RIBBONS.size():
			var c := _ribbon(i)
			var hue := fposmod(0.14 + float(SisterScript.RIBBONS[i][1]), 1.0)
			inn.overlay.draw_circle(c, 22.0, Color.from_hsv(hue, 0.8, 0.95))
			var mine := i == int(game.data.get("ribbon", 0))
			inn.overlay.draw_arc(c, 22.0, 0.0, TAU, 28, Color.WHITE if mine else Color(0.0, 0.0, 0.0, 0.6), 4.0 if mine else 2.0)
		inn._button(_done(), "Done", 22, Color(0.3, 0.6, 0.35, 0.92))
		if styling >= 0 and rig != null:
			# Sparkles round her head while her hair is brushed.
			var head: Vector2 = inn._to_screen(at + Vector2(-facing * 20.0, -150.0 * inn._depth(at.y)))
			for i in 7:
				var a := clock * 3.2 + i * TAU / 7.0
				var p := head + Vector2(cos(a) * 60.0, sin(a * 1.3) * 42.0)
				var r := 7.0 + 4.0 * sin(clock * 9.0 + i)
				inn.overlay.draw_line(p - Vector2(r, 0.0), p + Vector2(r, 0.0), Color(1.0, 0.95, 0.6), 3.0)
				inn.overlay.draw_line(p - Vector2(0.0, r), p + Vector2(0.0, r), Color(1.0, 0.95, 0.6), 3.0)
		return
	if not here:
		inn._button(_button(0), "Call your sister in", 20, green)
	else:
		inn._button(_button(0), "Balloon game", 20, green)
		inn._button(_button(1), "Do her hair", 20, green)
		inn._button(_button(2), "Off you go and play", 18, Color(0.35, 0.35, 0.45, 0.9))


# --- Doing her hair --------------------------------------------------------------

func _style(which: int) -> void:
	styling = which
	style_time = 1.7
	strokes = 0
	# Adeline steps in behind her, where the hair is.
	inn.goal = _on_floor(at + Vector2(-facing * 88.0, -12.0))  # a little behind, so the hair can be seen


func _finish_style() -> void:
	game.data["hair"] = styling
	game._save()
	game.sister.set_hair(styling)
	_dress()
	styling = -1
	hop = 0.8
	game.sound.play("chime", -5.0)
	game.sound.shout("sister", "sister_pretty", 1.0, true)


# --- The balloon -----------------------------------------------------------------

func _start_balloon() -> void:
	play = "balloon"
	bops = 0
	bop_wait = 0.6
	inn.selected = -1
	var seen: Rect2 = inn._seen()
	b_at = Vector2(seen.get_center().x, 250.0)
	b_speed = Vector2(randf_range(-70.0, 70.0), -60.0)
	balloon = Node2D.new()
	balloon.z_index = 3400
	balloon.draw.connect(_draw_balloon.bind(balloon))
	inn.stage.add_child(balloon)
	game.sound.shout("sister", "sister_balloon", 1.0, true)


func _stop_balloon() -> void:
	if balloon != null and is_instance_valid(balloon):
		balloon.queue_free()
	balloon = null


func _bop(push: Vector2) -> void:
	b_speed = Vector2(b_speed.x * 0.3 + push.x, push.y)
	bops += 1
	game.sound.play("pop", -4.0, 0.12, 0.9 + minf(bops, 20) * 0.02)


func _draw_balloon(on: Node2D) -> void:
	var tilt := clampf(b_speed.x / 500.0, -0.4, 0.4)
	on.draw_set_transform(Vector2.ZERO, tilt, Vector2(1.0, 1.18))
	on.draw_circle(Vector2.ZERO, BALLOON_SIZE, Color(0.95, 0.25, 0.35))
	on.draw_arc(Vector2.ZERO, BALLOON_SIZE, 0.0, TAU, 40, Color(0.25, 0.05, 0.1), 4.0)
	on.draw_circle(Vector2(-15.0, -17.0), 11.0, Color(1.0, 0.75, 0.8, 0.9))
	on.draw_set_transform(Vector2.ZERO, tilt, Vector2.ONE)
	on.draw_colored_polygon(PackedVector2Array([Vector2(-8.0, 53.0), Vector2(8.0, 53.0), Vector2(0.0, 64.0)]), Color(0.8, 0.15, 0.25))
	var string := PackedVector2Array()
	for i in 9:
		string.append(Vector2(sin(clock * 3.0 + i * 0.8) * 5.0 - b_speed.x * 0.004 * i * i, 64.0 + i * 11.0))
	on.draw_polyline(string, Color(1.0, 1.0, 1.0, 0.85), 2.0)


func _balloon_frame(delta: float) -> void:
	var seen: Rect2 = inn._seen()
	var floor_y: float = inn._front() - 16.0
	b_speed.y += 330.0 * delta
	b_speed *= 1.0 - 0.7 * delta
	b_at += b_speed * delta
	if b_at.x < seen.position.x + 60.0 or b_at.x > seen.end.x - 60.0:
		b_at.x = clampf(b_at.x, seen.position.x + 60.0, seen.end.x - 60.0)
		b_speed.x = -b_speed.x * 0.7
	if b_at.y < 110.0:
		b_at.y = 110.0
		b_speed.y = absf(b_speed.y) * 0.5
	balloon.position = b_at
	balloon.queue_redraw()
	if play == "over":
		b_at.y = minf(b_at.y, floor_y - BALLOON_SIZE)
		over_time -= delta
		if over_time <= 0.0:
			_stop_balloon()
			play = ""
		return
	# Her sister runs to get under it, and bops it when it comes down to her. Now and then
	# she misses.
	goal = _on_floor(Vector2(b_at.x + b_speed.x * 0.35, inn._front() - 30.0))
	bop_wait -= delta
	var reach: float = 170.0 * inn._depth(at.y)
	if bop_wait <= 0.0 and b_speed.y > 0.0 and absf(b_at.x - at.x) < 62.0 and b_at.y > at.y - reach - 150.0 and b_at.y < at.y - reach + 40.0:
		if randf() < 0.8:
			_bop(Vector2(randf_range(-170.0, 170.0), -450.0))
			hop = 0.5
			bop_wait = 0.7
		else:
			bop_wait = 0.45
	if b_at.y >= floor_y - BALLOON_SIZE:
		play = "over"
		over_time = 2.8
		b_speed = Vector2.ZERO
		if bops > int(inn.home.get("balloon", 0)):
			inn.home["balloon"] = bops
			inn._save()
		inn._say("%d bops!" % bops)
		game.sound.play("thump", -8.0)
		game.sound.shout("sister", "sister_again", 1.0, true)
		hop = 0.9


# --- Every frame -----------------------------------------------------------------

func frame(delta: float) -> void:
	if not here or rig == null or not is_instance_valid(rig) or inn.room == "bathroom":
		return
	clock += delta
	hop = maxf(hop - delta, 0.0)
	if (play == "balloon" or play == "over") and balloon != null:
		_balloon_frame(delta)
	if styling >= 0:
		style_time -= delta
		var done := int((1.7 - style_time) / 0.5)
		if done > strokes and done <= 3:
			strokes = done
			game.sound.play("brush", -5.0, 0.1)
		if style_time <= 0.0:
			_finish_style()
	elif play == "":
		# Left to herself she keeps near Adeline, and now and then waves or wanders.
		if at.distance_to(inn.at) > 200.0:
			goal = _on_floor(inn.at + Vector2(-inn.facing * 95.0, 8.0))
		idle -= delta
		if idle <= 0.0:
			idle = randf_range(6.0, 11.0)
			if randf() < 0.5:
				hop = 0.7
			else:
				goal = _on_floor(inn.at + Vector2(randf_range(-190.0, 190.0), randf_range(-30.0, 20.0)))

	var size: float = 2.3 * inn._depth(at.y)
	rig.root_angle = 0.0
	if inn.sleep == 2:
		# Adeline is asleep, so she curls up on the floor beside the bed.
		rig.pose = { "arm_upper": 12.0, "arm_lower": 6.0, "torso": sin(clock * 1.5) * 1.4, "cloak_back": 0.0 }
		rig.root_angle = -PI / 2.0
		rig.root_offset = -rig.rest_pos("torso")
		rig.apply(delta)
		rig.position = at + Vector2(0.0, -16.0 * size)
		rig.scale = Vector2(size * facing, size)
		rig.z_index = int(at.y)
		return
	var pose: Dictionary = Moves.girl_idle(clock)
	var to := goal - at
	if to.length() > 6.0:
		var pace := 330.0 if play == "balloon" else 240.0
		at += to.normalized() * minf(pace * delta, to.length())
		if absf(to.x) > 3.0:
			facing = 1 if to.x > 0.0 else -1
		walk += pace * delta * 0.034
		pose = Moves.girl_run(walk, 0.55 if play == "balloon" else 0.35)
	elif play == "" and styling < 0:
		facing = 1 if inn.at.x >= at.x else -1  # she watches her big sister
	var lift := float(pose["_lift"])
	pose.erase("_lift")
	if hop > 0.0:
		pose["arm_upper"] = -112.0 + sin(clock * 16.0) * 10.0  # an arm up: a wave, or a bop
		pose["arm_lower"] = -22.0 + sin(clock * 16.0 + 1.0) * 12.0
		lift -= absf(sin(hop * 10.5)) * 9.0
	rig.pose = pose
	rig.root_offset = Vector2(0.0, lift)
	rig.apply(delta)
	rig.position = at
	rig.scale = Vector2(size * facing, size)
	rig.z_index = int(at.y)
