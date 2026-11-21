extends HFlowContainer
## Rangée qui passe à la ligne si l'espace manque, gouttière tokenisée.
const Tokens := preload("res://kit/tokens.gd")
var gap := Tokens.S2: set = _g
func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("h_separation", gap)
	add_theme_constant_override("v_separation", gap)
func _g(v: int) -> void:
	gap = v
	add_theme_constant_override("h_separation", v)
	add_theme_constant_override("v_separation", v)
