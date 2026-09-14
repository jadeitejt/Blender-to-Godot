@tool
extends EditorScenePostImport


# example search order for prefabs or materials:
#
#	Blender to Godot properties
#		Path: [resource_name]
#
#	import_path/resource_name.extensions
#	CONST_PATH/resource_name.extensions
#	CONST_PATH/resource_name/resource_name.extensions
#	
# when using a dash for variants:
#	
#	import_path/property_path-variant.extensions
#	import_path/resource_name/variant.extensions
#	import_path/resource_name/resource_name-variant.extensions
#	CONST_PATH/resource_name-variant.extensions
#	CONST_PATH/resource_name/variant.extensions
#	CONST_PATH/resource_name/resource_name-variant.extensions
#	
# if 'full path' is checked the prefab name will be loaded as a path,
# and no other searches done
#
# if 'collection asset' is checked the prefab's _parent_ node is replaced
# this is because blender assets create an extra Node3D

# example search for decal textures:
#
#	Blender to Godot properties
#		Path: [resource_name]
#
#	import_path/resource_name.extensions (as albedo)
#	import_path/resource_name_albedo.extensions
#	import_path/resource_name/resource_name_albedo.extensions
#	CONST_PATH/resource_name.extensions (as albedo)
#	CONST_PATH/resource_name_albedo.extensions
#	CONST_PATH/resource_name/resource_name_albedo.extensions
#
#	repeat with _normal, _orm, _emission

# change these to match your project
const MATERIAL_PATH := "res://materials/"
const PREFAB_PATH := "res://prefabs/"
const TEXTURE_PATH := "res://textures/"
const MATERIAL_EXTENSIONS:Array[String] = ['.tres', '.material']
const PREFAB_EXTENSIONS:Array[String] = ['.tscn', '.glb']
const TEXTURE_EXTENSIONS:Array[String] = ['.png','.jpg','.jpeg','.webp','.tga','.bmp','.exr','.hdr','.svg','.dds','.ktx']

var file_path:String

func _post_import(scene:Node) -> Node:
	if scene == null: return
	
	file_path = get_source_file().get_base_dir() + '/'
	
	var missing_prefabs:Array[String] = []
	var missing_materials:Array[String] = []
	var static_bodies:Array[StaticBody3D] = []
	var to_remove := []
	
	var offset := Vector3()
	for child:Node in scene.get_children():
		if child is Node3D:
			if child.has_meta(&'extras'):
				if child.get_meta(&'extras').has_all(['godot_type','prefab_offset','godot_prefab_asset']):
					if child.get_meta(&'extras')['godot_prefab_asset'] and child.get_meta(&'extras')['godot_type'] == 'prefab':
						var arr:Array[float]
						for i in range(child.get_meta(&'extras')['prefab_offset'].size()):
							arr.append(child.get_meta(&'extras')['prefab_offset'][i])
						arr.resize(3)
						offset = Vector3(arr[0], arr[2], -arr[1])
						if child.get_child_count() == 0:
							to_remove.append(child)
	
	for child:Node in get_all_children(scene):
		
		if child is Node3D: child.position -= offset
		
		if is_object_reflectionprobe(child):
			var probe := ReflectionProbe.new()
			child.get_parent().add_child(probe)
			probe.set_owner(scene)
			copy_transform(child, probe)
			to_remove.append(child)
			continue
		
		elif is_object_lightmapprobe(child):
			var probe := LightmapProbe.new()
			child.get_parent().add_child(probe)
			probe.set_owner(scene)
			copy_transform(child, probe)
			to_remove.append(child)
			continue
		
		elif is_object_decal(child):
			load_decal_from_object(scene, child)
			to_remove.append(child)
			continue
		
		elif is_object_prefab(child, scene):
			missing_prefabs = load_prefab_from_object(scene, child, missing_prefabs)
			if is_object_asset(child): to_remove.append(child.get_parent())
			else: to_remove.append(child)
			continue
		
		elif child is MeshInstance3D:
			var valid := true
			var parent:Node = child.get_parent()
			while true:
				if parent == null: break
				if to_remove.has(parent): valid = false; break
				parent = parent.get_parent()
			if !valid: continue
			
			if is_object_collision_shape(child):
				add_collision_shape_from_mesh(child, static_bodies, scene)
			if is_object_visible_mesh(child):
				apply_metadata_config(child)
				load_replacement_materials(child, missing_materials)
			else:
				to_remove.append(child)
			continue
	
	if offset != Vector3() and scene is Node3D:
		(scene as Node3D).position = Vector3()
	
	for node:Node in to_remove:
		node.free()
	
	missing_prefabs.sort()
	missing_materials.sort()
	
	for prop in missing_prefabs:
		push_warning("Importing '" + scene.name + "' prop not found: '" + prop + "'")
	for mat in missing_materials:
		push_warning("Importing '" + scene.name + "' material not found: '" + mat + "'")
	
	return scene

