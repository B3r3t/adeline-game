extends Node2D
## Mission 2: rescue Mom and Dad from the ogre's fort.
##
## Adeline cannot do it alone, and that is the point of the mission. Her little sister is
## needed three times: she charges through the goblin guards on her pony and knocks them
## dizzy, she waits on one gate stone while Adeline runs to the other, and she gallops past
## the ogre so he turns to watch her, which is the only time he can be hurt.
##
## The island is the stretch of ground past the river. The steps, kept in the save file
## as "m2_step": 0 fetch her sister, 1 take the boat, 2 the guards, 3 the gate, 4 the ogre,
## 5 open the cage.

const Season := preload("res://scripts/season.gd")
const LEFT := 5900.0  # the island's shore
const RIGHT := 7650.0
const LAND_X := 5990.0
const BOAT_X := 5730.0
const STONE_A := 6170.0
const STONE_B := 6540.0
const GATE_X := 6670.0
const CAGE_X := 7500.0
const HOME_MOM_X := 352.0
const HOME_DAD_X := 432.0

const GUARDS := {
	"trigger": 6110.0, "left": 5940.0, "right": 6590.0,
	"goblins": [{ "x": 6400.0, "attacks": "swing" }, { "x": 6520.0, "attacks": "charge" }],
	"hint": "Your sister charges through on her pony. Hit the goblins while they are dizzy!",
}
const OGRE := {
	"trigger": 6830.0, "left": 6740.0, "right": 7370.0, "title": "Defeat the ogre",
	"goblins": [{ "x": 7250.0, "attacks": "swing", "ogre": true }],
	"hint": "He shrugs off every hit! Strike while he is watching your sister.",
}

var game = null
var on_island := false
var fade := 0.0  # 0 clear, 1 black
var fade_way := 0  # 1 going dark, -1 clearing
var after_dark: Callable
var charge_wait := 0.0
var door_up := 0.0  # 0 shut, 1 fully raised
var cage_gone := 0.0
var shrug_note := 0.0
var clock := 0.0

var boat: Sprite2D
var door: Sprite2D
var plate_a: Sprite2D
var plate_b: Sprite2D
var cage: Sprite2D
var mom: Sprite2D
var dad: Sprite2D
var home_mom: Sprite2D
var home_dad: Sprite2D
var dark: ColorRect


func _ready() -> void:
	boat = _prop("boat", BOAT_X, 34.0)
	door = _prop("fort_door", GATE_X, 0.0)
	_prop("fort_arch", GATE_X, 0.0)
	plate_a = _prop("plate", STONE_A, 2.0)
	plate_b = _prop("plate", STONE_B, 2.0)
	mom = _prop("mum", CAGE_X - 38.0, -18.0)
	dad = _prop("dad", CAGE_X + 34.0, -18.0)
	cage = _prop("cage", CAGE_X, 0.0)
	home_mom = _prop("mum", HOME_MOM_X, 0.0)
	home_dad = _prop("dad", HOME_DAD_X, 0.0)
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	dark = ColorRect.new()
	dark.color = Color(0.0, 0.0, 0.0, 0.0)
	dark.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(dark)


## A picture standing on the ground line, centred on x. `sink` lowers it a little.
func _prop(art: String, x: float, sink: float) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.texture = Season.tex("res://art/props/%s.png" % art)
	sprite.centered = false
	sprite.scale = Vector2(game.ART_SCALE, game.ART_SCALE)
	var size: Vector2 = sprite.texture.get_size() * game.ART_SCALE
	sprite.position = Vector2(x - size.x / 2.0, game.GROUND_Y + 4.0 + sink - size.y)
	sprite.set_meta("rest_y", sprite.position.y)
	add_child(sprite)
	return sprite


func step() -> int:
	return int(game.data["m2_step"])


func active() -> bool:
	return str(game.data["m2"]) == "active"


func fading() -> bool:
	return fade_way != 0 or fade > 0.5


func _set_step(n: int) -> void:
	game.data["m2_step"] = n
	game._save()
	game._update_limits()


# --- Called by the game ----------------------------------------------------------

## Puts everyone where the saved step says they should be.
func restore() -> void:
	fade = 0.0
	fade_way = 0
	charge_wait = 0.0
	if active() and step() >= 6:
		# The cage was opened and the game closed before the trip home: they are home.
		game.data["m2"] = "done"
		game._save()
	on_island = active() and step() >= 2
	var s := step() if active() else (6 if str(game.data["m2"]) == "done" else 0)
	door_up = 1.0 if s >= 4 else 0.0
	cage_gone = 1.0 if s >= 6 else 0.0
	if on_island:
		var at: float = [LAND_X, LAND_X, LAND_X, STONE_A - 120.0, GATE_X + 90.0, CAGE_X - 260.0][s]
		game.player.reset(Vector2(at, game.GROUND_Y))
		game.horse.place(game.STABLE_X)
		game.sister.put(at - 110.0)
		game.sister.follow()
	elif active() and s == 1:
		game.sister.put(float(game.player.position.x) - 130.0)
		game.sister.follow()
	_dress()


