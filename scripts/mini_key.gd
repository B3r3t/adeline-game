extends Node2D
## Mission 4, part two: the key, in the goblin chief's den.
##
## Adeline is in a cage and Spirit is tied up beside it. The chief is asleep in his
## armchair with the key on his belt. Her little sister has to lift the key off him and
## carry it to the padlock on the cage, with one finger, slowly.
##
## Carrying it fast makes a noise, and the bar at the top fills. When it is full, or when
## he simply has one of his restless turns, he stirs: one eye opens. Then the key must be
## held quite still until he settles. If it moves while he is stirring he wakes with a
## snort, she drops it and ducks down, and the key is back on his belt when he nods off
## again. Letting go of the key drops it with a clatter, which is noisy too, but it can be
## picked up from where it fell. Nobody is hurt and nothing is lost but a little time.
##
## When the key reaches the padlock the cage opens, Adeline's wand sends the chief diving
## behind his chair, and the sister picks up Merlin's spell book on the way out.

const Ui := preload("res://scripts/ui.gd")
const RigScript := preload("res://scripts/rig.gd")

const PATH := 644.0  # the line the girls stand on
const CHIEF_AT := Vector2(600.0, 668.0)
const CHIEF := 0.56  # how big the chief is drawn
const BELT := Vector2(0.58, 0.66)  # where the key hangs from his belt, as shares of his picture
const CAGE_AT := Vector2(990.0, 668.0)
const LOCK := Vector2(990.0, 530.0)  # the padlock on the cage
const QUIET := 230.0  # how fast the key can be carried without a sound
const STIR := 1.9  # how long he stirs before settling
const SLIP := 26.0  # how far the key may move while he is stirring

var host = null
var game = null
var who := {}  # the little sister
var adeline := {}
var spirit: Node2D = null
var chief: Sprite2D = null
var cage: Sprite2D = null
var key: Sprite2D = null
var book: Sprite2D = null
var art := {}
var phase := "walk"  # "walk", "take", "free"
var held := false
var finger := Vector2.ZERO
var key_home := Vector2.ZERO
var speed := 0.0
var noise := 0.0
var mood := "sleep"  # the chief: "sleep", "stir", "awake"
var mood_time := 0.0
var restless := 7.0  # seconds until he next stirs of his own accord
var slipped := 0.0
var woken := 0
var clock := 0.0
var free_time := 0.0
var snore := 1.5
var fallen := false  # the key is lying on the floor


func begin() -> void:
	for name in ["chief_sleep", "chief_stir"]:
		art[name] = load("res://art/mini/%s.png" % name)
	var tex: Texture2D = art["chief_sleep"]
	chief = host.picture("res://art/mini/chief_sleep.png", CHIEF_AT, tex.get_width() * CHIEF, int(PATH) - 20)
	key_home = CHIEF_AT + Vector2((BELT.x - 0.5) * tex.get_width(), (BELT.y - 1.0) * tex.get_height()) * CHIEF + Vector2(0.0, 44.0)
	key = host.picture("res://art/mini/key.png", key_home, 96.0, 3000)
	key.offset = Vector2.ZERO
	key.rotation = PI / 2.0  # it hangs by its ring
	book = host.picture("res://art/mini/spellbook.png", Vector2(806.0, 664.0), 84.0, int(PATH) - 10)
	# Adeline in the cage, and Spirit tied up beside it.
	adeline = host.girl("res://art/adeline", CAGE_AT + Vector2(-52.0, -22.0), 2.25)
	adeline["facing"] = -1
	cage = host.picture("res://art/props/cage.png", CAGE_AT, 330.0, int(PATH) + 40)
	spirit = Node2D.new()
	spirit.set_script(RigScript)
	host.stage.add_child(spirit)
	spirit.build("res://art/spirit")
	for part in ["leg_front_far_upper", "leg_front_far_lower", "leg_hind_far_upper", "leg_hind_far_lower"]:
		spirit.tint(part, Color(0.72, 0.72, 0.78))
	spirit.position = Vector2(1226.0, PATH + 10.0)
	spirit.scale = Vector2(-1.5, 1.5)
	spirit.z_index = int(PATH) - 30
	who = host.girl("res://art/sister", Vector2(140.0, PATH), 2.5)
	who["speed"] = 140.0
	who["goal"] = Vector2(452.0, PATH)


