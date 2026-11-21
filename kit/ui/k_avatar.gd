extends "res://kit/ui/k_press.gd"
## Avatar rond : image (texture) ou initiales ; anneau et pastille de statut optionnels ; cliquable si clickable.
var tex: Texture2D: set = _s
var initials := "": set = _s
var diameter := 40: set = _sd
var tint := Color(0, 0, 0, 0)
var ring_accent := false
var status: Variant = null  # Color ou null
var clickable := false

func _init() -> void:
	super()
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	size_flags_horizontal = 0

func _ready() -> void:
	super()
	mouse_filter = Control.MOUSE_FILTER_STOP if clickable else Control.MOUSE_FILTER_IGNORE
	_sd(diameter)

func _s(_v: Variant = null) -> void:
	queue_redraw()
func _sd(v: int) -> void:
	diameter = v
	custom_minimum_size = Vector2(v, v) if not clickable else Vector2(maxi(v, Tokens.TOUCH), maxi(v, Tokens.TOUCH))
	queue_redraw()

func _fg() -> Color:
	var bg := tint if tint.a > 0 else Tokens.surface3
	return Tokens.text if Tokens.contrast(Tokens.text, bg) >= 4.5 else (Color("0b0e12") if Tokens.contrast(Color("0b0e12"), bg) > Tokens.contrast(Color.WHITE, bg) else Color.WHITE)

func k_colors() -> Array:
	return [[_fg(), tint if tint.a > 0 else Tokens.surface3]] if tex == null else []

func _draw() -> void:
	var c := size * 0.5
	var r := diameter * 0.5
	var bg := tint if tint.a > 0 else Tokens.surface3
	if tex != null:
		draw_circle(c, r, Tokens.surface3)
		var rr := Rect2(c - Vector2(r, r), Vector2(diameter, diameter))
		draw_texture_rect(tex, rr, false)
	else:
		draw_circle(c, r, bg)
		KS.draw_text(self, initials.substr(0, 2).to_upper(), c.x - r, c.y, int(diameter * 0.38), _fg(), 600, diameter, HORIZONTAL_ALIGNMENT_CENTER)
	if ring_accent or ring > 0.01:
		draw_arc(c, r + 2, 0, TAU, 48, Tokens.accent if ring_accent else Tokens.ring_color(), 2.0, true)
	if status != null:
		draw_circle(c + Vector2(r, r) * 0.72, 6.0, Tokens.surface1)
		draw_circle(c + Vector2(r, r) * 0.72, 4.0, status)
