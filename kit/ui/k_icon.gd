extends Control
## Nœud icône Lucide : KIcon (nom, taille, couleur ; sans couleur = texte du thème kit).
const Tokens := preload("res://kit/tokens.gd")
const Icon := preload("res://kit/icon.gd")
var icon_name := "": set = _set_name
var px := 20: set = _set_px
var color: Variant = null: set = _set_color

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(20, 20)

func _ready() -> void:
	Tokens.bus.changed.connect(queue_redraw)

func _set_name(v: String) -> void:
	icon_name = v
	queue_redraw()

func _set_px(v: int) -> void:
	px = v
	custom_minimum_size = Vector2(v, v)
	queue_redraw()

func _set_color(v: Variant) -> void:
	color = v
	queue_redraw()

func _draw() -> void:
	var t := Icon.texture(icon_name, px)
	if t == null:
		return
	var c: Color = color if color != null else Tokens.text
	var r := Rect2((size - Vector2(px, px)) * 0.5, Vector2(px, px)).abs()
	draw_texture_rect(t, Rect2(Vector2(floorf((size.x - px) * 0.5), floorf((size.y - px) * 0.5)), Vector2(px, px)), false, c)
