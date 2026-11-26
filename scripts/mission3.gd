extends Node2D
## Mission 3: the missing unicorn.
##
## A unicorn has fallen out of the sky and goblin trappers have her under a net at the east
## end of the island. Adeline's little sister is needed again: only the very young can see a
## unicorn's hoofprints, so the trail shows itself only when she is close by, and in the
## fight she bowls the trappers over on her pony.
##
## The steps, kept in the save file as "m3_step": 0 fetch her sister, 1 follow the trail
## (how many of the three sets of hoofprints have been found is "m3_clues"), 2 the trappers,
## 3 free the unicorn, 4 fly her home. The flight home is the sky ride (sky.gd).

const Season := preload("res://scripts/season.gd")
const RigScript := preload("res://scripts/rig.gd")
const HorseScript := preload("res://scripts/horse.gd")
const Moves := preload("res://scripts/moves.gd")

const CLUES := [2080.0, 3020.0, 3920.0]
const NET_X := 4610.0
const UNICORN_NAME := "Aurora"
const TRAPPERS := {
	"trigger": 4200.0, "left": 4040.0, "right": 5010.0, "title": "Chase off the goblin trappers",
	"goblins": [{ "x": 4440.0, "attacks": "swing" }, { "x": 4840.0, "attacks": "charge" }],
	"hint": "Your sister charges through on her pony. Hit the goblins while they are dizzy!",
}

var game = null
var unicorn = null  # the unicorn as she is found: a drawing of her, standing under the net
var net: Sprite2D = null
var net_gone := 0.0  # 0 the net is on her, 1 it is off
var seen := 0.0  # how clearly the next hoofprints show, from 0 to 1
var called := -1  # which hoofprints her sister has already shouted about
var clock := 0.0
var rear := 0.0  # seconds left of rearing up for joy


func _ready() -> void:
	unicorn = Node2D.new()
	unicorn.set_script(RigScript)
	unicorn.position = Vector2(NET_X, game.GROUND_Y)
	add_child(unicorn)
	unicorn.bends["body"] = { "strips": 12, "across": true, "at": Vector2(0.71, 0.45), "from": 0.63, "to": 0.82, "pose": "neck" }
	unicorn.build("res://art/unicorn")
	HorseScript.set_wings(unicorn, "res://art/unicorn", false)
	for part in ["leg_front_far_upper", "leg_front_far_lower", "leg_hind_far_upper", "leg_hind_far_lower"]:
		unicorn.tint(part, Color(0.8, 0.8, 0.88))
	unicorn.tint("wing_far", Color(0.8, 0.8, 0.9))
	unicorn.scale = Vector2(-1.0, 1.0)  # she looks back west, the way help will come from
	net = Sprite2D.new()
	net.texture = Season.tex("res://art/props/net.png")
	net.scale = Vector2(game.ART_SCALE, game.ART_SCALE) * 1.12
	net.offset = Vector2(0.0, -net.texture.get_height() / 2.0)
	net.position = Vector2(NET_X + 6.0, game.GROUND_Y + 8.0)
	net.z_index = 1
	add_child(net)


func step() -> int:
	return int(game.data["m3_step"])


func active() -> bool:
	return str(game.data["m3"]) == "active"


func clues() -> int:
	return int(game.data["m3_clues"])


func _set_step(n: int) -> void:
	game.data["m3_step"] = n
	game._save()
	game._update_limits()


## Whether her sister is on this mission with her, and so stays close.
func with_sister() -> bool:
	return active() and step() >= 1


# --- Called by the game ----------------------------------------------------------

func restore() -> void:
	net_gone = 1.0 if (active() and step() >= 4) else 0.0
	rear = 0.0
	seen = 0.0
	called = clues() - 1
	if with_sister():
		game.sister.put(float(game.player.position.x) - 130.0)
		game.sister.follow()
	_dress()


