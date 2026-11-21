extends BoxContainer
## 2 colonnes (principale + latérale) quand la largeur propre >= wide_at (lg une fois les marges retirées), sinon 1 colonne empilée.
## Basé sur BoxContainer (bascule vertical/horizontal) : hauteurs et retours à la ligne gérés nativement. Deux enfants.
signal layout_changed(wide: bool)
const Tokens := preload("res://kit/tokens.gd")
var side_width := 340
var gap := Tokens.S6: set = _setgap
var wide_at := 880
var side_first := false
var wide := false

func _init() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_theme_constant_override("separation", gap)
	resized.connect(_adapt)
	child_entered_tree.connect(func(_c): _adapt.call_deferred())

func _setgap(v: int) -> void:
	gap = v
	add_theme_constant_override("separation", v)

func _adapt() -> void:
	var kids: Array = []
	for c in get_children():
		if c is Control and c.visible:
			kids.append(c)
	if kids.size() < 2:
		return
	var w := size.x >= wide_at
	wide = w
	vertical = not w
	var main_c: Control = kids[1] if side_first else kids[0]
	var side_c: Control = kids[0] if side_first else kids[1]
	if w:
		side_c.custom_minimum_size.x = side_width
		side_c.size_flags_horizontal = Control.SIZE_FILL
		side_c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		main_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_c.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	else:
		side_c.custom_minimum_size.x = 0
		side_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		side_c.size_flags_vertical = Control.SIZE_FILL
		main_c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		main_c.size_flags_vertical = Control.SIZE_FILL
	layout_changed.emit(w)
