extends Node
## Scène de démarrage commune : charge la mise à jour téléchargée (user://update.pck) si elle est plus récente que
## la version intégrée (res://version.gd), puis lance la scène principale (res://main.tscn).
const Updater := preload("res://kit/update/updater.gd")


func _ready() -> void:
	var base: String = load("res://version.gd").VERSION
	var cfg := ConfigFile.new()
	if FileAccess.file_exists(Updater.PCK) and cfg.load(Updater.CFG) == OK:
		var v: String = cfg.get_value("update", "version", "0")
		if Updater.newer(v, base) and ProjectSettings.load_resource_pack(Updater.PCK):
			print("Mise à jour chargée : ", v)
		else:
			DirAccess.remove_absolute(Updater.PCK)  # obsolète (programme plus récent) ou illisible
	get_tree().change_scene_to_file.call_deferred("res://main.tscn")
