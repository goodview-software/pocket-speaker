extends Control
## Pocket Speaker : le téléphone devient l'enceinte + le micro du PC (USB ou Wi-Fi).
## PC : adb (installe/lance l'app, `adb forward`) ou Wi-Fi, sorties PulseAudio virtuelles, capture -> TCP.
## Téléphone : écoute sur PORT, joue le son reçu, renvoie son micro.
##
## Trame : [type u8][longueur u16 LE][données]

const PORT := 5105
const BEACON_PORT := PORT + 1  # téléphone -> réseau (UDP) : "POCKET"
const RATE := 48000
const PKG := "fr.goodview.pocketspeaker"
const VERSION := 700  # versionCode de l'APK
const KTok := preload("res://kit/tokens.gd")
const KPx := preload("res://kit/ui/px.gd")
const KPixelize := preload("res://kit/pixelize.gd")
const LessonScript := preload("res://lesson.gd")
const APP_VERSION: String = preload("res://version.gd").VERSION
const T_AUDIO := 1  # PC -> téléphone : PCM s16 stéréo 48 kHz
const T_MIC := 2  # téléphone -> PC : PCM s16 mono
const T_HELLO := 3  # téléphone -> PC : u32 fréquence micro + nom du téléphone
const T_NAME := 4  # PC -> téléphone : [variante de mascotte u8] + nom du PC
const T_CTRL := 5  # [son u8, micro u8, volume 0-100 u8, sous-titres u8] (dans les deux sens)
const T_PIN := 9  # PC -> téléphone : code PIN affiché sur le PC
const T_DENY := 10  # téléphone -> PC : code refusé
const T_TEXT := 11  # PC -> téléphone : phrase comprise par Whisper (UTF-8)
const LANGS := [["none", "Aucune"], ["es", "Español"], ["en", "English"], ["fr", "Français"], ["de", "Deutsch"], ["it", "Italiano"], ["pt", "Português"]]
const T_ASK := 12  # téléphone -> PC : [mode u8 : 0 chat, 1 explication d'un mot] + texte UTF-8
const T_ANS := 13  # PC -> téléphone : réponse de la mascotte (UTF-8)
const T_CMD := 14  # téléphone -> PC : [1 pause/lecture, 2 reculer de 5 s] du média en cours
const T_PING := 7
const T_PONG := 8
const SINK := "pocket_out"
const MIC_SINK := "pocket_mic_sink"
const MIC_SRC := "pocket_mic_sink.monitor"
const CHUNK := RATE / 50  # 20 ms

const C_BG := Color("0e1116")
const C_CARD := Color("171b22")
const C_TEXT := Color("e8ecf1")
const C_DIM := Color("8892a0")
const C_OK := Color("4de1b4")
const C_WAIT := Color("ffb454")
const C_IDLE := Color("5b6573")

enum { ST_IDLE, ST_WAIT, ST_LINKED }


# ------------------------------------------------------------------ Widgets dessinés

class Orb extends Control:
	const SHEET := preload("res://mascot/goody.png")
	const ANIMS := {"idle": [0, 4], "happy": [1, 4], "wait": [2, 4], "off": [3, 4], "sad": [4, 4]}
	const FPS := {"idle": 3.0, "happy": 6.0, "wait": 3.0, "off": 1.5, "sad": 2.0}
	var color := Color("5b6573")
	var variant := 0
	var level := 0.0
	var pulse := 0.0
	var t := 0.0
	var anim := "off":
		set(v):
			if v != anim:
				anim = v
				t = 0.0

	func _init() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _process(d: float) -> void:
		pulse = fposmod(pulse + d, TAU)
		t += d * FPS[anim] * (1.0 + level * 1.5)
		queue_redraw()

	func _draw() -> void:
		var c := size / 2.0
		var r := minf(size.x, size.y) * 0.26
		for i in 4:  # halos carrés par paliers de 4 px
			var rr := floorf((r + 8.0 * (i + 1) + level * 14.0 + sin(pulse + i) * 2.0) / 4.0) * 4.0
			draw_rect(Rect2(c - Vector2(rr, rr), Vector2(rr, rr) * 2.0), Color(color, 0.11 - i * 0.025))
		draw_rect(Rect2(c - Vector2(r, r), Vector2(r, r) * 2.0), Color(color, 0.16))
		var row: int = ANIMS[anim][0] + variant * 5
		var n: int = ANIMS[anim][1]
		var sc := maxi(1, int(size.y * 0.72 / 32.0))
		var px := 32 * sc
		var bob := 0.0 if anim != "idle" else 0.0
		var pos := (c - Vector2(px, px) / 2.0 + Vector2(0, bob)).round()
		draw_texture_rect_region(SHEET, Rect2(pos, Vector2(px, px)), Rect2((int(t) % n) * 32, row * 32, 32, 32))


class Meter extends Control:
	var value := 0.0
	var shown := 0.0
	var peak := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 14)

	func _process(d: float) -> void:
		shown = move_toward(shown, value, d * (8.0 if value > shown else 2.5))
		peak = maxf(peak - d * 0.4, shown)
		queue_redraw()

	func _draw() -> void:
		var n := 30
		var gap := 3.0
		var w := (size.x - gap * (n - 1)) / n
		var pk := int(peak * n)
		for i in n:
			var f := (i + 1.0) / n
			var col := Color("4de1b4")
			if f > 0.85:
				col = Color("ff6b6b")
			elif f > 0.65:
				col = Color("ffb454")
			var lit := f <= shown or i == pk - 1
			draw_rect(Rect2(i * (w + gap), 0, w, size.y), col if lit else Color(1, 1, 1, 0.07), true)


class Ico:
	static func box(ci: CanvasItem, r: Rect2, rad: float, col: Color) -> void:
		KPx.panel(ci, r, col, Color(0, 0, 0, 0), false)

	static func draw_kind(ci: CanvasItem, kind: String, c: Vector2, k: float, col: Color) -> void:
		match kind:
			"speaker", "speaker_low":
				var body := PackedVector2Array([Vector2(-18, -9), Vector2(-6, -9), Vector2(8, -21),
						Vector2(8, 21), Vector2(-6, 9), Vector2(-18, 9)])
				for i in body.size():
					body[i] = c + Vector2(-4, 0) * k + body[i] * k
				ci.draw_colored_polygon(body, col)
				if kind == "speaker":
					ci.draw_arc(c + Vector2(6, 0) * k, 12.0 * k, -0.9, 0.9, 16, col, 3.0 * k, true)
					ci.draw_arc(c + Vector2(6, 0) * k, 23.0 * k, -0.9, 0.9, 20, Color(col, 0.6), 3.0 * k, true)
			"mic":
				box(ci, Rect2(c + Vector2(-8, -22) * k, Vector2(16, 28) * k), 8.0 * k, col)
				ci.draw_arc(c + Vector2(0, -2) * k, 15.0 * k, 0.0, PI, 24, col, 3.0 * k, true)
				ci.draw_line(c + Vector2(0, 13) * k, c + Vector2(0, 22) * k, col, 3.0 * k, true)
				ci.draw_line(c + Vector2(-8, 22) * k, c + Vector2(8, 22) * k, col, 3.0 * k, true)
			"usb":
				ci.draw_line(c + Vector2(-22, 0) * k, c + Vector2(20, 0) * k, col, 3.0 * k, true)
				ci.draw_circle(c + Vector2(-24, 0) * k, 5.5 * k, col)
				ci.draw_colored_polygon(PackedVector2Array([c + Vector2(18, -7) * k, c + Vector2(30, 0) * k,
						c + Vector2(18, 7) * k]), col)
				ci.draw_polyline(PackedVector2Array([c + Vector2(-8, 0) * k, c + Vector2(0, -13) * k,
						c + Vector2(10, -13) * k]), col, 3.0 * k, true)
				ci.draw_rect(Rect2(c + Vector2(10, -17) * k, Vector2(8, 8) * k), col)
				ci.draw_polyline(PackedVector2Array([c + Vector2(2, 0) * k, c + Vector2(10, 12) * k]), col, 3.0 * k, true)
				ci.draw_circle(c + Vector2(12, 12) * k, 4.5 * k, col)
			"wifi":
				ci.draw_circle(c + Vector2(0, 16) * k, 3.5 * k, col)
				for r in [12.0, 22.0, 32.0]:
					ci.draw_arc(c + Vector2(0, 16) * k, r * k, -2.36, -0.78, 20, col, 3.0 * k, true)
			"auto":
				var st := PackedVector2Array([Vector2(0, -22), Vector2(5, -5), Vector2(22, 0), Vector2(5, 5),
						Vector2(0, 22), Vector2(-5, 5), Vector2(-22, 0), Vector2(-5, -5)])
				for i in st.size():
					st[i] = c + st[i] * k
				ci.draw_colored_polygon(st, col)


class Icon extends Control:
	var kind := "speaker"
	var col := Color.WHITE:
		set(v):
			if v != col:
				col = v
				queue_redraw()

	func _init(k := "speaker") -> void:
		kind = k
		custom_minimum_size = Vector2(40, 40)

	func _draw() -> void:
		Ico.draw_kind(self, kind, size / 2.0, minf(size.x, size.y) / 46.0, col)


## Boîte pixel art à taille maîtrisée : cadre en escalier dessiné, contenu avec marges fixes.
class PixBox extends MarginContainer:
	var fill := Color(0.09, 0.11, 0.14)
	var edge := Color(0.3, 0.88, 0.7, 0.8)
	var tail_left := false  # bulle de dialogue : petite pointe en escalier vers la gauche (la mascotte)

	func _init(f := Color(0.09, 0.11, 0.14), e := Color(0.3, 0.88, 0.7, 0.8), pad := 12) -> void:
		fill = f
		edge = e
		for k in ["left", "right", "top", "bottom"]:
			add_theme_constant_override("margin_" + k, pad)
		texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST

	func _draw() -> void:
		KPx.panel(self, Rect2(Vector2.ZERO, size), fill, edge, false, 2)
		if tail_left:
			var cy := roundf(size.y * 0.5)
			for i in 4:
				var w := float((4 - i) * 4)
				draw_rect(Rect2(-w + 2, cy - 8 + i * 4, w, 16 - i * 8), edge)
				draw_rect(Rect2(-w + 4, cy - 6 + i * 4, w, 12 - i * 8), fill)


