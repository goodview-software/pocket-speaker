extends Control
## Toasts empilés en bas, auto-disparition. Ajouter un KToast plein écran à la racine puis push(texte, kind, action, cb).
const Tokens := preload("res://kit/tokens.gd")
const KS := preload("res://kit/ui/ks.gd")
const Icon := preload("res://kit/icon.gd")
const Btn := preload("res://kit/ui/k_button.gd")
const MAX := 3
var stack: VBoxContainer
var instant := false

func _init() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 3800
	set_meta("k_overlay", true)
	stack = VBoxContainer.new()
	stack.add_theme_constant_override("separation", Tokens.S2)
	stack.alignment = BoxContainer.ALIGNMENT_END
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(stack)
	resized.connect(_layout)

func _layout() -> void:
	var w := minf(420.0, size.x - Tokens.S8)
	stack.custom_minimum_size.x = maxf(w, 1.0)
	stack.reset_size()
	stack.position = Vector2((size.x - stack.size.x) * 0.5, size.y - stack.size.y - Tokens.S6)

func _process(_dt: float) -> void:
	_layout()

## kind : info | success | warn | danger
func push(text: String, kind := "info", action := "", cb := Callable(), ttl := 3.5) -> Control:
	while stack.get_child_count() >= MAX:
		var old := stack.get_child(0)
		stack.remove_child(old)
		old.queue_free()
	var col: Color = {"success": Tokens.success, "warn": Tokens.warn, "danger": Tokens.danger}.get(kind, Tokens.info)
	var ico: String = {"success": "circle-check", "warn": "info", "danger": "circle-x"}.get(kind, "info")
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", Tokens.shadow(KS.box(Tokens.surface2, Tokens.R_LG, Tokens.S3, Tokens.S3, Tokens.border_strong, 1), 3))
	p.mouse_filter = Control.MOUSE_FILTER_STOP
	var h := KS.hbox(p, Tokens.S3)
	var ic := Icon.make(ico, 20, col)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := KS.label(h, text, Tokens.FS_SM, null, 500, true)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if action != "":
		var b := Btn.make(action, "ghost", "sm")
		b.pressed.connect(func(): if cb.is_valid(): cb.call(); _dismiss(p))
		h.add_child(b)
	stack.add_child(p)
	if instant or not is_inside_tree():
		p.modulate.a = 1.0
	else:
		p.modulate.a = 0.0
		create_tween().tween_property(p, "modulate:a", 1.0, Tokens.DUR)
		get_tree().create_timer(ttl).timeout.connect(_dismiss.bind(p))
	return p

func _dismiss(p: Variant) -> void:
	if not is_instance_valid(p) or p.is_queued_for_deletion():
		return
	var tw := create_tween()
	tw.tween_property(p, "modulate:a", 0.0, Tokens.DUR)
	tw.finished.connect(func(): if is_instance_valid(p): p.queue_free())
