extends PanelContainer
## Infobulle arrondie : KTooltip.attach(control, "texte"). Remplace l'infobulle native.
const Tokens := preload("res://kit/tokens.gd")
const KS := preload("res://kit/ui/ks.gd")
var _l: Label
var _timer: SceneTreeTimer

static func attach(c: Control, txt: String) -> void:
	c.tooltip_text = ""
	var tip: PanelContainer = load("res://kit/ui/k_tooltip.gd").new()
	tip.setup(txt)
	c.mouse_entered.connect(func(): tip._show_for(c))
	c.mouse_exited.connect(func(): tip._hide())
	c.tree_exiting.connect(func(): if is_instance_valid(tip): tip.queue_free())

func setup(txt: String) -> void:
	top_level = true
	visible = false
	z_index = 4000
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_theme_stylebox_override("panel", Tokens.shadow(KS.box(Tokens.surface3, Tokens.R_SM, Tokens.S3, Tokens.S2, Tokens.border_strong, 1), 2))
	_l = KS.label(self, txt, Tokens.FS_XS, null, 500, false)

func _show_for(c: Control) -> void:
	if get_parent() == null:
		c.add_child(self)
	_timer = c.get_tree().create_timer(0.4)
	_timer.timeout.connect(_reveal.bind(c))

func _reveal(c: Control) -> void:
	if is_instance_valid(c) and c.get_global_rect().has_point(c.get_global_mouse_position()):
		visible = true
		reset_size()
		var vp := c.get_viewport_rect().size
		var p := Vector2(c.global_position.x + (c.size.x - size.x) * 0.5, c.global_position.y - size.y - Tokens.S2)
		if p.y < 4:
			p.y = c.global_position.y + c.size.y + Tokens.S2
		global_position = Vector2(clampf(p.x, 4, maxf(4, vp.x - size.x - 4)), p.y)

func _hide() -> void:
	visible = false
