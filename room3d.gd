extends Node3D
## Salle de classe 3D, façon Doom : on se déplace (ZQSD / flèches), on tourne (flèches ← → ou clic droit maintenu + souris).
## Le tableau des diapos est sur le mur du fond, le tableau des entités sur le mur de gauche (ce sont de vrais écrans :
## la souris fonctionne dessus). La mascotte est dans la pièce, avec sa bulle de parole.

const W := 14.0  # largeur (x)
const D := 10.0  # profondeur (z)
const H := 4.0  # hauteur (y)
const SPEED := 3.6
const TURN := 2.0
const SHEET := preload("res://mascot/goody.png")
const ANIMS := {"idle": [0, 4], "happy": [1, 4], "wait": [2, 4], "off": [3, 4], "sad": [4, 4]}

var board_vp: SubViewport  # tableau des diapos
var graph_vp: SubViewport  # tableau des entités
var player: CharacterBody3D
var cam: Camera3D
var mascot: Sprite3D
var bubble: Label3D
var clock_lbl: Label3D
var yaw := 0.0
var pitch := 0.0
var look_held := false
var anim := "idle"
var variant := 0
var _t := 0.0
var _boards: Array = []  # {xf: Transform3D, size: Vector2, vp: SubViewport}
var _hint: Label


func _ready() -> void:
	_build_environment()
	_build_room()
	_build_props()
	_build_boards()
	_build_mascot()
	_build_player()
	_build_hud()


# ------------------------------------------------------------------ textures pixel (générées)

func _tex(kind: String) -> ImageTexture:
	var rng := RandomNumberGenerator.new()
	rng.seed = kind.hash()
	var n := 64
	var im := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var c := Color.WHITE
			var jit := rng.randf_range(-0.04, 0.04)
			match kind:
				"wall":
					if y > n * 0.62:  # lambris vert
						c = Color("3f6b57") if (x % 16) > 1 else Color("2f5445")
						if y == int(n * 0.62) + 1:
							c = Color("8a6240")
					else:
						c = Color("dccfae")
						if y % 32 == 0:
							c = Color("cfc19c")
				"floor":
					c = Color("8a6240") if ((x + (y / 16) * 7) % 32) > 1 else Color("5e4128")
					if y % 16 == 0:
						c = Color("5e4128")
				"ceil":
					c = Color("c9ccd1") if (x % 32) > 1 and (y % 32) > 1 else Color("9da1a8")
				_:
					c = Color.GRAY
			im.set_pixel(x, y, Color(clampf(c.r + jit, 0, 1), clampf(c.g + jit, 0, 1), clampf(c.b + jit, 0, 1)))
	return ImageTexture.create_from_image(im)


