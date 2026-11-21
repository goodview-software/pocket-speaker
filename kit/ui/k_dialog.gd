extends RefCounted
## Dialogues prêts à l'emploi : KDialog.confirm(host, titre, message, ok, danger) -> KModal (signal result("ok"|"")).
const Modal := preload("res://kit/ui/k_modal.gd")
static func confirm(host: Node, title: String, msg: String, ok_text := "Confirmer", danger := false, cancel_text := "Annuler") -> Control:
	var m: Control = Modal.new()
	m.title = title
	m.danger = danger
	m.add_text(msg)
	m.add_button(cancel_text, "secondary", "")
	m.add_button(ok_text, "danger" if danger else "primary", "ok")
	m.popup(host)
	return m

static func alert(host: Node, title: String, msg: String, ok_text := "OK") -> Control:
	var m: Control = Modal.new()
	m.title = title
	m.add_text(msg)
	m.add_button(ok_text, "primary", "ok")
	m.popup(host)
	return m
