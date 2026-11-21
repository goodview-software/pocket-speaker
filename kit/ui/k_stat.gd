extends VBoxContainer
## Statistique : valeur (grande) + légende.
const Tokens := preload("res://kit/tokens.gd")
const KS := preload("res://kit/ui/ks.gd")
var value_l: Label
var caption_l: Label
static func make(value: String, caption: String) -> VBoxContainer:
	var s: VBoxContainer = load("res://kit/ui/k_stat.gd").new()
	s.setup(value, caption)
	return s
func setup(value: String, caption: String) -> void:
	add_theme_constant_override("separation", 0)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	value_l = KS.label(self, value, Tokens.FS_2XL, null, 700, true)
	caption_l = KS.label(self, caption, Tokens.FS_SM, Tokens.text_muted, 400, true)