func how() -> String:
	return "Lift the key off the chief and carry it to the cage.\nSlowly! If he stirs, hold it still."


func go() -> void:
	game.sound.say("Little sister! Shh. The key is on his belt.")


func press(at: Vector2) -> void:
	finger = at
	if phase == "take" and mood != "awake" and at.distance_to(key.position) < 100.0:
		held = true
		if fallen or key.position.distance_to(key_home) < 6.0:
			game.sound.play("jingle", -9.0)
		fallen = false


func drag(at: Vector2) -> void:
	finger = at


func release(_at: Vector2) -> void:
	if held and phase == "take":
		_drop()
	held = false


## She lets go of it, or loses hold of it: down it goes with a clatter.
func _drop() -> void:
	held = false
	if key.position.distance_to(key_home) < 40.0:
		key.position = key_home  # hardly lifted: it swings back on his belt
		return
	fallen = true
	noise = minf(noise + 0.55, 1.0)
	game.sound.play("clatter", -9.0, 0.1, 1.5)


func frame(delta: float) -> void:
	clock += delta
	var playing: bool = host.state == "play"
	if phase == "walk" and playing and not bool(who["moving"]):
		phase = "take"
	if phase == "take" and playing:
		_carry(delta)
		_chief(delta)
	elif phase == "free":
		_freed(delta)
	# The key falls to the floor when it is dropped, and swings a little on his belt.
	if fallen and key.position.y < PATH - 6.0:
		key.position.y = minf(key.position.y + 900.0 * delta, PATH - 6.0)
		key.rotation = move_toward(key.rotation, 0.0, delta * 8.0)
	elif not held and not fallen and phase != "free":
		key.rotation = PI / 2.0 + sin(clock * 2.2) * 0.07
	if phase != "free":
		who["goal"] = Vector2(clampf(key.position.x - 46.0, 320.0, LOCK.x - 120.0), PATH) if (held or fallen) and mood != "awake" else Vector2(452.0, PATH)
	host.step(who, delta, { "arm_upper": -120.0, "arm_lower": -20.0 } if held else {})
	host.step(adeline, delta)
	if mood == "awake" and phase == "take":
		who["rig"].scale.y *= 0.84  # ducked down small beside his chair
	spirit.pose = { "tail": sin(clock * 2.0) * 6.0, "body": sin(clock * 1.3) * 1.0 + (-4.0 if phase == "free" else 0.0) }
	spirit.root_offset = Vector2(0.0, -absf(sin(free_time * 9.0)) * 10.0 if (phase == "free" and free_time > 0.9 and free_time < 2.2) else 0.0)
	spirit.apply()
	var tex: Texture2D = art["chief_stir" if mood != "sleep" else "chief_sleep"]
	chief.texture = tex
	var breath := 1.0 + sin(clock * 1.5) * 0.02 if mood == "sleep" else 1.0 + absf(sin(clock * 16.0)) * (0.03 if mood == "awake" else 0.008)
	chief.scale = Vector2(CHIEF, CHIEF * breath)
	# His two pictures are not quite the same width: the armchair's right side is kept where it is.
	chief.offset = Vector2(((art["chief_sleep"] as Texture2D).get_width() - tex.get_width()) / 2.0, -tex.get_height() / 2.0)
	if playing and mood == "sleep" and phase == "take":
		snore -= delta
		if snore <= 0.0:
			snore = 3.4
			game.sound.play("snore", -9.0, 0.06, 0.9)


