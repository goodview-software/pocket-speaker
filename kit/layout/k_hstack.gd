extends HBoxContainer
## Rangée sans retour à la ligne (HBox) avec gouttière tokenisée.
const Tokens := preload("res://kit/tokens.gd")
var gap := Tokens.S2: set = _g
func _init() -> void:
	add_theme_constant_override("separation", gap)
func _g(v: int) -> void:
	gap = v
	add_theme_constant_override("separation", v)
