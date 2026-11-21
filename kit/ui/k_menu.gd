extends Control
## Menu contextuel arrondi avec ombre. items : [{id, label, icon?, danger?, sep?}]. KMenu.open(host, items, rect) ; signal chosen(id).
signal chosen(id: String)
const Tokens := preload("res://kit/tokens.gd")
const KS := preload("res://kit/ui/ks.gd")
const Icon := preload("res://kit/icon.gd")
const Press := preload("res://kit/ui/k_press.gd")
var panel: PanelContainer
var anchor := Rect2()
var closing := false

class Item extends Press:
	var label := ""
	var icon := ""
	var danger := false
	func _get_minimum_size() -> Vector2:
		return Vector2(KS.text_w(label, Tokens.FS_SM, 500) + Tokens.S3 * 2 + (28 if icon != "" else 0), Tokens.TOUCH)
	func k_overflow() -> bool:
		return size.x + 1.0 < _get_minimum_size().x
	func k_colors() -> Array:
		return [[Tokens.danger if danger else Tokens.text, Tokens.surface2]]
	func _draw() -> void:
		draw_style_box(KS.box(Color(1, 1, 1, 0.08 * hover + 0.05 * down), Tokens.R_SM), Rect2(Vector2.ZERO, size))
		var col := (Tokens.danger if danger else Tokens.text)
		col.a = 0.45 if disabled else 1.0
		var x := Tokens.S3
		if icon != "":
			var t := Icon.texture(icon, 16)
			if t != null:
				draw_texture_rect(t, Rect2(x, size.y * 0.5 - 8, 16, 16), false, col if danger else Tokens.text_muted)
			x += 28
		KS.draw_text(self, label, x, size.y * 0.5, Tokens.FS_SM, col, 500)
		draw_ring(Rect2(Vector2.ZERO, size), Tokens.R_SM)

static func open(host: Node, items: Array, at: Rect2) -> Control:
	var m: Control = load("res://kit/ui/k_menu.gd").new()
	m.build(items, at)
	host.add_child(m)
	m.call_deferred("_place")
	return m

func build(items: Array, at: Rect2) -> void:
	anchor = at
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 3500
	mouse_filter = Control.MOUSE_FILTER_STOP
	panel = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", Tokens.shadow(KS.box(Tokens.surface2, Tokens.R_LG, Tokens.S2, Tokens.S2, Tokens.border_strong, 1), 3))
	add_child(panel)
	var v := KS.vbox(panel, Tokens.S1)
	for it in items:
		if it.get("sep", false):
			var d: Control = load("res://kit/ui/k_divider.gd").new()
			v.add_child(d)
			continue
		var b := Item.new()
		b.label = str(it.label)
		b.icon = str(it.get("icon", ""))
		b.danger = it.get("danger", false)
		b.disabled = it.get("disabled", false)
		var id := str(it.id)
		b.pressed.connect(func(): chosen.emit(id); close())
		v.add_child(b)
	modulate.a = 0.0
	var f := v.get_child(0) if v.get_child_count() > 0 else null
	if f != null:
		(f as Control).grab_focus.call_deferred()

func _place() -> void:
	panel.reset_size()
	var w := maxf(panel.size.x, 180.0)
	panel.custom_minimum_size.x = w
	panel.reset_size()
	var p := Vector2(anchor.end.x - panel.size.x, anchor.end.y + Tokens.S1)
	if p.y + panel.size.y > size.y - 4:
		p.y = anchor.position.y - panel.size.y - Tokens.S1
	p.x = clampf(p.x, 4, maxf(4, size.x - panel.size.x - 4))
	p.y = clampf(p.y, 4, maxf(4, size.y - panel.size.y - 4))
	panel.position = p
	if is_inside_tree() and not get_meta("instant", false):
		create_tween().tween_property(self, "modulate:a", 1.0, Tokens.DUR)
	else:
		modulate.a = 1.0

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		close()
	accept_event()

func _input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.keycode == KEY_ESCAPE and not closing:
		close()
		get_viewport().set_input_as_handled()

func close() -> void:
	if closing:
		return
	closing = true
	queue_free()