## The key follows the finger, and how fast it goes is how much noise it makes.
func _carry(delta: float) -> void:
	if not held:
		speed = 0.0
		noise = maxf(noise - 0.3 * delta, 0.0)
		return
	var before := key.position
	key.position = key.position.lerp(finger + Vector2(0.0, -46.0), 1.0 - exp(-16.0 * delta))
	key.position.y = minf(key.position.y, PATH - 6.0)
	key.rotation = move_toward(key.rotation, 0.25, delta * 6.0)
	var moved := key.position.distance_to(before)
	speed = lerpf(speed, moved / maxf(delta, 0.001), 0.25)
	if mood == "stir" and mood_time > 0.35:  # a moment's grace to stop the hand
		slipped += moved
	if speed > QUIET:
		noise = minf(noise + (speed - QUIET) / QUIET * 1.5 * delta, 1.0)
		if fmod(clock, 0.3) < delta:
			game.sound.play("jingle", -12.0, 0.15, 1.2)
	else:
		noise = maxf(noise - 0.3 * delta, 0.0)
	if key.position.distance_to(LOCK) < 48.0 and mood != "awake":
		_unlock()


## The chief's sleep: he stirs when it is too noisy, or just because, and wakes if the key
## moves while he is stirring.
func _chief(delta: float) -> void:
	mood_time += delta
	match mood:
		"sleep":
			restless -= delta
			var carrying := held and key.position.distance_to(key_home) > 40.0
			if noise >= 1.0 or (restless <= 0.0 and carrying):
				mood = "stir"
				mood_time = 0.0
				slipped = 0.0
				game.sound.play("goblin_taunt", -10.0, 0.05, 0.62)
			elif restless <= 0.0:
				restless = randf_range(2.0, 4.0)
		"stir":
			if slipped > SLIP:
				_wake()
			elif mood_time >= STIR:
				mood = "sleep"
				mood_time = 0.0
				noise = 0.15
				restless = randf_range(5.5, 8.5)
		"awake":
			# He looks about, sees nothing, and goes back to sleep.
			key.position = key.position.lerp(key_home, 1.0 - exp(-7.0 * delta))
			key.rotation = move_toward(key.rotation, PI / 2.0, delta * 8.0)
			if mood_time >= 2.2:
				mood = "sleep"
				mood_time = 0.0
				noise = 0.0
				restless = randf_range(6.0, 9.0)
				key.position = key_home


func _wake() -> void:
	mood = "awake"
	mood_time = 0.0
	woken += 1
	held = false
	fallen = false
	game.sound.play("goblin_attack", -6.0, 0.05, 0.7)
	game.sound.shout("sister", "sister_uhoh", 1.0, true)
	host.word(CHIEF_AT + Vector2(-30.0, -400.0), "Who's there?", Color(1.0, 0.75, 0.6))


func _unlock() -> void:
	phase = "free"
	free_time = 0.0
	held = false
	mood = "sleep"
	key.visible = false
	game.sound.play("creak", -4.0)
	game.sound.play("chime", -6.0)
	host.burst(LOCK, "star", 16, Color(1.0, 0.9, 0.5))
	var tween := cage.create_tween()
	tween.set_parallel(true)
	tween.tween_property(cage, "position:y", cage.position.y - 60.0, 0.7)
	tween.tween_property(cage, "modulate:a", 0.0, 0.7)


