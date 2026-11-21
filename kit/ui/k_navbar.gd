extends Control
## Barre de navigation basse PIXEL ART commune aux apps : onglets [{id,label,icon,badge?}], signal selected(id).
## Onglet actif = bloc relevé couleur accent ; bords en escalier ; police pixel ; icônes sur grille.
signal selected(id: String)
const Tokens := preload("res://kit/tokens.gd")
const Fonts := preload("res://kit/fonts.gd")
const Icon := preload("res://kit/icon.gd")
const Px := preload("res://kit/ui/px.gd")
const HEIGHT := 64

var items: Array = []
var current := "": set = _set_current
var hot := -1
var _pop := 0.0

func _init() -> void:
	custom_minimum_size = Vector2(0, HEIGHT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE

func _ready() -> void:
	Tokens.bus.changed.connect(queue_redraw)

func setup(its: Array, cur := "") -> void:
	items = its
	current = cur if cur != "" else str(its[0].id)
	queue_redraw()

func _set_current(v: String) -> void:
	if v != current:
		_pop = 1.0
		set_process(true)
	current = v
	queue_redraw()

func set_badge(id: String, on: bool) -> void:
	for it in items:
		if it.id == id:
			it["badge"] = on
	queue_redraw()

func _process(d: float) -> void:
	_pop = move_toward(_pop, 0.0, d * 5.0)
	queue_redraw()
	if _pop <= 0.0:
		set_process(false)

func _slot(x: float) -> int:
	return clampi(int(x / (size.x / maxf(items.size(), 1))), 0, items.size() - 1)

func _gui_input(e: InputEvent) -> void:
	if items.is_empty():
		return
	if e is InputEventMouseMotion:
		var h := _slot(e.position.x)
		if h != hot:
			hot = h
			queue_redraw()
	elif e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		if Rect2(Vector2.ZERO, size).has_point(e.position):
			var id := str(items[_slot(e.position.x)].id)
			current = id
			selected.emit(id)
		accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT:
		hot = -1
		queue_redraw()

func _draw() -> void:
	var bar := Tokens.surface1.darkened(0.15)
	draw_rect(Rect2(Vector2.ZERO, size), bar)
	draw_rect(Rect2(0, 0, size.x, 2), Tokens.surface0.darkened(0.6))
	draw_rect(Rect2(0, 2, size.x, 2), Tokens.surface3)
	if items.is_empty():
		return
	var w := size.x / items.size()
	var f := Fonts.weight(700)
	var fs := 14
	for i in items.size():
		var it: Dictionary = items[i]
		var on: bool = str(it.id) == current
		var r := Rect2(w * i + 6, 8 - (2.0 if on else 0.0) - _pop * 2.0 * (1.0 if on else 0.0), w - 12, size.y - 12)
		if on:
			Px.panel(self, r, Tokens.accent.darkened(0.55), Tokens.accent.darkened(0.75), true)
		elif hot == i:
			Px.panel(self, r, Tokens.surface2, Tokens.surface0, false)
		var col := Tokens.accent_fg if on else (Tokens.text if hot == i else Tokens.text_muted)
		var cx := r.position.x + r.size.x * 0.5
		var t := Icon.texture(str(it.get("icon", "")), 24)
		if t != null:
			draw_texture_rect(t, Rect2(Vector2(floorf(cx - 12), floorf(r.position.y + 6)), Vector2(24, 24)), false, col)
		var lab := str(it.label).to_upper()
		var tw := f.get_string_size(lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, Vector2(floorf(cx - tw * 0.5), floorf(r.position.y + 46)), lab, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, col)
		if it.get("badge", false):
			draw_rect(Rect2(cx + 10, r.position.y + 4, 10, 10), Color.BLACK)
			draw_rect(Rect2(cx + 12, r.position.y + 6, 6, 6), Tokens.warn)
