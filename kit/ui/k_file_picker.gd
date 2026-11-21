extends "res://kit/ui/k_modal.gd"
## Sélecteur de fichiers (remplace FileDialog) : navigation dans les dossiers, sélection multiple.
signal files_selected(paths: PackedStringArray)
const Row := preload("res://kit/ui/k_list_row.gd")
var dir := ""
var multi := true
var picked: Array = []
var _list: VBoxContainer
var _path_l: Label
var _ok: Control
var show_hidden := false

func _init() -> void:
	super()
	title = "Choisir des fichiers"
	max_w = 480

func open_in(host: Node, start := "") -> void:
	dir = start if start != "" and DirAccess.dir_exists_absolute(start) else OS.get_environment("HOME")
	_ensure()
	_path_l = KS.label(body, "", Tokens.FS_XS, Tokens.text_muted, 400, true)
	var sc := ScrollContainer.new()
	sc.custom_minimum_size.y = 280
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(sc)
	_list = KS.vbox(sc, Tokens.S1)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_button("Annuler", "secondary", "")
	_ok = Btn.make("Ajouter", "primary")
	_ok.pressed.connect(func():
		files_selected.emit(PackedStringArray(picked))
		close("ok"))
	foot.add_child(_ok)
	foot.visible = true
	_fill()
	popup(host)

func _fill() -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_path_l.text = dir
	_ok.disabled = picked.is_empty()
	_ok.text = "Ajouter (%d)" % picked.size() if picked.size() > 0 else "Ajouter"
	var up := Row.make("Dossier parent", "", "chevron-left")
	up.pressed.connect(func():
		dir = dir.get_base_dir()
		_fill())
	_list.add_child(up)
	var dirs := DirAccess.get_directories_at(dir)
	var files := DirAccess.get_files_at(dir)
	dirs.sort()
	files.sort()
	for d in dirs:
		if d.begins_with(".") and not show_hidden:
			continue
		var r := Row.make(d, "", "folder-open")
		var full := dir.path_join(d)
		r.pressed.connect(func():
			dir = full
			_fill())
		_list.add_child(r)
	for f in files:
		if f.begins_with(".") and not show_hidden:
			continue
		var full2 := dir.path_join(f)
		var r2 := Row.make(f, "", "file-text")
		if full2 in picked:
			r2.selected = true
		r2.pressed.connect(func():
			if full2 in picked:
				picked.erase(full2)
			else:
				if not multi:
					picked.clear()
				picked.append(full2)
			_fill())
		_list.add_child(r2)