func _dress() -> void:
	unicorn.visible = active()
	net.visible = active() and net_gone < 1.0
	net.modulate.a = 1.0 - net_gone


## Her sister agrees to come. Called from the sister's menu.
func sister_joins() -> void:
	game.sister.follow()
	game.sound.shout("sister", "sister_coming", 1.0, true)
	_set_step(1)
	game.dialog.say("Little sister", ["A unicorn? A real one? I'm coming!"])


## What the action button does for this mission, given what it would otherwise do.
func context(now: String) -> String:
	if not active():
		return now
	var px: float = game.player.position.x
	if step() == 3 and absf(px - NET_X) < 170.0 and not game.player.mounted:
		return "free"
	if step() == 4 and absf(px - NET_X) < 170.0:
		return "unicorn"
	return now


func interact(action: String) -> void:
	if action == "free":
		_free()
	elif action == "unicorn":
		game._dismount()
		game.start_sky(1, true)


func on_fight_won() -> void:
	game.sister.follow()
	game.toast("The trappers have run for it! Now free the unicorn.")
	_set_step(3)


func objective() -> String:
	match step():
		0:
			return "Fetch your little sister"
		1:
			return "Follow the rainbow hoofprints: %d of 3" % clues()
		2:
			return "Find the unicorn"
		3:
			return "Free the unicorn"
		_:
			return "Fly %s home" % UNICORN_NAME


func hint() -> String:
	match step():
		0:
			return "She is riding her pony near home. Walk up to her and tap SISTER."
		1:
			if absf(game.sister.x - game.player.position.x) > 420.0:
				return "Wait for your sister! Only she can see the hoofprints."
			return "Head east past the signpost with your sister close behind. She will spot the hoofprints."
		2:
			return "The hoofprints stop just ahead. Keep going east."
		3:
			return "Walk up to the net and tap FREE."
		_:
			if game.context_action == "unicorn":
				return "Tap FLY. You and your sister will ride her up into the sky."
			return "%s is waiting. Walk up to her." % UNICORN_NAME


## The flight home is over: she comes to live in the stable.
func flight_done() -> void:
	game.data["m3"] = "done"
	game.data["m3_step"] = 5
	game.data["mount"] = "unicorn"
	game.data["checkpoint_x"] = game.START_X
	game._save()
	game.mode = "play"
	game._place_player()
	game.player.position.x = game.STABLE_X + 190.0
	game.player.facing = -1
	game.player.reset_physics_interpolation()
	game.sister.put(game.STABLE_X + 330.0)
	game.snap_camera()
	game.dialog.say("Little sister", ["She doesn't want to say goodbye. She wants to come and live with us!"], func():
		game.toast("%s lives in the stable now. Swap between her and Spirit any time." % UNICORN_NAME)
		game.sound.play("fanfare", -5.0, 0.0))


# --- The trail and the net -----------------------------------------------------------

func _free() -> void:
	net_gone = 0.01
	rear = 1.6
	game.sound.play("clatter", -6.0)
	game.sound.play("whinny", -4.0, 0.0, 1.3)
	game.sound.play("chime", -4.0)
	game.sound.shout("adeline", "free", 1.0, true)
	_burst(Vector2(NET_X, game.GROUND_Y - 90.0), 44)
	_set_step(4)
	get_tree().create_timer(1.5).timeout.connect(func():
		if game.mode == "play" and active() and not game.dialog.active:
			game.sound.shout("sister", "sister_unicorn", 1.0, true)
			game.dialog.say("Little sister", [
				"She says thank you! The goblins scared her and now she can't find her way home.",
				"Her home is up in the clouds. Can we take her? Please, please, please?",
			]))


