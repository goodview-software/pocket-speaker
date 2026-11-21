extends "res://kit/ui/k_card.gd"
## Ligne de liste : icône, titre, sous-titre, zone trailing (nœuds ajoutés avec add_trailing) et chevron si interactive.
const Icon := preload("res://kit/icon.gd")
var title_l: Label
var sub_l: Label
var lead: Control
var trail: HBoxContainer

static func make(title: String, sub := "", ico := "", interactive_ := true) -> Control:
	var r: Control = load("res://kit/ui/k_list_row.gd").new()
	r.setup(title, sub, ico)
	r.interactive = interactive_
	return r

func setup(title: String, sub := "", ico := "") -> void:
	flat = true
	pad = Tokens.S3
	radius = Tokens.R_MD
	custom_minimum_size.y = Tokens.TOUCH
	var h := KS.hbox(self, Tokens.S3)
	if ico != "":
		var holder := PanelContainer.new()
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		holder.add_theme_stylebox_override("panel", KS.box(Tokens.surface3, Tokens.R_MD, Tokens.S2))
		h.add_child(holder)
		lead = Icon.make(ico, 20, Tokens.accent_fg)
		holder.add_child(lead)
	var v := KS.vbox(h, 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_l = KS.label(v, title, Tokens.FS_BASE, null, 500, true)
	sub_l = KS.label(v, sub, Tokens.FS_SM, Tokens.text_muted, 400, true)
	sub_l.visible = sub != ""
	trail = KS.hbox(h, Tokens.S2)
	trail.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_apply()

func add_trailing(n: Control) -> void:
	trail.add_child(n)

func set_chevron() -> void:
	add_trailing(Icon.make("chevron-right", 20, Tokens.text_muted))
