extends Node
## Mission 4, "The Littlest Hero": the mission where the little sister is the one who
## saves the day, and the one who is played.
##
## The goblins have dug a burrow and carried off Merlin's spell book. Adeline rides off to
## fetch it and is caught in a net with Spirit. The tunnel is too small for Merlin and for
## a horse, but not for a small girl. So her sister creeps down it past the dozing sentries
## (scripts/mini_sneak.gd), lifts the key off the sleeping chief and unlocks the cage
## (scripts/mini_key.gd), and they come home with the book.
##
## The two parts are played on painted scenes of their own, in the frame the farm games use
## (scripts/mini.gd, `STORY`). This script is the story round them: what is said before,
## between and after, and what is kept. In the save, "m4" is "available", "active" or
## "done", and "m4_part" is which part she has reached, so leaving half way loses nothing.

const REWARD := 6  # stars for the purse when it is done

var game = null


func state() -> String:
	return str(game.data["m4"])


## The line for Merlin's list of missions.
func row() -> Dictionary:
	var open: bool = game.data["m1"] == "done"
	var words := { "available": "Available", "active": "Active", "done": "Completed" }
	var busy: bool = game.data["m2"] == "active" or game.data["m3"] == "active"
	return { "id": "m4", "label": "The Littlest Hero", "status": str(words[state()]) if open else "Locked", "enabled": open and state() != "done" and not busy }


## Picked from Merlin's list: the story begins, or goes on from where it was left.
func picked() -> void:
	if state() == "active":
		game.dialog.say("Merlin", [
			"Little one! A net has fallen on your sister and on Spirit. The tunnel is too small for me.",
			"But it is not too small for you.",
		], _into_burrow)
		return
	game.data["m4"] = "active"
	game.data["m4_part"] = 0
	game._save()
	game.dialog.say("Merlin", [
		"The goblins have dug a burrow under the hill, and they have carried off my spell book.",
		"It is a small, dark place, Adeline. Do be careful.",
	], func():
		game.dialog.say("Adeline", ["Small and dark? Spirit and I are not afraid."], func():
			game.dialog.say("", ["Adeline and Spirit rode off to the burrow. They did not come back."], func():
				game.dialog.say("Merlin", [
					"Little one! A net has fallen on your sister and on Spirit. The tunnel is too small for me.",
					"But it is not too small for you.",
				], func():
					game.dialog.say("Little sister", ["I'm not scared. Well, maybe a little. I'm coming, Adeline!"], _into_burrow)))))


func _into_burrow() -> void:
	game.controls.release_all()
	game.mini.start_story(clampi(int(game.data["m4_part"]), 0, 1))


## Called by the frame when a part has been played through.
func part_done(part: int) -> void:
	if part == 0:
		game.data["m4_part"] = 1
		game._save()
		game.mini.start_story(1)
		return
	# Home again, with the book.
	game.mini.close()
	game.mode = "play"
	game.data["m4"] = "done"
	game.data["m4_part"] = 0
	game.earn(REWARD)
	game.sound.play("fanfare", -5.0)
	game.dialog.say("Merlin", ["The smallest of us, and the bravest. Six stars for the littlest hero!"], func():
		game.dialog.say("Adeline", ["My little sister saved me."], func():
			game.dialog.say("Little sister", ["And Spirit! I saved Spirit too!"], func():
				game.toast("Mission complete: The Littlest Hero"))))


## Leaving the burrow from the menu: back to the island, the mission still open.
func leave() -> void:
	game.mini.close()
	game.mode = "play"
