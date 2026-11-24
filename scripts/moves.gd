extends RefCounted
## The shapes of movement, shared by everyone who moves that way: Adeline outdoors and
## indoors, her little sister, Spirit, the pony and the race horses.
##
## Each function returns a pose: degrees for each part of a rig, by name. Two extra entries
## are not parts: "_lift" is how far the whole body rises or sinks (negative is up), and
## "_tip" is how far a horse's body rocks. Angles: negative swings a limb forward.


## Standing: breathing, a slow look around, cloak and hair stirring.
static func girl_idle(t: float) -> Dictionary:
	var breath := sin(t * 1.9)
	return {
		"torso": breath * 0.8,
		"head": -breath * 0.8 + sin(t * 0.63) * 1.6,
		"arm_upper": sin(t * 1.9 + 0.9) * 2.4,
		"arm_lower": sin(t * 1.9 + 1.7) * 2.0,
		"leg_near_upper": 0.0, "leg_near_lower": 0.0, "leg_far_upper": 0.0, "leg_far_lower": 0.0,
		"cloak_back": 2.0 + sin(t * 1.3) * 2.4,
		"ponytail": sin(t * 1.6 + 0.8) * 3.0,
		"_lift": breath * 0.6,
	}


## Running. `phase` goes round once for every two steps and follows the ground covered, so
## feet do not slide. `go` is 0 at a walk and 1 at full speed.
static func girl_run(phase: float, go: float) -> Dictionary:
	var pose := {}
	var reach := lerpf(22.0, 34.0, go)
	for side in [["near", 0.0], ["far", PI]]:
		var ph: float = phase + side[1]
		var swing := sin(ph)
		var forward := maxf(0.0, -cos(ph))  # 1 while this leg is swinging through to the front
		var standing := maxf(0.0, cos(ph))  # 1 while it is under her, taking her weight
		pose["leg_%s_upper" % side[0]] = swing * reach - 3.0
		# The knee folds as the leg comes through, and gives a little as it takes her weight.
		pose["leg_%s_lower" % side[0]] = pow(forward, 0.8) * lerpf(42.0, 66.0, go) + standing * 9.0
	var lean := lerpf(2.0, 7.0, go)
	pose["torso"] = lean + sin(phase * 2.0) * 1.2
	pose["head"] = -lean * 0.5 + sin(phase * 2.0 + 0.6) * 1.2
	# Her arm swings against her near leg.
	pose["arm_upper"] = -sin(phase) * lerpf(10.0, 22.0, go)
	pose["arm_lower"] = -6.0 - maxf(0.0, sin(phase)) * lerpf(4.0, 14.0, go)
	pose["cloak_back"] = lerpf(8.0, 18.0, go) + sin(phase * 2.0 + 0.9) * 3.0
	pose["ponytail"] = lerpf(6.0, 14.0, go) + sin(phase * 2.0 + 1.6) * 4.0
	# She sinks as each foot lands and rises between steps.
	pose["_lift"] = -(0.5 - 0.5 * cos(phase * 2.0 + PI - 0.5)) * lerpf(2.0, 4.5, go)
	return pose


## In the air. `fall` is her downward speed: knees tuck on the way up and legs reach for
## the ground on the way down, changing over smoothly at the top.
static func girl_air(fall: float) -> Dictionary:
	var k := smoothstep(-260.0, 320.0, fall)
	return {
		"leg_near_upper": lerpf(-44.0, -18.0, k), "leg_near_lower": lerpf(58.0, 20.0, k),
		"leg_far_upper": lerpf(22.0, 10.0, k), "leg_far_lower": lerpf(26.0, 12.0, k),
		"arm_upper": lerpf(-20.0, -40.0, k), "arm_lower": lerpf(-4.0, -12.0, k),
		"torso": lerpf(5.0, -2.0, k), "head": lerpf(-3.0, 3.0, k),
		"cloak_back": lerpf(14.0, 38.0, k), "ponytail": lerpf(8.0, 30.0, k),
		"_lift": 0.0,
	}