func get_all_children(parent:Node, arr:=[]) -> Array:
	arr.push_back(parent)
	for child in parent.get_children():
		get_all_children(child, arr)
	return arr

func is_object_reflectionprobe(object:Node) -> bool:
	if object is Node3D and object.name.begins_with("rprobe"): return true
	if !object.has_meta(&'extras'): return false
	if typeof(object.get_meta(&'extras')) != TYPE_DICTIONARY: return false
	if !object.get_meta(&'extras').has('godot_type'): return false
	if object.get_meta(&'extras')['godot_type'] != "rprobe": return false
	return true

func is_object_lightmapprobe(object:Node) -> bool:
	if object is Node3D and object.name.begins_with("lmprobe"): return true
	if !object.has_meta(&'extras'): return false
	if typeof(object.get_meta(&'extras')) != TYPE_DICTIONARY: return false
	if !object.get_meta(&'extras').has('godot_type'): return false
	if object.get_meta(&'extras')['godot_type'] != "lmprobe": return false
	return true

func is_object_decal(object:Node) -> bool:
	if !object.has_meta(&'extras'): return false
	if typeof(object.get_meta(&'extras')) != TYPE_DICTIONARY: return false
	if !object.get_meta(&'extras').has('godot_type'): return false
	if object.get_meta(&'extras')['godot_type'] != "decal": return false
	return true

func is_object_prefab(object:Node, scene:Node) -> bool:
	if object.get_parent() == scene: return false
	if !object.has_meta(&'extras'): return false
	if typeof(object.get_meta(&'extras')) != TYPE_DICTIONARY: return false
	if !object.get_meta(&'extras').has('godot_type'): return false
	if !object.get_meta(&'extras')['godot_type'] == "prefab": return false
	if !object.get_meta(&'extras').has('godot_path'): return false
	if typeof(object.get_meta(&'extras')['godot_path']) != TYPE_STRING: return false
	if object.get_meta(&'extras')['godot_path'] == '': return false
	return true

func is_object_asset(object:Node) -> bool:
	if !object.has_meta(&'extras'): return false
	if typeof(object.get_meta(&'extras')) != TYPE_DICTIONARY: return false
	if !object.get_meta(&'extras').has('godot_type'): return false
	if !object.get_meta(&'extras')['godot_type'] == "prefab": return false
	if !object.get_meta(&'extras').has('godot_prefab_asset'): return false
	return object.get_meta(&'extras')['godot_prefab_asset']

func is_object_collision_shape(object:MeshInstance3D) -> bool:
	if !object.has_meta(&'extras'): return false
	if typeof(object.get_meta(&'extras')) != TYPE_DICTIONARY: return false
	
	if object.get_meta(&'extras').has('godot_type'):
		var types := (object.get_meta(&'extras')['godot_type'] as String).split(';', false)
		if types.has('convex') or types.has('trimesh'):
			return true
	
	return false

func is_object_visible_mesh(object:MeshInstance3D) -> bool:
	if !object.has_meta(&'extras'): return true
	if typeof(object.get_meta(&'extras')) != TYPE_DICTIONARY: return true
	if !object.get_meta(&'extras').has('godot_type'): return true
	
	var types := (object.get_meta(&'extras')['godot_type'] as String).split(';', false)
	if object.get_meta(&'extras')['godot_type'] != '' and !types.has('mesh'):
		return false
	
	return true

