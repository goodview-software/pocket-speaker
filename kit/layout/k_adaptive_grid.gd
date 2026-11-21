extends GridContainer
## Grille adaptative : colonnes = floor(largeur / min_card_width), gouttières tokenisées, cartes de hauteur égale par ligne
## (GridContainer natif : toutes les cellules d'une ligne prennent la hauteur de la plus haute).
const Tokens := preload("res://kit/tokens.gd")
var min_card_width := 280: set = _smw
var gap := Tokens.S4: set = _sg
var max_columns := 6

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("h_separation", gap)
	add_theme_constant_override("v_separation", gap)
	resized.connect(_adapt)
	child_entered_tree.connect(_on_child)

func _on_child(c: Node) -> void:
	if c is Control:
		(c as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
		(c as Control).size_flags_vertical = Control.SIZE_FILL
		(c as Control).custom_minimum_size.x = 0

func _smw(v: int) -> void:
	min_card_width = v
	_adapt()

func _sg(v: int) -> void:
	gap = v
	add_theme_constant_override("h_separation", v)
	add_theme_constant_override("v_separation", v)
	_adapt()

func cols_for(w: float) -> int:
	return clampi(int(floor((w + gap) / (min_card_width + gap))), 1, max_columns)

func _adapt() -> void:
	var n := cols_for(size.x)
	if columns != n:
		columns = n
