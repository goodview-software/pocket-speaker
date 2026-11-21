extends VBoxContainer
## Section : titre (+ sous-titre, + zone d'actions à droite) et contenu (add_content).
const Tokens := preload("res://kit/tokens.gd")
const KS := preload("res://kit/ui/ks.gd")
var title_l: Label
var sub_l: Label
var head_right: HBoxContainer
var content: VBoxContainer

static func make(title: String, sub := "") -> VBoxContainer:
	var s: VBoxContainer = load("res://kit/ui/k_section.gd").new()
	s.setup(title, sub)
	return s

func setup(title: String, sub := "") -> void:
	add_theme_constant_override("separation", Tokens.S3)
	var h := KS.hbox(self, Tokens.S3)
	var v := KS.vbox(h, 0)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_l = KS.label(v, title, Tokens.FS_LG, null, 600, true)
	sub_l = KS.label(v, sub, Tokens.FS_SM, Tokens.text_muted, 400, true)
	sub_l.visible = sub != ""
	head_right = KS.hbox(h, Tokens.S2)
	content = KS.vbox(self, Tokens.S3)

func add_content(n: Node) -> Node:
	content.add_child(n)
	return n