func _mat(tex: Texture2D, uv: Vector3 = Vector3.ONE, col := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex
	m.albedo_color = col
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_scale = uv
	m.roughness = 1.0
	return m


func _flat(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.roughness = 1.0
	return m


func _quad(size: Vector2, pos: Vector3, rot: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot
	add_child(mi)
	return mi


func _box(size: Vector3, pos: Vector3, col: Color, solid := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _flat(col)
	mi.position = pos
	add_child(mi)
	if solid:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		sb.add_child(cs)
		sb.position = pos
		add_child(sb)
	return mi


# ------------------------------------------------------------------ pièce

func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("14161d")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("ffe9c4")
	env.ambient_light_energy = 0.85
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	for p in [Vector3(-3.5, 3.5, -1.0), Vector3(3.5, 3.5, -1.0), Vector3(0.0, 3.5, 2.5)]:
		var l := OmniLight3D.new()
		l.position = p
		l.omni_range = 9.0
		l.light_energy = 0.9
		l.light_color = Color("fff1d6")
		add_child(l)


func _build_room() -> void:
	var wt := _tex("wall")
	_quad(Vector2(W, H), Vector3(0, H / 2, -D / 2), Vector3(0, 0, 0), _mat(wt, Vector3(W / 4.0, 1, 1)))
	_quad(Vector2(W, H), Vector3(0, H / 2, D / 2), Vector3(0, 180, 0), _mat(wt, Vector3(W / 4.0, 1, 1)))
	_quad(Vector2(D, H), Vector3(-W / 2, H / 2, 0), Vector3(0, 90, 0), _mat(wt, Vector3(D / 4.0, 1, 1)))
	_quad(Vector2(D, H), Vector3(W / 2, H / 2, 0), Vector3(0, -90, 0), _mat(wt, Vector3(D / 4.0, 1, 1)))
	_quad(Vector2(W, D), Vector3(0, 0, 0), Vector3(-90, 0, 0), _mat(_tex("floor"), Vector3(W / 2.0, D / 2.0, 1)))
	_quad(Vector2(W, D), Vector3(0, H, 0), Vector3(90, 0, 0), _mat(_tex("ceil"), Vector3(W / 2.0, D / 2.0, 1)))
	# collisions des murs (épais, à l'extérieur)
	for d in [[Vector3(W + 2, H, 1), Vector3(0, H / 2, -D / 2 - 0.5)], [Vector3(W + 2, H, 1), Vector3(0, H / 2, D / 2 + 0.5)],
			[Vector3(1, H, D + 2), Vector3(-W / 2 - 0.5, H / 2, 0)], [Vector3(1, H, D + 2), Vector3(W / 2 + 0.5, H / 2, 0)]]:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = d[0]
		cs.shape = sh
		sb.add_child(cs)
		sb.position = d[1]
		add_child(sb)
	# plinthe
	_box(Vector3(W, 0.12, 0.06), Vector3(0, 0.06, -D / 2 + 0.03), Color("3a2a1c"), false)


func _build_props() -> void:
	var wood := Color("a9743f")
	# estrade + bureau du professeur
	_box(Vector3(5.0, 0.18, 2.0), Vector3(0, 0.09, -D / 2 + 1.1), Color("7a5430"))
	_box(Vector3(2.2, 0.08, 0.9), Vector3(-3.4, 0.82, -3.2), wood)
	_box(Vector3(0.1, 0.78, 0.8), Vector3(-4.4, 0.4, -3.2), Color("7a5430"))
	_box(Vector3(0.1, 0.78, 0.8), Vector3(-2.4, 0.4, -3.2), Color("7a5430"))
	_box(Vector3(0.18, 0.16, 0.18), Vector3(-3.0, 0.94, -3.2), Color("d9363e"), false)  # pomme
	_box(Vector3(0.5, 0.16, 0.36), Vector3(-3.8, 0.94, -3.2), Color("4f81bd"), false)  # livres
	# pupitres des élèves
	for r in 3:
		for c in 4:
			var x := -4.2 + c * 2.8
			var z := -0.2 + r * 2.0
			_box(Vector3(1.3, 0.06, 0.7), Vector3(x, 0.74, z), wood)
			_box(Vector3(0.08, 0.7, 0.08), Vector3(x - 0.55, 0.35, z), Color("5e4128"), false)
			_box(Vector3(0.08, 0.7, 0.08), Vector3(x + 0.55, 0.35, z), Color("5e4128"), false)
			_box(Vector3(0.5, 0.06, 0.5), Vector3(x, 0.45, z + 0.65), Color("c0504d"), false)  # chaise
	# bibliothèque (mur de droite)
	_box(Vector3(0.45, 2.4, 3.6), Vector3(W / 2 - 0.25, 1.2, 1.0), Color("6b4a2f"))
	for i in 16:
		var bc: Color = [Color("c0504d"), Color("4f81bd"), Color("9bbb59"), Color("f2c14e")][i % 4]
		_box(Vector3(0.3, 0.45, 0.16), Vector3(W / 2 - 0.5, 0.5 + (i / 8) * 0.9, -0.6 + (i % 8) * 0.45), bc, false)
	# plante
	_box(Vector3(0.45, 0.45, 0.45), Vector3(W / 2 - 0.6, 0.22, -D / 2 + 0.7), Color("c0623a"))
	for i in 4:
		_box(Vector3(0.12, 0.7 + i * 0.15, 0.12), Vector3(W / 2 - 0.7 + i * 0.1, 0.8, -D / 2 + 0.6 + i * 0.06), Color("59a14f"), false)
	# horloge au mur du fond (heure réelle)
	var cl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.4
	cm.bottom_radius = 0.4
	cm.height = 0.06
	cl.mesh = cm
	cl.material_override = _flat(Color("f4f1e6"))
	cl.position = Vector3(0, 3.3, D / 2 - 0.05)
	cl.rotation_degrees = Vector3(90, 0, 0)
	add_child(cl)
	clock_lbl = Label3D.new()
	clock_lbl.position = Vector3(0, 3.3, D / 2 - 0.1)
	clock_lbl.rotation_degrees = Vector3(0, 180, 0)
	clock_lbl.pixel_size = 0.006
	clock_lbl.font_size = 64
	clock_lbl.modulate = Color("1b1b1b")
	clock_lbl.double_sided = false
	add_child(clock_lbl)


func _build_boards() -> void:
	# tableau principal : mur du fond
	board_vp = _make_vp(Vector2i(1100, 700))
	var bsize := Vector2(6.6, 4.2 * 6.6 / 10.4)
	_box(Vector3(bsize.x + 0.3, bsize.y + 0.3, 0.08), Vector3(0, 2.15, -D / 2 + 0.05), Color("a9743f"), false)
	var bm := _screen_mat(board_vp)
	_quad(bsize, Vector3(0, 2.15, -D / 2 + 0.1), Vector3.ZERO, bm)
	_boards.append({"xf": Transform3D(Basis.IDENTITY, Vector3(0, 2.15, -D / 2 + 0.1)), "size": bsize, "vp": board_vp})
	_box(Vector3(bsize.x, 0.08, 0.2), Vector3(0, 2.15 - bsize.y / 2 - 0.1, -D / 2 + 0.2), Color("c9b79a"), false)
	# tableau des entités : mur de gauche
	graph_vp = _make_vp(Vector2i(900, 560))
	var gsize := Vector2(4.2, 4.2 * 560.0 / 900.0)
	_box(Vector3(0.08, gsize.y + 0.3, gsize.x + 0.3), Vector3(-W / 2 + 0.05, 2.0, -0.6), Color("a9743f"), false)
	var gb := Basis.from_euler(Vector3(0, deg_to_rad(90), 0))
	_quad(gsize, Vector3(-W / 2 + 0.1, 2.0, -0.6), Vector3(0, 90, 0), _screen_mat(graph_vp))
	_boards.append({"xf": Transform3D(gb, Vector3(-W / 2 + 0.1, 2.0, -0.6)), "size": gsize, "vp": graph_vp})


func _make_vp(sz: Vector2i) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = sz
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vp.gui_embed_subwindows = true
	var bg := ColorRect.new()
	bg.color = Color("14352c")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	vp.add_child(bg)
	add_child(vp)
	return vp


func _screen_mat(vp: SubViewport) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = vp.get_texture()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	return m


func _build_mascot() -> void:
	mascot = Sprite3D.new()
	mascot.texture = SHEET
	mascot.region_enabled = true
	mascot.region_rect = Rect2(0, 0, 32, 32)
	mascot.pixel_size = 0.045
	mascot.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	mascot.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mascot.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	mascot.shaded = false
	mascot.position = Vector3(2.0, 0.18 + 0.72, -3.4)
	add_child(mascot)
	bubble = Label3D.new()
	bubble.position = Vector3(2.0, 1.95, -3.4)
	bubble.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	bubble.pixel_size = 0.0032
	bubble.font_size = 40
	bubble.width = 520
	bubble.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bubble.outline_size = 10
	bubble.outline_modulate = Color(0.03, 0.04, 0.06)
	bubble.modulate = Color.WHITE
	bubble.no_depth_test = true
	add_child(bubble)


func _build_player() -> void:
	player = CharacterBody3D.new()
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.6
	cs.shape = cap
	player.add_child(cs)
	player.position = Vector3(0, 0.85, 4.0)
	add_child(player)
	cam = Camera3D.new()
	cam.position = Vector3(0, 0.7, 0)
	cam.fov = 75.0
	cam.current = true
	player.add_child(cam)


func _build_hud() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	_hint = Label.new()
	_hint.text = "ZQSD / flèches : bouger · ← → ou clic droit + souris : regarder · Tab : retour vue 2D"
	_hint.position = Vector2(16, 12)
	_hint.add_theme_font_size_override("font_size", 14)
	_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
	_hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	_hint.add_theme_constant_override("outline_size", 6)
	cl.add_child(_hint)


# ------------------------------------------------------------------ boucle

func set_mascot(a: String, v: int, live: String) -> void:
	anim = a if ANIMS.has(a) else "idle"
	variant = v
	bubble.text = live
	bubble.visible = live != ""


func _process(d: float) -> void:
	_t += d
	var row: int = ANIMS[anim][0] + variant * 5
	var n: int = ANIMS[anim][1]
	mascot.region_rect = Rect2((int(_t * 3.0) % n) * 32, row * 32, 32, 32)
	var t := Time.get_time_dict_from_system()
	clock_lbl.text = "%02d:%02d" % [t["hour"], t["minute"]]


func _physics_process(d: float) -> void:
	var turn := float(Input.is_key_pressed(KEY_LEFT)) - float(Input.is_key_pressed(KEY_RIGHT))
	yaw += turn * TURN * d
	player.rotation.y = yaw
	var f := float(Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_Z) or Input.is_key_pressed(KEY_UP)) - float(Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN))
	var s := float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_Q))
	var dir := (player.global_transform.basis * Vector3(s, 0, -f))
	dir.y = 0.0
	player.velocity = dir.normalized() * SPEED if dir.length() > 0.01 else Vector3.ZERO
	player.move_and_slide()
	player.position.y = 0.85