class Seg extends Control:
	signal picked(id: int)
	var ids: Array = []
	var kinds: Array = []
	var sel := 0
	var hi := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(0, 54)

	func setup(k: Array, i: Array, cur: int) -> void:
		kinds = k
		ids = i
		sel = maxi(0, ids.find(cur))
		hi = sel

	func _process(d: float) -> void:
		hi = move_toward(hi, sel, d * 14.0)
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT and not ids.is_empty():
			sel = clampi(int(e.position.x / (size.x / ids.size())), 0, ids.size() - 1)
			picked.emit(ids[sel])
			accept_event()

	func _draw() -> void:
		if ids.is_empty():
			return
		Ico.box(self, Rect2(Vector2.ZERO, size), size.y / 2.0, Color("232a34"))
		var w := size.x / ids.size()
		Ico.box(self, Rect2(Vector2(hi * w + 4, 4), Vector2(w - 8, size.y - 8)), (size.y - 8) / 2.0, Color("4de1b4", 0.22))
		for i in ids.size():
			var on := i == sel
			Ico.draw_kind(self, kinds[i], Vector2((i + 0.5) * w, size.y / 2.0), 0.55,
					Color("4de1b4") if on else Color("8892a0"))


class Toggle extends Control:
	signal toggled(on: bool)
	var on := false
	var t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(58, 34)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	func set_on(v: bool) -> void:  # sans émettre de signal
		on = v

	func _process(d: float) -> void:
		t = move_toward(t, 1.0 if on else 0.0, d * 9.0)
		queue_redraw()

	func _gui_input(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			on = not on
			toggled.emit(on)
			accept_event()

	func _draw() -> void:
		var h := size.y
		var bg := Color("2a313c").lerp(Color("4de1b4"), t)
		KPx.panel(self, Rect2(Vector2.ZERO, size).grow(-2), bg, Color(0, 0, 0, 0), false)
		var kx := lerpf(6.0, size.x - h + 2.0, t)
		KPx.panel(self, Rect2(kx, 6, h - 8, h - 12), Color.WHITE, Color(0, 0, 0, 0), false)


# ------------------------------------------------------------------ État

var is_phone := OS.has_feature("android") or OS.get_environment("POCKET_PHONE") == "1"
var test_mode := OS.get_environment("POCKET_TEST") == "1"
var peer: StreamPeerTCP
var rxbuf := PackedByteArray()
var linked := false
var state := ST_IDLE
var want_sound := true
var want_mic := false
var vol := 1.0
var want_subs := false  # sous-titres Whisper en bulles sur le téléphone
var tog_subs: Toggle
var subs_pid := -1
var subs_io: FileAccess
var th_subs: Thread
var subs_ready := false
var subs_out: Array = []
var bubbles: VBoxContainer
var settings_layer: Control
var settings_box: VBoxContainer
var press_t := -1.0
var tap_pending := -1.0
var subs_card: Control
var chat_sc: ScrollContainer
var chat_in: LineEdit
var pop_layer: Control
var pop_word: Label
var pop_text: Label
var subs_sc: ScrollContainer
var subs_rows: Container
var blocks := {}  # id de bloc -> VBox
var live_box: Control
var land := false  # paysage : salle de classe, conférence en diaporama (lesson.gd)
var lesson: Control
var hint_n: Label
var chat_root_n: VBoxContainer
var margin_n: Control
var vbox_rows: VBoxContainer
var block_data: Array = []  # [{id, text, trans}]
var transcript: Array = []  # phrases entendues (contexte pour l'assistant)
var live_lbl: Label  # mots en direct (hypothèse en cours), avant la fin de la phrase
var sub_delay := 0.0  # secondes de décalage du son (pour avoir le temps de lire)
var delay_q: Array = []
var sub_sched: Array = []  # groupes de mots en attente : [heure d'affichage ms, texte]
var subs_t0 := 0  # heure (ms) du premier octet envoyé à Whisper
var subs_bytes := 0
var sub_last := 0
var sub_lag := 0.0  # retard moyen du texte par rapport à la parole (s)
var ai_hist: Array = []
const INTER := preload("res://kit/fonts/Inter-500.woff2")
const PERSONA := "Tu es Goody, la mascotte de Pocket Speaker : un assistant généraliste, chaleureux et clair. Réponds court (2-4 phrases), dans la langue de l'utilisateur, sans markdown."
var img_on := true  # photos Wikipédia (envoie seulement les noms cités)
var src_i := 0  # langue parlée (Vosk) : 0 fr · 1 en · 2 es
var sub_target := 0  # langue de traduction (index dans LANGS, 0 = aucune)
var subs_target_run := -1
var opt_lang: OptionButton
var subs_lbl: Label
var subs_lines: Array = []
var lvl_out := 0.0
var lvl_mic := 0.0
var rtt_ms := -1
var link_mode := 0  # 0 auto · 1 Wi-Fi · 2 USB
var peer_name := ""
var pin := ""  # PC : code affiché, ne change que sur demande
var phone_pin := ""  # téléphone : code saisi (vide = accepte tout PC)
var authed := false
var phones := {}  # PC : téléphones qui écoutent {clé: {name, ip, t}}
var chosen := ""  # PC : clé du téléphone choisi ("usb" ou ip)
var last_name := ""
var user_disc := false
var deny_t := -100000
var phones_box: VBoxContainer
var phones_sig := ""
var pin_lbl: Label
var disc_btn: Button
var mic_rate := 48000
var linked_t := 0.0
var mascot := 0  # variante de Goody choisie dans le Goodview Launcher (profil partagé)
var mascot_t := 0.0

# UI
var orb: Orb
var status: Label
var sub: Label
var chip: Label
var chip_sb: StyleBoxFlat
var ico_sound: Icon
var ico_mic: Icon
var meter_out: Meter
var meter_mic: Meter
var tog_sound: Toggle
var tog_mic: Toggle
var vol_slider: HSlider
var content: VBoxContainer

# PC
var adb_bin := "adb"
var th_adb: Thread
var mtx := Mutex.new()
var quit := false
var adb_state := "none"
var adb_msg := ""
var cap_pid := -1
var cap_io: FileAccess
var th_cap: Thread
var cap_queue: Array = []
var mic_pid := -1
var mic_io: FileAccess
var prev_sink := ""
var prev_src := ""
var modules := PackedStringArray()
var lan := PacketPeerUDP.new()
var lan_ip := ""
var lan_t := 0
var try_t := 0.0
var wait_t := 0.0
var hello_t := 0.0
var name_sent := false
var ping_t := 0.0

# Téléphone
var server: TCPServer
var player: AudioStreamPlayer
var pb: AudioStreamGeneratorPlayback
var cap: AudioEffectCapture
var mic_player: AudioStreamPlayer
var beacon := PacketPeerUDP.new()
var beacon_t := 0.0


func _ready() -> void:
	get_tree().set_auto_accept_quit(false)
	_load_pref()
	KTok.set_pixel(true)
	_build_ui()
	if OS.get_environment("POCKET_DEMO") == "1":
		_demo.call_deferred()
	KPixelize.install(self)
	if is_phone:
		_phone_init()
	else:
		_pc_init()
	_set_status(ST_IDLE, "Prêt", "")
	_start_updates()

## Mise à jour automatique commune aux apps Goodview (kit/update) : carte pixel art, bouton vert « METTRE À JOUR ».
func _start_updates() -> void:
	if test_mode:
		return
	var ui = preload("res://kit/update/update_ui.gd").new()
	add_child(ui)
	ui.setup("goodview-software/pocket-speaker", APP_VERSION)


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_shutdown()
		get_tree().quit()


## Mascotte choisie dans le Goodview Launcher : ~/.config/goodview/profile.json
func _read_shared_profile() -> void:
	var p := OS.get_environment("HOME") + "/.config/goodview/profile.json"
	if not FileAccess.file_exists(p):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	if d is Dictionary:
		var m := clampi(int(d.get("mascot", 0)), 0, 7)
		if m != mascot:
			mascot = m
			_send_name()


func _send_name() -> void:
	if not is_phone and peer != null and name_sent:
		_send(T_NAME, PackedByteArray([mascot]) + _pc_name().to_utf8_buffer())


func _process(delta: float) -> void:
	if not is_phone:
		mascot_t -= delta
		if mascot_t <= 0.0:
			mascot_t = 2.0
			_read_shared_profile()
	if is_phone:
		_phone_process(delta)
	else:
		_pc_process(delta)
	_ui_tick(delta)


func _shutdown() -> void:
	quit = true
	if not is_phone:
		_pc_subs_stop()  # tue Vosk et rejoint son fil (sinon la fenêtre reste ouverte)
		_pc_teardown()
		if th_adb != null:
			var t0 := Time.get_ticks_msec()
			while th_adb.is_alive() and Time.get_ticks_msec() - t0 < 1500:
				OS.delay_msec(50)
			if not th_adb.is_alive():
				th_adb.wait_to_finish()
			th_adb = null


func _load_pref() -> void:
	var cf := ConfigFile.new()
	if cf.load("user://pref.cfg") == OK:
		link_mode = int(cf.get_value("net", "mode", 0))
		vol = float(cf.get_value("audio", "vol", 1.0))
		pin = str(cf.get_value("net", "pin", ""))
		phone_pin = str(cf.get_value("net", "phone_pin", ""))
		last_name = str(cf.get_value("net", "last", ""))
		want_subs = bool(cf.get_value("audio", "subs", false))
		sub_target = int(cf.get_value("audio", "target", 0))
		src_i = clampi(int(cf.get_value("audio", "src", 0)), 0, 2)
		img_on = bool(cf.get_value("audio", "imgs", true))
	if pin == "":
		_new_pin()


func _new_pin() -> void:
	pin = "%04d" % (randi() % 10000)
	if pin_lbl != null:
		pin_lbl.text = pin
	_save_pref()


func _save_pref() -> void:
	var cf := ConfigFile.new()
	cf.set_value("net", "mode", link_mode)
	cf.set_value("audio", "vol", vol)
	cf.set_value("net", "pin", pin)
	cf.set_value("net", "phone_pin", phone_pin)
	cf.set_value("net", "last", last_name)
	cf.set_value("audio", "subs", want_subs)
	cf.set_value("audio", "target", sub_target)
	cf.set_value("audio", "src", src_i)
	cf.set_value("audio", "imgs", img_on)
	cf.set_value("audio", "delay", sub_delay)
	cf.save("user://pref.cfg")


# ------------------------------------------------------------------ Interface

func _make_theme() -> Theme:
	var th := Theme.new()
	th.default_font_size = 16
	th.set_color("font_color", "Label", C_TEXT)
	for n in ["font_color", "font_hover_color", "font_pressed_color"]:
		th.set_color(n, "OptionButton", C_TEXT)
	for st in ["normal", "hover", "pressed", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color("232a34") if st != "hover" else Color("2c3541")
		sb.set_corner_radius_all(12)
		sb.set_content_margin_all(12)
		if st == "focus":
			sb.bg_color = Color("232a34")
		th.set_stylebox(st, "OptionButton", sb)
	for cls in ["HSlider", "ScrollContainer", "VScrollBar", "OptionButton", "PopupMenu"]:
		th.set_stylebox("focus", cls, StyleBoxEmpty.new()) if cls != "OptionButton" else null
	var pop := StyleBoxFlat.new()
	pop.bg_color = Color("232a34")
	pop.set_corner_radius_all(12)
	th.set_stylebox("panel", "PopupMenu", pop)
	var track := StyleBoxFlat.new()
	track.bg_color = Color("2a313c")
	track.set_corner_radius_all(4)
	track.content_margin_top = 4
	track.content_margin_bottom = 4
	var fill := StyleBoxFlat.new()
	fill.bg_color = C_OK
	fill.set_corner_radius_all(4)
	fill.content_margin_top = 4
	fill.content_margin_bottom = 4
	th.set_stylebox("slider", "HSlider", track)
	th.set_stylebox("grabber_area", "HSlider", fill)
	th.set_stylebox("grabber_area_highlight", "HSlider", fill)
	var sc := StyleBoxFlat.new()
	sc.bg_color = Color(0, 0, 0, 0)
	sc.content_margin_left = 6
	sc.content_margin_right = 6
	var sg := StyleBoxFlat.new()
	sg.bg_color = Color(1, 1, 1, 0.18)
	sg.set_corner_radius_all(3)
	sg.content_margin_left = 6
	sg.content_margin_right = 6
	th.set_stylebox("scroll", "VScrollBar", sc)
	for n in ["grabber", "grabber_highlight", "grabber_pressed"]:
		th.set_stylebox(n, "VScrollBar", sg)
	th.set_icon("grabber", "HSlider", _knob(Color.WHITE))
	th.set_icon("grabber_highlight", "HSlider", _knob(C_OK))
	th.set_icon("grabber_disabled", "HSlider", _knob(C_DIM))
	return KPixelize.theme(th)


func _knob(col: Color) -> Texture2D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.88, 1.0])
	g.colors = PackedColorArray([col, col, Color(col, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 32
	t.height = 32
	return t


func _label(text: String, size: int, col: Color, parent: Control) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	parent.add_child(l)
	return l


func _card(parent: Control) -> VBoxContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = C_CARD
	sb.set_corner_radius_all(20)
	sb.set_content_margin_all(18)
	sb.anti_aliasing_size = 1.2
	p.add_theme_stylebox_override("panel", sb)
	parent.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	return v


func _build_ui() -> void:
	theme = _make_theme()
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)
	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var top := 22
	if is_phone:
		top += int(DisplayServer.get_display_safe_area().position.y / maxf(1.0, get_window().content_scale_factor))
	margin.add_theme_constant_override("margin_top", top)
	margin.add_theme_constant_override("margin_bottom", 22)
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	scroll.add_child(margin)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(center)
	margin_n = scroll
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	content.custom_minimum_size = Vector2(440, 0)
	center.add_child(content)
	get_viewport().size_changed.connect(_fit_width)
	_fit_width()

	var head := HBoxContainer.new()
	content.add_child(head)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(sp)
	var chip_p := PanelContainer.new()
	chip_sb = StyleBoxFlat.new()
	chip_sb.set_corner_radius_all(14)
	chip_sb.content_margin_left = 12
	chip_sb.content_margin_right = 12
	chip_sb.content_margin_top = 4
	chip_sb.content_margin_bottom = 4
	chip_p.add_theme_stylebox_override("panel", chip_sb)
	head.add_child(chip_p)
	chip = _label("", 14, C_DIM, chip_p)

	var orb_row := HBoxContainer.new()
	orb_row.add_theme_constant_override("separation", 22)
	content.add_child(orb_row)
	orb = Orb.new()
	orb.custom_minimum_size = Vector2(0, 230)
	orb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	orb_row.add_child(orb)
	live_box = PixBox.new(Color(0.03, 0.04, 0.06), Color(C_OK, 1.0), 12)
	live_box.custom_minimum_size = Vector2(0, 150)  # taille fixe : ne se déforme jamais
	live_box.tail_left = true
	live_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	live_box.size_flags_stretch_ratio = 1.5
	live_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	live_box.visible = want_subs
	live_lbl = Label.new()
	live_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	live_lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	live_lbl.clip_text = true
	live_lbl.add_theme_font_override("font", INTER)
	live_lbl.add_theme_font_size_override("font_size", 26 if is_phone else 23)
	live_lbl.add_theme_color_override("font_color", Color.WHITE)
	live_lbl.add_theme_constant_override("line_spacing", 6)
	live_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	live_box.add_child(live_lbl)
	orb_row.add_child(live_box)
	status = _label("", 22, C_TEXT, content)
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub = _label("", 14, C_DIM, content)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.custom_minimum_size = Vector2(0, 40)
	hint_n = _label("Personnage : appui = pause · double appui = reculer 5 s · appui long = paramètres", 13, C_IDLE, content)
	hint_n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_n.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	# Paramètres : fenêtre ouverte par un appui long sur le personnage.
	var main_content := content
	settings_layer = Control.new()
	settings_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	settings_layer.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			settings_layer.visible = false)
	settings_layer.add_child(dim)
	var sc := ScrollContainer.new()
	sc.set_anchors_preset(Control.PRESET_FULL_RECT)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	sc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	settings_layer.add_child(sc)
	var sm := MarginContainer.new()
	sm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sm.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in ["top", "bottom", "left", "right"]:
		sm.add_theme_constant_override("margin_" + side, 22 if side != "top" else top)
	sc.add_child(sm)
	var scen := CenterContainer.new()
	scen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sm.add_child(scen)
	content = VBoxContainer.new()
	content.add_theme_constant_override("separation", 16)
	scen.add_child(content)
	settings_box = content
	var th := HBoxContainer.new()
	content.add_child(th)
	var tl := _label("Paramètres", 24, C_TEXT, th)
	tl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var xb := Button.new()
	xb.text = "Fermer"
	xb.custom_minimum_size = Vector2(0, 44)
	xb.pressed.connect(func(): settings_layer.visible = false)
	th.add_child(xb)
	orb.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			if e.pressed:
				press_t = 0.0
			else:
				if press_t >= 0.0 and press_t < 0.6:  # appui court
					if tap_pending >= 0.0:
						tap_pending = -1.0
						_media(2)  # double appui : on recule
					else:
						tap_pending = 0.0
				press_t = -1.0)

	var c1 := _card(content)
	var r1 := HBoxContainer.new()
	r1.add_theme_constant_override("separation", 14)
	c1.add_child(r1)
	ico_sound = Icon.new("speaker")
	r1.add_child(ico_sound)
	meter_out = Meter.new()
	meter_out.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter_out.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r1.add_child(meter_out)
	tog_sound = Toggle.new()
	tog_sound.set_on(want_sound)
	tog_sound.toggled.connect(_on_sound)
	tog_sound.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r1.add_child(tog_sound)
	var vh := HBoxContainer.new()
	vh.add_theme_constant_override("separation", 10)
	c1.add_child(vh)
	var il := Icon.new("speaker_low")
	il.custom_minimum_size = Vector2(40, 30)
	il.col = C_DIM
	vh.add_child(il)
	vol_slider = HSlider.new()
	vol_slider.min_value = 0
	vol_slider.max_value = 100
	vol_slider.step = 1
	vol_slider.value = vol * 100.0
	vol_slider.custom_minimum_size = Vector2(0, 30)
	vol_slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vol_slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	vol_slider.value_changed.connect(_on_vol)
	vh.add_child(vol_slider)
	var ih := Icon.new("speaker")
	ih.custom_minimum_size = Vector2(40, 30)
	ih.col = C_DIM
	vh.add_child(ih)

	var c2 := _card(content)
	var r2 := HBoxContainer.new()
	r2.add_theme_constant_override("separation", 14)
	c2.add_child(r2)
	ico_mic = Icon.new("mic")
	r2.add_child(ico_mic)
	meter_mic = Meter.new()
	meter_mic.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	meter_mic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r2.add_child(meter_mic)
	tog_mic = Toggle.new()
	tog_mic.set_on(want_mic)
	tog_mic.toggled.connect(_on_mic)
	tog_mic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r2.add_child(tog_mic)

	var c3 := _card(content)
	var r3 := HBoxContainer.new()
	r3.add_theme_constant_override("separation", 14)
	c3.add_child(r3)
	var l3 := _label("Sous-titres en bulles (Whisper)", 16, C_TEXT, r3)
	l3.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l3.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	tog_subs = Toggle.new()
	tog_subs.set_on(want_subs)
	tog_subs.toggled.connect(_on_subs)
	tog_subs.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r3.add_child(tog_subs)

	var c4 := _card(content)
	var r4 := HBoxContainer.new()
	r4.add_theme_constant_override("separation", 14)
	c4.add_child(r4)
	var l4 := _label("Traduire les paroles en", 16, C_TEXT, r4)
	l4.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l4.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	opt_lang = OptionButton.new()
	for l in LANGS:
		opt_lang.add_item(l[1])
	opt_lang.select(sub_target)
	opt_lang.item_selected.connect(func(i: int):
		sub_target = i
		_save_pref()
		if not is_phone:
			_pc_subs_sync()
		_send_ctrl())
	r4.add_child(opt_lang)
	if not is_phone:
		var r4b := HBoxContainer.new()
		r4b.add_theme_constant_override("separation", 14)
		c4.add_child(r4b)
		var l4b := _label("Langue parlée", 16, C_TEXT, r4b)
		l4b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var opt_src := OptionButton.new()
		for l in ["Français", "English", "Español"]:
			opt_src.add_item(l)
		opt_src.select(src_i)
		opt_src.item_selected.connect(func(i: int):
			src_i = i
			lesson.lang = ["fr", "en", "es"][i]
			_save_pref()
			_pc_subs_sync())
		r4b.add_child(opt_src)
		var r4c := HBoxContainer.new()
		r4c.add_theme_constant_override("separation", 14)
		c4.add_child(r4c)
		var l4c := _label("Images depuis internet (Wikipédia)", 16, C_TEXT, r4c)
		l4c.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var tg_img := Toggle.new()
		tg_img.set_on(img_on)
		tg_img.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		tg_img.toggled.connect(func(on: bool):
			img_on = on
			lesson.images_on = on
			lesson._update_mini()
			_save_pref())
		r4c.add_child(tg_img)
		var h4c := _label("Cherche la photo des personnes et lieux cités. Seuls les noms sont envoyés à Wikipédia.", 13, C_DIM, c4)
		h4c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	if not is_phone:
		var cph := _card(content)
		var lt := Label.new()
		lt.text = "Téléphones à l'écoute"
		lt.add_theme_color_override("font_color", C_DIM)
		cph.add_child(lt)
		phones_box = VBoxContainer.new()
		phones_box.add_theme_constant_override("separation", 8)
		cph.add_child(phones_box)
		disc_btn = Button.new()
		disc_btn.text = "Déconnecter"
		disc_btn.visible = false
		disc_btn.pressed.connect(func():
			chosen = ""
			last_name = ""
			user_disc = true
			_save_pref()
			_pc_unlink())
		cph.add_child(disc_btn)
		var seg := Seg.new()
		seg.setup(["auto", "usb", "wifi"], [0, 2, 1], link_mode)
		seg.picked.connect(func(id: int):
			link_mode = id
			_save_pref())
		content.add_child(seg)
	content = main_content
	var chat_root := VBoxContainer.new()
	chat_root_n = chat_root
	chat_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	chat_root.anchor_top = 0.45
	chat_root.offset_left = 14
	chat_root.offset_right = -14
	chat_root.offset_bottom = -14
	chat_root.add_theme_constant_override("separation", 8)
	add_child(chat_root)
	subs_sc = ScrollContainer.new()
	subs_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	subs_sc.size_flags_stretch_ratio = 2.0
	subs_sc.custom_minimum_size = Vector2(0, 200)  # zone des blocs : taille minimale définie
	subs_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var clr_row := HBoxContainer.new()
	var clr_sp := Control.new()
	clr_sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	clr_row.add_child(clr_sp)
	var clr_btn := Button.new()
	clr_btn.text = "Effacer les paroles"
	clr_btn.pressed.connect(_clear_subs)
	clr_row.add_child(clr_btn)
	chat_root.add_child(clr_row)
	chat_root.add_child(subs_sc)
	subs_rows = VBoxContainer.new()
	subs_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	subs_rows.add_theme_constant_override("separation", 6)
	subs_sc.add_child(subs_rows)
	vbox_rows = subs_rows
	lesson = LessonScript.new()
	lesson.master = not is_phone
	lesson.images_on = img_on
	lesson.lang = ["fr", "en", "es"][src_i]
	lesson.make_label = func(t: String, col: String, fs: int) -> Control:
		var lw := []
		return _sub_label(_linkify(t, col, lw), t, fs, lw)
	lesson.slide_changed.connect(_on_slide)
	lesson.keyword_changed.connect(func(id: int, kw: String):
		if not is_phone and linked:
			_send(T_TEXT, ("\u000c%d\u001f%s" % [id, kw]).to_utf8_buffer()))
	lesson.graph_changed.connect(func(sid: int, payload: String):
		if not is_phone and linked:
			_send(T_TEXT, ("\u000b%d\u001f%s" % [sid, payload]).to_utf8_buffer().slice(0, 3000)))
	lesson.visible = false
	add_child(lesson)
	move_child(lesson, 1)
	chat_sc = ScrollContainer.new()
	chat_sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chat_root.add_child(chat_sc)
	bubbles = VBoxContainer.new()
	bubbles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bubbles.add_theme_constant_override("separation", 8)
	var chat_wrap := VBoxContainer.new()
	chat_wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_wrap.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var chat_fill := Control.new()
	chat_fill.size_flags_vertical = Control.SIZE_EXPAND_FILL
	chat_wrap.add_child(chat_fill)
	chat_wrap.add_child(bubbles)
	chat_sc.add_child(chat_wrap)
	var crow := HBoxContainer.new()
	crow.add_theme_constant_override("separation", 6)
	chat_root.add_child(crow)
	chat_in = LineEdit.new()
	chat_in.placeholder_text = "Pose une question à Goody…"
	chat_in.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_in.custom_minimum_size = Vector2(0, 44)
	chat_in.text_submitted.connect(func(_t: String): _chat_send())
	crow.add_child(chat_in)
	var sendb := Button.new()
	sendb.text = "Envoyer"
	sendb.pressed.connect(_chat_send)
	crow.add_child(sendb)
	var clrb := Button.new()
	clrb.text = "Effacer"
	clrb.pressed.connect(_chat_clear)
	crow.add_child(clrb)
	pop_layer = Control.new()
	pop_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	pop_layer.visible = false
	var pdim := ColorRect.new()
	pdim.color = Color(0, 0, 0, 0.55)
	pdim.set_anchors_preset(Control.PRESET_FULL_RECT)
	pdim.gui_input.connect(func(e: InputEvent):
		if e is InputEventMouseButton and e.pressed:
			pop_layer.visible = false)
	pop_layer.add_child(pdim)
	var pcen := CenterContainer.new()
	pcen.set_anchors_preset(Control.PRESET_FULL_RECT)
	pcen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pop_layer.add_child(pcen)
	var ppan := PanelContainer.new()
	var psb := StyleBoxFlat.new()
	psb.bg_color = C_CARD
	psb.border_color = C_OK
	psb.set_border_width_all(2)
	psb.set_corner_radius_all(14)
	for sd in ["left", "right", "top", "bottom"]:
		psb.set("content_margin_" + sd, 20)
	ppan.add_theme_stylebox_override("panel", psb)
	ppan.custom_minimum_size.x = clampf(get_viewport_rect().size.x - 60.0, 260.0, 520.0)
	pcen.add_child(ppan)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 12)
	ppan.add_child(pv)
	pop_word = _label("", 28, C_OK, pv)
	pop_word.add_theme_font_override("font", INTER)
	pop_text = _label("", 19, C_TEXT, pv)
	pop_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pop_text.add_theme_font_override("font", INTER)
	var pcl := Button.new()
	pcl.text = "Fermer"
	pcl.custom_minimum_size = Vector2(0, 44)
	pcl.pressed.connect(func(): pop_layer.visible = false)
	pv.add_child(pcl)
	add_child(pop_layer)
	add_child(settings_layer)
	_fit_width()


