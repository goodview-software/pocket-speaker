extends VBoxContainer
## Onglets : add_tab(id, libellé, contenu) ; soulignement animé ; défile horizontalement si trop étroit.
signal tab_changed(id: String)
const Tokens := preload("res://kit/tokens.gd")
const KS := preload("res://kit/ui/ks.gd")
const Press := preload("res://kit/ui/k_press.gd")
var tabs: Array = []  # [id, label, content]
var current := ""
var bar: HBoxContainer
var _btns := {}
var stack: Control

class Tab extends Press:
	var text := ""
	var active := false: set = _sa
	func _sa(v: bool) -> void:
		active = v
		queue_redraw()
	func _get_minimum_size() -> Vector2:
		return Vector2(KS.text_w(text, Tokens.FS_SM, 600) + Tokens.S4 * 2, Tokens.TOUCH)
	func k_overflow() -> bool:
		return size.x + 1.0 < _get_minimum_size().x
	func k_colors() -> Array:
		return [[Tokens.accent_fg if active else Tokens.text_muted, Tokens.surface0]]
	func _draw() -> void:
		var col := Tokens.accent_fg if active else Tokens.text_muted.lerp(Tokens.text, hover)
		KS.draw_text(self, text, 0, size.y * 0.5, Tokens.FS_SM, col, 600, size.x, HORIZONTAL_ALIGNMENT_CENTER)
		if active:
			draw_rect(Rect2(Tokens.S2, size.y - 2, size.x - Tokens.S4, 2), Tokens.accent)
		draw_ring(Rect2(Vector2.ZERO, size), Tokens.R_SM)

func _init() -> void:
	add_theme_constant_override("separation", Tokens.S3)
	var sc := ScrollContainer.new()
	sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.custom_minimum_size.y = Tokens.TOUCH + 2
	add_child(sc)
	bar = KS.hbox(sc, 0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stack = Control.new()
	stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(stack)

func add_tab(id: String, label: String, content: Control) -> void:
	var b := Tab.new()
	b.text = label
	b.pressed.connect(func(): select(id))
	bar.add_child(b)
	_btns[id] = b
	var holder := VBoxContainer.new()
	holder.visible = false
	holder.add_child(content)
	stack.add_child(holder)
	tabs.append([id, label, holder])
	if current == "":
		select(id)

func select(id: String) -> void:
	current = id
	for t in tabs:
		t[2].visible = t[0] == id
		_btns[t[0]].active = t[0] == id
	stack.custom_minimum_size.y = 0
	for t in tabs:
		if t[0] == id:
			stack.custom_minimum_size.y = t[2].get_combined_minimum_size().y
			t[2].set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tab_changed.emit(id)
