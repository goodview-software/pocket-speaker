extends "res://kit/layout/k_page.gd"
## Galerie : chaque composant dans chaque état, pour relecture humaine. Utilisable seule (gallery.tscn) ou comme page.
const K := preload("res://kit/k.gd")
var toaster: Control
var embedded := false
var popup_host: Node

func _ready() -> void:
	if not embedded:
		build_shell()
		set_title("Kit Goodview")
	if popup_host == null:
		popup_host = self
	_build()

func _sec(title: String, sub := "") -> VBoxContainer:
	var card: Control = K.Card.new()
	body.add_child(card)
	var v: VBoxContainer = K.KS.vbox(card, K.Tokens.S4)
	var s: VBoxContainer = K.Section.make(title, sub)
	v.add_child(s)
	return s.content

func _row(parent: Node) -> Control:
	var r: Control = K.Row.new()
	r.gap = K.Tokens.S3
	parent.add_child(r)
	return r

func _build() -> void:
	toaster = K.Toast.new()
	popup_host.add_child(toaster)
	# Couleurs
	var c := _sec("Couleurs", "Accent, échelle 50 à 950, surfaces, états")
	var pr := _row(c)
	for i in K.Tokens.pal.size():
		var sw := ColorRect.new()
		sw.color = K.Tokens.pal[i]
		sw.custom_minimum_size = Vector2(32, 32)
		pr.add_child(sw)
	var sr := _row(c)
	for col in [K.Tokens.surface0, K.Tokens.surface1, K.Tokens.surface2, K.Tokens.surface3, K.Tokens.success, K.Tokens.warn, K.Tokens.danger, K.Tokens.info]:
		var sw2 := ColorRect.new()
		sw2.color = col
		sw2.custom_minimum_size = Vector2(32, 32)
		sr.add_child(sw2)
	# Typographie
	var t := _sec("Typographie", "Inter 400/500/600/700, échelle xs à 3xl")
	for p in [["3xl", K.Tokens.FS_3XL], ["2xl", K.Tokens.FS_2XL], ["xl", K.Tokens.FS_XL], ["lg", K.Tokens.FS_LG], ["base", K.Tokens.FS_BASE], ["sm", K.Tokens.FS_SM], ["xs", K.Tokens.FS_XS]]:
		K.label(t, "%s — Portez ce vieux whisky au juge blond qui fume" % p[0], p[1], null, 400 if p[1] < 20 else 700)
	# Boutons
	var b := _sec("Boutons", "primary, secondary, ghost, danger, icon ; sm / md / lg ; états")
	for kind in ["primary", "secondary", "ghost", "danger"]:
		var r := _row(b)
		for sz in ["sm", "md", "lg"]:
			r.add_child(K.Btn.make(kind.capitalize(), kind, sz, "plus" if sz == "md" else ""))
		var dis: Control = K.Btn.make("Désactivé", kind, "md")
		dis.disabled = true
		r.add_child(dis)
		var ld: Control = K.Btn.make("Chargement", kind, "md")
		ld.loading = true
		r.add_child(ld)
	var ri := _row(b)
	for ic in ["settings", "trash-2", "search", "send"]:
		ri.add_child(K.Btn.make("", "icon", "md", ic))
	var rr: Control = K.Btn.make("Icône à droite", "secondary", "md")
	rr.icon_right = "chevron-right"
	ri.add_child(rr)
	# Badges
	var bd := _sec("Badges")
	var br := _row(bd)
	for k in ["neutral", "accent", "success", "warn", "danger", "info"]:
		br.add_child(K.Badge.make(k, k))
	br.add_child(K.Badge.make("Installée", "success", "check"))
	# Champs
	var f := _sec("Champs", "libellé flottant, erreur, icône")
	var i1 = K.InputField.new()
	i1.label_text = "Nom"
	f.add_child(i1)
	var i2 = K.InputField.new()
	i2.label_text = "Recherche"
	i2.icon = "search"
	f.add_child(i2)
	var i3 = K.InputField.new()
	i3.label_text = "Adresse Ollama"
	i3.error = "Adresse invalide"
	f.add_child(i3)
	var i4 = K.Textarea.new()
	i4.label_text = "Message"
	f.add_child(i4)
	# Contrôles
	var ct := _sec("Contrôles", "interrupteur, segmenté, onglets, progression, avatar")
	var tr := _row(ct)
	var tg: Control = K.Toggle.new()
	tr.add_child(tg)
	var tg2: Control = K.Toggle.new()
	tg2.set_on(true, false)
	tr.add_child(tg2)
	var sg: Control = K.Segmented.new()
	sg.options = [["a", "Max"], ["b", "Réduit"], ["c", "Off"]]
	ct.add_child(sg)
	var tabs: Control = K.Tabs.new()
	for n in ["Aperçu", "Détails", "Journal"]:
		tabs.add_tab(n, n, K.label(null, "Contenu " + n, K.Tokens.FS_SM, K.Tokens.text_muted))
	ct.add_child(tabs)
	var pg: Control = K.Progress.new()
	pg.value = 0.6
	ct.add_child(pg)
	var pg2: Control = K.Progress.new()
	pg2.indeterminate = true
	ct.add_child(pg2)
	var av := _row(ct)
	for n in ["Goody", "Rosie", "Bleu"]:
		var a: Control = K.Avatar.new()
		a.initials = n
		a.diameter = 40
		a.tint = K.Tokens.pal_at(700)
		a.status = K.Tokens.success
		av.add_child(a)
	# Listes
	var l := _sec("Lignes, statistiques, clé/valeur")
	var lr: Control = K.ListRow.make("Goodview Chat", "Version 1.2.0 · Linux", "message-circle")
	lr.set_chevron()
	l.add_child(lr)
	l.add_child(K.ListRow.make("Paramètres", "Nom très très long pour vérifier le retour à la ligne sans coupure du texte", "settings"))
	var st := _row(l)
	for p in [["12", "apps"], ["3", "mises à jour"], ["1,2 Go", "espace"]]:
		var s: Control = K.Stat.make(p[0], p[1])
		s.custom_minimum_size.x = 96
		st.add_child(s)
	var kv = K.KeyValue.new()
	kv.add_row("Version", "1.2.0")
	kv.add_row("Éditeur", "goodview-software")
	kv.add_row("Description", "Une description plus longue qui passe à la ligne proprement")
	l.add_child(kv)
	l.add_child(K.Divider.new())
	# Cartes et grille adaptative
	var g := _sec("Cartes et grille adaptative")
	var grid: Control = K.Grid.new()
	grid.min_card_width = 220
	g.add_child(grid)
	for i in 5:
		var cd: Control = K.Card.new()
		cd.interactive = i != 1
		cd.selected = i == 2
		var v := K.KS.vbox(cd, K.Tokens.S1)
		K.label(v, "Carte %d" % (i + 1), K.Tokens.FS_LG, null, 600)
		K.muted(v, ["Interactive", "Statique", "Sélectionnée", "Interactive", "Texte plus long pour tester la hauteur égale des cartes de la grille"][i])
		grid.add_child(cd)
	# Chargement et vide
	var e := _sec("Squelettes et état vide")
	var sk: Control = K.Skeleton.new()
	sk.custom_minimum_size.y = 20
	e.add_child(sk)
	var sk2: Control = K.Skeleton.new()
	sk2.custom_minimum_size.y = 20
	e.add_child(sk2)
	e.add_child(K.EmptyState.make("Aucune application", "Ajoute une app ou vérifie ta connexion.", "package", "Actualiser"))
	# Popups
	var p := _sec("Modales, feuilles, menus, toasts")
	var pr2 := _row(p)
	var mb: Control = K.Btn.make("Modale", "secondary")
	mb.pressed.connect(func():
		var m: Control = K.Modal.new()
		m.title = "Titre de la modale"
		m.add_text("Contenu de la modale, avec des boutons alignés à droite.")
		m.add_button("Annuler", "secondary", "")
		m.add_button("Valider", "primary", "ok")
		m.popup(popup_host))
	pr2.add_child(mb)
	var db: Control = K.Btn.make("Dialogue danger", "danger")
	db.pressed.connect(func(): K.Dialog.confirm(popup_host, "Supprimer ?", "Cette action est définitive.", "Supprimer", true))
	pr2.add_child(db)
	var sb: Control = K.Btn.make("Feuille", "secondary")
	sb.pressed.connect(func():
		var m: Control = K.Sheet.new()
		m.title = "Feuille"
		m.add_text("Monte du bas de l'écran.")
		m.add_button("Fermer", "primary", "")
		m.popup(popup_host))
	pr2.add_child(sb)
	var mn: Control = K.Btn.make("Menu", "secondary", "md", "ellipsis")
	mn.pressed.connect(func(): K.Menu.open(popup_host, [{"id": "a", "label": "Renommer", "icon": "pencil"}, {"id": "b", "label": "Copier", "icon": "copy"}, {"sep": true}, {"id": "c", "label": "Supprimer", "icon": "trash-2", "danger": true}], mn.get_global_rect()))
	pr2.add_child(mn)
	var tb: Control = K.Btn.make("Toast", "secondary")
	tb.pressed.connect(func(): toaster.push("Enregistré", "success"))
	pr2.add_child(tb)
	K.Tooltip.attach(tb, "Affiche un toast")