## Just landed: knees give, then she straightens. `k` runs from 0 at touchdown to 1.
static func girl_land(pose: Dictionary, k: float) -> void:
	var give := sin(clampf(k, 0.0, 1.0) * PI) * (1.0 - k * 0.4)
	for side in ["near", "far"]:
		pose["leg_%s_upper" % side] = float(pose.get("leg_%s_upper" % side, 0.0)) - 24.0 * give
		pose["leg_%s_lower" % side] = float(pose.get("leg_%s_lower" % side, 0.0)) + 48.0 * give
	pose["torso"] = float(pose.get("torso", 0.0)) + 8.0 * give
	pose["arm_upper"] = float(pose.get("arm_upper", 0.0)) + 10.0 * give
	pose["_lift"] = float(pose.get("_lift", 0.0)) + 4.2 * give  # bent legs are shorter


## In the saddle. `pace` is 0 standing and 1 at a gallop; `stride` is the horse's step.
## `rise` is the horse's upward speed in a jump (0 on the ground).
static func girl_ride(t: float, pace: float, stride: float, rise := 0.0) -> Dictionary:
	var sway := sin(t * 2.0)
	var beat := sin(stride * 2.0 + 0.8)
	# Over a jump she folds forward going up and sits back coming down.
	var fold := clampf(rise / 500.0, -1.0, 1.0)
	return {
		"leg_near_upper": -55.0 + beat * 3.0 * pace - maxf(fold, 0.0) * 8.0,
		"leg_near_lower": 60.0 - beat * 4.0 * pace,
		"leg_far_upper": -55.0, "leg_far_lower": 60.0,
		"arm_upper": -14.0 + sin(stride + 0.5) * 5.0 * pace - fold * 10.0,
		"arm_lower": 8.0 + sin(stride + 1.2) * 4.0 * pace,
		"torso": 2.0 + pace * 6.0 + beat * 2.0 * pace + fold * 13.0,
		"head": -pace * 3.0 - beat * 1.5 * pace - fold * 7.0 + sway * 0.8 * (1.0 - pace),
		"cloak_back": 4.0 + pace * 24.0 + sway * 2.5 + beat * 3.0 * pace - minf(fold, 0.0) * 14.0,
		"ponytail": pace * 20.0 + sway * 2.5 + beat * 4.0 * pace - minf(fold, 0.0) * 16.0,
		"_lift": beat * 1.6 * pace,
	}


# --- Horses -------------------------------------------------------------------

# When each leg takes its turn, as a share of the stride, at a walk, a trot and a gallop.
const HORSE_TURNS := {
	"front_near": [0.25, 0.0, 0.0], "front_far": [0.75, 0.5, 0.11],
	"hind_near": [0.0, 0.5, 0.36], "hind_far": [0.5, 0.0, 0.47],
}


## The points in a stride (0 to 1) at which a hoof comes down, in order. These come from
## the same numbers as the leg movement, so what is heard matches what is seen: four even
## beats at a walk, two at a trot, and at a gallop four quick ones and then a pause.
static func horse_footfalls(speed: float) -> Array:
	var trot := smoothstep(120.0, 240.0, speed)
	var gallop := smoothstep(300.0, 430.0, speed)
	var beats := []
	for leg in HORSE_TURNS:
		var turn: Array = HORSE_TURNS[leg]
		# A leg is furthest forward, and lands, three quarters of the way through its own turn.
		beats.append(fposmod(0.75 - lerpf(lerpf(turn[0], turn[1], trot), turn[2], gallop), 1.0))
	beats.sort()
	return beats


