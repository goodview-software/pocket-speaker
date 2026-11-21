extends GridContainer
## Clé / valeur alignées en 2 colonnes ; passe en 1 colonne quand c'est trop étroit.
const Tokens := preload("res://kit/tokens.gd")
const KS := preload("res://kit/ui/ks.gd")
var _rows: Array = []
func _init() -> void:
	columns = 2
	add_theme_constant_override("h_separation", Tokens.S4)
	add_theme_constant_override("v_separation", Tokens.S2)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	resized.connect(_adapt)
func add_row(key: String, value: String) -> Label:
	var k := KS.label(self, key, Tokens.FS_SM, Tokens.text_muted, 400, false)
	k.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	var v := KS.label(self, value, Tokens.FS_SM, null, 500, true)
	_rows.append([k, v])
	return v
func _adapt() -> void:
	var want := 1 if size.x < 320 else 2
	if columns != want:
		columns = want