func _input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_RIGHT:
		look_held = e.pressed
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if e.pressed else Input.MOUSE_MODE_VISIBLE
		return
	if e is InputEventMouseMotion and look_held:
		yaw -= e.relative.x * 0.003
		pitch = clampf(pitch - e.relative.y * 0.003, -1.1, 1.1)
		cam.rotation.x = pitch
		return
	# la souris agit sur les tableaux (ce sont de vrais écrans)
	if e is InputEventMouseButton or e is InputEventMouseMotion:
		for b in _boards:
			var uv := _board_uv(b, e.position)
			if uv.x >= 0.0:
				var vp: SubViewport = b["vp"]
				var ev: InputEvent = e.duplicate()
				ev.position = uv * Vector2(vp.size)
				ev.global_position = ev.position
				if ev is InputEventMouseMotion:
					ev.relative = e.relative * 1.6
				vp.push_input(ev, true)
				get_viewport().set_input_as_handled()
				return


## Point de l'écran -> coordonnées (0..1) sur un tableau, ou (-1,-1) si on ne le vise pas.
func _board_uv(b: Dictionary, mouse: Vector2) -> Vector2:
	var o := cam.project_ray_origin(mouse)
	var dn := cam.project_ray_normal(mouse)
	var xf: Transform3D = b["xf"]
	var n: Vector3 = xf.basis.z
	var den := dn.dot(n)
	if den > -0.0001:
		return Vector2(-1, -1)
	var t := (xf.origin - o).dot(n) / den
	if t <= 0.0:
		return Vector2(-1, -1)
	var loc := xf.affine_inverse() * (o + dn * t)
	var sz: Vector2 = b["size"]
	var uv := Vector2(loc.x / sz.x + 0.5, 0.5 - loc.y / sz.y)
	if uv.x < 0.0 or uv.x > 1.0 or uv.y < 0.0 or uv.y > 1.0:
		return Vector2(-1, -1)
	return uv
