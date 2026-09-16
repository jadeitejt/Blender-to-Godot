@tool
extends EditorPlugin

var button:Button

func _enter_tree() -> void:
	get_viewport().gui_focus_changed.connect(func(n:Node) -> void:
		if n is TextEdit or n is LineEdit:
			if &"middle_mouse_paste_enabled" in n:
				n.middle_mouse_paste_enabled = false
	)
