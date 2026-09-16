bl_info = {
    "name": "BlenderToGodotProperties",
    "author": "Jadeite",
    "version": (1, 0, 2),
    "blender": (4, 0, 2),
    "location" : "3D Viewport > Sidebar > B2GP",
    "description": "Metadata",
    "category": "Object",
}

import bpy
import bmesh
import math
import sys
import random

### funcs ###

def set_type(self, context):
    objects = bpy.context.selected_objects
    for obj in objects:
        if obj is not None:
            if obj.type == 'MESH':
                obj['godot_type'] = ''
                
                solid = False
                for type in obj.b2g_properties.mesh_type:
                    obj['godot_type'] += type + ';'
                    if type == 'mesh':
                        solid = True
                
                obj['godot_type'] = obj['godot_type'].rstrip(';')
                
                if solid or obj['godot_type'] == '':
                    obj.display_type = 'TEXTURED'
                else:
                    obj.display_type = 'WIRE'
            if obj.type == 'EMPTY':
                obj['godot_type'] = obj.b2g_properties.empty_type

def set_shadow(self, context):
    objects = bpy.context.selected_objects
    for obj in objects:
        if obj is not None and obj.type == 'MESH':
            obj['godot_shadow_mode'] = obj.b2g_properties.shadow_mode

def set_gi(self, context):
    objects = bpy.context.selected_objects
    for obj in objects:
        if obj is not None and obj.type == 'MESH':
            obj['godot_gi_mode'] = obj.b2g_properties.gi_mode

def set_vis_layers(self, context):
    objects = bpy.context.selected_objects
    for obj in objects:
        if obj is not None and (obj.type == 'MESH' or obj.type == 'EMPTY'):
            layer_value = 0
            for layer in obj.b2g_properties.vis_layers:
                layer_value += 1<<(int(layer) - 1)
            obj['godot_vis_layers'] = layer_value

def set_coll_layers(self, context):
    objects = bpy.context.selected_objects
    for obj in objects:
        if obj is not None and obj.type == 'MESH':
            layer_value = 0
            for layer in obj.b2g_properties.coll_layers:
                layer_value += 1<<(int(layer) - 1)
            obj['godot_coll_layer'] = layer_value

def set_coll_mask(self, context):
    objects = bpy.context.selected_objects
    for obj in objects:
        if obj is not None and (obj.type == 'MESH' or obj.type == 'EMPTY'):
            layer_value = 0
            for layer in obj.b2g_properties.coll_mask:
                layer_value += 1<<(int(layer) - 1)
            obj['godot_coll_mask'] = layer_value

def set_path(self, context):
    objects = bpy.context.selected_objects
    for obj in objects:
        if obj is not None and obj.type == 'EMPTY':
            obj['godot_path'] = obj.b2g_properties.path
            obj['godot_full_path'] = obj.b2g_properties.full_path
            obj['godot_prefab_asset'] = obj.b2g_properties.asset

def set_rigidprop(self, context):
    objects = bpy.context.selected_objects
    for obj in objects:
        if obj is not None and obj.type == 'EMPTY':
            obj['godot_rigid_mass'] = obj.b2g_properties.rigid_mass
            obj['godot_rigid_gravity'] = obj.b2g_properties.rigid_gravity
            obj['godot_rigid_ldamp'] = obj.b2g_properties.rigid_ldamp
            obj['godot_rigid_adamp'] = obj.b2g_properties.rigid_adamp

def set_mat_skip(self, context):
    objects = bpy.context.selected_objects
    for obj in objects:
        if obj is not None and obj.type == 'MESH':
            obj['godot_default_mat'] = obj.b2g_properties.default_mat

### config ###

