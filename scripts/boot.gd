extends Node
## The first thing that runs. If a newer copy of the game's content was downloaded
## during an earlier play session, it is loaded here, before anything else starts.
## Keep this file small and free of game code: it is the one script an update cannot replace.

const PACK := "user://update.pck"
const PACK_INFO := "user://update.json"
const GUARD := "user://update_loading"  # present only while an update is being tried out


func _ready() -> void:
	var installed := _installed_build()
	var build := installed
	if FileAccess.file_exists(GUARD):
		# The last start with this update never got going. Throw the update away.
		_remove(PACK)
		_remove(PACK_INFO)
		_remove(GUARD)
	elif FileAccess.file_exists(PACK) and FileAccess.file_exists(PACK_INFO):
		var info = JSON.parse_string(FileAccess.get_file_as_string(PACK_INFO))
		var pack_build := int(info.get("build", 0)) if info is Dictionary else 0
		if pack_build > installed:
			var guard := FileAccess.open(GUARD, FileAccess.WRITE)
			if guard != null:
				guard.store_string("1")
				guard.close()
			if ProjectSettings.load_resource_pack(PACK):
				build = pack_build
			else:
				_remove(GUARD)
		else:
			# The installed app is as new as the download, so the download is not needed.
			_remove(PACK)
			_remove(PACK_INFO)
	Engine.set_meta("build", build)
	Engine.set_meta("installed_build", installed)
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")


## The build number is the last part of the version, for example 12 in "0.1.12".
func _installed_build() -> int:
	var version := str(ProjectSettings.get_setting("application/config/version", "0.0.0"))
	var parts := version.split(".")
	return int(parts[parts.size() - 1])


func _remove(path: String) -> void:
	if FileAccess.file_exists(path):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
