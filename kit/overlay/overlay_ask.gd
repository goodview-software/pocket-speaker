extends RefCounted
## Écran d'explication « afficher par-dessus les autres applis », montré une seule fois au premier besoin.

static func ask_once(host: Control, ov: Node, app_name: String, flag_path: String) -> void:
	if not ov.available() or ov.has_permission():
		return
	var cf := ConfigFile.new()
	cf.load(flag_path)
	if bool(cf.get_value("overlay", "asked", false)):
		return
	cf.set_value("overlay", "asked", true)
	cf.save(flag_path)
	var dlg := ConfirmationDialog.new()
	dlg.title = "Bulle flottante"
	dlg.dialog_text = "Quand tu quittes %s, une petite bulle reste affichée par-dessus les autres applis : elle montre l'état de la liaison et un toucher rouvre l'app.\n\nAndroid va te demander l'autorisation « Afficher par-dessus les autres applis » : active-la pour %s." % [app_name, app_name]
	dlg.ok_button_text = "Autoriser"
	dlg.cancel_button_text = "Plus tard"
	dlg.confirmed.connect(ov.request_permission)
	dlg.canceled.connect(dlg.queue_free)
	dlg.confirmed.connect(dlg.queue_free)
	host.add_child(dlg)
	dlg.popup_centered(Vector2i(440, 300))
