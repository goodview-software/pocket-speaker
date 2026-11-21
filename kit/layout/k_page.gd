extends Control
## Page : en-tête (retour, titre, actions) + contenu défilant dans un KContainer ; zones sûres téléphone ; signal breakpoint_changed.
signal breakpoint_changed(bp: String)
signal back_pressed
const Tokens := preload("res://kit/tokens.gd")
const KS := preload("res://kit/ui/ks.gd")
const Btn := preload("res://kit/ui/k_button.gd")
const KContainer := preload("res://kit/layout/k_container.gd")
var has_back := true
var bp := ""
var head_title: Label
var head_right: HBoxContainer
var head_left: HBoxContainer
var body: VBoxContainer
var scroll: ScrollContainer
var header: Control
var back_btn: Control
var _outer: VBoxContainer
var _hc: Container
var _bc: Container
var safe := Rect2()
var scroll_margin_bottom := Tokens.S8

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func build_shell() -> void:
	_outer = VBoxContainer.new()
	_outer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_outer.add_theme_constant_override("separation", 0)
	add_child(_outer)
	var top := _safe_top()
	if top > 0:
		var sp := Control.new()
		sp.custom_minimum_size.y = top
		_outer.add_child(sp)
	_hc = KContainer.new()
	_hc.pad_v = Tokens.S3
	_hc.breakpoint_changed.connect(_on_bp)
	_outer.add_child(_hc)
	var head := KS.hbox(null, Tokens.S3)
	head_left = KS.hbox(head, Tokens.S2)
	head_title = KS.label(head, "", Tokens.FS_2XL, null, 700, true)
	head_title.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	head_right = KS.hbox(head, Tokens.S2)
	if has_back:
		back_btn = Btn.make("", "icon", "md", "chevron-left")
		back_btn.pressed.connect(func(): back_pressed.emit())
		head_left.add_child(back_btn)
		head.move_child(head_left, 0)
	_hc.add_child(head)
	header = head
	scroll = ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_outer.add_child(scroll)
	_bc = KContainer.new()
	_bc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bc.pad_v = 0
	scroll.add_child(_bc)
	var holder := VBoxContainer.new()
	holder.add_theme_constant_override("separation", 0)
	_bc.add_child(holder)
	body = KS.vbox(holder, Tokens.S6)
	var pad := Control.new()
	pad.custom_minimum_size.y = scroll_margin_bottom + _safe_bottom()
	holder.add_child(pad)

func _safe_top() -> float:
	if OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		return maxf(0.0, DisplayServer.get_display_safe_area().position.y)
	return 0.0

func _safe_bottom() -> float:
	if OS.has_feature("mobile") and DisplayServer.get_name() != "headless":
		var s := DisplayServer.get_display_safe_area()
		return maxf(0.0, DisplayServer.screen_get_size().y - s.end.y)
	return 0.0

func _on_bp(b: String) -> void:
	bp = b
	breakpoint_changed.emit(b)

func set_title(t: String) -> void:
	if head_title != null:
		head_title.text = t
