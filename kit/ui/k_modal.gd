extends Control
## Modale moderne : voile sombre (flou optionnel), carte centrée <= 480 px, fondu + zoom 0.96->1,
## Échap / clic hors carte pour fermer, piège de focus, boutons alignés à droite, variante danger.
## Utilisation : var m = KModal.new(); m.title = "..."; m.add_text("..."); m.add_button("OK", "primary", "ok"); m.popup(host)
signal result(id: String)
const Tokens := preload("res://kit/tokens.gd")
const KS := preload("res://kit/ui/ks.gd")
const Icon := preload("res://kit/icon.gd")
const Btn := preload("res://kit/ui/k_button.gd")
const BLUR := "shader_type canvas_item;\nuniform float lod : hint_range(0.0, 5.0) = 2.0;\nuniform sampler2D tex : hint_screen_texture, filter_linear_mipmap;\nvoid fragment(){ vec4 c = textureLod(tex, SCREEN_UV, lod); COLOR = vec4(c.rgb * 0.45, 1.0); }\n"
var title := ""
var subtitle := ""
var danger := false
var dismissable := true
var max_w := 480
var sheet := false
var blur := true
var scrim: ColorRect
var card: PanelContainer
var body: VBoxContainer
var foot: HFlowContainer
var scroll: ScrollContainer
var closing := false
var _inner: VBoxContainer
var _prev_focus: Control
var _open_t := 0.0: set = _set_open

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 3000
	set_meta("k_overlay", true)

func _ensure() -> void:
	if card != null:
		return
	scrim = ColorRect.new()
	scrim.color = Color(0, 0, 0, 0.55)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", Tokens.shadow(KS.box(Tokens.surface1, Tokens.R_XL if not sheet else Tokens.R_XL, Tokens.S6, Tokens.S6, Tokens.border_strong, 1), 3))
	card.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(card)
	_inner = KS.vbox(card, Tokens.S4)
	if sheet:
		var hnd := Control.new()
		hnd.custom_minimum_size = Vector2(0, 4)
		hnd.draw.connect(func(): hnd.draw_style_box(KS.box(Tokens.border_strong, Tokens.R_FULL), Rect2((hnd.size.x - 40) * 0.5, 0, 40, 4)))
		_inner.add_child(hnd)
	if title != "":
		var hr := KS.hbox(_inner, Tokens.S3)
		if danger:
			var ib := PanelContainer.new()
			ib.add_theme_stylebox_override("panel", KS.box(Color(Tokens.danger, 0.15), Tokens.R_FULL, Tokens.S2))
			ib.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			hr.add_child(ib)
			ib.add_child(Icon.make("trash-2", 20, Tokens.danger))
		var tv := KS.vbox(hr, Tokens.S1)
		tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		KS.label(tv, title, Tokens.FS_XL, null, 600, true)
		if subtitle != "":
			KS.label(tv, subtitle, Tokens.FS_SM, Tokens.text_muted, 400, true)
		if dismissable and not sheet:
			var x: Control = Btn.make("", "icon", "sm", "x")
			x.pressed.connect(func(): close(""))
			x.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			hr.add_child(x)
	scroll = ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_inner.add_child(scroll)
	body = KS.vbox(scroll, Tokens.S3)
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot = load("res://kit/layout/k_row.gd").new()
	_inner.add_child(foot)
	foot.alignment = FlowContainer.ALIGNMENT_END
	foot.last_wrap_alignment = FlowContainer.LAST_WRAP_ALIGNMENT_END
	foot.visible = false

func add_text(t: String, muted := true) -> Label:
	_ensure()
	return KS.label(body, t, Tokens.FS_BASE if not muted else Tokens.FS_SM, Tokens.text_muted if muted else null, 400, true)

func add_body(n: Control) -> Control:
	_ensure()
	body.add_child(n)
	return n

func add_button(text: String, kind: String, id: String, icon := "") -> Control:
	_ensure()
	foot.visible = true
	var b := Btn.make(text, kind, "md", icon)
	b.pressed.connect(func(): close(id))
	foot.add_child(b)
	return b

