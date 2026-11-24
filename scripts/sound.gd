extends Node
## Every sound in the game: spoken lines, shouts and grunts, and effects.
## The list of sounds is audio/manifest.json, written by art_src/build_audio.py.
## A sound that is not in the list is simply silent, so the game never depends on one.

var game = null
var bank := {}  # name -> the recordings for it; one is picked at random each time
var lines := {}  # a line of dialogue, word for word -> its recording
var players: Array = []
var voice: AudioStreamPlayer = null  # dialogue: one speaker at a time
var callouts := {}  # who -> their own player, so nobody talks over themselves
var last_pick := {}
var last_time := {}
var muted := false
var turn := 0

# Music and background sound. Two music players, so one tune can fade out as the next
# fades in. `tunes` and `airs` are the loops by name, from the manifest.
const MUSIC_LEVEL := -7.0  # how loud music is, in decibels, when nobody is talking
const MUSIC_UNDER_TALK := -15.0
const AIR_LEVEL := -4.0
var tunes := {}
var airs := {}
var decks: Array = []
var deck := 0  # which of the two music players is the one playing now
var tune := ""  # the tune asked for
var air_player: AudioStreamPlayer = null
var air := ""
var music_off := false


func _ready() -> void:
	var text := FileAccess.get_file_as_string("res://audio/manifest.json") if FileAccess.file_exists("res://audio/manifest.json") else ""
	var data = JSON.parse_string(text) if text != "" else null
	if data is Dictionary:
		var sounds: Dictionary = data.get("sounds", {})
		for name in sounds:
			var list: Array = []
			for file in sounds[name]:
				var stream = load("res://audio/" + str(file))
				if stream != null:
					list.append(stream)
			bank[name] = list
		var spoken: Dictionary = data.get("lines", {})
		for line in spoken:
			var stream = load("res://audio/" + str(spoken[line]))
			if stream != null:
				lines[line] = stream
		for kind in [["music", tunes], ["ambience", airs]]:
			var files: Dictionary = data.get(kind[0], {})
			for name in files:
				var stream = load("res://audio/" + str(files[name]))
				if stream != null:
					stream.loop = true
					kind[1][name] = stream
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		players.append(p)
	voice = AudioStreamPlayer.new()
	add_child(voice)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -60.0
		add_child(p)
		decks.append(p)
	air_player = AudioStreamPlayer.new()
	air_player.volume_db = -60.0
	add_child(air_player)


## Asks for a tune and a background sound by name ("" for none). Changing either is a
## gentle fade, never a cut. Called every frame with whatever suits the moment.
func want(music: String, background: String) -> void:
	if music != tune:
		tune = music
		deck = 1 - deck
		var p: AudioStreamPlayer = decks[deck]
		p.stop()
		if tunes.has(music):
			p.stream = tunes[music]
			p.volume_db = -50.0
			p.play()
	if background != air:
		air = background


func _process(delta: float) -> void:
	var quiet: bool = muted or music_off
	# Music dips while somebody is speaking a line, so they can be heard.
	var level := MUSIC_UNDER_TALK if voice.playing else MUSIC_LEVEL
	for i in decks.size():
		var p: AudioStreamPlayer = decks[i]
		var goal := level if (i == deck and not quiet and tunes.has(tune)) else -60.0
		p.volume_db = move_toward(p.volume_db, goal, delta * (34.0 if goal > p.volume_db else 46.0))
		if p.playing and p.volume_db <= -59.0 and i != deck:
			p.stop()
		p.stream_paused = quiet and p.volume_db <= -59.0
	# The background sound: one player, faded down, swapped, and faded up again.
	var wanted = airs.get(air)
	if air_player.stream != wanted:
		air_player.volume_db = move_toward(air_player.volume_db, -60.0, delta * 50.0)
		if air_player.volume_db <= -59.0:
			air_player.stop()
			air_player.stream = wanted
			if wanted != null:
				air_player.play()
	else:
		air_player.volume_db = move_toward(air_player.volume_db, AIR_LEVEL if (wanted != null and not muted) else -60.0, delta * 30.0)


func set_music(on: bool) -> void:
	music_off = not on


func _pick(name: String) -> AudioStream:
	if muted or not bank.has(name) or (bank[name] as Array).is_empty():
		return null
	var list: Array = bank[name]
	var pick := randi() % list.size()
	if list.size() > 1 and pick == int(last_pick.get(name, -1)):
		pick = (pick + 1) % list.size()
	last_pick[name] = pick
	return list[pick]


## An effect. Several can play at once. `jitter` varies the pitch a little each time so
## a sound that repeats, like a hoofbeat, does not sound like a machine.
func play(name: String, volume_db := 0.0, jitter := 0.05, pitch := 1.0, gap := 0.04) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now - float(last_time.get(name, -10.0)) < gap:
		return
	var stream := _pick(name)
	if stream == null:
		return
	last_time[name] = now
	var p: AudioStreamPlayer = null
	for candidate in players:
		if not candidate.playing:
			p = candidate
			break
	if p == null:
		turn = (turn + 1) % players.size()
		p = players[turn]
	p.stream = stream
	p.volume_db = volume_db
	p.pitch_scale = maxf(pitch * randf_range(1.0 - jitter, 1.0 + jitter), 0.1)
	p.play()


## A shout or grunt from a character. Each character has one mouth: a new shout is
## skipped while the last one is still going, unless it matters more (`urgent`).
func shout(who: String, name: String, chance := 1.0, urgent := false, volume_db := 0.0) -> void:
	if randf() > chance:
		return
	if not callouts.has(who):
		var p := AudioStreamPlayer.new()
		add_child(p)
		callouts[who] = p
	var mouth: AudioStreamPlayer = callouts[who]
	if mouth.playing and not urgent:
		return
	var stream := _pick(name)
	if stream == null:
		return
	mouth.stream = stream
	mouth.volume_db = volume_db
	mouth.pitch_scale = randf_range(0.97, 1.03)
	mouth.play()


## A line of dialogue, spoken aloud if it has been recorded.
func say(text: String) -> void:
	voice.stop()
	if muted or not lines.has(text):
		return
	voice.stream = lines[text]
	voice.play()


func hush() -> void:
	voice.stop()


func set_muted(off: bool) -> void:
	muted = off
	if muted:
		voice.stop()
		for p in players:
			p.stop()
		for who in callouts:
			callouts[who].stop()