func _fit_width() -> void:
	var w := clampf(get_viewport_rect().size.x - 36.0, 280.0, 520.0)
	if content != null:
		content.custom_minimum_size.x = w
	if settings_box != null:
		settings_box.custom_minimum_size.x = w


func _set_status(st: int, a: String, b: String) -> void:
	state = st
	status.text = a
	sub.text = b if st == ST_IDLE else ""


func _ui_tick(delta: float) -> void:
	if tap_pending >= 0.0:
		tap_pending += delta
		if tap_pending > 0.35:
			tap_pending = -1.0
			_media(1)
	if press_t >= 0.0:
		press_t += delta
		if press_t > 0.6:
			press_t = -1.0
			settings_layer.visible = true
	lvl_out = maxf(0.0, lvl_out - delta * 1.2)
	lvl_mic = maxf(0.0, lvl_mic - delta * 1.2)
	ico_sound.col = C_TEXT if want_sound else C_DIM
	ico_mic.col = C_TEXT if want_mic else C_DIM
	meter_out.value = lvl_out if want_sound else 0.0
	meter_mic.value = lvl_mic if want_mic else 0.0
	var anim_n := "off"
	if state == ST_LINKED:
		anim_n = "happy" if maxf(lvl_out, lvl_mic) > 0.04 or (live_lbl != null and live_lbl.text != "") else "idle"
	elif state == ST_WAIT:
		anim_n = "wait"
	orb.anim = anim_n
	if live_box != null:
		live_box.visible = want_subs
		var vp := get_viewport_rect().size
		var want_land := vp.x > vp.y * 1.2 and want_subs and chat_root_n != null
		if want_land != land and chat_root_n != null:
			_set_land(want_land)
	orb.variant = mascot
	orb.level = maxf(meter_out.shown, meter_mic.shown) if state == ST_LINKED else 0.0
	var col: Color = [C_IDLE, C_WAIT, C_OK][state]
	orb.color = orb.color.lerp(col, minf(1.0, delta * 8.0))
	if state == ST_LINKED and peer != null:
		var tr := "USB" if peer.get_connected_host() == "127.0.0.1" else "Wi-Fi"
		chip.text = tr + (" · %d ms" % rtt_ms if rtt_ms >= 0 else "")
		chip.add_theme_color_override("font_color", C_OK)
		chip_sb.bg_color = Color(C_OK, 0.14)
	else:
		chip.text = "Hors ligne"
		chip.add_theme_color_override("font_color", C_DIM)
		chip_sb.bg_color = Color(1, 1, 1, 0.06)