func popup(host: Node) -> void:
	_ensure()
	_prev_focus = host.get_viewport().gui_get_focus_owner() if host.is_inside_tree() else null
	host.add_child(self)
	if blur:
		var sh := Shader.new()
		sh.code = BLUR
		var m := ShaderMaterial.new()
		m.shader = sh
		var bl := ColorRect.new()
		bl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bl.material = m
		add_child(bl)
		move_child(bl, 0)
	resized.connect(_layout)
	_layout()
	_open_t = 0.0
	var instant: bool = get_meta("instant", false)
	if instant or not is_inside_tree():
		_open_t = 1.0
	else:
		create_tween().tween_property(self, "_open_t", 1.0, Tokens.DUR * 1.4).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_focus_first.call_deferred()

func _set_open(v: float) -> void:
	_open_t = v
	if card == null:
		return
	modulate.a = v if not sheet else 1.0
	scrim.color.a = 0.55 * v
	if sheet:
		card.position.y = lerpf(size.y, size.y - card.size.y, ease(v, 0.25))
	else:
		card.scale = Vector2.ONE * lerpf(0.96, 1.0, v)

func _layout() -> void:
	if card == null:
		return
	var margin := Tokens.S4
	var w := minf(float(max_w) if not sheet else 560.0, size.x - (margin * 2 if not sheet else 0))
	w = maxf(w, 1.0)
	var avail := size.y - margin * 2
	scroll.custom_minimum_size.y = 0
	card.custom_minimum_size.x = w
	card.reset_size()
	var over := card.size.y - avail
	if over > 0:
		scroll.custom_minimum_size.y = maxf(48.0, body.get_combined_minimum_size().y - over)
		card.reset_size()
	scroll.size_flags_vertical = Control.SIZE_FILL
	card.size.x = w
	card.pivot_offset = card.size * 0.5
	if sheet:
		card.position.x = (size.x - w) * 0.5
		card.position.y = lerpf(size.y, size.y - card.size.y, ease(_open_t, 0.25))
	else:
		card.position = ((size - card.size) * 0.5).floor()

func _focus_first() -> void:
	var f := _focusables()
	if not f.is_empty():
		f[0].grab_focus()

func _focusables() -> Array:
	var out: Array = []
	var st: Array = [card]
	while not st.is_empty():
		var n: Node = st.pop_back()
		for c in n.get_children():
			st.append(c)
		if n is Control and n != card and (n as Control).focus_mode == Control.FOCUS_ALL and (n as Control).is_visible_in_tree() and not n.has_meta("k_inner_skip"):
			out.append(n)
	out.sort_custom(func(a: Control, b: Control): return _order(a) < _order(b))
	return out

func _order(c: Control) -> float:
	var p := c.global_position
	return p.y * 10000.0 + p.x

func _input(e: InputEvent) -> void:
	if closing or not is_visible_in_tree():
		return
	if e is InputEventKey and e.pressed:
		if e.keycode == KEY_ESCAPE:
			if dismissable:
				close("")
			get_viewport().set_input_as_handled()
		elif e.keycode == KEY_TAB:
			var f := _focusables()
			if not f.is_empty():
				var cur := get_viewport().gui_get_focus_owner()
				var i := f.find(cur)
				if i < 0 and cur != null:
					for k in f.size():
						if (f[k] as Node).is_ancestor_of(cur):
							i = k
				i = (i + (-1 if e.shift_pressed else 1) + f.size()) % f.size()
				f[i].grab_focus()
			get_viewport().set_input_as_handled()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and dismissable:
		if not card.get_global_rect().has_point(e.global_position):
			close("")
	accept_event()

func close(id := "") -> void:
	if closing:
		return
	closing = true
	result.emit(id)
	var finish := func():
		if is_instance_valid(_prev_focus) and _prev_focus.is_inside_tree():
			_prev_focus.grab_focus()
		queue_free()
	if get_meta("instant", false) or not is_inside_tree():
		finish.call()
		return
	var tw := create_tween()
	tw.tween_property(self, "_open_t", 0.0, Tokens.DUR)
	tw.finished.connect(finish)