func add_collision_shape_from_mesh(mesh:MeshInstance3D, bodies:Array[StaticBody3D], scene:Node) -> void:
	var convex := false
	var trimesh := false
	var layer := 1
	var mask := 1
	
	if mesh.has_meta(&'extras'):
		if typeof(mesh.get_meta(&'extras')) == TYPE_DICTIONARY:
			
			var types := (mesh.get_meta(&'extras')['godot_type'] as String).split(';', false)
			if types.has('convex'):
				convex = true
			if types.has('trimesh'):
				trimesh = true
			if mesh.get_meta(&'extras').has('godot_coll_layer'):
				layer = int(mesh.get_meta(&'extras')['godot_coll_layer'])
			if mesh.get_meta(&'extras').has('godot_coll_mask'):
				mask = int(mesh.get_meta(&'extras')['godot_coll_mask'])
	
	if convex:
		var shape := create_convex_shape(mesh)
		var collision_shape := CollisionShape3D.new()
		collision_shape.shape = shape
		collision_shape.name = 'CollisionShape3DConvex' + mesh.name
		add_collision_shape_to_scene(scene, bodies, collision_shape, get_local_root_transform(mesh), layer, mask)
	
	if trimesh:
		var shape := create_concave_shape(mesh)
		var collision_shape := CollisionShape3D.new()
		collision_shape.shape = shape
		collision_shape.name = 'CollisionShape3DTriMesh' + mesh.name
		add_collision_shape_to_scene(scene, bodies, collision_shape, get_local_root_transform(mesh), layer, mask)

func add_collision_shape_to_scene(scene:Node3D, bodies:Array[StaticBody3D], coll_shape:CollisionShape3D, trans:Transform3D, layer:int, mask:int) -> void:
	var collision_body:StaticBody3D = null
	
	for body in bodies:
		if body.collision_layer == layer and body.collision_mask == mask:
			collision_body = body
			break
	
	if collision_body == null:
		collision_body = StaticBody3D.new()
		collision_body.name = 'StaticBody'
		collision_body.collision_layer = layer
		collision_body.collision_mask = mask
		scene.add_child(collision_body)
		collision_body.set_owner(scene)
		bodies.append(collision_body)
	
	collision_body.add_child(coll_shape)
	coll_shape.set_owner(scene)
	set_local_root_transform(coll_shape, trans)

func create_convex_shape(mesh:MeshInstance3D) -> ConvexPolygonShape3D:
	var convex_shape := ConvexPolygonShape3D.new()
	var verts := mesh.mesh.get_faces()
	var points := PackedVector3Array()
	for v in verts:
		if !points.has(v):
			points.append(v)
	convex_shape.points = points
	return convex_shape

func create_concave_shape(mesh:MeshInstance3D) -> ConcavePolygonShape3D:
	var concave_shape := ConcavePolygonShape3D.new()
	var verts := mesh.mesh.get_faces()
	concave_shape.set_faces(verts)
	return concave_shape

func load_decal_from_object(scene:Node3D, object:Node3D) -> void:
	var decal := Decal.new()
	object.get_parent().add_child(decal)
	decal.set_owner(scene)
	copy_transform(object, decal)
	
	decal.scale = Vector3(1,1,1)
	decal.size = Vector3(object.scale.x, object.scale.y * 0.1, object.scale.z)
	
	if !object.has_meta(&'extras'): return
	if typeof(object.get_meta(&'extras')) != TYPE_DICTIONARY: return
	if !object.get_meta(&'extras').has('godot_path'): return
	if typeof(object.get_meta(&'extras')['godot_path']) != TYPE_STRING: return
	
	if object.get_meta(&'extras').has('godot_vis_layers'):
		if typeof(object.get_meta(&'extras')['godot_vis_layers']) == TYPE_FLOAT:
			decal.layers = int(object.get_meta(&'extras')['godot_vis_layers'])
	if object.get_meta(&'extras').has('godot_coll_mask'):
		if typeof(object.get_meta(&'extras')['godot_coll_mask']) == TYPE_FLOAT:
			decal.cull_mask = int(object.get_meta(&'extras')['godot_coll_mask'])
	
	var texture_name:String = object.get_meta(&'extras')['godot_path'].to_lower()
	var full_path := false
	if object.get_meta(&'extras').has('godot_full_path'):
		if typeof(object.get_meta(&'extras')['godot_full_path']) == TYPE_BOOL:
			full_path = object.get_meta(&'extras')['godot_full_path']
	
	if full_path:
		if ResourceLoader.exists(texture_name):
			var texture_resource := load(texture_name)
			if texture_resource is Texture2D:
				decal.texture_albedo = texture_resource
				return
	
	const TSLOT:Array[String] = ['','_albedo','_normal','_orm','_emission']
	for tex in TSLOT:
		var paths:Array[String] = []
		for ext in TEXTURE_EXTENSIONS:
			paths.append(file_path + texture_name + tex + ext)
			paths.append(file_path + texture_name + '/' + texture_name + tex + ext)
			paths.append(TEXTURE_PATH + texture_name + tex + ext)
			paths.append(TEXTURE_PATH + texture_name + '/' + texture_name + tex + ext)
		for p in paths:
			if ResourceLoader.exists(p):
				match tex:
					TSLOT[0], TSLOT[1]: decal.texture_albedo = load(p)
					TSLOT[2]: decal.texture_normal = load(p)
					TSLOT[3]: decal.texture_orm = load(p)
					TSLOT[4]: decal.texture_emission = load(p)
				break