class B2GP_Config(bpy.types.PropertyGroup):
    mesh_type   :   bpy.props.EnumProperty(
        options = {'ENUM_FLAG'},
        items = [
            ('mesh', 	    'Mesh',             'Mesh'),
            ('convex', 	    'Convex collider',  'Replace with convex collider'),
            ('trimesh',     'Trimesh collider', 'Replace with trimesh collider'),
        ],
        default = {'mesh'},
        update = set_type)
    shadow_mode :   bpy.props.EnumProperty(
        items = [
            ('enabled', 	'Enabled',		    'Cast shadows',                 '', 0),
            ('disabled', 	'Disabled', 	    'Disable shadows',              '', 1),
            ('double',      'Double sided',     'Cast shadows from both sides', '', 2),
            ('sh_only', 	'Shadows only',     'Only cast shadows',            '', 3),
        ],
        default = 'enabled',
        update = set_shadow)
    gi_mode     :       bpy.props.EnumProperty(
        items = [
            ('static',      'Static',           'Static',                       '', 0),
            ('dynamic',     'Dynamic',          'Dynamic'                       '', 1),
            ('disabled',    'Disabled',         'Disabled'                      '', 2),
        ],
        default = 'static',
        update = set_gi)
    vis_layers  :       bpy.props.EnumProperty(
        name = 'Visual layers',
        options = {'ENUM_FLAG'},
        items = [
            ( '1',  '1',  '1'),
            ( '2',  '2',  '2'),
            ( '3',  '3',  '3'),
            ( '4',  '4',  '4'),
            ( '5',  '5',  '5'),
            ( '6',  '6',  '6'),
            ( '7',  '7',  '7'),
            ( '8',  '8',  '8'),
            ( '9',  '9',  '9'),
            ('10', '10', '10'),
            ('11', '11', '11'),
            ('12', '12', '12'),
            ('13', '13', '13'),
            ('14', '14', '14'),
            ('15', '15', '15'),
            ('16', '16', '16'),
            ('17', '17', '17'),
            ('18', '18', '18'),
            ('19', '19', '19'),
            ('20', '20', '20'),
        ],
        default = {'1'},
        update = set_vis_layers)
    default_mat :       bpy.props.BoolProperty(
        name = 'Default material import',
        description = 'Use default material importing method',
        default = False,
        update = set_mat_skip)
    coll_layers :       bpy.props.EnumProperty(
        name = 'Collision layers',
        options = {'ENUM_FLAG'},
        items = [
            ( '1',  '1',  '1'),
            ( '2',  '2',  '2'),
            ( '3',  '3',  '3'),
            ( '4',  '4',  '4'),
            ( '5',  '5',  '5'),
            ( '6',  '6',  '6'),
            ( '7',  '7',  '7'),
            ( '8',  '8',  '8'),
            ( '9',  '9',  '9'),
            ('10', '10', '10'),
            ('11', '11', '11'),
            ('12', '12', '12'),
            ('13', '13', '13'),
            ('14', '14', '14'),
            ('15', '15', '15'),
            ('16', '16', '16'),
            ('17', '17', '17'),
            ('18', '18', '18'),
            ('19', '19', '19'),
            ('20', '20', '20'),
        ],
        default = {'1'},
        update = set_coll_layers)
    coll_mask   :       bpy.props.EnumProperty(
        name = 'Collision mask',
        options = {'ENUM_FLAG'},
        items = [
            ( '1',  '1',  '1'),
            ( '2',  '2',  '2'),
            ( '3',  '3',  '3'),
            ( '4',  '4',  '4'),
            ( '5',  '5',  '5'),
            ( '6',  '6',  '6'),
            ( '7',  '7',  '7'),
            ( '8',  '8',  '8'),
            ( '9',  '9',  '9'),
            ('10', '10', '10'),
            ('11', '11', '11'),
            ('12', '12', '12'),
            ('13', '13', '13'),
            ('14', '14', '14'),
            ('15', '15', '15'),
            ('16', '16', '16'),
            ('17', '17', '17'),
            ('18', '18', '18'),
            ('19', '19', '19'),
            ('20', '20', '20'),
        ],
        default = {'1'},
        update = set_coll_mask)
    path      	:       bpy.props.StringProperty(
        name = 'Path',
        description = 'Path to load Godot resource',
        default = '',
        update = set_path)
    full_path   :       bpy.props.BoolProperty(
        name = 'Full path',
        description = 'Load prefab with full path instead of file name',
        default = False,
        update = set_path)
    empty_type   :      bpy.props.EnumProperty(
        name = 'Type',
        items = [
            ('node3d', 	    'Node3D',           'Import as Node3D'			'', 0),
            ('rprobe',      'ReflectionProbe',  'Import as ReflectionProbe'	'', 1),
            ('lmprobe',     'LightmapProbe',    'Import as LightmapProbe'	'', 2),
            ('decal',		'Decal',			'Import as Decal'			'', 3),
            ('prefab', 	    'Prefab',           'Replace with prefab'		'', 4),
            ('rigid', 	    'RigidBody3D',      'Replace with prefab'		'', 5),
            ('animatable', 	'AnimatableBody3D', 'Replace with prefab'		'', 6),
        ],
        default = 'node3d',
        update = set_type)
    asset       :       bpy.props.BoolProperty(
        name = 'Asset',
        description = 'Enable when this empty is part of a collection asset',
        default = False,
        update = set_path)
    rigid_mass      :    bpy.props.FloatProperty(	name = 'Mass',          step = 0.001,    default = 1.0,	update = set_rigidprop)
    rigid_gravity   :    bpy.props.FloatProperty(	name = 'Gravity',       step = 0.001,    default = 1.0,	update = set_rigidprop)
    rigid_ldamp     :    bpy.props.FloatProperty(	name = 'Linear damp',   step = 0.001,    default = 0.0,	update = set_rigidprop)
    rigid_adamp     :    bpy.props.FloatProperty(	name = 'Angular damp',  step = 0.001,    default = 0.0,	update = set_rigidprop)

