extends RefCounted
## Thème Godot complet généré à partir des tokens (Label, Button, LineEdit, TextEdit, RichTextLabel, ScrollBar, Tabs, Popup, Tooltip…).
const T := preload("res://kit/tokens.gd")
const Fonts := preload("res://kit/fonts.gd")
const KS := preload("res://kit/ui/ks.gd")

static func build() -> Theme:
	var th := Theme.new()
	var f400 := Fonts.weight(400)
	th.default_font = f400
	th.default_font_size = T.FS_BASE
	var empty := StyleBoxEmpty.new()
	# Label
	th.set_color("font_color", "Label", T.text)
	th.set_constant("line_spacing", "Label", T.line_extra(T.FS_BASE))
	# Button (repli pour les Button natifs encore utilisés)
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		var bg := T.surface3
		if st == "hover":
			bg = bg.lightened(0.08)
		elif st == "pressed":
			bg = bg.darkened(0.1)
		var sb := KS.box(bg, T.R_MD, T.S4, T.S2)
		if st == "focus":
			sb = KS.box(Color(0, 0, 0, 0), T.R_MD, T.S4, T.S2, T.ring_color(), 2)
		th.set_stylebox(st, "Button", sb)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		th.set_color(c, "Button", T.text)
	th.set_color("font_disabled_color", "Button", T.text_muted)
	th.set_font("font", "Button", Fonts.weight(500))
	th.set_font_size("font_size", "Button", T.FS_SM)
	# Champs
	for typ in ["LineEdit", "TextEdit"]:
		for st in ["normal", "read_only"]:
			th.set_stylebox(st, typ, KS.box(T.surface3, T.R_MD, T.S3, T.S3))
		th.set_stylebox("focus", typ, KS.box(T.surface3, T.R_MD, T.S3, T.S3, T.ring_color(), 2))
		th.set_color("font_color", typ, T.text)
		th.set_color("font_placeholder_color", typ, T.text_muted)
		th.set_color("caret_color", typ, T.accent)
		th.set_color("selection_color", typ, Color(T.accent, 0.3))
		th.set_color("font_selected_color", typ, T.text)
	# RichTextLabel
	th.set_color("default_color", "RichTextLabel", T.text)
	th.set_color("selection_color", "RichTextLabel", Color(T.accent, 0.3))
	th.set_font("normal_font", "RichTextLabel", f400)
	th.set_font("bold_font", "RichTextLabel", Fonts.weight(700))
	th.set_font("bold_italics_font", "RichTextLabel", Fonts.weight(700))
	th.set_font("italics_font", "RichTextLabel", f400)
	th.set_font_size("normal_font_size", "RichTextLabel", T.FS_BASE)
	th.set_font_size("bold_font_size", "RichTextLabel", T.FS_BASE)
	th.set_constant("line_separation", "RichTextLabel", T.line_extra(T.FS_BASE))
	# Barres de défilement fines et arrondies
	for typ in ["VScrollBar", "HScrollBar"]:
		var g := KS.box(Color(1, 1, 1, 0.16), T.R_FULL, 3)
		var gh := KS.box(Color(1, 1, 1, 0.28), T.R_FULL, 3)
		th.set_stylebox("grabber", typ, g)
		th.set_stylebox("grabber_highlight", typ, gh)
		th.set_stylebox("grabber_pressed", typ, KS.box(Color(T.accent, 0.7), T.R_FULL, 3))
		th.set_stylebox("scroll", typ, empty)
		th.set_stylebox("scroll_focus", typ, empty)
	th.set_stylebox("focus", "ScrollContainer", empty)
	# Onglets
	th.set_stylebox("panel", "TabContainer", KS.box(Color(0, 0, 0, 0), 0, 0))
	for st in ["tab_selected", "tab_unselected", "tab_hovered", "tab_focus", "tab_disabled"]:
		var col := Color(0, 0, 0, 0)
		if st == "tab_selected":
			col = T.surface3
		elif st == "tab_hovered":
			col = T.surface2
		th.set_stylebox(st, "TabContainer", KS.box(col, T.R_MD, T.S4, T.S2))
		th.set_stylebox(st, "TabBar", KS.box(col, T.R_MD, T.S4, T.S2))
	for typ in ["TabContainer", "TabBar"]:
		th.set_color("font_selected_color", typ, T.text)
		th.set_color("font_unselected_color", typ, T.text_muted)
		th.set_color("font_hovered_color", typ, T.text)
		th.set_font("font", typ, Fonts.weight(500))
	# Menus et infobulles
	th.set_stylebox("panel", "PopupMenu", T.shadow(KS.box(T.surface2, T.R_LG, T.S2, T.S2, T.border_strong, 1), 3))
	th.set_stylebox("hover", "PopupMenu", KS.box(Color(1, 1, 1, 0.08), T.R_SM, T.S2))
	th.set_stylebox("separator", "PopupMenu", KS.box(T.border, 0, 0))
	th.set_color("font_color", "PopupMenu", T.text)
	th.set_color("font_hover_color", "PopupMenu", T.text)
	th.set_constant("v_separation", "PopupMenu", T.S2)
	th.set_stylebox("panel", "TooltipPanel", T.shadow(KS.box(T.surface3, T.R_SM, T.S3, T.S2, T.border_strong, 1), 2))
	th.set_color("font_color", "TooltipLabel", T.text)
	th.set_font_size("font_size", "TooltipLabel", T.FS_XS)
	# Progression, curseurs
	th.set_stylebox("background", "ProgressBar", KS.box(T.surface3, T.R_FULL, 0))
	th.set_stylebox("fill", "ProgressBar", KS.box(T.accent, T.R_FULL, 0))
	th.set_constant("outline_size", "ProgressBar", 0)
	for typ in ["HSlider", "VSlider"]:
		var sl := KS.box(T.surface3, T.R_FULL, 0, 2)
		th.set_stylebox("slider", typ, sl)
		th.set_stylebox("grabber_area", typ, KS.box(T.accent, T.R_FULL, 0, 2))
		th.set_stylebox("grabber_area_highlight", typ, KS.box(T.accent, T.R_FULL, 0, 2))
	# Cases, OptionButton
	th.set_color("font_color", "CheckBox", T.text)
	th.set_color("font_color", "CheckButton", T.text)
	th.set_color("font_color", "OptionButton", T.text)
	th.set_stylebox("panel", "PanelContainer", KS.box(T.surface1, T.R_LG, 0))
	th.set_stylebox("separator", "HSeparator", KS.box(T.border, 0, 0, 0))
	th.set_constant("separation", "HSeparator", 1)
	return th
