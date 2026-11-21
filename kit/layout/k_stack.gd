extends VBoxContainer
## Pile verticale avec gouttière tokenisée (gap = Tokens.S*).
const Tokens := preload("res://kit/tokens.gd")
var gap := Tokens.S4: set = _g
func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", gap)
func _g(v: int) -> void:
	gap = v
	add_theme_constant_override("separation", v)