func _on_sound(on: bool) -> void:
	want_sound = on
	if not is_phone:
		_pc_route()
	_send_ctrl()


func _on_mic(on: bool) -> void:
	want_mic = on
	if is_phone:
		mic_player.stream_paused = not on
	else:
		_pc_route()
	_send_ctrl()


## Pause/lecture (1) ou retour de 5 s (2) du média en cours sur le PC ; le téléphone transmet au PC.
func _media(code: int) -> void:
	if is_phone:
		_send(T_CMD, PackedByteArray([code]))
		return
	var sc := ""
	for p in [OS.get_executable_path().get_base_dir() + "/media.sh", ProjectSettings.globalize_path("res://tools/media.sh")]:
		if FileAccess.file_exists(p):
			sc = p
			break
	if sc == "":
		return
	var arg := "playpause" if code == 1 else "back"
	if OS.get_environment("FLATPAK_ID") != "":
		OS.create_process("flatpak-spawn", ["--host", "sh", sc, arg])
	else:
		OS.create_process("sh", [sc, arg])


func _on_subs(on: bool) -> void:
	want_subs = on
	if subs_card != null:
		subs_card.get_parent().visible = on
	_save_pref()
	if not is_phone:
		_pc_subs_sync()
	_send_ctrl()


func _on_vol(v: float) -> void:
	vol = v / 100.0
	if is_phone and player != null:
		player.volume_db = linear_to_db(maxf(vol, 0.0001)) if vol > 0.0 else -80.0
	_save_pref()
	_send_ctrl()