func load_prefab_from_object(scene:Node3D, object:Node3D, missing_prefabs:Array) -> Array:
	if !object.has_meta(&'extras'): return missing_prefabs
	if typeof(object.get_meta(&'extras')) != TYPE_DICTIONARY: return missing_prefabs
	if !object.get_meta(&'extras').has('godot_path'): return missing_prefabs
	if typeof(object.get_meta(&'extras')['godot_path']) != TYPE_STRING: return missing_prefabs
	
	var prefab_name:String = object.get_meta(&'extras')['godot_path'].to_lower()
	var variant := ''
	var prefab_split:PackedStringArray
	var prefab_found := false
	var prefab_resource:Resource
	var full_path := false
	if object.get_meta(&'extras').has('godot_full_path'):
		if typeof(object.get_meta(&'extras')['godot_full_path']) == TYPE_BOOL:
			full_path = object.get_meta(&'extras')['godot_full_path']
	var asset := false
	if object.get_meta(&'extras').has('godot_prefab_asset'):
		if typeof(object.get_meta(&'extras')['godot_prefab_asset']) == TYPE_BOOL:
			asset = object.get_meta(&'extras')['godot_prefab_asset']
	
	if full_path:
		if ResourceLoader.exists(prefab_name):
			prefab_resource = load(prefab_name)
			prefab_found = true
	else:
		prefab_split = prefab_name.split("-", false)
		if prefab_split.size() > 1:
			prefab_name = prefab_split[0]
			variant = prefab_split[1]
		
		var paths:Array[String] = []
		
		var base_name := prefab_name.get_slice('/', prefab_name.get_slice_count('/') - 1)
		
		for ext in PREFAB_EXTENSIONS:
			if variant != '':
				paths.append(file_path + prefab_name + '-' + variant + ext)
				paths.append(file_path + prefab_name + '/' + variant + ext)
				paths.append(file_path + prefab_name + '/' + base_name + '-' + variant + ext)
				paths.append(PREFAB_PATH + prefab_name + '-' + variant + ext)
				paths.append(PREFAB_PATH + prefab_name + '/' + variant + ext)
				paths.append(PREFAB_PATH + prefab_name + '/' + base_name + '-' + variant + ext)
			else:
				paths.append(file_path + prefab_name + ext)
				paths.append(file_path + prefab_name + '/' + base_name + ext)
				paths.append(PREFAB_PATH + prefab_name + ext)
				paths.append(PREFAB_PATH + prefab_name + '/' + base_name + ext)
		
		for path in paths:
			if path == file_path: continue
			if ResourceLoader.exists(path):
				prefab_resource = load(path)
				prefab_found = true
				break
	
	if prefab_found and prefab_resource != null:
		var prefab:Node3D = prefab_resource.instantiate()
		if asset:
			if object.get_parent().get_parent() != null:
				object.get_parent().get_parent().add_child(prefab)
				prefab.set_owner(scene)
				copy_transform(object, prefab)
				#object.get_parent().call_deferred("free")
		else:
			if object.get_parent() != null:
				object.get_parent().add_child(prefab)
				prefab.set_owner(scene)
				copy_transform(object, prefab)
				#object.call_deferred("free")
	
	if !prefab_found:
		if prefab_name != "":
			if variant != "":
				if !missing_prefabs.has(prefab_name + "-" + variant):
					missing_prefabs.append(prefab_name + "-" + variant)
			else:
				if !missing_prefabs.has(prefab_name):
					missing_prefabs.append(prefab_name)
	
	return missing_prefabs

