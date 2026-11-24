extends Node
## Runs between the boot script and the game, and loads the newest update on top of
## whatever is already loaded.
##
## Why this exists: a file that the game has loaded must never be changed while the game
## is running. The game reads its pictures and sounds out of that file as it needs them,
## using a list of positions it took when it started, so swapping the file gives it rubbish.
## So a download is saved under its own name (update_new), is renamed here at the next
## start before anything has been read from it (update_next), and is then loaded.
##
## Keep this file free of game code, so the game's scripts are first read after the update
## is in place.

const NEW := "user://update_new"  # finished downloading while the game was running
const NEXT := "user://update_next"  # the update to load on top
const GUARD := "user://update_next_loading"  # present only while that update is being tried out


func _ready() -> void:
	var build := int(Engine.get_meta("build", _installed_build()))
	if not Engine.has_meta("installed_build"):
		Engine.set_meta("installed_build", _installed_build())
	var dir := DirAccess.open("user://")
	if dir != null:
		_remove(NEW + ".tmp")  # a download that was cut off
		if FileAccess.file_exists(NEW + ".pck") and FileAccess.file_exists(NEW + ".json"):
			for end in [".pck", ".json"]:
				_remove(NEXT + end)
				dir.rename(NEW.get_file() + end, NEXT.get_file() + end)
			_remove(GUARD)
		else:
			_remove(NEW + ".pck")
			_remove(NEW + ".json")
		if FileAccess.file_exists(GUARD):
			# The last start with this update never got going. Throw the update away.
			_remove(NEXT + ".pck")
			_remove(NEXT + ".json")
			_remove(GUARD)
		elif FileAccess.file_exists(NEXT + ".pck") and FileAccess.file_exists(NEXT + ".json"):
			var info = JSON.parse_string(FileAccess.get_file_as_string(NEXT + ".json"))
			var next_build := int(info.get("build", 0)) if info is Dictionary else 0
			var loaded := false
			if next_build > build:
				var guard := FileAccess.open(GUARD, FileAccess.WRITE)
				if guard != null:
					guard.store_string("1")
					guard.close()
				loaded = ProjectSettings.load_resource_pack(NEXT + ".pck")
				if loaded:
					build = next_build
				else:
					_remove(GUARD)
			if not loaded:
				# Older than what is already running, or unreadable.
				_remove(NEXT + ".pck")
				_remove(NEXT + ".json")
	Engine.set_meta("build", build)
	get_tree().change_scene_to_file.call_deferred("res://scenes/game.tscn")


## The build number is the last part of the version, for example 12 in "0.1.12".
func _installed_build() -> int:
	var version := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var parts := version.split(".")
	return int(parts[parts.size() - 1])


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