func _apply_ctrl_ui() -> void:
	tog_sound.set_on(want_sound)
	tog_mic.set_on(want_mic)
	tog_subs.set_on(want_subs)
	if subs_card != null:
		subs_card.get_parent().visible = want_subs
	vol_slider.set_value_no_signal(vol * 100.0)
	if is_phone:
		player.volume_db = linear_to_db(vol) if vol > 0.0 else -80.0
		mic_player.stream_paused = not want_mic


# ------------------------------------------------------------------ Réseau commun

func _send(t: int, data: PackedByteArray) -> void:
	if peer == null or peer.get_status() != StreamPeerTCP.STATUS_CONNECTED:
		return
	peer.put_data(PackedByteArray([t, data.size() & 255, data.size() >> 8]) + data)


func _send_ctrl() -> void:
	if linked:
		_send(T_CTRL, PackedByteArray([1 if want_sound else 0, 1 if want_mic else 0, int(vol * 100.0), 1 if want_subs else 0, sub_target, int(sub_delay * 2.0), 0]))


## Lit les trames reçues ; retourne false si la connexion est perdue.
func _read() -> bool:
	peer.poll()
	var st := peer.get_status()
	if st == StreamPeerTCP.STATUS_CONNECTING:
		wait_t += get_process_delta_time()
		return wait_t < 1.5
	if st != StreamPeerTCP.STATUS_CONNECTED:
		return false
	var n := peer.get_available_bytes()
	if n > 0:
		var r := peer.get_data(n)
		if r[0] == OK:
			rxbuf.append_array(r[1])
	while rxbuf.size() >= 3:
		var ln: int = rxbuf[1] | (rxbuf[2] << 8)
		if rxbuf.size() < 3 + ln:
			break
		var t: int = rxbuf[0]
		var pl := rxbuf.slice(3, 3 + ln)
		rxbuf = rxbuf.slice(3 + ln)
		_on_frame(t, pl)
	return true


func _on_frame(t: int, pl: PackedByteArray) -> void:
	match t:
		T_CTRL:
			if pl.size() >= 3:
				want_sound = pl[0] == 1
				want_mic = pl[1] == 1
				vol = pl[2] / 100.0
				if pl.size() >= 4:
					want_subs = pl[3] == 1
					if pl.size() >= 5:
						sub_target = clampi(pl[4], 0, LANGS.size() - 1)
						opt_lang.select(sub_target)
					if not is_phone:
						_pc_subs_sync()
				_apply_ctrl_ui()
				if not is_phone:
					_pc_route()
		T_PING:
			_send(T_PONG, pl)
		T_PONG:
			if pl.size() >= 4:
				rtt_ms = int(Time.get_ticks_msec() - pl.decode_u32(0)) & 0xFFFF
		T_CMD:
			if not is_phone and pl.size() >= 1:
				_media(pl[0])
		T_ANS:
			if is_phone:
				var at := pl.get_string_from_utf8()
				if at.begins_with("\u0004"):
					pop_text.text = at.substr(1)
				else:
					_add_msg("ai", at)
		T_ASK:
			if not is_phone and pl.size() >= 2:
				_ai_ask(pl.slice(1).get_string_from_utf8(), pl[0], true)
		T_TEXT:
			if is_phone and want_subs:
				_bubble(pl.get_string_from_utf8())
		T_AUDIO:
			if is_phone:
				_play(pl)
		T_NAME:
			if pl.size() >= 1:
				mascot = clampi(pl[0], 0, 7)
				peer_name = pl.slice(1).get_string_from_utf8()
		T_PIN:
			if is_phone:
				if pl.get_string_from_utf8() == phone_pin or phone_pin == "":
					authed = true
				else:
					_send(T_DENY, PackedByteArray())
					peer.poll()
					peer.disconnect_from_host()
					peer = null
					linked = false
		T_DENY:
			if not is_phone:
				deny_t = Time.get_ticks_msec()
				chosen = ""
				_pc_unlink()
		T_HELLO:
			if not is_phone and pl.size() >= 4:
				mic_rate = pl.decode_u32(0)
				peer_name = pl.slice(4).get_string_from_utf8()
				_pc_link()
		T_MIC:
			if not is_phone:
				_pc_mic(pl)


# ------------------------------------------------------------------ Téléphone

func _phone_init() -> void:
	DisplayServer.screen_set_keep_on(true)
	_overlay_init()
	var gen := AudioStreamGenerator.new()
	gen.mix_rate = RATE
	gen.buffer_length = 0.25
	player = AudioStreamPlayer.new()
	player.stream = gen
	add_child(player)
	player.play()
	pb = player.get_stream_playback()
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, "Mic")
	cap = AudioEffectCapture.new()
	cap.buffer_length = 0.5
	AudioServer.add_bus_effect(idx, cap)
	AudioServer.set_bus_mute(idx, true)
	mic_player = AudioStreamPlayer.new()
	mic_player.stream = AudioStreamMicrophone.new()
	mic_player.bus = "Mic"
	add_child(mic_player)
	get_tree().on_request_permissions_result.connect(func(_p, ok: bool): if ok: mic_player.play())
	if "android.permission.RECORD_AUDIO" in OS.get_granted_permissions() or not OS.has_feature("android"):
		mic_player.play()
	else:
		OS.request_permissions()
	mic_player.stream_paused = not want_mic
	server = TCPServer.new()
	server.listen(PORT)
	beacon.set_broadcast_enabled(true)
	beacon.set_dest_address("255.255.255.255", BEACON_PORT)
	_on_vol(vol * 100.0)


## Bulle flottante quand l'app passe en arrière-plan (Android + plugin PocketOverlay uniquement).
func _overlay_init() -> void:
	var ov: Node = preload("res://kit/overlay/overlay.gd").new()
	add_child(ov)
	if not ov.available():
		return
	ov.state_fn = func() -> Dictionary:
		return {"ok": linked, "text": "Connecté" if linked else "Hors ligne", "buttons": true, "sound": want_sound, "mic": want_mic}
	ov.action.connect(func(a: String):
		if a == "sound":
			tog_sound.set_on(not want_sound)
			_on_sound(not want_sound)
		elif a == "mic":
			tog_mic.set_on(not want_mic)
			_on_mic(not want_mic))
	preload("res://kit/overlay/overlay_ask.gd").ask_once(self, ov, "Pocket Speaker", "user://overlay.cfg")


func _phone_name() -> String:
	var m := OS.get_model_name()
	return m if m != "" and m != "GenericDevice" else "Téléphone"


func _phone_process(delta: float) -> void:
	if server.is_connection_available():
		var np := server.take_connection()
		if peer != null:
			peer.disconnect_from_host()
		peer = np
		rxbuf.clear()
		linked = false
		authed = true
	if peer != null:
		peer.poll()
		var st := peer.get_status()
		if st == StreamPeerTCP.STATUS_CONNECTED:
			_read()
			if peer == null:
				return
			if not linked and authed:
				linked = true
				var h := PackedByteArray()
				h.resize(4)
				h.encode_u32(0, int(AudioServer.get_mix_rate()))
				_send(T_HELLO, h + _phone_name().to_utf8_buffer())
				_send_ctrl()
				_set_status(ST_LINKED, "Connecté", "Le son de ton PC sort sur ce téléphone.")
			if linked:
				_phone_pump_mic()
		elif st != StreamPeerTCP.STATUS_CONNECTING:
			peer = null
			linked = false
			rtt_ms = -1
	if not linked:
		_set_status(ST_WAIT, "En attente du PC", "Lance Pocket Speaker sur le PC\n(USB branché ou même Wi-Fi).")
		beacon_t -= delta
		if beacon_t <= 0.0:
			beacon_t = 1.0
			beacon.put_packet(("POCKET|" + _phone_name()).to_utf8_buffer())


