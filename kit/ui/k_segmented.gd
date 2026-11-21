extends "res://kit/ui/k_press.gd"
## Sélecteur segmenté : options [[id, libellé], ...] ; indicateur animé.
signal changed(id: String)
var options: Array = []: set = _set_opts
var value := ""
var _pos := 0.0: set = _set_pos
var _hov := -1

func _init() -> void:
	super()
	custom_minimum_size.y = Tokens.TOUCH
	mouse_filter = Control.MOUSE_FILTER_STOP

func _set_opts(v: Array) -> void:
	options = v
	if value == "" and not v.is_empty():
		value = str(v[0][0])
	_pos = float(_idx())
	update_minimum_size()
	queue_redraw()

func _set_pos(v: float) -> void:
	_pos = v
	queue_redraw()

func _idx() -> int:
	for i in options.size():
		if str(options[i][0]) == value:
			return i
	return 0

func _natural() -> Array:
	var l: Array = []
	for o in options:
		l.append(KS.text_w(str(o[1]), Tokens.FS_SM, 600) + Tokens.S3 * 2)
	return l

func _get_minimum_size() -> Vector2:
	var t := 8.0
	for w in _natural():
		t += w
	return Vector2(t, Tokens.TOUCH)

func k_overflow() -> bool:
	return size.x + 1.0 < _get_minimum_size().x

## Positions [x, largeur] des segments, étirés pour remplir la largeur.
func _slots() -> Array:
	var nat := _natural()
	var tot := 0.0
	for w in nat:
		tot += w
	var k := (size.x - 8.0) / maxf(tot, 1.0)
	var out: Array = []
	var x := 4.0
	for w in nat:
		out.append([x, w * k])
		x += w * k
	return out

func set_value(id: String, anim := true) -> void:
	value = id
	if anim and is_inside_tree():
		create_tween().tween_property(self, "_pos", float(_idx()), Tokens.DUR).set_trans(Tween.TRANS_SINE)
	else:
		_pos = float(_idx())

func _gui_input(e: InputEvent) -> void:
	if disabled or options.is_empty():
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		var sl := _slots()
		var i := 0
		for k in sl.size():
			if e.position.x >= sl[k][0]:
				i = k
		if str(options[i][0]) != value:
			set_value(str(options[i][0]))
			changed.emit(value)
			pressed.emit()
		accept_event()
	elif e is InputEventKey and e.pressed and (e.keycode == KEY_LEFT or e.keycode == KEY_RIGHT):
		var i2 := clampi(_idx() + (1 if e.keycode == KEY_RIGHT else -1), 0, options.size() - 1)
		set_value(str(options[i2][0]))
		changed.emit(value)
		accept_event()

func k_colors() -> Array:
	return [[Tokens.text, Tokens.surface1], [Tokens.text_muted, Tokens.surface3]]

func _draw() -> void:
	if options.is_empty():
		return
	var r := Rect2(0, (size.y - 40) * 0.5, size.x, 40)
	draw_style_box(KS.box(Tokens.surface3, Tokens.R_MD), r)
	var sl := _slots()
	var i0 := clampi(int(floor(_pos)), 0, sl.size() - 1)
	var i1 := clampi(i0 + 1, 0, sl.size() - 1)
	var f: float = _pos - floor(_pos)
	var ix := lerpf(sl[i0][0], sl[i1][0], f)
	var iw := lerpf(sl[i0][1], sl[i1][1], f)
	draw_style_box(Tokens.shadow(KS.box(Tokens.surface1.lightened(0.06), Tokens.R_SM), 1), Rect2(ix, r.position.y + 4, iw, 32))
	draw_ring(r, Tokens.R_MD)
	for i in options.size():
		var sel := clampf(1.0 - absf(_pos - i), 0.0, 1.0)
		var col := Tokens.text_muted.lerp(Tokens.text, sel)
		KS.draw_text(self, str(options[i][1]), sl[i][0], size.y * 0.5, Tokens.FS_SM, Color(col, 0.42 if disabled else 1.0), 600, sl[i][1], HORIZONTAL_ALIGNMENT_CENTER)