## A horse on the ground. `speed` is in pixels a second and `stride` follows the ground
## covered. Slow is a walk (four separate beats), faster a trot (legs in diagonal pairs),
## fastest a gallop (hind legs then front legs, and a moment in the air).
static func horse_ground(t: float, stride: float, speed: float) -> Dictionary:
	var pose := {}
	var moving := smoothstep(4.0, 60.0, speed)
	var trot := smoothstep(120.0, 240.0, speed)
	var gallop := smoothstep(300.0, 430.0, speed)
	var turns := HORSE_TURNS
	var reach := lerpf(lerpf(15.0, 23.0, trot), 36.0, gallop) * moving
	var fold := lerpf(lerpf(30.0, 50.0, trot), 74.0, gallop) * moving
	for leg in turns:
		var turn: Array = turns[leg]
		var ph: float = stride + lerpf(lerpf(turn[0], turn[1], trot), turn[2], gallop) * TAU
		var swing := sin(ph)
		var through := maxf(0.0, -cos(ph))  # 1 in the middle of the forward swing
		if str(leg).begins_with("front"):
			pose["leg_%s_upper" % leg] = swing * reach
			pose["leg_%s_lower" % leg] = pow(through, 0.85) * fold
		else:
			pose["leg_%s_upper" % leg] = swing * reach * 0.84
			pose["leg_%s_lower" % leg] = (minf(0.0, swing) * 0.46 - through * 0.36 + maxf(0.0, swing) * 0.14) * fold
	# The body: a walk nods, a trot bounces twice a stride, a gallop rocks once a stride.
	var nod := sin(stride * 2.0) * 1.1 * moving * (1.0 - trot)
	var rock := sin(stride + 0.9) * 3.4 * gallop
	pose["body"] = nod + rock + sin(t * 0.8) * 0.5 * (1.0 - moving)
	# Her head: it nods at a walk, is carried steady at a trot, and reaches out and down
	# with every stride of a gallop. Standing, she looks about and now and then drops it.
	var graze := pow(maxf(0.0, sin(t * 0.23 + 1.0)), 8.0) * 9.0
	pose["neck"] = sin(stride * 2.0 + 0.4) * 4.0 * moving * (1.0 - trot) + sin(stride * 2.0) * 1.3 * trot * (1.0 - gallop) \
		+ (2.0 + sin(stride + 2.6) * 6.0) * gallop + (sin(t * 0.6) * 2.0 + graze) * (1.0 - moving)
	var hop := (0.5 - 0.5 * cos(stride * 2.0 + 0.6)) * 3.6 * trot * (1.0 - gallop)
	var bound := (0.5 - 0.5 * cos(stride + 2.2)) * 7.0 * gallop
	pose["_lift"] = -(hop + bound) - sin(t * 1.5) * 0.7 * (1.0 - moving)
	var go := clampf(speed / 560.0, 0.0, 1.0)
	# A resting horse swishes its tail now and then.
	var swish := pow(maxf(0.0, sin(t * 0.7)), 6.0) * sin(t * 9.0) * 9.0 * (1.0 - moving)
	pose["tail"] = 4.0 + sin(t * 1.7) * 3.0 + swish + go * 26.0 + sin(stride * 2.0) * 3.0 * moving
	if moving < 0.5:
		# Resting a hind leg.
		pose["leg_hind_far_lower"] = float(pose["leg_hind_far_lower"]) - 7.0 * (1.0 - moving * 2.0)
	return pose


## A horse in the air over a jump. `fall` is its downward speed: the front legs tuck going
## up and reach for the ground coming down, and the hind legs trail and then gather.
static func horse_air(pose: Dictionary, fall: float) -> void:
	var k := smoothstep(-320.0, 320.0, fall)
	pose["body"] = lerpf(-10.0, 8.0, k)
	for side in ["near", "far"]:
		var apart := 0.0 if side == "near" else 5.0
		pose["leg_front_%s_upper" % side] = lerpf(-54.0, -32.0, k) + apart
		pose["leg_front_%s_lower" % side] = lerpf(88.0, 18.0, k) - apart
		pose["leg_hind_%s_upper" % side] = lerpf(36.0, 14.0, k) - apart
		pose["leg_hind_%s_lower" % side] = lerpf(10.0, -44.0, k)
	pose["tail"] = lerpf(30.0, 40.0, k)
	pose["neck"] = lerpf(-9.0, 9.0, k)  # head up as she rises, stretched out as she comes down
	pose["_lift"] = 0.0