func _play(pl: PackedByteArray) -> void:
	var n := pl.size() / 4
	var pk := 0
	for i in range(0, pl.size() - 1, 32):
		pk = maxi(pk, absi(pl.decode_s16(i)))
	lvl_out = maxf(lvl_out, pk / 32768.0)
	if not want_sound:
		return
	var buffered := int(RATE * 0.25) - pb.get_frames_available()
	if buffered > int(RATE * 0.15) or pb.get_frames_available() < n:
		return  # trop de retard : on jette ce bloc pour rester en direct
	var arr := PackedVector2Array()
	arr.resize(n)
	for i in n:
		arr[i] = Vector2(pl.decode_s16(i * 4), pl.decode_s16(i * 4 + 2)) / 32768.0
	pb.push_buffer(arr)


func _phone_pump_mic() -> void:
	var n := cap.get_frames_available()
	if n <= 0:
		return
	var fr := cap.get_buffer(n)
	if not want_mic:
		return
	var out := PackedByteArray()
	out.resize(fr.size() * 2)
	var pk := 0.0
	for i in fr.size():
		var s := (fr[i].x + fr[i].y) * 0.5
		pk = maxf(pk, absf(s))
		out.encode_s16(i * 2, int(clampf(s, -1.0, 1.0) * 32767.0))
	lvl_mic = maxf(lvl_mic, pk)
	var o := 0
	while o < out.size():
		var e := mini(out.size(), o + 32000)
		_send(T_MIC, out.slice(o, e))
		o = e


# ------------------------------------------------------------------ PC

func _pc_name() -> String:
	var h := OS.get_environment("HOSTNAME")
	if h == "":
		h = FileAccess.get_file_as_string("/etc/hostname").strip_edges()
	return h if h != "" else "PC"


func _pa(args: PackedStringArray) -> String:
	var out: Array = []
	OS.execute("pactl", args, out, true)
	return "".join(out).strip_edges()


func _pc_init() -> void:
	var env := OS.get_environment("POCKET_ADB")
	var local := OS.get_executable_path().get_base_dir() + "/adb"
	adb_bin = env if env != "" else (local if FileAccess.file_exists(local) else "adb")
	# restes d'un lancement interrompu
	for line in _pa(["list", "short", "modules"]).split("\n"):
		if line.contains(SINK) or line.contains(MIC_SINK):
			var id := line.split("\t")[0]
			if id.is_valid_int():
				_pa(["unload-module", id])
	lan.bind(BEACON_PORT)
	th_adb = Thread.new()
	th_adb.start(_adb_loop)


func _adb(args: PackedStringArray) -> String:
	var out: Array = []
	if OS.execute(adb_bin, args, out, true) == -1:
		return "<noadb>"
	return "".join(out)


func _apk_path() -> String:
	for p in [OS.get_executable_path().get_base_dir() + "/pocket-speaker.apk",
			ProjectSettings.globalize_path("res://build/pocket-speaker.apk")]:
		if FileAccess.file_exists(p):
			return p
	return ""


## Thread : détecte le téléphone, installe/lance l'app, ouvre le tunnel USB.
func _adb_loop() -> void:
	var seen := ""
	while not quit:
		var out := _adb(["devices"])
		var serial := ""
		var unauth := false
		for line in out.split("\n"):
			var p := line.strip_edges().split("\t")
			if p.size() == 2:
				if p[1] == "device":
					serial = p[0]
				elif p[1] == "unauthorized":
					unauth = true
		mtx.lock()
		if serial == "":
			adb_state = "none"
			if out == "<noadb>":
				adb_msg = "adb introuvable (installe « android-tools-adb »)."
			elif unauth:
				adb_msg = "Autorise ce PC sur le téléphone (« Autoriser le débogage USB »)."
			else:
				adb_msg = "Branche le câble USB et active le débogage USB."
			seen = ""
		mtx.unlock()
		if serial != "":
			if serial != seen:
				seen = serial
				_adb_prepare()
			_adb(["forward", "tcp:%d" % PORT, "tcp:%d" % PORT])
			mtx.lock()
			adb_state = "ready"
			mtx.unlock()
		for i in 20:
			if quit:
				return
			OS.delay_msec(100)


func _adb_prepare() -> void:
	var have := -1
	var mt := RegEx.create_from_string("versionCode=(\\d+)").search(_adb(["shell", "dumpsys", "package", PKG]))
	if mt:
		have = mt.get_string(1).to_int()
	var apk := _apk_path()
	if have < VERSION and apk != "":
		mtx.lock()
		adb_msg = "Installation de l'app sur le téléphone…"
		mtx.unlock()
		_adb(["install", "-r", apk])
	_adb(["shell", "monkey", "-p", PKG, "-c", "android.intent.category.LAUNCHER", "1"])


func _pc_scan() -> void:
	var now := Time.get_ticks_msec()
	while lan.get_available_packet_count() > 0:
		var txt := lan.get_packet().get_string_from_utf8()
		var ip := lan.get_packet_ip()
		if txt.begins_with("POCKET"):
			var nm := txt.substr(7) if txt.length() > 7 else "Téléphone"
			phones[ip] = {"name": nm, "ip": ip, "t": now}
	for k in phones.keys():
		if now - int(phones[k]["t"]) > 4000:
			phones.erase(k)
	mtx.lock()
	var ast := adb_state
	mtx.unlock()
	var list: Array = []
	if link_mode != 2 and ast == "ready":
		list.append({"key": "usb", "name": "Téléphone branché (USB)"})
	if link_mode != 1:
		for k in phones:
			list.append({"key": k, "name": phones[k]["name"] + " · Wi-Fi"})
	if linked and chosen != "" and chosen != "usb":
		var found := false
		for d in list:
			found = found or d["key"] == chosen
		if not found:  # le téléphone connecté n'émet plus de balise : on le garde dans la liste
			list.append({"key": chosen, "name": (peer_name if peer_name != "" else "Téléphone") + " · connecté"})
	var sig := chosen + "|" + str(linked)
	for d in list:
		sig += "|" + d["key"] + d["name"]
	if test_mode and chosen == "" and not list.is_empty():
		chosen = list[0]["key"]
	if chosen == "" and not user_disc and not list.is_empty() and last_name == "":
		chosen = list[0]["key"]  # un seul clic en moins : on se connecte au premier téléphone proposé
	if chosen == "" and not user_disc and last_name != "":
		for d in list:
			if d["name"].begins_with(last_name):
				chosen = d["key"]
				break
	if sig != phones_sig and phones_box != null:
		phones_sig = sig
		for c in phones_box.get_children():
			c.queue_free()
		if list.is_empty():
			var e := Label.new()
			e.text = "Aucun pour l'instant. Ouvre Pocket Speaker sur le téléphone (même Wi-Fi) ou branche-le."
			e.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			e.add_theme_color_override("font_color", C_DIM)
			phones_box.add_child(e)
		for d in list:
			var b := Button.new()
			b.text = ("● " if d["key"] == chosen else "") + d["name"]
			b.custom_minimum_size = Vector2(0, 46)
			var key: String = d["key"]
			var nm2: String = d["name"]
			b.pressed.connect(func():
				if key == chosen:
					return
				if linked or peer != null:
					_pc_unlink()
				chosen = key
				user_disc = false
				last_name = nm2.split(" · ")[0]
				_save_pref())
			phones_box.add_child(b)
	if disc_btn != null:
		disc_btn.visible = chosen != ""


func _pc_process(delta: float) -> void:
	_pc_scan()
	if peer != null:
		if not _read():
			_pc_unlink()
			return
		if peer.get_status() == StreamPeerTCP.STATUS_CONNECTED:
			if not name_sent:
				name_sent = true
				_send(T_PIN, pin.to_utf8_buffer())
				_send(T_NAME, PackedByteArray([mascot]) + _pc_name().to_utf8_buffer())
			if linked:
				linked_t += delta
				_pc_pump_capture()
				_pc_pump_subs()
				ping_t -= delta
				if ping_t <= 0.0:
					ping_t = 2.0
					var b := PackedByteArray()
					b.resize(4)
					b.encode_u32(0, Time.get_ticks_msec())
					_send(T_PING, b)
				if test_mode and linked_t > 3.0:
					print("POCKET_TEST link ok rtt=%d phone=%s mascot=%d" % [rtt_ms, peer_name, mascot])
					_shutdown()
					get_tree().quit()
			else:
				hello_t += delta
				_set_status(ST_WAIT, "Téléphone trouvé", "Ouverture de la liaison…")
				if hello_t > 6.0:
					_pc_unlink()
		return
	mtx.lock()
	var st := adb_state
	var msg := adb_msg
	mtx.unlock()
	var host := ""
	if chosen == "usb" and link_mode != 1 and st == "ready":
		host = "127.0.0.1"
		_set_status(ST_WAIT, "Téléphone détecté", "Démarrage de l'app sur le téléphone…")
	elif chosen != "" and chosen != "usb" and phones.has(chosen) and link_mode != 2:
		host = chosen
		_set_status(ST_WAIT, "Connexion à " + str(phones[chosen]["name"]) + "…", "")
	elif chosen == "":
		if Time.get_ticks_msec() - deny_t < 6000:
			_set_status(ST_IDLE, "Code refusé", "Entre le code PIN affiché ici dans l'app du téléphone.")
		else:
			_set_status(ST_IDLE, "Choisis ton téléphone", msg + "\nOu ouvre l'app sur le téléphone (même Wi-Fi).")
		return
	else:
		_set_status(ST_IDLE, "Cherche le téléphone…", "Ouvre Pocket Speaker sur le téléphone (même Wi-Fi) ou branche-le.")
		return
	try_t -= delta
	if try_t <= 0.0:
		try_t = 0.8
		peer = StreamPeerTCP.new()
		rxbuf.clear()
		wait_t = 0.0
		hello_t = 0.0
		name_sent = false
		peer.connect_to_host(host, PORT)


func _pc_unlink() -> void:
	if linked:
		_pc_teardown()
	linked = false
	if peer != null:
		peer.disconnect_from_host()
	peer = null
	name_sent = false
	rtt_ms = -1
	_set_status(ST_IDLE, "Connexion perdue", "Nouvelle tentative…")


