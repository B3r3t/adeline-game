extends Node2D
## Adeline's little sister, who rides her pony about near home. Nobody plays her: she trots
## up and down the meadow, stops for a rest now and then, and calls hello when Adeline is near.
##
## She and her pony have drawings of their own: a five-year-old with a big head and short
## legs, and a round, shaggy pony. Neither is a bigger character made small.

const RigScript := preload("res://scripts/rig.gd")
const Moves := preload("res://scripts/moves.gd")
const HorseScript := preload("res://scripts/horse.gd")

const PONY_SIZE := 1.0
const GIRL_SIZE := 1.0
const LEFT := 330.0  # she stays between the house and the signpost
const RIGHT := 1660.0
const TROT := 210.0

var game = null
var pony = null
var girl = null
var who := { "position": Vector2.ZERO, "velocity": Vector2.ZERO, "air": false, "pitch": 0.0, "facing": 1 }
var x := 1250.0
var facing := -1
var speed := 0.0
var goal := 700.0
var rest := 1.5  # seconds left of standing still
var hello := 6.0  # seconds until she may call out again
var hop := 0.0
var clock := 0.0


func _ready() -> void:
	pony = Node2D.new()
	pony.set_script(HorseScript)
	pony.game = game
	pony.wild = true
	pony.subject = who
	pony.art = "res://art/pony"
	pony.seat_at = Vector2(-10.0, -29.0)  # just behind her mane
	pony.bit_at = Vector2(171.0, 74.0)  # the ring of her halter
	pony.pommel_at = Vector2(96.0, 72.0)
	pony.hands_at = Vector2(13.0, -11.0)
	pony.step_rate = 0.056
	add_child(pony)
	pony.state = "mounted"

	girl = Node2D.new()
	girl.set_script(RigScript)
	add_child(girl)
	girl.build("res://art/sister")
	# Her far leg is on the other side of the pony.
	for part in ["leg_far_upper", "leg_far_lower"]:
		girl.info[part]["sprite"].visible = false


func _physics_process(delta: float) -> void:
	clock += delta
	hello = maxf(hello - delta, 0.0)
	hop = maxf(hop - delta, 0.0)
	var want := 0.0
	if rest > 0.0:
		rest -= delta
		if rest <= 0.0:
			# Off again, to somewhere a fair way from here.
			goal = randf_range(LEFT, RIGHT)
			if absf(goal - x) < 320.0:
				goal = LEFT if x > (LEFT + RIGHT) / 2.0 else RIGHT
			if game.mode == "play" and absf(game.player.position.x - x) < 700.0:
				game.sound.shout("sister", "sister_whee", 0.4)
	elif absf(goal - x) < 12.0:
		rest = randf_range(2.0, 5.0)
	else:
		facing = 1 if goal > x else -1
		want = TROT
	speed = move_toward(speed, want, 420.0 * delta)
	x += facing * speed * delta

	# A hello for Adeline when she comes close.
	if game.mode == "play" and hello <= 0.0 and absf(game.player.position.x - x) < 190.0 and not game.dialog.active:
		hello = 28.0
		hop = 0.6
		game.sound.shout("sister", "sister_hello", 1.0, true)

	var lift := -absf(sin(hop * 10.5)) * 10.0 if hop > 0.0 else 0.0
	who["position"] = Vector2(x, game.GROUND_Y + lift)
	who["velocity"] = Vector2(facing * speed, 0.0)
	who["facing"] = facing
	pony.carry(delta)

	var seat: Vector2 = pony.seat()
	var pace := clampf(speed / TROT, 0.0, 1.0)
	girl.position = Vector2(x + seat.x * facing * PONY_SIZE, game.GROUND_Y + lift + seat.y * PONY_SIZE)
	girl.scale = Vector2(GIRL_SIZE * facing, GIRL_SIZE)
	var pose: Dictionary = Moves.girl_ride(clock, pace, pony.stride)
	if hop > 0.0:
		pose["arm_upper"] = -105.0 + sin(clock * 16.0) * 10.0  # an arm up, waving
		pose["arm_lower"] = -20.0 + sin(clock * 16.0 + 1.0) * 14.0
	var bob: float = pose["_lift"]
	pose.erase("_lift")
	girl.pose = pose
	girl.root_offset = -girl.rest_pos("torso") + Vector2(0.0, bob)
	girl.apply()