func load_replacement_materials(mesh:MeshInstance3D, missing_materials:Array) -> Array:
	var material_name:String
	var variant:String
	var mat_split:PackedStringArray
	var mat_found := false
	var material:Material
	
	for i in range(mesh.mesh.get_surface_count()):
		
		material_name = (mesh.mesh.get("surface_" + str(i) + "/name")).to_lower()
		variant = ""
		mat_split = material_name.split("-", false)
		if mat_split.size() > 1:
			material_name = mat_split[0]
			variant = mat_split[1]
		
		var paths:Array[String] = []
		
		for ext in MATERIAL_EXTENSIONS:
			if variant != '':
				paths.append(file_path + material_name + '-' + variant + ext)
				paths.append(file_path + material_name + '/' + variant + ext)
				paths.append(file_path + material_name + '/' + material_name + '-' + variant + ext)
				paths.append(MATERIAL_PATH + material_name + '-' + variant + ext)
				paths.append(MATERIAL_PATH + material_name + '/' + variant + ext)
				paths.append(MATERIAL_PATH + material_name + '/' + material_name + '-' + variant + ext)
			else:
				paths.append(file_path + material_name + ext)
				paths.append(file_path + material_name + '/' + material_name + ext)
				paths.append(MATERIAL_PATH + material_name + ext)
				paths.append(MATERIAL_PATH + material_name + '/' + material_name + ext)
		
		for path in paths:
			if ResourceLoader.exists(path):
				material = load(path)
				mat_found = true
				break
		
		if mat_found and material != null:
			(mesh as MeshInstance3D).mesh.surface_set_material(i, material)
		
		if !mat_found:
			if material_name != "":
				if variant != "":
					if !missing_materials.has(material_name + "-" + variant):
						missing_materials.append(material_name + "-" + variant)
				else:
					if !missing_materials.has(material_name):
						missing_materials.append(material_name)
	
	return missing_materials

func apply_metadata_config(mesh:MeshInstance3D) -> void:
	if !mesh.has_meta(&'extras'): return
	if typeof(mesh.get_meta(&'extras')) != TYPE_DICTIONARY: return
	
	if mesh.get_meta(&'extras').has('godot_vis_layers'):
		if typeof(mesh.get_meta(&'extras')['godot_vis_layers']) == TYPE_FLOAT:
			mesh.layers = int(mesh.get_meta(&'extras')['godot_vis_layers'])
	
	if mesh.get_meta(&'extras').has('godot_gi_mode'):
		if typeof(mesh.get_meta(&'extras')['godot_gi_mode']) == TYPE_STRING:
			match mesh.get_meta(&'extras')['godot_gi_mode']:
				'static': mesh.gi_mode = GeometryInstance3D.GI_MODE_STATIC
				'dynamic': mesh.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
				'disabled': mesh.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	
	if mesh.get_meta(&'extras').has('godot_shadow_mode'):
		if typeof(mesh.get_meta(&'extras')['godot_shadow_mode']) == TYPE_STRING:
			match mesh.get_meta(&'extras')['godot_shadow_mode']:
				'enabled': mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
				'disabled': mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				'double': mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_DOUBLE_SIDED
				'sh_only': mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY

func get_local_root_transform(node:Node3D) -> Transform3D:
	var xform := Transform3D()
	var parent := node.get_parent_node_3d()
	
	if parent == null:
		xform = node.transform
	else:
		xform = get_local_root_transform(parent) * node.transform
	
	return xform.orthonormalized()

func set_local_root_transform(node:Node3D, transform:Transform3D) -> void:
	var parent := node.get_parent_node_3d()
	var xform:Transform3D = transform if parent == null else get_local_root_transform(parent).affine_inverse() * transform
	node.transform = xform

func copy_transform(node_from:Node3D, node_to:Node3D) -> void:
	set_local_root_transform(node_to, get_local_root_transform(node_from))