func _pc_link() -> void:
	if linked:
		return
	linked = true
	linked_t = 0.0
	ping_t = 0.0
	prev_src = _pa(["get-default-source"])
	prev_sink = _pa(["get-default-sink"])
	var m1 := _pa(["load-module", "module-null-sink", "sink_name=" + SINK,
			"sink_properties=device.description=Telephone-Pocket"])
	var m2 := _pa(["load-module", "module-null-sink", "sink_name=" + MIC_SINK,
			"sink_properties=device.description=Micro-Telephone"])
	modules = PackedStringArray([m2, m1])
	_pc_route()
	_pc_subs_sync()
	var io := OS.execute_with_pipe("parec", ["-d", SINK + ".monitor", "--format=s16le",
			"--rate=%d" % RATE, "--channels=2", "--latency-msec=20"], false)
	if io.has("pid"):
		cap_pid = io["pid"]
		cap_io = io["stdio"]
		th_cap = Thread.new()
		th_cap.start(_cap_loop)
	var mi := OS.execute_with_pipe("pacat", ["--playback", "--device=" + MIC_SINK,
			"--format=s16le", "--rate=%d" % mic_rate, "--channels=1", "--latency-msec=30"], false)
	if mi.has("pid"):
		mic_pid = mi["pid"]
		mic_io = mi["stdio"]
	_send_ctrl()
	_set_status(ST_LINKED, "Connecté", "Sortie « Telephone-Pocket » et micro « Micro-Telephone » prêts.")


## Envoie le son du PC vers l'enceinte virtuelle (ou le rend au PC si désactivé).
func _pc_route() -> void:
	if not linked or OS.get_environment("POCKET_NOROUTE") == "1":
		return
	var target := SINK if want_sound else prev_sink
	var want_src := MIC_SRC if want_mic else prev_src
	if want_src != "":
		_pa(["set-default-source", want_src])
	if target == "":
		return
	_pa(["set-default-sink", target])
	for line in _pa(["list", "short", "sink-inputs"]).split("\n"):
		var id := line.split("\t")[0]
		if id.is_valid_int():
			_pa(["move-sink-input", id, target])


func _cap_loop() -> void:
	while not quit and cap_pid > 0:
		var b := PackedByteArray()
		while b.size() < CHUNK * 4:
			var part := cap_io.get_buffer(CHUNK * 4 - b.size())
			if part.size() == 0:
				if cap_pid <= 0 or not OS.is_process_running(cap_pid):
					return
				OS.delay_msec(4)
				continue
			b.append_array(part)
		mtx.lock()
		cap_queue.append(b)
		if cap_queue.size() > 8:
			cap_queue.pop_front()
		mtx.unlock()


func _pc_pump_capture() -> void:
	mtx.lock()
	var q := cap_queue
	cap_queue = []
	mtx.unlock()
	for b: PackedByteArray in q:
		var p := 0
		for i in range(0, b.size() - 1, 32):
			p = maxi(p, absi(b.decode_s16(i)))
		lvl_out = maxf(lvl_out, p / 32768.0)
		if subs_io != null and subs_ready:
			if subs_bytes == 0:
				subs_t0 = Time.get_ticks_msec()
			subs_bytes += b.size()
			subs_io.store_buffer(b)
		if want_sound:
			if sub_delay < 0.05 or not want_subs:
				_send(T_AUDIO, b)
			else:
				delay_q.append([Time.get_ticks_msec(), b])
	var now := Time.get_ticks_msec()
	var lim := sub_delay * 1000.0 if want_subs else 0.0
	while not delay_q.is_empty() and (now - int(delay_q[0][0]) >= lim or not want_sound):
		var it: Array = delay_q.pop_front()
		if want_sound:
			_send(T_AUDIO, it[1])


func _pc_mic(pl: PackedByteArray) -> void:
	var p := 0
	for i in range(0, pl.size() - 1, 16):
		p = maxi(p, absi(pl.decode_s16(i)))
	lvl_mic = maxf(lvl_mic, p / 32768.0)
	if want_mic and mic_io != null:
		mic_io.store_buffer(pl)


func _pc_teardown() -> void:
	_pc_subs_stop()
	if prev_src != "":
		_pa(["set-default-source", prev_src])
	if prev_sink != "":
		if OS.get_environment("POCKET_NOROUTE") != "1":
			_pa(["set-default-sink", prev_sink])
			for line in _pa(["list", "short", "sink-inputs"]).split("\n"):
				var id := line.split("\t")[0]
				if id.is_valid_int():
					_pa(["move-sink-input", id, prev_sink])
	if cap_pid > 0:
		OS.kill(cap_pid)
		cap_pid = -1
	if th_cap != null:
		th_cap.wait_to_finish()
		th_cap = null
	cap_io = null
	if mic_pid > 0:
		OS.kill(mic_pid)
		mic_pid = -1
	mic_io = null
	for m in modules:
		if m.is_valid_int():
			_pa(["unload-module", m])
	modules = PackedStringArray()
	cap_queue.clear()


# ------------------------------------------------------------------ Sous-titres (Whisper)

func _subs_script() -> String:
	for p in [OS.get_executable_path().get_base_dir() + "/vosk_stream.py",
			ProjectSettings.globalize_path("res://tools/vosk_stream.py")]:
		if FileAccess.file_exists(p):
			return p
	return ""


## Démarre ou arrête Whisper selon « sous-titres » et l'état de la liaison.
func _pc_subs_sync() -> void:
	if want_subs and linked:
		if subs_pid > 0 and subs_target_run != sub_target * 4 + src_i:
			_pc_subs_stop()
		if subs_pid <= 0:
			var sc := _subs_script()
			if sc == "":
				return
			var cmd := "python3"
			var venv := OS.get_environment("HOME") + "/.local/share/pocket-speaker/venv/bin/python3"
			if FileAccess.file_exists(venv):
				cmd = venv
			var args := PackedStringArray([sc, "_", ["fr", "en", "es"][src_i], LANGS[sub_target][0], "0"])
			if OS.get_environment("FLATPAK_ID") != "":  # le Python du sandbox n'a pas Whisper : on lance sur l'hôte
				cmd = "flatpak-spawn"
				args = PackedStringArray(["--host", "--watch-bus", venv if FileAccess.file_exists(venv) else "python3"]) + args
			var io := OS.execute_with_pipe(cmd, args, false)
			if io.has("pid"):
				subs_pid = io["pid"]
				subs_io = io["stdio"]
				subs_ready = false
				subs_target_run = sub_target * 4 + src_i
				th_subs = Thread.new()
				th_subs.start(_subs_loop)
	else:
		_pc_subs_stop()


func _pc_subs_stop() -> void:
	if subs_pid > 0:
		OS.kill(subs_pid)
		subs_pid = -1
	if th_subs != null:
		th_subs.wait_to_finish()
		th_subs = null
	subs_io = null
	subs_ready = false
	subs_bytes = 0
	sub_sched.clear()
	mtx.lock()
	subs_out.clear()
	mtx.unlock()


func _subs_loop() -> void:
	while not quit and subs_pid > 0 and subs_io != null:
		var line := subs_io.get_line()
		if line == "":
			if subs_pid <= 0 or not OS.is_process_running(subs_pid):
				return
			OS.delay_msec(20)
			continue
		if line.begins_with("\u0001ready"):
			subs_ready = true
			continue
		mtx.lock()
		subs_out.append(line)
		mtx.unlock()


## Planifie chaque groupe de mots à l'heure où il est prononcé (son décalé), sans les lâcher d'un seul coup.
func _pc_pump_subs() -> void:
	if subs_out.is_empty():
		return
	mtx.lock()
	var q := subs_out
	subs_out = []
	mtx.unlock()
	for line: String in q:
		_send(T_TEXT, line.to_utf8_buffer().slice(0, 1000))
		_bubble(line)


## Aperçu sans voix (POCKET_DEMO=1) : une petite conférence qui arrive phrase par phrase ; POCKET_SHOT=fichier.png capture puis quitte.
func _demo() -> void:
	want_subs = true
	var txt := ["Marie Curie est née à Varsovie en 1867.", "Elle a épousé Pierre Curie, un physicien français, en 1895.",
		"Ensemble ils ont découvert le radium et le polonium à Paris.", "En 1903, ils reçoivent le prix Nobel de physique avec Henri Becquerel.",
		"Pierre meurt dans un accident de la route en 1906.", "Marie obtient seule un second prix Nobel, de chimie, en 1911."]
	for i in txt.size():
		_add_block(i + 1, txt[i])
		await get_tree().create_timer(1.2).timeout
	var shot := OS.get_environment("POCKET_SHOT")
	if shot != "":
		await get_tree().create_timer(25.0).timeout
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _clear_subs() -> void:
	for c in subs_rows.get_children():
		c.queue_free()
	blocks.clear()
	block_data.clear()
	transcript.clear()
	lesson.clear()
	_set_live("")


func _set_live(t: String) -> void:
	if live_lbl != null:
		if lesson != null:
			lesson.note_text(t)
		live_lbl.text = t if t.length() <= 84 else "…" + t.substr(t.length() - 82)  # on garde la fin, la boîte reste fixe


func _bubble(text: String) -> void:
	if text.begins_with("\u0006"):
		_set_live(text.substr(1))
	elif text.begins_with("\u000c"):
		var kc := text.find("\u001f")
		if kc > 1:
			lesson.apply_keyword(text.substr(1, kc - 1).to_int(), text.substr(kc + 1))
	elif text.begins_with("\u000b"):
		var kk := text.find("\u001f")
		if kk > 1:
			lesson.apply_graph(text.substr(1, kk - 1).to_int(), text.substr(kk + 1))
	elif text.begins_with("\u0009"):
		var parts := text.substr(1).split("\u001f")
		if parts.size() >= 3:
			var ids: Array = []
			for x in parts[2].split(",", false):
				ids.append(int(x))
			lesson.apply_slide(int(parts[0]), parts[1], ids)
	elif text.begins_with("\u0007") or text.begins_with("\u0008"):
		var k := text.find("\u001f")
		if k > 1:
			var id := text.substr(1, k - 1).to_int()
			if text.begins_with("\u0007"):
				_add_block(id, text.substr(k + 1))
			else:
				_set_trans(id, text.substr(k + 1))