func _burst(where: Vector2, amount: int) -> void:
	var burst := CPUParticles2D.new()
	burst.texture = game.spark
	burst.material = game.additive
	burst.position = where
	burst.one_shot = true
	burst.explosiveness = 0.9
	burst.amount = amount
	burst.lifetime = 0.9
	burst.spread = 180.0
	burst.initial_velocity_min = 60.0
	burst.initial_velocity_max = 260.0
	burst.gravity = Vector2(0.0, 120.0)
	burst.scale_amount_min = 0.25
	burst.scale_amount_max = 0.75
	burst.scale_amount_curve = game.shrink
	var colors := Gradient.new()
	colors.set_color(0, Color(1.0, 0.6, 0.8))
	colors.set_color(1, Color(0.5, 0.7, 1.0))
	colors.add_point(0.5, Color(1.0, 0.95, 0.5))
	burst.color_initial_ramp = colors
	burst.z_index = 3
	burst.emitting = true
	add_child(burst)
	get_tree().create_timer(1.6).timeout.connect(burst.queue_free)


func _physics_process(delta: float) -> void:
	clock += delta
	visible = game.mode == "play"
	if not visible:
		return
	_dress()
	if net_gone > 0.0 and net_gone < 1.0:
		net_gone = minf(net_gone + delta * 1.4, 1.0)
	rear = maxf(rear - delta, 0.0)
	if unicorn.visible:
		_pose_unicorn()
	if not active() or game.dialog.active:
		queue_redraw()
		return
	var p = game.player
	var sis = game.sister
	if step() == 1:
		# The next hoofprints fade into view as her sister comes near them.
		var at: float = CLUES[clues()]
		var near: bool = absf(sis.x - at) < 330.0
		seen = move_toward(seen, 1.0 if near else 0.0, delta * 1.6)
		if near and called < clues():
			called = clues()
			sis.hop = 0.8
			game.sound.shout("sister", "sister_prints", 1.0, true)
			game.toast("Your sister can see hoofprints! Go and look.")
		# They are found when Adeline walks up to them, or when her sister reaches them with
		# Adeline not far off.
		var beside: bool = absf(p.position.x - at) < 140.0 or (absf(sis.x - at) < 70.0 and absf(p.position.x - at) < 560.0)
		if seen > 0.6 and beside:
			game.data["m3_clues"] = clues() + 1
			game.sound.play("chime", -4.0, 0.0, 1.0 + 0.12 * clues())
			_burst(Vector2(at, game.GROUND_Y - 20.0), 26)
			seen = 0.0
			if clues() >= CLUES.size():
				game.toast("The trail ends here. Something is caught in a net!")
				_set_step(2)
			else:
				game.toast("Rainbow hoofprints! They lead east.")
				game._save()
	elif step() == 2 and game.encounter.is_empty() and p.position.x >= float(TRAPPERS["trigger"]):
		if p.mounted:
			game._dismount()
			game.toast("%s waits back here, safe from the goblins." % game.horse.title)
		game.horse.retreat(float(TRAPPERS["left"]) - 90.0)
		game._begin_encounter(TRAPPERS, "m3")
		sis.stay_at(float(TRAPPERS["left"]) + 46.0)
		game.mission2.charge_wait = 2.2
	if not game.encounter.is_empty() and game.encounter_kind == "m3":
		game.mission2.sister_fights(delta)
	queue_redraw()


