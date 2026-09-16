@tool
extends EditorPlugin

var button:Button

func _enter_tree() -> void:
	button = Button.new()
	button.text = 'Gizmos'
	button.button_pressed = false
	button.toggle_mode = false
	button.pressed.connect(func():
		
		var viewport_menu:Control
		var ver := Engine.get_version_info()
		match str(ver.major) + "." + str(ver.minor):
			"4.4":
				viewport_menu = button.get_parent(
					).get_parent(
					).get_parent(
					).get_parent(
					).get_parent(
					).get_child(1
					).get_child(0
					).get_child(0
					).get_child(0
					).get_child(0
					).get_child(1
					).get_child(0
					).get_child(0)
			"4.5":
				viewport_menu = button.get_parent(
					).get_parent(
					).get_parent(
					).get_parent(
					).get_parent(
					).get_child(1
					).get_child(0
					).get_child(0
					).get_child(0
					).get_child(0
					).get_child(1
					).get_child(0
					).get_child(0
					).get_child(0)
			"4.7":
				viewport_menu = button.get_parent(
					).get_parent(
					).get_parent(
					).get_parent(
					).get_parent(
					).get_child(1
					).get_child(0
					).get_child(0
					).get_child(0
					).get_child(0
					).get_child(0
					).get_child(0
					).get_child(1
					).get_child(0
					).get_child(0
					).get_child(0)
			_:
				viewport_menu = button
				while viewport_menu.get_class() != "Node3DEditor":
					viewport_menu = viewport_menu.get_parent()
				if viewport_menu:
					for c in _get_all_children(viewport_menu):
						if c is MenuButton:
							if c.text == "Perspective" or c.text == "Orthogonal":
								viewport_menu = c
								push_warning("Toggle Overlays: configured automatically, may not be correct for this version")
								break
		
		if !viewport_menu: return
		if viewport_menu is not MenuButton: return
		
		var popup:PopupMenu
		if viewport_menu is MenuButton:
			popup = viewport_menu.get_popup()
		else:
			if viewport_menu.modulate == Color.WHITE:
				viewport_menu.modulate = Color.RED
			else:
				viewport_menu.modulate = Color.WHITE
			return
		
		#var list := [22,23,24,25,26]
		var list := [22,23,24]
		
		var gizmos := false
		for i in list:
			if popup.is_item_checked(i):
				gizmos = true
				break
		
		if gizmos:
			viewport_menu.modulate = (Color.FIREBRICK + Color.WHITE) * 0.5
			for i in list:
				popup.set_item_checked(i, true)
				popup.id_pressed.emit(popup.get_item_id(i))
		else:
			viewport_menu.modulate = Color.WHITE
			for i in list:
				popup.set_item_checked(i, false)
				popup.id_pressed.emit(popup.get_item_id(i))
	)
	
	add_control_to_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, button)

func _exit_tree() -> void:
	# Clean up
	if is_instance_valid(button):
		remove_control_from_container(EditorPlugin.CONTAINER_SPATIAL_EDITOR_MENU, button)
		button.queue_free()
		button = null

func _get_all_children(node:Node) -> Array[Node]:
	var nodes:Array[Node]
	for n in node.get_children():
		nodes.append(n)
		if n.get_child_count() > 0:
			nodes.append_array(_get_all_children(n))
	return nodes