## How far Adeline may walk on the island: up to whatever is still in her way.
func wall() -> float:
	var s := step()
	if s <= 3:
		return GATE_X - 62.0
	return CAGE_X - 118.0


## What the action button does on the island.
func island_context() -> String:
	var px: float = game.player.position.x
	var sis = game.sister
	if step() == 3:
		if sis.mode == "follow" and absf(sis.x - px) < 330.0 and (absf(px - STONE_A) < 70.0 or absf(px - STONE_B) < 70.0):
			return "stay"
		if sis.mode == "stay" and absf(sis.x - px) < 110.0:
			return "come"
	elif step() == 5 and px > CAGE_X - 240.0:
		return "open"
	return ""


## At home the boat flies once her sister is with her.
func home_context(now: String) -> String:
	if now == "boat" and active() and step() == 1 and absf(game.sister.x - game.player.position.x) < 420.0:
		return "fly"
	return now


func interact(action: String) -> void:
	var sis = game.sister
	if action == "fly":
		game._dismount()
		_go_dark(_land)
	elif action == "stay":
		var px: float = game.player.position.x
		var stone := STONE_A if absf(px - STONE_A) < absf(px - STONE_B) else STONE_B
		sis.stay_at(stone)
		game.sound.shout("sister", "sister_stay", 1.0, true)
		game.toast("She will wait on that stone. Now run to the other one!")
	elif action == "come":
		sis.follow()
	elif action == "open":
		_open_cage()


## Her sister agrees to come. Called from the sister's menu.
func sister_joins() -> void:
	game.sister.follow()
	game.sound.shout("sister", "sister_coming", 1.0, true)
	_set_step(1)
	game.dialog.say("Little sister", [
		"Mom and Dad? Then I'm coming too!",
		"My pony is small but she is ever so fast. To the boat!",
	])


func on_fight_won() -> void:
	game.sister.follow()
	game.data["checkpoint_x"] = game.START_X
	if step() == 2:
		game.toast("The guards are beaten! Now for the gate.")
		_set_step(3)
	elif step() == 4:
		game.toast("The ogre is beaten! Open the cage.")
		_set_step(5)


func on_shrugged() -> void:
	if shrug_note <= 0.0:
		shrug_note = 4.0
		game.toast("He shrugs it off! Wait for your sister to gallop past.")


func objective() -> String:
	match step():
		0:
			return "Fetch your little sister"
		1:
			return "Take the flying boat"
		2:
			return "Get past the goblin guards"
		3:
			return "Open the fort gate"
		4:
			return "Find the ogre"
		_:
			return "Free Mom and Dad"


func hint() -> String:
	var sis = game.sister
	match step():
		0:
			return "She is riding her pony near home. Walk up to her and tap SISTER."
		1:
			if game.context_action == "fly":
				return "Tap FLY and the boat will carry you both to Ogre Island."
			return "Your sister is following. The boat is at the river, far to the east. Spirit can carry you there."
		2:
			return "Head into the island. Your sister is right behind you."
		3:
			if sis.mode == "stay":
				return "She is holding one stone down. Run to the other stone and stand on it."
			return "Two stones open the gate, and both must be pressed at once. Stand on one and tap STAY."
		4:
			return "The gate is open. The ogre is waiting on the other side."
		_:
			return "Walk up to the cage and tap OPEN."


# --- The island --------------------------------------------------------------------

func _go_dark(then: Callable) -> void:
	fade_way = 1
	after_dark = then
	game.controls.release_all()


func _land() -> void:
	on_island = true
	_set_step(2)
	game.player.reset(Vector2(LAND_X, game.GROUND_Y))
	game.horse.place(game.STABLE_X)
	game.sister.put(LAND_X - 110.0)
	game.sister.follow()
	game._update_limits()
	game._update_camera(0.0, true)
	game.toast("Ogre Island")
	game.sound.play("chime", -4.0)


func _open_cage() -> void:
	game.sound.play("clatter", -5.0)
	game.sound.play("fanfare", -5.0, 0.0)
	game.sound.shout("sister", "sister_family", 1.0, true)
	cage_gone = 0.01
	_set_step(6)
	game.dialog.say("Mom", [
		"Adeline! And our little one too! You found us!",
		"Dad: That ogre never stood a chance against the two of you.",
		"Everybody climbs into the flying boat. Time to go home.",
	], func(): _go_dark(_home))


func _home() -> void:
	on_island = false
	game.data["m2"] = "done"
	game.data["checkpoint_x"] = game.START_X
	game._save()
	game.player.reset(Vector2(540.0, game.GROUND_Y))
	game.player.facing = -1
	game.horse.place(game.STABLE_X)
	game.sister.reset()
	game.sister.put(650.0)
	_dress()
	game._update_limits()
	game._update_camera(0.0, true)
	game.toast("Mission complete! Your family is home.")
	game.sound.shout("adeline", "we_did_it", 1.0, true)