## Under the net she is frightened: head low, shifting about. Free, she rears for joy and
## then stands tall and watches the sisters.
func _pose_unicorn() -> void:
	var pose: Dictionary = Moves.horse_ground(clock, 0.0, 0.0)
	var lift: float = pose["_lift"]
	pose.erase("_lift")
	var offset := Vector2(0.0, lift)
	var angle := 0.0
	if net_gone <= 0.0:
		pose["neck"] = 9.0 + sin(clock * 5.0) * 4.0
		pose["body"] = 2.0 + sin(clock * 2.3) * 1.5
		pose["tail"] = 2.0 + sin(clock * 7.0) * 5.0
		offset.x = sin(clock * 3.1) * 3.0
	elif rear > 0.0:
		var up := sin(clampf((1.6 - rear) / 1.6, 0.0, 1.0) * PI)
		angle = -0.5 * up
		pose["leg_front_near_upper"] = -70.0 * up
		pose["leg_front_near_lower"] = 80.0 * up + sin(clock * 14.0) * 14.0 * up
		pose["leg_front_far_upper"] = -55.0 * up
		pose["leg_front_far_lower"] = 70.0 * up - sin(clock * 14.0) * 14.0 * up
		pose["neck"] = -8.0 * up
		pose["tail"] = 20.0 * up
	pose["wing_near"] = -10.0
	pose["wing_far"] = -8.0
	# She turns to face whoever comes to her.
	var want := 1.0 if game.player.position.x > NET_X else -1.0
	if net_gone > 0.0 and signf(unicorn.scale.x) != want:
		unicorn.scale.x = want
	var joint: Vector2 = unicorn.rest_pos("body")
	var hind := Vector2(-46.0, 0.0)  # she rears about her hind hooves
	unicorn.root_angle = angle
	unicorn.root_offset = offset + (joint - hind).rotated(angle) - (joint - hind)
	unicorn.pose = pose
	unicorn.apply()


func _draw() -> void:
	if not active() or game.mode != "play":
		return
	var g: float = game.GROUND_Y
	# Hoofprints already found stay, faintly. The next ones glow as her sister nears them.
	for i in CLUES.size():
		var strength := 0.0
		if i < clues():
			strength = 0.45
		elif i == clues() and step() == 1:
			strength = seen
		if strength <= 0.0:
			continue
		var fresh := i == clues()
		for n in 4:
			var at := Vector2(float(CLUES[i]) - 84.0 + n * 56.0, g - 2.0 + (6.0 if n % 2 == 0 else -3.0))
			var color := Color.from_hsv(fposmod(0.08 + n * 0.19 + clock * 0.05, 1.0), 0.8, 1.0, strength)
			if fresh:
				# A soft glow standing up from each print, so they cannot be missed.
				var pulse := 0.6 + 0.4 * sin(clock * 3.0 + n)
				for ring in 4:
					draw_set_transform(at + Vector2(0.0, -8.0 - ring * 13.0), 0.0, Vector2(1.0, 0.5))
					draw_circle(Vector2.ZERO, 30.0 - ring * 5.0, Color(color.r, color.g, color.b, strength * pulse * (0.2 - ring * 0.04)))
			draw_set_transform(at, 0.0, Vector2(1.0, 0.5))
			draw_arc(Vector2.ZERO, 17.0, PI * 0.15, PI * 1.85, 16, Color(1.0, 1.0, 1.0, strength), 11.0)
			draw_arc(Vector2.ZERO, 17.0, PI * 0.15, PI * 1.85, 16, color, 7.0)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			if fresh:
				for spark in 2:
					var twinkle := 0.5 + 0.5 * sin(clock * 6.0 + n * 1.7 + spark * 2.4)
					var up := at + Vector2(-12.0 + spark * 24.0, -26.0 - 30.0 * twinkle - spark * 14.0)
					var r := 3.0 + 7.0 * twinkle
					draw_line(up - Vector2(r, 0.0), up + Vector2(r, 0.0), Color(1.0, 1.0, 0.85, strength * twinkle), 3.0)
					draw_line(up - Vector2(0.0, r), up + Vector2(0.0, r), Color(1.0, 1.0, 0.85, strength * twinkle), 3.0)
	# Her name over her head once she is free.
	if step() >= 4 and absf(game.player.position.x - NET_X) < 320.0:
		var font: Font = ThemeDB.fallback_font
		draw_string_outline(font, Vector2(NET_X - 60.0, g - 176.0), UNICORN_NAME, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 20, 5, Color(0.0, 0.0, 0.0, 0.5))
		draw_string(font, Vector2(NET_X - 60.0, g - 176.0), UNICORN_NAME, HORIZONTAL_ALIGNMENT_CENTER, 120.0, 20, Color.WHITE)
