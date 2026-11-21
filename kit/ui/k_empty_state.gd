extends VBoxContainer
## État vide : mascotte (texture) ou icône + titre + message + action optionnelle.
signal action
const Tokens := preload("res://kit/tokens.gd")
const KS := preload("res://kit/ui/ks.gd")
const Icon := preload("res://kit/icon.gd")
const Btn := preload("res://kit/ui/k_button.gd")
var btn: Control
var title_l: Label
var msg_l: Label
var secondary: Control

static func make(title: String, msg := "", ico := "package", action_text := "", mascot: Texture2D = null) -> VBoxContainer:
	var s: VBoxContainer = load("res://kit/ui/k_empty_state.gd").new()
	s.setup(title, msg, ico, action_text, mascot)
	return s

func setup(title: String, msg := "", ico := "package", action_text := "", mascot: Texture2D = null) -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", Tokens.S3)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var holder := CenterContainer.new()
	add_child(holder)
	if mascot != null:
		var tr := TextureRect.new()
		tr.texture = mascot
		tr.custom_minimum_size = Vector2(96, 96)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(tr)
	else:
		var pc := PanelContainer.new()
		pc.add_theme_stylebox_override("panel", KS.box(Tokens.surface3, Tokens.R_XL, Tokens.S4))
		pc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(pc)
		pc.add_child(Icon.make(ico, 32, Tokens.accent_fg))
	title_l = KS.label(self, title, Tokens.FS_XL, null, 600, true)
	title_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if msg != "":
		msg_l = KS.label(self, msg, Tokens.FS_SM, Tokens.text_muted, 400, true)
		msg_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if action_text != "":
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", Tokens.S2)
		add_child(row)
		btn = Btn.make(action_text, "primary")
		btn.pressed.connect(func(): action.emit())
		row.add_child(btn)

func add_secondary(text: String, cb: Callable) -> Control:
	var b := Btn.make(text, "secondary")
	b.pressed.connect(cb)
	var row: Node = btn.get_parent() if btn != null else null
	if row == null:
		row = HBoxContainer.new()
		(row as HBoxContainer).alignment = BoxContainer.ALIGNMENT_CENTER
		add_child(row)
	row.add_child(b)
	return b