## The cage is open: Adeline is out, the chief gets a fright, and the book is fetched.
func _freed(delta: float) -> void:
	var before := free_time
	free_time += delta
	if before < 0.5 and free_time >= 0.5:
		adeline["hop"] = 0.4
		adeline["goal"] = Vector2(CAGE_AT.x + 30.0, PATH)
		game.sound.say("You did it! You were so brave.")
	if before < 1.2 and free_time >= 1.2:
		game.sound.play("whinny", -5.0)
	if before < 2.4 and free_time >= 2.4:
		# The chief wakes at the noise, and gets a wand pointed at him.
		mood = "awake"
		host.word(CHIEF_AT + Vector2(-30.0, -400.0), "Eh?!", Color(1.0, 0.75, 0.6))
		game.sound.play("goblin_hurt", -6.0, 0.05, 0.7)
	if before < 3.1 and free_time >= 3.1:
		game.sound.play("zap", -5.0)
		game.sound.shout("adeline", "take_that", 1.0, true)
		for i in 26:
			host.spark(Vector2(lerpf(float(adeline["at"].x), CHIEF_AT.x, randf()), PATH - randf_range(120.0, 260.0)), "star", Color(1.0, 0.9, 0.5))
		var tween := chief.create_tween()
		tween.tween_property(chief, "position:y", CHIEF_AT.y + 300.0, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
		host.word(CHIEF_AT + Vector2(-30.0, -300.0), "Eek!", Color(1.0, 0.9, 0.6))
		game.sound.play("goblin_down", -6.0, 0.05, 0.75)
	if before < 3.8 and free_time >= 3.8:
		who["goal"] = Vector2(book.position.x - 50.0, PATH)
		who["speed"] = 260.0
	if free_time >= 3.8 and book.visible and absf(float(who["at"].x) - (book.position.x - 50.0)) < 8.0:
		book.visible = false
		who["hop"] = 0.4
		game.sound.play("fanfare", -6.0, 0.0, 1.1)
		game.sound.shout("sister", "sister_made_it", 1.0, true)
		host.burst(book.position + Vector2(0.0, -60.0), "star", 18, Color(0.8, 0.6, 1.0))
		host.word(book.position + Vector2(0.0, -150.0), "Merlin's spell book!", Color(0.9, 0.8, 1.0))
		free_time = maxf(free_time, 5.0)
	if free_time >= 7.0:
		host.finish(3, "")


func draw_ui(on: Control, s: Vector2) -> void:
	if host.state != "play":
		return
	if phase == "free":
		host.banner(on, "The cage is open!")
		return
	if phase == "walk":
		host.banner(on, "Shh...")
		return
	if mood == "awake":
		host.banner(on, "He woke up! She ducks down until he nods off.")
	elif mood == "stir":
		host.banner(on, "He is stirring. Hold the key still!")
	elif fallen:
		host.banner(on, "Pick the key up again, gently.")
	elif not held:
		host.banner(on, "Lift the key off his belt.")
	else:
		host.banner(on, "Slowly, slowly, to the padlock on the cage.")
	# How much noise the key is making.
	var bar := Rect2(s.x / 2.0 - 170.0, 96.0, 340.0, 22.0)
	Ui.plate(on, bar.grow(6.0), Color(0.09, 0.11, 0.24, 0.7))
	var fill := Color(0.4, 0.85, 0.45).lerp(Color(1.0, 0.45, 0.25), clampf(noise * 1.2, 0.0, 1.0))
	on.draw_rect(Rect2(bar.position, Vector2(bar.size.x * clampf(noise, 0.0, 1.0), bar.size.y)), fill)
	host._text(on, Vector2(bar.position.x, bar.end.y + 26.0), "quiet", 16, Color(0.75, 1.0, 0.8))
	host._text(on, Vector2(bar.position.x, bar.end.y + 26.0), "noisy", 16, Color(1.0, 0.75, 0.6), HORIZONTAL_ALIGNMENT_RIGHT, bar.size.x)
	# Over the chief: z's, or the eye that has opened.
	var head: Vector2 = host.to_screen(CHIEF_AT + Vector2(10.0, -380.0))
	if mood == "sleep":
		for i in 3:
			var t := fmod(clock * 0.4 + i * 0.33, 1.0)
			host._text(on, head + Vector2(30.0 + t * 30.0, 50.0 - t * 70.0), "Z", int(20 + t * 18.0), Color(1.0, 1.0, 1.0, 1.0 - t))
	elif mood == "stir":
		host._text(on, head + Vector2(-10.0, 30.0), "?", 54, Color(1.0, 0.9, 0.4))
	# Where the key is going: a ring round the padlock while it is being carried.
	if held:
		var lock: Vector2 = host.to_screen(LOCK)
		on.draw_arc(lock, 44.0 + sin(clock * 5.0) * 4.0, 0.0, TAU, 40, Color(1.0, 0.9, 0.4, 0.9), 4.0)
