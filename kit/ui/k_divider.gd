extends Control
## Séparateur 1 px (horizontal par défaut), avec libellé centré optionnel.
const Tokens := preload("res://kit/tokens.gd")
const KS := preload("res://kit/ui/ks.gd")
var vertical := false
var text := ""
func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
func _ready() -> void:
	custom_minimum_size = Vector2(1, 0) if vertical else Vector2(0, 1 if text == "" else 20)
func k_colors() -> Array:
	return [[Tokens.text_muted, Tokens.surface1]] if text != "" else []
func _draw() -> void:
	if vertical:
		draw_rect(Rect2(size.x * 0.5, 0, 1, size.y), Tokens.border)
	elif text == "":
		draw_rect(Rect2(0, 0, size.x, 1), Tokens.border)
	else:
		var w := KS.text_w(text, Tokens.FS_XS, 500)
		var cy := size.y * 0.5
		draw_rect(Rect2(0, cy, (size.x - w) * 0.5 - Tokens.S3, 1), Tokens.border)
		draw_rect(Rect2((size.x + w) * 0.5 + Tokens.S3, cy, (size.x - w) * 0.5 - Tokens.S3, 1), Tokens.border)
		KS.draw_text(self, text, 0, cy, Tokens.FS_XS, Tokens.text_muted, 500, size.x, HORIZONTAL_ALIGNMENT_CENTER)