## Shows or hides the things that depend on how far the mission has got.
func _dress() -> void:
	var done := str(game.data["m2"]) == "done"
	home_mom.visible = done
	home_dad.visible = done
	mom.visible = not done
	dad.visible = not done
	cage.visible = cage_gone < 1.0
	cage.modulate.a = 1.0 - cage_gone


func _physics_process(delta: float) -> void:
	clock += delta
	shrug_note = maxf(shrug_note - delta, 0.0)
	visible = game.mode != "ride" and game.mode != "sky"
	# Going dark and coming back, for the boat trips.
	if fade_way != 0:
		fade = clampf(fade + fade_way * delta * 2.2, 0.0, 1.0)
		if fade_way > 0 and fade >= 1.0:
			fade_way = -1
			after_dark.call()
		elif fade_way < 0 and fade <= 0.0:
			fade_way = 0
	dark.color.a = fade
	# The boat bobs, the door rises, the cage falls away, and everyone breathes.
	boat.position.y = float(boat.get_meta("rest_y")) + sin(clock * 2.0) * 5.0
	var want_up := 1.0 if (step() >= 4 or str(game.data["m2"]) == "done") else 0.0
	door_up = move_toward(door_up, want_up, delta * 0.8)
	var tall := float(door.texture.get_height())
	door.region_enabled = true
	door.region_rect = Rect2(0.0, tall * door_up * 0.94, door.texture.get_width(), tall * (1.0 - door_up * 0.94))
	if cage_gone > 0.0 and cage_gone < 1.0:
		cage_gone = minf(cage_gone + delta * 1.3, 1.0)
		cage.visible = cage_gone < 1.0
		cage.modulate.a = 1.0 - cage_gone
	for who in [mom, dad, home_mom, home_dad]:
		var breath := 1.0 + sin(clock * 1.7 + who.position.x) * 0.012
		who.scale.y = game.ART_SCALE * breath
		who.position.y = float(who.get_meta("rest_y")) - who.texture.get_height() * game.ART_SCALE * (breath - 1.0)
	if game.mode != "play" or not active() or not on_island or game.dialog.active:
		_light_stones(false, false)
		return

	var p = game.player
	var sis = game.sister
	var fighting: bool = not game.encounter.is_empty()
	if fighting:
		sister_fights(delta)
	elif step() == 2 and p.position.x >= float(GUARDS["trigger"]):
		_begin(GUARDS)
	elif step() == 4 and p.position.x >= float(OGRE["trigger"]):
		_begin(OGRE)
	# The two stones.
	var a := false
	var b := false
	if step() == 3:
		var sis_down: bool = sis.mode == "stay" and absf(sis.x - sis.spot) < 12.0
		a = (absf(p.position.x - STONE_A) < 36.0 and p.is_on_floor()) or (sis_down and absf(sis.x - STONE_A) < 30.0)
		b = (absf(p.position.x - STONE_B) < 36.0 and p.is_on_floor()) or (sis_down and absf(sis.x - STONE_B) < 30.0)
		if a and b:
			game.sound.play("clatter", -4.0)
			game.sound.play("fanfare", -5.0, 0.0)
			game.toast("The gate is opening!")
			sis.follow()
			_set_step(4)
	_light_stones(a, b)


func _light_stones(a: bool, b: bool) -> void:
	var glow := Color(1.5, 1.4, 0.7)
	for pair in [[plate_a, a], [plate_b, b]]:
		var plate: Sprite2D = pair[0]
		plate.modulate = glow if pair[1] else Color.WHITE
		plate.position.y = float(plate.get_meta("rest_y")) + (4.0 if pair[1] else 0.0)


func _begin(fight: Dictionary) -> void:
	game._begin_encounter(fight, "m2")
	game.sister.stay_at(float(fight["left"]) + 46.0)
	charge_wait = 2.2


## Every few seconds she gallops from one end of the fight to the other. Whatever she
## passes is bowled over: goblins see stars and lose a little health, and the ogre turns
## to watch her go, which is the only time he can be hurt.
func sister_fights(delta: float) -> void:
	var sis = game.sister
	var fight: Dictionary = game.encounter
	charge_wait -= delta
	if not sis.charging and charge_wait <= 0.0 and not game.defeated:
		var left := float(fight["left"]) + 46.0
		var right := float(fight["right"]) - 46.0
		sis.charge_to(right if sis.x < (left + right) / 2.0 else left)
		charge_wait = 6.0
		game.sound.shout("sister", "sister_charge", 1.0, true)
	if not sis.charging:
		return
	for g in game.goblins:
		if not is_instance_valid(g) or g.is_dead() or g.dazed > 0.4:
			continue
		if absf(g.position.x - sis.x) < 44.0 * maxf(g.size, 1.0):
			game.sound.play("thump", -4.0, 0.1)
			if g.tough:
				g.daze(3.6, sis.spot)
			else:
				g.daze(2.4, sis.spot)
				g.take_damage(1, sis.facing)