### operator ###

class B2GP_set_collection_offset_from_object_origin(bpy.types.Operator):
    """Set instance offset to this object's position (use as origin)"""
    bl_options = {"REGISTER", "UNDO"}
    bl_idname = "b2gp.set_offset"
    bl_label = "Set instance offset of collection to this object's position"
    def execute(self, context):
        active = bpy.context.active_object
        bpy.data.collections[active.users_collection[0].name].instance_offset = active.location
        if active is not None and active.type == 'EMPTY':
            if active['godot_type'] == 'prefab':
                active['prefab_offset'] = active.location
        return {'FINISHED'}

### panel ###

class VIEW3D_PT_b2gp_panel(bpy.types.Panel):
    
    bl_space_type = "VIEW_3D"
    bl_region_type = "UI"

    bl_category = "B2GP"
    bl_label = "Blender to Godot properties"
    
    def draw(self, context):
        objects = bpy.context.selected_objects
        active = bpy.context.active_object
        layout = self.layout
        scene = context.scene
        
        if active is None: return
        
        if active.type == 'EMPTY':
            
            obj_count = 0
            for obj in objects:
                if obj is not None and (obj.type == 'EMPTY'):
                    obj_count += 1
                if obj_count > 1:
                    break
            should_draw = obj_count > 0
            if not should_draw: return
            
            split = layout.split()
            col = split.column(align=True)
            rows = layout.grid_flow(row_major=True, align=True, columns=1)
            
            rows.prop(active.b2g_properties, "empty_type", expand=False)
            
            # DECAL
            if active.b2g_properties.empty_type == "decal":
                rows.prop(active.b2g_properties, "path", expand=True)
                rows.prop(active.b2g_properties, "full_path", expand=True)
                
                # CULL MASK
                split = layout.split()
                col = split.column(align=True)
                col.label(icon = 'OVERLAY', text="Cull mask")
                rows = layout.grid_flow(row_major=True, align=True, columns=5)
                rows.prop(active.b2g_properties, "coll_mask", expand=True)
                
                # VISUAL LAYERS
                split = layout.split()
                col = split.column(align=True)
                col.label(icon = 'RENDERLAYERS', text="Visual layers")
                rows = layout.grid_flow(row_major=True, align=True, columns=5)
                rows.prop(active.b2g_properties, "vis_layers", expand=True)
            
            # PREFAB
            if active.b2g_properties.empty_type == "prefab":
                rows.prop(active.b2g_properties, "path", expand=True)
                rows.prop(active.b2g_properties, "full_path", expand=True)
                rows.prop(active.b2g_properties, "asset", expand=True)
                rows = layout.grid_flow(row_major=True, align=True, columns=1)
                rows.label(text="Make this empty a first child of")
                rows.label(text="the collection to import correctly")
                rows.operator("b2gp.set_offset", text="Set offset")
                rows.enabled = active.b2g_properties.asset
            
            if active.b2g_properties.empty_type == "rigid":
                
                split = layout.split()
                col = split.column(align=True)
                rows = layout.grid_flow(row_major=True, align=True, columns=1)
                rows.prop(active.b2g_properties, "rigid_mass", expand=True)
                rows.prop(active.b2g_properties, "rigid_gravity", expand=True)
                rows.prop(active.b2g_properties, "rigid_ldamp", expand=True)
                rows.prop(active.b2g_properties, "rigid_adamp", expand=True)
            
            if active.b2g_properties.empty_type == "rigid" or active.b2g_properties.empty_type == "animatable":
                
                rows.label(text="Collision settings override children")
                
                # COLLISION LAYERS
                split = layout.split()
                col = split.column(align=True)
                col.label(icon = 'SPHERE', text="Collision layers")
                rows = layout.grid_flow(row_major=True, align=True, columns=5)
                rows.prop(active.b2g_properties, "coll_layers", expand=True)
                
                # COLLISION MASK
                split = layout.split()
                col = split.column(align=True)
                col.label(icon = 'OVERLAY', text="Collision mask")
                rows = layout.grid_flow(row_major=True, align=True, columns=5)
                rows.prop(active.b2g_properties, "coll_mask", expand=True)
            
            return
        
        if active.type == 'MESH':
        
            obj_count = 0
            for obj in objects:
                if obj is not None and (obj.type == 'MESH'):
                    obj_count += 1
                if obj_count > 1:
                    break
            should_draw = obj_count > 0
            if not should_draw: return
            
            # TYPE
            split = layout.split()
            col = split.column(align=True)
            col.label(icon = 'OUTLINER_DATA_MESH', text="Type")
            rows = layout.grid_flow(row_major=True, align=True, columns=1)
            rows.prop(active.b2g_properties, "mesh_type", expand=True)
            
            vis = False
            coll = False
            for type in active.b2g_properties.mesh_type:
                if type == 'mesh':
                    vis = True
                else:
                    coll = True
            
            if vis:
            
                # SHADOWS
                split = layout.split()
                col = split.column(align=True)
                col.label(icon = 'LIGHT', text="Shadows")
                rows = layout.grid_flow(row_major=True, align=True, columns=1)
                rows.prop(active.b2g_properties, "shadow_mode", expand=True)
                
                # GI MODE
                split = layout.split()
                col = split.column(align=True)
                col.label(icon = 'SHADING_RENDERED', text="GI Mode")
                rows = layout.grid_flow(row_major=True, align=True, columns=1)
                rows.prop(active.b2g_properties, "gi_mode", expand=True)
                
                # VISUAL LAYERS
                split = layout.split()
                col = split.column(align=True)
                col.label(icon = 'RENDERLAYERS', text="Visual layers")
                rows = layout.grid_flow(row_major=True, align=True, columns=5)
                rows.prop(active.b2g_properties, "vis_layers", expand=True)
            
            if coll:
                
                # COLLISION LAYERS
                split = layout.split()
                col = split.column(align=True)
                col.label(icon = 'SPHERE', text="Collision layers")
                rows = layout.grid_flow(row_major=True, align=True, columns=5)
                rows.prop(active.b2g_properties, "coll_layers", expand=True)
                
                # COLLISION MASK
                split = layout.split()
                col = split.column(align=True)
                col.label(icon = 'OVERLAY', text="Collision mask")
                rows = layout.grid_flow(row_major=True, align=True, columns=5)
                rows.prop(active.b2g_properties, "coll_mask", expand=True)
            
            if not vis and not coll:
                pass

### register ###

classes = (
    B2GP_Config,
    B2GP_set_collection_offset_from_object_origin,
    VIEW3D_PT_b2gp_panel,
)

def register():
    for c in classes:
        bpy.utils.register_class(c)
    bpy.types.Object.b2g_properties = bpy.props.PointerProperty(type=B2GP_Config)

def unregister():
    for c in reversed(classes):
        bpy.utils.unregister_class(c)

if __name__ == "__main__":
    register()



    