## Un bloc par phrase terminée (chronologique, le plus récent en bas) ; la traduction s'ajoute dessous quand elle arrive.
func _add_block(id: int, orig: String) -> void:
	block_data.append({"id": id, "text": orig, "trans": ""})
	while block_data.size() > 200:
		block_data.pop_front()
	transcript.append(orig)
	while transcript.size() > 40:
		transcript.pop_front()
	_build_block(id, orig)
	lesson.add_sentence(id, orig)


func _build_block(id: int, orig: String) -> void:
	if subs_rows == null:
		return
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	var pc := PixBox.new(Color(0.04, 0.05, 0.07), Color(0.42, 0.5, 0.52), 14)
	var tm2 := Label.new()
	tm2.text = Time.get_time_string_from_system()
	tm2.add_theme_font_size_override("font_size", 12)
	tm2.add_theme_color_override("font_color", Color("9aa5b1"))
	v.add_child(tm2)
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pc.add_child(v)
	var lw := []
	v.add_child(_sub_label(_linkify(orig, "#ffffff", lw), orig, 26 if is_phone else 23, lw))
	var at_end := subs_sc.scroll_vertical >= subs_sc.get_v_scroll_bar().max_value - subs_sc.size.y - 40
	subs_rows.add_child(pc)
	blocks[id] = v
	var nb := subs_rows.get_child_count()
	for i in nb:
		subs_rows.get_child(i).modulate = Color(1, 1, 1, 1.0 if i >= nb - 1 else 0.6)
	while subs_rows.get_child_count() > 200:
		var old := subs_rows.get_child(0)
		subs_rows.remove_child(old)
		old.queue_free()
	if at_end:
		await get_tree().process_frame
		await get_tree().process_frame
		subs_sc.scroll_vertical = int(subs_sc.get_v_scroll_bar().max_value)


func _set_trans(id: int, t: String) -> void:
	lesson.set_trans(id, t)
	for d in block_data:
		if d["id"] == id:
			d["trans"] = t
	_show_trans(id, t)


func _show_trans(id: int, t: String) -> void:
	if not blocks.has(id) or not is_instance_valid(blocks[id]):
		return
	var rw := []
	blocks[id].add_child(_sub_label(_linkify(t, "#ffd45e", rw), t, 23 if is_phone else 20, rw))


## Bascule portrait <-> paysage : en paysage, salle de classe + diaporama ; la zone d'assistant passe sous la mascotte.
func _set_land(on: bool) -> void:
	land = on
	lesson.visible = on
	subs_sc.visible = not on
	status.visible = not on  # en paysage : la place sert au décor de la classe
	sub.visible = not on
	hint_n.visible = not on
	if on:
		chat_root_n.anchor_right = 0.34
		chat_root_n.anchor_top = 0.62
		margin_n.anchor_right = 0.34
		live_box.custom_minimum_size.y = 120
	else:
		chat_root_n.anchor_right = 1.0
		chat_root_n.anchor_top = 0.45
		margin_n.anchor_right = 1.0
		live_box.custom_minimum_size.y = 150


func _on_slide(sid: int, title: String, ids: Array) -> void:
	if not is_phone and linked:
		_send(T_TEXT, ("\u0009%d\u001f%s\u001f%s" % [sid, title, ",".join(ids.map(func(i): return str(i)))]).to_utf8_buffer().slice(0, 1000))


func _sub_label(bb: String, plain: String, fs: int, words: Array) -> RichTextLabel:
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.meta_underlined = false
	l.custom_minimum_size.x = 60
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("normal_font", INTER)
	l.add_theme_font_size_override("normal_font_size", fs)
	l.add_theme_constant_override("line_separation", 6)
	l.text = bb
	l.meta_clicked.connect(func(m: Variant): _explain(str(words[int(str(m))]), plain))
	return l


## Chaque mot devient cliquable (définition). Les métas sont des index : une apostrophe dans [url=…] casserait le bbcode.
func _linkify(t: String, col: String, words: Array) -> String:
	var out := "[color=" + col + "]"
	var re := RegEx.create_from_string("[\\p{L}][\\p{L}\\p{N}'’-]*")
	var p := 0
	for m in re.search_all(t):
		out += _esc(t.substr(p, m.get_start() - p))
		words.append(m.get_string())
		out += "[url=%d]%s[/url]" % [words.size() - 1, m.get_string()]
		p = m.get_end()
	return out + _esc(t.substr(p)) + "[/color]"


func _esc(t: String) -> String:
	return t.replace("[", "[lb]").replace("]", "[rb]")


## kind : "sub" (parole), "me" (ma question), "ai" (réponse de Goody).
func _add_msg(kind: String, bb: String, plain := "") -> void:
	if bubbles == null:
		return
	var wrap := MarginContainer.new()
	wrap.mouse_filter = Control.MOUSE_FILTER_PASS
	wrap.add_theme_constant_override("margin_left", 48 if kind == "me" else 0)
	wrap.add_theme_constant_override("margin_right", 48 if kind == "ai" else 0)
	var pc := PanelContainer.new()
	pc.mouse_filter = Control.MOUSE_FILTER_PASS
	var sb := StyleBoxFlat.new()
	sb.bg_color = {"sub": Color(0.09, 0.11, 0.14, 0.94), "me": Color(0.12, 0.2, 0.32, 0.95), "ai": Color(0.2, 0.15, 0.07, 0.95)}[kind]
	sb.border_color = {"sub": C_OK, "me": Color("5aa9ff"), "ai": C_WAIT}[kind]
	sb.border_color.a = 0.7
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	pc.add_theme_stylebox_override("panel", sb)
	var l := RichTextLabel.new()
	l.bbcode_enabled = true
	l.fit_content = true
	l.scroll_active = false
	l.meta_underlined = true
	l.mouse_filter = Control.MOUSE_FILTER_PASS
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_override("normal_font", INTER)
	l.add_theme_font_override("bold_font", INTER)
	l.add_theme_font_size_override("normal_font_size", 22 if is_phone else 19)
	l.add_theme_color_override("default_color", C_TEXT)
	l.text = bb
	if plain != "":
		l.meta_clicked.connect(func(m: Variant): _explain(str(m), plain))
	pc.add_child(l)
	wrap.add_child(pc)
	bubbles.add_child(wrap)
	while bubbles.get_child_count() > 150:
		var old := bubbles.get_child(0)
		bubbles.remove_child(old)
		old.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	chat_sc.scroll_vertical = int(chat_sc.get_v_scroll_bar().max_value)


func _chat_clear() -> void:
	for c in bubbles.get_children():
		c.queue_free()
	ai_hist.clear()


func _chat_send() -> void:
	var t := chat_in.text.strip_edges()
	if t == "":
		return
	chat_in.text = ""
	_add_msg("me", _esc(t))
	_ask(t, 0)


func _explain(word: String, sentence: String) -> void:
	var extra := ""
	if sub_target > 0:
		extra = " Ajoute ensuite, sur une nouvelle ligne, la définition en %s." % LANGS[sub_target][1]
	pop_word.text = word
	pop_text.text = "…"
	pop_layer.visible = true
	_ask("Définis le mot « %s » tel qu'il est utilisé dans la phrase « %s ». Donne d'abord la définition en français (1 à 2 phrases), puis un court exemple.%s" % [word, sentence, extra], 2)


func _ask(text: String, mode: int) -> void:
	if is_phone:
		if not linked:
			_add_msg("ai", "Je ne suis pas relié au PC : lance Pocket Speaker dessus.")
			return
		_send(T_ASK, PackedByteArray([mode]) + text.to_utf8_buffer().slice(0, 4000))
	else:
		_ai_ask(text, mode, false)


## PC : interroge Ollama (local) et affiche / renvoie la réponse de la mascotte.
func _ai_ask(text: String, mode: int, from_phone: bool) -> void:
	if from_phone and mode == 0:
		_add_msg("me", "[color=#8892a0]📱[/color] " + _esc(text))
	var msgs: Array = [{"role": "system", "content": PERSONA}]
	if not transcript.is_empty():
		msgs.append({"role": "system", "content": "Paroles entendues récemment sur le PC (sous-titres, de la plus ancienne à la plus récente) :\n" + "\n".join(transcript).right(3500)})
	if mode == 0:
		msgs.append_array(ai_hist)
	msgs.append({"role": "user", "content": text})
	var model := OS.get_environment("POCKET_CHAT_MODEL") if OS.get_environment("POCKET_CHAT_MODEL") != "" else "gemma3:4b"
	var http := HTTPRequest.new()
	http.timeout = 90
	add_child(http)
	http.request_completed.connect(func(_r: int, code: int, _h: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		var ans := "Ollama ne répond pas (lance « ollama serve »)."
		if code == 200:
			var j: Variant = JSON.parse_string(body.get_string_from_utf8())
			if j is Dictionary and j.has("message"):
				ans = str(j["message"].get("content", "")).strip_edges()
		if mode == 0 and code == 200:
			ai_hist.append({"role": "user", "content": text})
			ai_hist.append({"role": "assistant", "content": ans})
			while ai_hist.size() > 12:
				ai_hist.pop_front()
		if mode == 2:
			if from_phone:
				_send(T_ANS, ("\u0004" + ans).to_utf8_buffer().slice(0, 60000))
			else:
				pop_text.text = ans
			return
		_add_msg("ai", _esc(ans))
		if from_phone:
			_send(T_ANS, ans.to_utf8_buffer().slice(0, 60000)))
	var err := http.request("http://127.0.0.1:11434/api/chat", ["Content-Type: application/json"], HTTPClient.METHOD_POST,
			JSON.stringify({"model": model, "messages": msgs, "stream": false, "keep_alive": "30m", "options": {"num_predict": 400}}))
	if err != OK:
		http.queue_free()
		_add_msg("ai", "Impossible de joindre Ollama.")
