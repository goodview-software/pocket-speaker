extends RefCounted
## Convertit une app existante (styles Godot dessinés à la main) au skin PIXEL ART sans réécrire son code :
## Pixelize.install(self) -> police pixel par défaut, et chaque StyleBoxFlat (thème + surcharges de nœuds) passe en coins carrés,
## bordure 2 px, sans anticrénelage, ombre dure. À appeler après Tokens.set_pixel(true) et après avoir posé le thème de l'app.
const Tokens := preload("res://kit/tokens.gd")
const Fonts := preload("res://kit/fonts.gd")
const NAMES := ["panel", "normal", "hover", "pressed", "focus", "disabled", "read_only", "fill", "background", "grabber", "grabber_highlight",
		"grabber_pressed", "slider", "grabber_area", "grabber_area_highlight", "scroll", "embedded_border", "tab_selected", "tab_unselected"]

static func sbox(sb: StyleBoxFlat) -> void:
	if sb.has_meta("px"):
		return
	sb.set_meta("px", true)
	var rad := sb.corner_radius_top_left
	sb.set_corner_radius_all(4 if (rad >= 8 and rad < 400) else 0)
	sb.corner_detail = 1
	sb.anti_aliasing = false
	if sb.bg_color.a > 0.2 and sb.get_border_width(SIDE_LEFT) == 0:
		sb.border_color = sb.bg_color.darkened(0.5)
		sb.set_border_width_all(Tokens.PX)
		for s in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:  # la bordure ne doit pas manger le contenu
			sb.set_content_margin(s, maxf(sb.get_content_margin(s), Tokens.PX * 2) if sb.get_content_margin(s) >= 0 else Tokens.PX * 2)
	elif sb.get_border_width(SIDE_LEFT) > 0:
		sb.set_border_width_all(maxi(sb.get_border_width(SIDE_LEFT), Tokens.PX))
	if sb.shadow_size > 0:
		sb.shadow_size = 1
		sb.shadow_offset = Vector2(4, 4)
		sb.shadow_color = Color(0, 0, 0, 0.55)

static func theme(th: Theme) -> Theme:
	th.default_font = Fonts.weight(500)
	for typ in th.get_stylebox_type_list():
		for n in th.get_stylebox_list(typ):
			var sb := th.get_stylebox(n, typ)
			if sb is StyleBoxFlat:
				sbox(sb)
	return th

static func node(n: Variant) -> void:
	if not is_instance_valid(n) or not (n is Control):
		return
	var c := n as Control
	for name in NAMES:
		if c.has_theme_stylebox_override(name):
			var sb := c.get_theme_stylebox(name)
			if sb is StyleBoxFlat:
				sbox(sb)

## Branche la conversion sur tous les nœuds présents et futurs de l'arbre.
static func install(root: Node) -> void:
	var tree := root.get_tree()
	for n in root.find_children("*", "Control", true, false):
		node(n)
	var me: GDScript = load("res://kit/pixelize.gd")
	tree.node_added.connect(func(n: Node): me.call_deferred("node", n))
