extends Control
class_name VertexBakerMainWindow
var MOVING_WINDOW = false
var default_texture = ("res://textures/default.png")
var missing_texture = ("res://textures/missing_texture.png")
var missing_texture_ = preload("res://textures/missing_texture.png")
var layer_prefab = preload("res://layer_prefab.tscn")
var light_prefab = preload("res://light_prefab.tscn")
var recent_list_item_prefab = preload("res://list_item_recent_prefab.tscn")
var mesh_list_item_prefab = preload("res://list_item_mesh_prefab.tscn")
var scene_list_item_prefab = preload("res://list_item_scene_prefab.tscn")
var surface_list_item_prefab = preload("res://list_item_surface_prefab.tscn")
var material_list_item_prefab = preload("res://list_item_material_prefab.tscn")
var material_override_list_item_prefab = preload("res://list_item_material_override_prefab.tscn")
var material_replacement_list_item_prefab = preload("res://list_item_material_replacement_prefab.tscn")
var light_mesh = preload("res://light_mesh_prefab.tscn")
var imported_mesh_prefab = preload("res://imported_mesh_prefab.tscn")
var scene_prefab = preload("res://scene_prefab.tscn")
var surface_prefab = preload("res://surface_prefab.tscn")
var AUTO_BAKE = false
@export var gizmo : Gizmo3D

enum BUILT_IN_MATERIALS {
	DEFAULT = 0,
	WATER = 1,
	WATER_FLOW = 2,
	WINDY = 3,
	GLASS = 4
	}

enum SHADERS {
	DEFAULT = 0,
	WATER = 1,
	WATER_FLOW = 2,
	WINDY = 3,
	GLASS = 4
	}

@export var DEFAULT_SHADER:VisualShader
@export var WATER_SHADER:VisualShader
@export var WATER_FLOW_SHADER:VisualShader
@export var WINDY_SHADER:VisualShader
@export var GLASS_SHADER:VisualShader

var BAKE_ROTATION_ON_EXPORT = true
var BAKE_SCALE_ON_EXPORT = true
var OG_MESH
var brush_hardness = 1.0
var calculated_size:float = 5.0
var PREVIOUS_COLOR:Color = Color.WHITE
var LIGHT_SPHERES_ON = true

var icon_off = preload("res://icon_icons.png")
var icon_on = preload("res://icon_light.png")
var icon_sphere = preload("res://icon_light_sphere.png")
var CURRENT_LIGHT: VertexLight= null
var CURRENT_LAYER:LightLayer = null
var max_recursion = 100

var CURRENT_WINDOW:WindowMover

var baking_timer:Timer

var CURRENT_REPLACEMENT:MaterialReplacement
var CURRENT_REPLACEMENT_LIST_ITEM:Node

func _ready():
	baking_timer = Timer.new()
	baking_timer.one_shot = true;
	baking_timer.connect("timeout", actually_bake)
	baking_timer.wait_time = 0.25;
	add_child(baking_timer)
	DATA.load_recents()
	update_recents_window()

func _input(event:InputEvent):
	if event is InputEventMouseMotion:
		if(CURRENT_WINDOW != null && MOVING_WINDOW == true):
			CURRENT_WINDOW.position = Vector2i(event.position-CURRENT_WINDOW.LAST_POSITION)
	if(event is InputEventMouseButton && event.is_released()):
		if(CURRENT_WINDOW != null && MOVING_WINDOW == true):
			MOVING_WINDOW = false
			CURRENT_WINDOW.mouse_passthrough = false
			CURRENT_WINDOW.unfocusable = true
			CURRENT_WINDOW = null



func _on_add_layer_pressed(
	layer_name:String="UNTITLED",
	blending_method:LightLayer.BLENDING_METHODS=LightLayer.BLENDING_METHODS.MULTIPLY,
	blending_direction:LightLayer.BLENDING_DIRECTIONS=LightLayer.BLENDING_DIRECTIONS.EVERYTHING,
	blending_fade:LightLayer.BLENDING_FADES=LightLayer.BLENDING_FADES.FLAT,
	imported_id:int=-1) -> void:
	$HBoxContainer.visible = false
	$MENU_BUTTON.visible = true;
	var layer:LightLayer = LightLayer.new()
	layer.LIGHTS = []
	layer.BLENDING_METHOD = blending_method
	if(imported_id == -1):
		layer.ID =generate_id()
	else:
		layer.ID = imported_id
	if(layer_name == "UNTITLED"):
		layer.NAME = "%s #%s"%[layer_name,layer.ID]
	else:
		layer.NAME = layer_name
	DATA.LAYERS.push_back(layer)
	var new_layer = layer_prefab.instantiate()
	layer.LIST_ITEM = new_layer;
	$LAYER_INSPECTOR/ScrollContainer/CONTAINER/LAYERS.add_child(new_layer)
	var button  = new_layer.get_node("NAME/ADD_LIGHT_TO_LAYER")
	var delete_button  = new_layer.get_node("MORE_MENU/DELETE")
	var blending_dropdown:OptionButton  = new_layer.get_node("NAME/BLENDING_METHOD")
	var blending_direction_dropdown:OptionButton  = new_layer.get_node("NAME/BLENDING_DIRECTION")
	var blending_fade_dropdown:OptionButton  = new_layer.get_node("NAME/BLENDING_FADE")
	var name_label  = new_layer.get_node("NAME")
	name_label.text = layer.NAME
	button.connect("pressed",on_add_light_to_layer.bind(new_layer,layer))
	delete_button.connect("pressed",on_delete_layer_pressed.bind(new_layer,layer))
	blending_dropdown.select(layer.BLENDING_METHOD)
	blending_dropdown.connect("pressed",on_blending_method_dropdown_pressed.bind(layer))
	blending_dropdown.connect("item_selected",on_blending_method_dropdown_selected)
	blending_direction_dropdown.select(layer.BLENDING_DIRECTION)
	blending_direction_dropdown.connect("pressed",on_blending_direction_dropdown_pressed.bind(layer))
	blending_direction_dropdown.connect("item_selected",on_blending_direction_dropdown_selected)
	blending_fade_dropdown.select(layer.BLENDING_FADE)
	blending_fade_dropdown.connect("pressed",on_blending_fade_dropdown_pressed.bind(layer))
	blending_fade_dropdown.connect("item_selected",on_blending_fade_dropdown_selected)

func on_blending_method_dropdown_selected(index:int):
	if(CURRENT_LAYER != null):
		CURRENT_LAYER.BLENDING_METHOD = index
	auto_bake()

func on_blending_method_dropdown_pressed(light_layer:LightLayer):
		CURRENT_LAYER = light_layer

func on_blending_direction_dropdown_selected(index:int):
	if(CURRENT_LAYER != null):
		CURRENT_LAYER.BLENDING_DIRECTION = index
	auto_bake()

func on_blending_direction_dropdown_pressed(light_layer:LightLayer):
		CURRENT_LAYER = light_layer

func on_blending_fade_dropdown_selected(index:int):
	if(CURRENT_LAYER != null):
		CURRENT_LAYER.BLENDING_FADE = index
	auto_bake()

func on_blending_fade_dropdown_pressed(light_layer:LightLayer):
		CURRENT_LAYER = light_layer

func on_delete_layer_pressed(layer:Control,light_layer:LightLayer):
	var index_to_remove = DATA.LAYERS.find(light_layer)
	#remove all of the lights
	for light in light_layer.LIGHTS:
		on_delete_light(light)
	#remove from UI
	light_layer.LIST_ITEM.queue_free()
	DATA.LAYERS.remove_at(index_to_remove)
	auto_bake()

func on_add_light_to_layer(
	layer:Control,light_layer:LightLayer,
	imported_position:Vector3=Vector3.ZERO,
	imported_color:Color= Color.WHITE,
	imported_radius:float=1.0,
	imported_mix:float=1.0):
	light_layer.LIST_ITEM.get_node("VBoxContainer/EXPAND").show()
	var light = VertexLight.new()
	light.COLOR = imported_color
	light.LIGHT_MESH = light_mesh.instantiate()
	light.LIGHT_MESH.position = imported_position
	var mesh:MeshInstance3D = light.LIGHT_MESH.get_node("MeshInstance3D")
	mesh.visible = LIGHT_SPHERES_ON;
	mesh.scale = Vector3.ONE *imported_radius;
	light.LIGHT_MESH.modulate = light.COLOR
	light.RADIUS = imported_radius
	light.LAYER = light_layer
	light.PARENT_LAYER_ID = light_layer.ID
	light.MIX = imported_mix
	light_layer.LIGHTS.push_back(light)
	$SubViewportContainer/SubViewport.add_child(light.LIGHT_MESH)
	var new_light = light_prefab.instantiate()
	light.LIST_ITEM = new_light;
	var name_label:Label = new_light.get_node("VBoxContainer/LIGHT_NAME")
	name_label.text ="%s"% light.PARENT_LAYER_ID
	var radius_control:SpinBox = new_light.get_node("VBoxContainer/RADIUS_CONTAINER/SpinBox")
	radius_control.value =imported_radius
	radius_control.connect("value_changed",on_radius_value_changed.bind(light,radius_control))
	var color_control:ColorPickerButton = new_light.get_node("VBoxContainer/COLOR_CONTAINER/ColorPickerButton")
	color_control.color = light.COLOR;
	color_control.connect("color_changed",on_color_picker_changed.bind(light,color_control))
	var mix_control:SpinBox = new_light.get_node("VBoxContainer/MIX_CONTAINER/SpinBox")
	mix_control.value = imported_mix;
	mix_control.connect("value_changed",on_mix_value_changed.bind(light,mix_control))
	var delete_button = new_light.get_node("VBoxContainer/BUTTON_ROW_1/DELETE")
	delete_button.connect("pressed",on_delete_light.bind(light))
	var duplicate_button = new_light.get_node("VBoxContainer/BUTTON_ROW_1/DUPLICATE")
	duplicate_button.connect("pressed",on_duplicate_light.bind(light))
	var move_button = new_light.get_node("VBoxContainer/BUTTON_ROW_1/MOVE")
	move_button.connect("pressed",on_move_light.bind(light))
	var scale_button = new_light.get_node("VBoxContainer/RADIUS_CONTAINER/SCALE")
	scale_button.connect("pressed",on_scale_light_pressed.bind(light))
	layer.get_node("VBoxContainer/LIGHTS").add_child(new_light)
	auto_bake()

func on_scale_light_pressed(light:VertexLight):
	gizmo.clear_selection()
	CURRENT_LIGHT = light
	gizmo.mode = Gizmo3D.ToolMode.SCALE
	gizmo.select(light.LIGHT_MESH)
	auto_bake()

func on_radius_value_changed(value:float,light:VertexLight,radius:SpinBox):
	light.RADIUS = value
	var mesh:MeshInstance3D = light.LIGHT_MESH.get_node("MeshInstance3D")
	mesh.scale = Vector3.ONE *value;
	auto_bake()

func on_color_picker_changed(color:Color,light:VertexLight,color_button:ColorPickerButton):
	light.COLOR = color_button.color;
	light.LIGHT_MESH.modulate = light.COLOR
	PREVIOUS_COLOR = light.COLOR
	auto_bake()

func on_mix_value_changed(value:float,light:VertexLight,mix:SpinBox):
	light.MIX = value
	auto_bake()

func on_duplicate_light(light:VertexLight):
	on_add_light_to_layer(light.LAYER.LIST_ITEM,
		light.LAYER,
		light.LIGHT_MESH.global_position,
		light.COLOR,
		light.RADIUS,
		light.MIX)

func on_move_light(light:VertexLight):
	p2log("PRESS SPACEBAR TO DESELECT")
	gizmo.clear_selection()
	gizmo.mode = Gizmo3D.ToolMode.MOVE
	gizmo.select(light.LIGHT_MESH)
	disable_collision_shapes()

func _on_import_button_pressed() -> void:
	$HBoxContainer.visible = false
	$MENU_BUTTON.visible = true;
	$IMPORT.show()

func _on_save_button_pressed() -> void:
	$HBoxContainer.visible = false
	$MENU_BUTTON.visible = true;
	$SAVE.show()

func _on_export_button_pressed() -> void:
	$HBoxContainer.visible = false
	$MENU_BUTTON.visible = true;
	$EXPORT.show()

func _on_open_button_pressed() -> void:
	$HBoxContainer.visible = false
	$MENU_BUTTON.visible = true;
	$OPEN.show()

func on_toggle_layer(layer:Control):
	var children =  layer.get_node("VBoxContainer/LIGHTS").get_children();
	if(children.size() == 0):return
	var first = children[0]
	var toggle  = layer.get_node("VBoxContainer/TOGGLE")
	var add  = layer.get_node("VBoxContainer/ADD_LIGHT_TO_LAYER")
	var showing = !first.visible
	if(showing):
		toggle.text = "hide"
		add.show()
	else:
		toggle.text = "show"
		add.hide()
	for child in layer.get_node("VBoxContainer/LIGHTS").get_children():
		child.visible = showing

func show_palette(for_light:VBoxContainer):
	pass

func blend_lights_into_vertex_colors(
	mesh:MeshInstance3D,
	imported_scene:ImportedScene,
	layer,
	light :VertexLight,
	index,
	tools):
		var data:MeshDataTool = tools[index]
		var mesh_array:ArrayMesh = mesh.mesh
		data.create_from_surface(mesh_array, index)
		for i in range(data.get_vertex_count()):
			var vertex:Vector3 = mesh.to_global(data.get_vertex(i))
			var normal:Vector3 = data.get_vertex_normal(i)

			var distance_vector:Vector3 = (vertex - light.LIGHT_MESH.global_position)
			var normalized_distance_vector = distance_vector.normalized()
			var vertex_distance:float = vertex.distance_to(light.LIGHT_MESH.global_position)
			if vertex_distance < light.RADIUS:
				var is_masked = is_masked(layer,mesh,index,imported_scene)
				var old_color:Color = data.get_vertex_color(i)
				var tangent = data.get_vertex_tangent(i).normal
				if(is_masked==false):
					var linear_distance = 1 - (vertex_distance / (light.RADIUS))
					var new_color:Color = light.COLOR
					var mixed_color:Color = light.COLOR
					var mix = 1.0
					match(layer.BLENDING_METHOD):
						LightLayer.BLENDING_METHODS.MIN:
							var max_r = minf(old_color.r,new_color.r)
							var max_g = minf(old_color.g,new_color.g)
							var max_b = minf(old_color.b,new_color.b)
							mix = light.MIX
						LightLayer.BLENDING_METHODS.MAX:
							var max_r = maxf(old_color.r,new_color.r)
							var max_g = maxf(old_color.g,new_color.g)
							var max_b = maxf(old_color.b,new_color.b)
							mix = light.MIX
						LightLayer.BLENDING_METHODS:
							var max_r = maxf(old_color.r,new_color.r)
							var max_g = maxf(old_color.g,new_color.g)
							var max_b = maxf(old_color.b,new_color.b)
							mix = light.MIX
						LightLayer.BLENDING_METHODS.DIVIDE:
							mixed_color = Color(
								old_color.r/(new_color.r+0.001),
								old_color.g/(new_color.g+0.001),
								old_color.b/(new_color.b+0.001))
							mix = light.MIX
						LightLayer.BLENDING_METHODS.MULTIPLY,LightLayer.BLENDING_METHODS.DEFAULT:
							mixed_color = Color(old_color.r*new_color.r,old_color.g*new_color.g,old_color.b*new_color.b)
							mix = light.MIX
						LightLayer.BLENDING_METHODS.ADD:
							var clamped_r = clamp(old_color.r+new_color.r,0,1)
							var clamped_g = clamp(old_color.g+new_color.g,0,1)
							var clamped_b = clamp(old_color.b+new_color.b,0,1)
							mixed_color = Color(clamped_r,clamped_g,clamped_b)
							mix = light.MIX
						LightLayer.BLENDING_METHODS.SUBTRACT:
							var clamped_r = clamp(old_color.r-new_color.r,0,1)
							var clamped_g = clamp(old_color.g-new_color.g,0,1)
							var clamped_b = clamp(old_color.b-new_color.b,0,1)
							mixed_color = Color(clamped_r,clamped_g,clamped_b)
							mix = light.MIX
						LightLayer.BLENDING_METHODS.INVERTED_SUBTRACT:
							var hue =  new_color.h - 0.5
							if(hue <0):
								hue+=1.0
							var inverted_hue_color = Color.from_hsv(hue,new_color.s,new_color.v,new_color.a)
							var clamped_r = clamp(old_color.r-inverted_hue_color.r,0,1)
							var clamped_g = clamp(old_color.g-inverted_hue_color.g,0,1)
							var clamped_b = clamp(old_color.b-inverted_hue_color.b,0,1)
							mixed_color = Color(clamped_r,clamped_g,clamped_b)

					match(layer.BLENDING_FADE):
						LightLayer.BLENDING_FADES.FLAT:
							mix = light.MIX

						LightLayer.BLENDING_FADES.LINEAR_FADE:
							mix =  light.MIX ^ linear_distance

					match(layer.BLENDING_DIRECTION):
						LightLayer.BLENDING_DIRECTIONS.EVERYTHING:
							data.set_vertex_color(i,lerp(old_color,mixed_color,mix))
						LightLayer.BLENDING_DIRECTIONS.POINT_LIGHTS:
							var facing_light_mix = 1.0- normal.dot(distance_vector)
							data.set_vertex_color(i,lerp(old_color,mixed_color,mix*facing_light_mix))
						LightLayer.BLENDING_DIRECTIONS.FACING_UP:
							data.set_vertex_color(i,lerp(old_color,mixed_color,mix*normal.y))
						LightLayer.BLENDING_DIRECTIONS.FACING_DOWN:
							data.set_vertex_color(i,lerp(old_color,mixed_color,mix*(1.0-normal.y)))
						LightLayer.BLENDING_DIRECTIONS.INVERTED_POINT_LIGHT:
							var facing_light_mix = normal.dot(distance_vector)
							data.set_vertex_color(i,lerp(old_color,mixed_color,mix*facing_light_mix))
						LightLayer.BLENDING_DIRECTIONS.DIRECTIONAL:
							var light_direction = (mesh.global_position - light.LIGHT_MESH.global_position).normalized()
							var facing_light_mix =  1.0 - normal.dot(light_direction)
							data.set_vertex_color(i,lerp(old_color,mixed_color,mix*facing_light_mix))
							pass
						LightLayer.BLENDING_DIRECTIONS.INVERSE_DIRECTIONAL:
							var light_direction = (mesh.global_position - light.LIGHT_MESH.global_position).normalized()
							var facing_light_mix = normal.dot(light_direction)
							data.set_vertex_color(i,lerp(old_color,mixed_color,mix*facing_light_mix))

				else:
					data.set_vertex_color(i,old_color)

func scale_mesh(mesh:MeshInstance3D, target_scale):
		var mesh_array:ArrayMesh = mesh.mesh;
		var surface_count =mesh_array.get_surface_count()
		var tools = []
		for index_ in surface_count:
			tools.push_back(MeshDataTool.new())
		for index in surface_count:
			var data:MeshDataTool = tools[index]
			data.create_from_surface(mesh_array, index)
			for i in range(data.get_vertex_count()):
				var vertex = data.get_vertex(i) * target_scale
				var normal = data.get_vertex_normal(i) * target_scale
				data.set_vertex(i, vertex)
				data.set_vertex_normal(i, normal)
		mesh.scale = Vector3.ONE
		var mesh_:Mesh = mesh_array;
		mesh_.clear_surfaces()
		for index in surface_count:
			var data:MeshDataTool = tools[index]
			data.commit_to_surface(mesh_array)

func is_masked(layer,mesh,surf,imported_scene):
	return DATA.LAYER_MASKS.any(func(layer_mask:LightLayerMask):
						return (layer_mask.LAYER_ID == layer.ID &&
						layer_mask.MESH_NAME == mesh.name &&
						layer_mask.SURFACE_ID == surf &&
						layer_mask.SCENE_ID == imported_scene.ID))

func update_mesh(mesh:MeshInstance3D, imported_scene:ImportedScene) -> void:
		var mesh_array:ArrayMesh =  mesh.mesh
		var surface_count =mesh_array.get_surface_count()
		var tools = []
		var surface_names = []
		for index in surface_count:
			var surf_name = mesh_array.surface_get_name(index)
			surface_names.push_back(surf_name)
			tools.push_back(MeshDataTool.new())
		for layer in DATA.LAYERS:
			for light in layer.LIGHTS:
				for surf in surface_count:
						blend_lights_into_vertex_colors(
							mesh,
							imported_scene,
							layer,
							light,
							surf,
							tools)
				mesh_array.clear_surfaces()
				for index in surface_count:
						var surf_name = surface_names[index]
						var data = tools[index]
						data.commit_to_surface(mesh_array)
						mesh_array.surface_set_name(index,surf_name)
						var mat = get_mat_override_for_surface(index,mesh,imported_scene)
						if(mat!=null):
							mesh_array.surface_set_material(index,mat)
						else:
							var og_mat = mesh_array.surface_get_material(index)
							if(og_mat is StandardMaterial3D):
								var shader_material:=ShaderMaterial.new()
								shader_material.resource_name = og_mat.resource_name
								shader_material.shader = DEFAULT_SHADER
								shader_material.set_shader_parameter("MAIN",og_mat.albedo_texture)
								mesh_array.surface_set_material(index,shader_material)

func add_title_to_data_window(title):
	var layer_title = Label.new()
	layer_title.text = "====== %s =========" % title
	layer_title.custom_minimum_size = (Vector2(490,50))
	$DATA_INSPECTOR/ScrollContainer/CONTAINER/DATA.add_child(layer_title)

func re_save_file(path):
	$SAVE.current_path = path
	$SAVE.show()

func re_export_file(path):
	$EXPORT.current_path = path
	$EXPORT.show()

func update_recents_window():
	for child in $RECENT_SAVES/ScrollContainer/CONTAINER/RECENTS.get_children():
		child.queue_free()
	for child in $RECENT_FILES/ScrollContainer/CONTAINER/RECENTS.get_children():
		child.queue_free()
	for child in $RECENT_MESHES/ScrollContainer/CONTAINER/RECENTS.get_children():
		child.queue_free()
	for child in $RECENT_TEXTURES/ScrollContainer/CONTAINER/RECENTS.get_children():
		child.queue_free()
	for recent_file in DATA.RECENTS:
		var recent_prefab = recent_list_item_prefab.instantiate()
		recent_prefab.get_node("Control/PATH").text = recent_file.PATH
		match(recent_file.TYPE):
			VBRecentFile.VB_FILE_TYPES.TEXTURE:
				recent_prefab.get_node("Control/EXPORT_BUTTON").hide()
				recent_prefab.get_node("Control/IMPORT_BUTTON").hide()
				recent_prefab.get_node("Control/OPEN_BUTTON").hide()
				recent_prefab.get_node("Control/SAVE_BUTTON").hide()
				recent_prefab.get_node("Control/ICON").show()
				$RECENT_TEXTURES/ScrollContainer/CONTAINER/RECENTS.add_child(recent_prefab)
			VBRecentFile.VB_FILE_TYPES.PROJECT_FILE_SAVED:
				recent_prefab.get_node("Control/ICON").hide()
				recent_prefab.get_node("Control/EXPORT_BUTTON").hide()
				recent_prefab.get_node("Control/IMPORT_BUTTON").hide()
				recent_prefab.get_node("Control/OPEN_BUTTON").hide()
				recent_prefab.get_node("Control/SAVE_BUTTON").show()
				recent_prefab.get_node("Control/OPEN_BUTTON").connect("pressed",_on_open_file_selected.bind(recent_file.PATH))
				recent_prefab.get_node("Control/SAVE_BUTTON").connect("pressed",re_save_file.bind(recent_file.PATH))
				$RECENT_SAVES/ScrollContainer/CONTAINER/RECENTS.add_child(recent_prefab)

			VBRecentFile.VB_FILE_TYPES.IMPORTED:
				recent_prefab.get_node("Control/ICON").hide()
				recent_prefab.get_node("Control/OPEN_BUTTON").hide()
				recent_prefab.get_node("Control/SAVE_BUTTON").hide()
				recent_prefab.get_node("Control/EXPORT_BUTTON").hide()
				recent_prefab.get_node("Control/IMPORT_BUTTON").show()
				#recent_prefab.get_node("Control/EXPORT_BUTTON").connect("pressed",re_export_file.bind(recent_file.PATH))
				recent_prefab.get_node("Control/IMPORT_BUTTON").connect("pressed",_on_import_file_selected.bind(recent_file.PATH))
				$RECENT_MESHES/ScrollContainer/CONTAINER/RECENTS.add_child(recent_prefab)

			VBRecentFile.VB_FILE_TYPES.EXPORTED:
				recent_prefab.get_node("Control/ICON").hide()
				recent_prefab.get_node("Control/OPEN_BUTTON").hide()
				recent_prefab.get_node("Control/SAVE_BUTTON").hide()
				recent_prefab.get_node("Control/IMPORT_BUTTON").hide()
				recent_prefab.get_node("Control/EXPORT_BUTTON").show()
				#recent_prefab.get_node("Control/IMPORT_BUTTON").connect("pressed",_on_import_file_selected.bind(recent_file.PATH))
				recent_prefab.get_node("Control/EXPORT_BUTTON").connect("pressed",re_export_file.bind(recent_file.PATH))
				$RECENT_MESHES/ScrollContainer/CONTAINER/RECENTS.add_child(recent_prefab)

			VBRecentFile.VB_FILE_TYPES.PROJECT_FILE_OPENED:
				recent_prefab.get_node("Control/ICON").hide()
				recent_prefab.get_node("Control/EXPORT_BUTTON").hide()
				recent_prefab.get_node("Control/IMPORT_BUTTON").hide()
				recent_prefab.get_node("Control/SAVE_BUTTON").hide()
				recent_prefab.get_node("Control/OPEN_BUTTON").show()
				recent_prefab.get_node("Control/SAVE_BUTTON").connect("pressed",re_save_file.bind(recent_file.PATH))
				recent_prefab.get_node("Control/OPEN_BUTTON").connect("pressed",_on_open_file_selected.bind(recent_file.PATH))
				$RECENT_FILES/ScrollContainer/CONTAINER/RECENTS.add_child(recent_prefab)
func update_data_window():
	#update_data_window_scenes()
	#update_data_window_layers()
	update_data_window_layer_masks()
	#update_data_window_replacements()
	#update_data_window_overrides()

func update_data_window_scenes():
	add_title_to_data_window("SCENES (%s)" % DATA.SCENES.size())

	for scene in DATA.SCENES:
		var new_label = Label.new()
		new_label.text = "%s \n %s\n\n" % [scene.PATH,scene.ID]
		new_label.custom_minimum_size = (Vector2(400,50))
		$DATA_INSPECTOR/ScrollContainer/CONTAINER/DATA.add_child(new_label)

func update_data_window_layers():

	add_title_to_data_window("LAYERS (%s)" % DATA.LAYERS.size())

	for layer in DATA.LAYERS:
		var new_label = Label.new()
		new_label.text = "%s \n %s \n (%s) lights\n\n" % [layer.NAME,layer.ID, layer.LIGHTS.size()]
		new_label.custom_minimum_size = (Vector2(400,50))
		$DATA_INSPECTOR/ScrollContainer/CONTAINER/DATA.add_child(new_label)

func update_data_window_layer_masks():
	add_title_to_data_window("LAYER_MASKS (%s)" % DATA.LAYER_MASKS.size())

	for layer_mask in DATA.LAYER_MASKS:
		var new_label = Label.new()
		new_label.text = "LAYER ID: %s \nSCENE ID: %s \nMESH NAME: %s \nSURFACE ID: %s\n\n" % [
			layer_mask.LAYER_ID,
			layer_mask.MESH_NAME,
			layer_mask.SCENE_ID,
			layer_mask.SURFACE_ID	]
		new_label.custom_minimum_size = (Vector2(400,150))
		$DATA_INSPECTOR/ScrollContainer/CONTAINER/DATA.add_child(new_label)

func update_data_window_replacements():
	add_title_to_data_window("MATERIAL_REPLACEMENTS (%s)" % DATA.LAYER_MASKS.size())
	for replacement in DATA.MATERIAL_REPLACEMENTS:
		var new_label = Label.new()
		new_label.text = "NEW_MATERIAL_NAME: %s \n SHADER_ID: %s \nTEXTURE_PATH: %s\n\n" % [
			replacement.NEW_MATERIAL_NAME,
			replacement.SHADER_ID,
			replacement.TEXTURE_PATH]
		new_label.custom_minimum_size = (Vector2(400,150))
		$DATA_INSPECTOR/ScrollContainer/CONTAINER/DATA.add_child(new_label)

func update_data_window_overrides():
	add_title_to_data_window("OVERRIDES (%s)" % DATA.LAYER_MASKS.size())
	for override:MaterialOverride in DATA.MATERIAL_OVERRIDES:
		var new_label = Label.new()
		new_label.text =(
"OVERRIDE_SURFACE: %s \n SCENE_ID: %s \n MESH_NAME: %s \n SURF_ID: %s \n SHADER_ID: %s \n NEW_MATERIAL_NAME: %s \n TARGET_MATERIAL_NAME: %s\n\n" % [
			override.OVERRIDE_SURFACE,
			override.SCENE_ID,
			override.MESH_NAME,
			override.SURF_INDEX,
			override.SHADER_ID,
			override.NEW_MATERIAL_NAME,
			override.TARGET_MATERIAL_NAME])
		new_label.custom_minimum_size = (Vector2(400,150))
		$DATA_INSPECTOR/ScrollContainer/CONTAINER/DATA.add_child(new_label)

func _on_open_file_selected(path: String) -> void:
	p2log("LOADING")
	var result:VBData;
	if ResourceLoader.exists(path):
		result =  load(path)
	else:
		return
	DATA.update_recent_files(path,VBRecentFile.VB_FILE_TYPES.PROJECT_FILE_OPENED)
	update_recents_window()
	for layer_mask_data:VBLayerMaskData in result.LAYER_MASKS:
		var layer_mask:LightLayerMask = LightLayerMask.new()
		layer_mask.LAYER_ID = layer_mask_data.LAYER_ID
		layer_mask.MESH_NAME = layer_mask_data.MESH_NAME
		layer_mask.SCENE_ID = layer_mask_data.SCENE_ID
		layer_mask.SURFACE_ID = layer_mask_data.SURFACE_ID
		DATA.LAYER_MASKS.push_back(layer_mask)

	for layer_data:VBLayerData in result.LAYERS:
		_on_add_layer_pressed(
			layer_data.NAME,
			layer_data.BLENDING_METHOD,
			layer_data.BLENDING_DIRECTION,
			layer_data.BLENDING_FADE,
			layer_data.ID)
		for light_data:VBLightData in result.LIGHTS:
			if(light_data.PARENT_LAYER_ID == layer_data.ID):
				var last_layer_array =  DATA.LAYERS.filter(func(layer):return layer.ID == light_data.PARENT_LAYER_ID)
				if(last_layer_array!=null && last_layer_array.size()>0):
					var last_layer = last_layer_array[0]
					on_add_light_to_layer(
						last_layer.LIST_ITEM,
						last_layer,
						light_data.POSITION,
						Color(light_data.COLOR.x,light_data.COLOR.y,light_data.COLOR.z),
						light_data.RADIUS,
						light_data.MIX)

	for scene:VBSceneData in result.SCENES:
		p2log(scene.PATH)
		load_from_path(scene.PATH, scene.POSITION,scene.ROTATION,scene.SCALE,scene.ID)

	for vb_replacement:VBMaterialReplacement in result.MATERIAL_REPLACEMENTS:
		var mat_replacement:MaterialReplacement = MaterialReplacement.new()
		mat_replacement.NEW_MATERIAL_NAME = vb_replacement.NEW_MATERIAL_NAME
		mat_replacement.TEXTURE_PATH = vb_replacement.TEXTURE_PATH
		mat_replacement.SHADER_ID = vb_replacement.SHADER_ID
		create_replacement (vb_replacement.TEXTURE_PATH,vb_replacement.NEW_MATERIAL_NAME,mat_replacement.SHADER_ID)

	for vb_material_override:VBMaterialOverride in result.MATERIAL_OVERRIDES:
		var replacements_ = DATA.MATERIAL_REPLACEMENTS.filter(func (rep:MaterialReplacement): return rep.NEW_MATERIAL_NAME == vb_material_override.NEW_MATERIAL_NAME)
		if(replacements_!=null && replacements_.size()>0):
			var index_for_replacement =  DATA.MATERIAL_REPLACEMENTS.find(replacements_[0])
			var replacement:MaterialReplacement = replacements_[0]
			if(vb_material_override.OVERRIDE_SURFACE==false):
					select_material(
						vb_material_override.TARGET_MATERIAL_NAME,
						vb_material_override.NEW_MATERIAL_NAME ,
						replacement.MATERIAL,
						vb_material_override.SHADER_ID);
			else:
				for scene in DATA.SCENES:
					for child in scene.SCENE.get_children():
						recursively_apply_overrides(child,vb_material_override,scene,index_for_replacement)
		else:
			print("could not find replacement")
	auto_bake()
	update_material_replacements_window();
	update_material_inspector()
	DATA.save_recents()
	p2log("")

func recursively_apply_overrides(root_scene,vb_material_override,scene,index_for_replacement, number_of_recursions = 0):
	number_of_recursions+=1
	if(number_of_recursions>100):	return
	if root_scene is MeshInstance3D:
		for surf in root_scene.mesh.get_surface_count():
				if(vb_material_override.MESH_NAME == root_scene.name &&
					vb_material_override.SURF_INDEX == surf &&
					vb_material_override.SCENE_ID == scene.ID):
							on_select_replace_mat_for_surface(index_for_replacement,scene,root_scene,surf)
	else:
		for child in root_scene.get_children():
			recursively_apply_overrides(child,vb_material_override,scene,index_for_replacement,number_of_recursions)

func _on_save_file_selected(path: String) -> void:
	var data = DATA.to_project_data();
	var err=ResourceSaver.save(data,path,ResourceSaver.FLAG_NONE)
	if(err != OK):
			p2log("ERROR: %s" % err)
	else:
		p2log("SAVED")
		DATA.update_recent_files(path,VBRecentFile.VB_FILE_TYPES.PROJECT_FILE_SAVED)
		update_recents_window()
		DATA.save_recents()


func _on_export_file_selected(path: String) -> void:
	merge_materials()
	bake_scale_and_rotation()
	var gltf_scene_root_node = Node3D.new()
	for imported_scene:ImportedScene in DATA.SCENES:
		if(imported_scene.EXCLUDE_FROM_EXPORT == false):
			for child_mesh in imported_scene.SCENE.get_children():
				child_mesh.reparent(gltf_scene_root_node)
	var gltf_document_save := GLTFDocument.new()
	var gltf_state_save := GLTFState.new()


	var mats:Array[Material]=[]
	for mat_replacement in DATA.MATERIAL_REPLACEMENTS:
		mats.push_back(mat_replacement.MATERIAL as Material)
	gltf_state_save.set_materials(mats)
	gltf_document_save.append_from_scene(gltf_scene_root_node, gltf_state_save)
	gltf_document_save.write_to_filesystem(gltf_state_save, path)
	DATA.update_recent_files(path,VBRecentFile.VB_FILE_TYPES.EXPORTED)
	update_recents_window()
	DATA.save_recents()

	p2log("EXPORT DONE")
func _on_import_file_selected(path: String) -> void:
	load_from_path(path)
	DATA.save_recents()
	var last_scene = DATA.SCENES[DATA.SCENES.size()-1]
	on_move_scene_pressed(last_scene.NODE)

func on_rotate_pressed(node):
	gizmo.clear_selection()
	gizmo.mode = Gizmo3D.ToolMode.ROTATE
	gizmo.select(node)

func on_scale_pressed(node):
	gizmo.clear_selection()
	gizmo.mode = Gizmo3D.ToolMode.SCALE
	gizmo.select(node)

func on_move_scene_pressed(node):
	p2log("PRESS SPACEBAR TO DESELECT")
	gizmo.clear_selection()
	gizmo.mode = Gizmo3D.ToolMode.MOVE
	gizmo.select(node)
	disable_collision_shapes()


func on_rotate_x_changed(node,scene_list_item):
	gizmo.clear_selection()
	var value = scene_list_item.get_node("ICON/MORE_MENU/ROTATE_X").text
	node.rotation_degrees.x=(float(value))


func on_rotate_x_value_changed(value,mesh:Node3D):
	p2log(value)
	mesh.rotation_degrees.x=(float(value))


func on_rotate_y_changed(node,scene_list_item):
	gizmo.clear_selection()
	var value = scene_list_item.get_node("ICON/MORE_MENU/ROTATE_Y").text
	node.rotation_degrees.y=(float(value))


func on_rotate_y_value_changed(value,mesh:Node3D):
	p2log(value)
	mesh.rotation_degrees.y=(float(value))


func on_rotate_z_changed(node,scene_list_item):
	gizmo.clear_selection()
	var value = scene_list_item.get_node("ICON/MORE_MENU/ROTATE_Z").text
	node.rotation_degrees.z=(float(value))


func on_rotate_z_value_changed(value,mesh:Node3D):
	p2log(value)
	mesh.rotation_degrees.z=(float(value))


func on_move_x_changed(node,scene_list_item):
	gizmo.clear_selection()
	var value = scene_list_item.get_node("ICON/MORE_MENU/MOVE_X").text
	node.position.x  = (float(value))


func on_move_x_value_changed(value,mesh:Node3D):
	p2log(value)
	mesh.position.x= (float(value))


func on_move_y_changed(node,scene_list_item):
	gizmo.clear_selection()
	var value = scene_list_item.get_node("ICON/MORE_MENU/MOVE_Y").text
	node.position.y= (float(value))


func on_move_y_value_changed(value,mesh:Node3D):
	p2log(value)
	mesh.position.y= (float(value))


func on_move_z_changed(node,scene_list_item):
	gizmo.clear_selection()
	var value = scene_list_item.get_node("ICON/MORE_MENU/MOVE_Z").text
	node.position.z = (float(value))


func on_move_z_value_changed(value,mesh:Node3D):
	p2log(value)
	mesh.position.z =(float(value))


func on_scale_changed(node,scene_list_item):
	gizmo.clear_selection()
	var value = scene_list_item.get_node("ICON/MORE_MENU/SCALE_VALUE").text
	node.scale = Vector3.ONE * float(value)

func on_scale_value_changed(value,mesh):
	p2log(value)
	mesh.scale = Vector3.ONE * float(value)

func on_focus():
	$MESH_INSPECTOR.unfocusable =false;

func on_assign_layers_to_mesh_pressed(
	mesh_list_item:VBoxContainer,
	imported_scene:ImportedScene,
	child_mesh:MeshInstance3D,
	surface:int):
	p2log("on_assign_layers_to_mesh_pressed")
	var menu_button:MenuButton = mesh_list_item.get_node("ICON/ASSIGN_LAYERS")
	menu_button.get_popup().clear()
	for light_layer in DATA.LAYERS:
		menu_button.get_popup().add_check_item(light_layer.NAME)
		var index = menu_button.get_popup().item_count - 1
		var already_has_a_mask = DATA.LAYER_MASKS.any(func(layer_mask:LightLayerMask):
				return( layer_mask.LAYER_ID == light_layer.ID &&
				layer_mask.MESH_NAME == child_mesh.name &&
				layer_mask.SURFACE_ID == surface &&
				layer_mask.SCENE_ID == imported_scene.ID))
		menu_button.get_popup().set_item_checked(index,!already_has_a_mask)

func on_assign_layers_to_mesh_done(
	mesh_list_item:VBoxContainer,
	imported_scene:ImportedScene,
	child_mesh:MeshInstance3D,
	surface:int):
	p2log("on_assign_layers_to_mesh_done")
	var menu_button:MenuButton = mesh_list_item.get_node("ICON/ASSIGN_LAYERS")
	for item_index in menu_button.get_popup().item_count:
		var light_layer = DATA.LAYERS[item_index]
		var item_is_checked = menu_button.get_popup().is_item_checked(item_index)
		var already_has_a_mask = DATA.LAYER_MASKS.any(func(layer_mask:LightLayerMask):
			return( layer_mask.LAYER_ID == light_layer.ID &&
				layer_mask.SURFACE_ID == surface &&
				layer_mask.MESH_NAME == child_mesh.name &&
				layer_mask.SCENE_ID == imported_scene.ID))
		if(item_is_checked == false && already_has_a_mask == false):
				var new_layer_mask = LightLayerMask.new()
				new_layer_mask.LAYER_ID = light_layer.ID
				new_layer_mask.SURFACE_ID = surface
				new_layer_mask.MESH_NAME = child_mesh.name
				new_layer_mask.SCENE_ID = imported_scene.ID
				DATA.LAYER_MASKS.push_back(new_layer_mask)
		elif(item_is_checked == true && already_has_a_mask == true):
			#TODO fix - replace find with filter
			var index_to_remove = DATA.LAYER_MASKS.find(light_layer)
			DATA.LAYER_MASKS.remove_at(index_to_remove)
	auto_bake()

func on_assign_layer_mask_state_changed(index:int,
	mesh_list_item:VBoxContainer,
	imported_scene:ImportedScene,
	child_mesh:MeshInstance3D,
	surface:int):
	p2log("on_assign_layer_mask_state_changed")

	var assign_layers:MenuButton = mesh_list_item.get_node("ICON/ASSIGN_LAYERS")
	var popup_menu:PopupMenu = assign_layers.get_popup()
	var item_is_checked = popup_menu.is_item_checked(index)
	popup_menu.set_item_checked(index,!item_is_checked)

func load_mesh(child_mesh,scene_list_item, recursion,imported_scene, imported_scale:Vector3=Vector3.ONE):
	p2log("load_mesh")
	if(child_mesh is MeshInstance3D):
		var mesh_list_item = mesh_list_item_prefab.instantiate()
		mesh_list_item.get_node("ICON/NAME").text = child_mesh.name
		scene_list_item.get_node("VBoxContainer/MESHES").add_child(mesh_list_item)
		var array_mesh:ArrayMesh = child_mesh.mesh
		for surface in array_mesh.get_surface_count():
			var surface_list_item = surface_list_item_prefab.instantiate()
			var assign_layers = surface_list_item.get_node("ICON/ASSIGN_LAYERS")
			var popup_menu:PopupMenu = assign_layers.get_popup()
			popup_menu.hide_on_checkable_item_selection = false;
			popup_menu.hide_on_item_selection = false;
			assign_layers.connect("about_to_popup",on_assign_layers_to_mesh_pressed.bind(
				surface_list_item,
				imported_scene,
				child_mesh,
				surface))
			popup_menu.connect("index_pressed",on_assign_layer_mask_state_changed.bind(
				surface_list_item,
				imported_scene,
				child_mesh,
				surface))
			popup_menu.connect("popup_hide",on_assign_layers_to_mesh_done.bind(
				surface_list_item,
				imported_scene,
				child_mesh,
				surface))
			surface_list_item.get_node("ICON/NAME").text = "Surface %s" % surface
			mesh_list_item.get_node("VBoxContainer/SURFACES").add_child(surface_list_item)
			var og_material:StandardMaterial3D = child_mesh.get_active_material(surface)
			var shader_mat :ShaderMaterial = ShaderMaterial.new()
			shader_mat.shader = DEFAULT_SHADER;
			var shader_name = og_material.resource_name
			if(shader_name == "" || shader_name== null ):
				print("Blank shader name")
				shader_name = "%s" % generate_id()
				og_material.resource_name = shader_name;
			print("MATERIAL NAME:%s for %s/%s/%s"%[shader_name,child_mesh.name,array_mesh.resource_name,surface])
			shader_mat.resource_name = shader_name
			shader_mat.set_shader_parameter("MAIN",og_material.albedo_texture)
			array_mesh.surface_set_material(surface,shader_mat)
			var material_list_item = material_list_item_prefab.instantiate()
			var imported_material = ImportedMaterial.new()
			imported_material.SCENE = imported_scene
			imported_scene.MATERIALS.push_back(imported_material)
			imported_material.MATERIAL = shader_mat
			imported_material.NAME =shader_name
			imported_material.LIST_ITEM = material_list_item;
			DATA.MATERIALS.push_back(imported_material)
			material_list_item.get_node("ICON/NAME").text =shader_name
			var options:OptionButton =  material_list_item.get_node("ICON/REPLACE_MATERIAL")
			options.connect("toggled",on_open_replace_mat_for_surface.bind(material_list_item,imported_scene,child_mesh,surface))
			options.connect("item_selected",on_select_replace_mat_for_surface.bind(imported_scene,child_mesh,surface))
			surface_list_item.get_node("VBoxContainer/MATERIALS").add_child(material_list_item)
	elif(child_mesh is Node3D && child_mesh.get_children().size()>0):
				for grand_child_mesh in child_mesh.get_children():
					recursion+=1;
					if(recursion>max_recursion):
						p2log("ERR too much recursion in this mesh")
						return
					load_mesh(grand_child_mesh,scene_list_item,recursion,imported_scene)

func on_open_replace_mat_for_surface(
	toggled_on:bool,
	material_list_item:VBoxContainer,
	imported_scene:ImportedScene,
	child_mesh:MeshInstance3D,
	surface:int):
	var options:OptionButton =  material_list_item.get_node("ICON/REPLACE_MATERIAL")
	options.clear()
	var selected_override:MaterialOverride = null
	var selected_replacement:int = -1
	for override in DATA.MATERIAL_OVERRIDES:
		if (override.OVERRIDE_SURFACE == true &&
			override.MESH_NAME== child_mesh.name &&
			override.SURF_INDEX == surface &&
		 	override.SCENE_ID == imported_scene.ID):
				selected_override = override
	var r_index = 0
	for replacement in DATA.MATERIAL_REPLACEMENTS:
		if(selected_override!=null&&
		selected_override.NEW_MATERIAL_NAME == replacement.NEW_MATERIAL_NAME):
			selected_replacement = r_index
		options.add_item(replacement.NEW_MATERIAL_NAME,r_index)
		r_index+=1
	if(selected_replacement !=-1):
		options.select(selected_replacement)

func on_select_replace_mat_for_surface(
	index:int,
	imported_scene:ImportedScene,
	child_mesh:MeshInstance3D,
	surface:int):
	var selected_override:MaterialOverride = null
	for override in DATA.MATERIAL_OVERRIDES:
		if (override.OVERRIDE_SURFACE == true &&
			override.MESH_NAME== child_mesh.name &&
			override.SURF_INDEX == surface &&
		 	override.SCENE_ID == imported_scene.ID):
				selected_override = override

	var selected_replacement := DATA.MATERIAL_REPLACEMENTS[index];

	if(selected_override== null):
		print("no override for this surf")
		var new_override := MaterialOverride.new()
		new_override.MESH_NAME = child_mesh.name
		new_override.SCENE_ID = imported_scene.ID
		new_override.SURF_INDEX = surface
		new_override.NEW_MATERIAL_NAME = selected_replacement.NEW_MATERIAL_NAME
		new_override.SHADER_ID = selected_replacement.SHADER_ID
		new_override.OVERRIDE_SURFACE = true
		DATA.MATERIAL_OVERRIDES.push_back(new_override)
	else:
		print("found override for this surf")
		selected_override.NEW_MATERIAL_NAME = selected_replacement.NEW_MATERIAL_NAME
		selected_override.SHADER_ID = selected_replacement.SHADER_ID
	child_mesh.set_surface_override_material(surface,selected_replacement.MATERIAL)

func on_duplicated_pressed(imported_scene:ImportedScene):
	load_from_path(
		imported_scene.PATH,
		imported_scene.NODE.global_position,
		imported_scene.NODE.rotation,
		imported_scene.NODE.scale)

func on_bake_toggle_pressed(imported_scene:ImportedScene):
	var check_box:CheckBox = imported_scene.LIST_ITEM.get_node("HBoxContainer/BAKE");
	imported_scene.EXCLUDE_FROM_BAKE = !check_box.button_pressed
	if(imported_scene.EXCLUDE_FROM_BAKE==true):
		imported_scene.LIST_ITEM.get_node("ICON/ICON_NO_BAKE").show()
	elif(imported_scene.EXCLUDE_FROM_BAKE==false):
		imported_scene.LIST_ITEM.get_node("ICON/ICON_NO_BAKE").hide()

func on_export_toggle_pressed(imported_scene:ImportedScene):
	var check_box:CheckBox = imported_scene.LIST_ITEM.get_node("HBoxContainer/EXPORT");
	imported_scene.EXCLUDE_FROM_EXPORT = !check_box.button_pressed

func on_delete_light(light:VertexLight):
	#_on_reset_pressed()
	gizmo.clear_selection()

	var index = 	light.LAYER.LIGHTS.find(light)
	light.LIGHT_MESH.queue_free()
	light.LIST_ITEM.queue_free()
	var lights = light.LAYER.LIGHTS
	lights.remove_at(index)
	auto_bake()

func on_delete_scene_pressed(imported_scene:ImportedScene):
	#_on_reset_pressed()
	gizmo.clear_selection()
	var index = DATA.SCENES.find(imported_scene)
	imported_scene.SCENE.queue_free()
	imported_scene.NODE.queue_free()
	imported_scene.LIST_ITEM.queue_free()
	for mat in imported_scene.MATERIALS:
		var mat_index = DATA.MATERIALS.find(mat)
		DATA.MATERIALS.remove_at(mat_index)

	imported_scene.MATERIALS = []
	DATA.SCENES.remove_at(index)
	update_material_inspector()

func load_from_path(
	path,
	imported_position:Vector3=Vector3.ZERO,
	imported_rotation:Vector3=Vector3.ZERO,
	imported_scale:Vector3=Vector3.ONE,
	imported_ID:int=-1):
	if(path == ""):return
	p2log("load_from_current_path")
	var gltf_state_load = GLTFState.new()
	var gltf_state_load_2 = GLTFState.new()
	var gltf_document_load_2 = GLTFDocument.new()
	var gltf_document_load = GLTFDocument.new()
	var error = gltf_document_load.append_from_file(path, gltf_state_load)
	var error_2 = gltf_document_load_2.append_from_file(path, gltf_state_load_2)
	var file:FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
	if error == OK:
		DATA.update_recent_files(path,VBRecentFile.VB_FILE_TYPES.IMPORTED)
		update_recents_window()

		var scene = gltf_document_load.generate_scene(gltf_state_load)
		var scene_2 = gltf_document_load_2.generate_scene(gltf_state_load_2)
		scene.name = "MESH"
		var imported_scene = ImportedScene.new()
		var node= $SubViewportContainer/SubViewport
		var mesh = scene_prefab.instantiate()
		imported_scene.NODE = mesh;
		imported_scene.SCENE = scene;
		imported_scene.IMPORTED_SCALE = imported_scale
		imported_scene.IMPORTED_POSITION = imported_position
		imported_scene.IMPORTED_ROTATION = imported_rotation
		imported_scene.PATH = path
		imported_scene.OG_SCENE = scene_2;
		if(imported_ID==-1):
			imported_scene.ID = generate_id()
		else:
			imported_scene.ID = imported_ID
		mesh.add_child(scene)
		node.add_child(mesh)
		mesh.scale = imported_scale
		mesh.position = imported_position
		mesh.rotation = imported_rotation
		var scene_list_item = scene_list_item_prefab.instantiate()
		imported_scene.LIST_ITEM = scene_list_item
		scene_list_item.get_node("HBoxContainer/ROTATE").connect("pressed",on_rotate_pressed.bind(mesh))
		scene_list_item.get_node("HBoxContainer/SCALE").connect("pressed",on_scale_pressed.bind(mesh))
		scene_list_item.get_node("HBoxContainer/MOVE").connect("pressed",on_move_scene_pressed.bind(mesh))
		scene_list_item.get_node("HBoxContainer/DUPLICATE").connect("pressed",on_duplicated_pressed.bind(imported_scene))
		scene_list_item.get_node("ICON/MORE_MENU/DELETE").connect("pressed",on_delete_scene_pressed.bind(imported_scene))
		scene_list_item.get_node("HBoxContainer/BAKE").connect("pressed",on_bake_toggle_pressed.bind(imported_scene))
		scene_list_item.get_node("HBoxContainer/EXPORT").connect("pressed",on_export_toggle_pressed.bind(imported_scene))

		scene_list_item.get_node("ICON/MORE_MENU/SCALE_VALUE").text = "%s" % imported_scale.x
		scene_list_item.get_node("ICON/MORE_MENU/SCALE_VALUE").connect("mouse_entered",on_focus)
		scene_list_item.get_node("ICON/MORE_MENU/SCALE_VALUE").connect("text_submitted",on_scale_value_changed.bind(mesh))
		scene_list_item.get_node("ICON/MORE_MENU/SCALE_VALUE").connect("focus_exited",on_scale_changed.bind(mesh,scene_list_item))

		scene_list_item.get_node("ICON/MORE_MENU/ROTATE_X").text = "%s" % imported_rotation.x
		scene_list_item.get_node("ICON/MORE_MENU/ROTATE_X").connect("mouse_entered",on_focus)
		scene_list_item.get_node("ICON/MORE_MENU/ROTATE_X").connect("text_submitted",on_rotate_x_value_changed.bind(mesh))
		scene_list_item.get_node("ICON/MORE_MENU/ROTATE_X").connect("focus_exited",on_rotate_x_changed.bind(mesh,scene_list_item))

		scene_list_item.get_node("ICON/MORE_MENU/ROTATE_Y").text = "%s" % imported_rotation.y
		scene_list_item.get_node("ICON/MORE_MENU/ROTATE_Y").connect("mouse_entered",on_focus)
		scene_list_item.get_node("ICON/MORE_MENU/ROTATE_Y").connect("text_submitted",on_rotate_y_value_changed.bind(mesh))
		scene_list_item.get_node("ICON/MORE_MENU/ROTATE_Y").connect("focus_exited",on_rotate_y_changed.bind(mesh,scene_list_item))

		scene_list_item.get_node("ICON/MORE_MENU/ROTATE_Z").text = "%s" % imported_rotation.z
		scene_list_item.get_node("ICON/MORE_MENU/ROTATE_Z").connect("mouse_entered",on_focus)
		scene_list_item.get_node("ICON/MORE_MENU/ROTATE_Z").connect("text_submitted",on_rotate_z_value_changed.bind(mesh))
		scene_list_item.get_node("ICON/MORE_MENU/ROTATE_Z").connect("focus_exited",on_rotate_z_changed.bind(mesh,scene_list_item))

		scene_list_item.get_node("ICON/MORE_MENU/MOVE_X").text = "%s" % imported_position.x
		scene_list_item.get_node("ICON/MORE_MENU/MOVE_X").connect("mouse_entered",on_focus)
		scene_list_item.get_node("ICON/MORE_MENU/MOVE_X").connect("text_submitted",on_move_x_value_changed.bind(mesh))
		scene_list_item.get_node("ICON/MORE_MENU/MOVE_X").connect("focus_exited",on_move_x_changed.bind(mesh,scene_list_item))

		scene_list_item.get_node("ICON/MORE_MENU/MOVE_Y").text = "%s" % imported_position.y
		scene_list_item.get_node("ICON/MORE_MENU/MOVE_Y").connect("mouse_entered",on_focus)
		scene_list_item.get_node("ICON/MORE_MENU/MOVE_Y").connect("text_submitted",on_move_y_value_changed.bind(mesh))
		scene_list_item.get_node("ICON/MORE_MENU/MOVE_Y").connect("focus_exited",on_move_y_changed.bind(mesh,scene_list_item))

		scene_list_item.get_node("ICON/MORE_MENU/MOVE_Z").text = "%s" % imported_position.z
		scene_list_item.get_node("ICON/MORE_MENU/MOVE_Z").connect("mouse_entered",on_focus)
		scene_list_item.get_node("ICON/MORE_MENU/MOVE_Z").connect("text_submitted",on_move_z_value_changed.bind(mesh))
		scene_list_item.get_node("ICON/MORE_MENU/MOVE_Z").connect("focus_exited",on_move_z_changed.bind(mesh,scene_list_item))

		imported_scene.NAME = mesh.name
		DATA.SCENES.push_back(imported_scene)
		scene_list_item.get_node("ICON/NAME").text = path
		$MESH_INSPECTOR/ScrollContainer/CONTAINER/MESHES.add_child(scene_list_item)
		for child_mesh in scene.get_children():
			load_mesh(child_mesh,scene_list_item,0,imported_scene)
		update_material_inspector()
	else:
		p2log("Couldn't load glTF scene (error code: %s)." % error_string(error))

func actually_bake():
	p2log("BAKING")
	$BAKE.text = ("BAKING")
	$HBoxContainer.visible = false
	$MENU_BUTTON.visible = true;
	_on_reset_pressed()
	for scene in DATA.SCENES:
		for child:MeshInstance3D in scene.SCENE.get_children():
			if(scene.EXCLUDE_FROM_BAKE == false):
				update_mesh(child,scene)
	$BAKE.text = ("BAKE")
	p2log("BAKE COMPLETE")

func auto_bake():
	if(AUTO_BAKE == true):
		_on_bake_pressed()

func _on_bake_pressed() -> void:
	$BAKE.text = ("BAKING")
	baking_timer.start()

func disable_collision_shapes():
	for scene in DATA.SCENES:
		scene.NODE.get_node("StaticBody3D/CollisionShape3D").disabled = true
	for layer:LightLayer in DATA.LAYERS:
		for light in layer.LIGHTS:
			light.LIGHT_MESH.get_node("StaticBody3D/CollisionShape3D").disabled = true

func _on_gizmo_3d_transform_begin(mode: Gizmo3D.TransformMode) -> void:
	p2log("PRESS SPACEBAR TO DESELECT")
	disable_collision_shapes()

func _on_gizmo_3d_transform_changed(mode: Gizmo3D.TransformMode, value: Vector3) -> void:
	if(CURRENT_LIGHT != null && mode == Gizmo3D.TransformMode.SCALE):
		CURRENT_LIGHT.LIGHT_MESH.scale =Vector3.ONE
		var mesh:MeshInstance3D = CURRENT_LIGHT.LIGHT_MESH.get_node("MeshInstance3D")
		mesh.scale = Vector3.ONE *CURRENT_LIGHT.RADIUS;
		CURRENT_LIGHT.RADIUS+=value.x/10.0
		CURRENT_LIGHT.RADIUS+=value.y/10.0
		CURRENT_LIGHT.RADIUS+=value.z/10.0
		CURRENT_LIGHT.LIST_ITEM.get_node("VBoxContainer/RADIUS_CONTAINER/SpinBox").value = 	CURRENT_LIGHT.RADIUS

func enable_collision_shapes():
	for scene in DATA.SCENES:
		scene.NODE.get_node("StaticBody3D/CollisionShape3D").disabled = false
	for layer:LightLayer in DATA.LAYERS:
		for light in layer.LIGHTS:
			light.LIGHT_MESH.get_node("StaticBody3D/CollisionShape3D").disabled = false

func _on_gizmo_3d_transform_end(mode: Gizmo3D.TransformMode) -> void:
	if(CURRENT_LIGHT != null && mode == Gizmo3D.TransformMode.SCALE):
		var mesh:MeshInstance3D = CURRENT_LIGHT.LIGHT_MESH.get_node("MeshInstance3D")
		mesh.scale = Vector3.ONE *CURRENT_LIGHT.RADIUS;
		CURRENT_LIGHT.LIGHT_MESH.scale =Vector3.ONE
		CURRENT_LIGHT.LIST_ITEM.get_node("VBoxContainer/RADIUS_CONTAINER/SpinBox").value = 	CURRENT_LIGHT.RADIUS
	$HBoxContainer.visible = false
	$MENU_BUTTON.visible = true;
	auto_bake()

func _on_menu_button_pressed() -> void:
	$HBoxContainer.visible = true
	$MENU_BUTTON.visible = false;

func _on_reset_pressed() -> void:
	for scene in DATA.SCENES:
		if(scene.EXCLUDE_FROM_BAKE):continue
		for mesh:MeshInstance3D in scene.SCENE.get_children():
			if(mesh is MeshInstance3D):
				var mesh_array:ArrayMesh=mesh.mesh;
				for og_mesh:MeshInstance3D in scene.OG_SCENE.get_children():
					if(og_mesh.name == mesh.name):
						var count =mesh_array.get_surface_count()
						var tools = []
						for index in count:
							tools.push_back(MeshDataTool.new())
						for index in count:
							var data:MeshDataTool = tools[index]
							data.create_from_surface(og_mesh.mesh, index)
						mesh_array.clear_surfaces()
						for index in count:
							var data = tools[index]
							data.commit_to_surface(mesh_array)
							var override_material = get_mat_override_for_surface(index,mesh,scene)
							if(override_material!=null):
								mesh.set_surface_override_material(index,override_material)
							else:
								var og_mat:StandardMaterial3D = mesh_array.surface_get_material(index)
								var shader_material:=ShaderMaterial.new()
								shader_material.shader = DEFAULT_SHADER

								shader_material.resource_name = og_mat.resource_name
								shader_material.set_shader_parameter("MAIN",og_mat.albedo_texture)
								mesh_array.surface_set_material(index,shader_material)
			else:
				print("TODO FIX | Skipped reset")

func _on_light_sphere_checkbox_toggled(toggled_on: bool) -> void:
	LIGHT_SPHERES_ON = toggled_on
	if(LIGHT_SPHERES_ON):
		$LIGHT_SPHERE_CHECKBOX.icon = icon_sphere
	else:
		$LIGHT_SPHERE_CHECKBOX.icon = icon_on

	for layer in DATA.LAYERS:
		for light in layer.LIGHTS:
			var sphere:MeshInstance3D = light.LIGHT_MESH.get_node("MeshInstance3D")
			sphere.visible = toggled_on;

func _on_autobake_checkbox_toggled(toggled_on: bool) -> void:
	AUTO_BAKE = toggled_on

func p2log(str:String):
	$INFO_TEXT.text = str

func _on_icon_checkbox_toggled(toggled_on: bool) -> void:
	if(toggled_on):
		$ICON_CHECKBOX.text = "ICONS ON"
		$ICON_CHECKBOX.icon = icon_on
		enable_collision_shapes()
		for scene in DATA.SCENES:
			scene.NODE.modulate.a =1.0
		for layer:LightLayer in DATA.LAYERS:
			for light in layer.LIGHTS:
				light.LIGHT_MESH.modulate.a =1.0
	else:
		$ICON_CHECKBOX.text = "ICONS OFF"
		$ICON_CHECKBOX.icon = icon_off
		gizmo.clear_selection()
		disable_collision_shapes()
		for scene in DATA.SCENES:
			scene.NODE.modulate.a =0.0
		for layer:LightLayer in DATA.LAYERS:
			for light in layer.LIGHTS:
				light.LIGHT_MESH.modulate.a =0.0

func bake_scale_and_rotation() -> void:
	if(BAKE_SCALE_ON_EXPORT || BAKE_ROTATION_ON_EXPORT):
		for imported_scene:ImportedScene in DATA.SCENES:
				var scene_scale =imported_scene.NODE.scale
				var scene_rotation = imported_scene.SCENE.rotation
				var node_rotation = imported_scene.NODE.rotation
				for child_mesh in imported_scene.SCENE.get_children():
					var target_scale =scene_scale *child_mesh.scale*imported_scene.SCENE.scale
					if(BAKE_SCALE_ON_EXPORT):
						scale_mesh(child_mesh,target_scale )
					if(BAKE_ROTATION_ON_EXPORT):
						rotate_mesh(child_mesh,scene_rotation)
						rotate_mesh(child_mesh,node_rotation)
				if(BAKE_SCALE_ON_EXPORT):
					imported_scene.NODE.scale=Vector3.ONE
					imported_scene.SCENE.scale=Vector3.ONE
				if(BAKE_ROTATION_ON_EXPORT):
					imported_scene.NODE.rotation=Vector3.ZERO
					imported_scene.SCENE.rotation=Vector3.ZERO

func bake_rotation(scene:MeshInstance3D,rotation_target:Vector3):
	var rotated_faces = PackedVector3Array(scene.mesh.get_faces())
	for i in rotated_faces.size():
		rotated_faces.set(i, rotated_faces[i].rotated(Vector3(0,0,1), rotation_target.z))
	for i in rotated_faces.size():
		rotated_faces.set(i, rotated_faces[i].rotated(Vector3(1,0,0), rotation_target.x))
	for i in rotated_faces.size():
		rotated_faces.set(i, rotated_faces[i].rotated(Vector3(0,1,0), rotation_target.y))

func rotate_mesh(mesh:MeshInstance3D, rotation_target:Vector3):
		var array_mesh:ArrayMesh = mesh.mesh
		var surface_count =array_mesh.get_surface_count()
		var tools = []
		for index_ in surface_count:
			tools.push_back(MeshDataTool.new())
		for index in surface_count:
			var data:MeshDataTool = tools[index]
			data.create_from_surface(array_mesh, index)
			for i in range(data.get_vertex_count()):
				var vertex = data.get_vertex(i)
				data.set_vertex(i, vertex.rotated(Vector3(0,0,1),rotation_target.z))
				data.set_vertex(i, vertex.rotated(Vector3(1,0,0),rotation_target.x))
				data.set_vertex(i, vertex.rotated(Vector3(0,1,0),rotation_target.y))
		mesh.scale = Vector3.ONE
		array_mesh.clear_surfaces()
		for index in surface_count:
			var data = tools[index]
			data.commit_to_surface(array_mesh)

func update_material_inspector():
	for child in $MATERIAL_INSPECTOR/ScrollContainer/CONTAINER/MATERIALS.get_children():
		child.queue_free()
	var grouped_materials = DATA.MATERIALS.map(func (imported_material:ImportedMaterial):
		var grouped_material_count = DATA.MATERIALS.filter(func(mat):return imported_material.NAME == mat.NAME).size()
		return [imported_material.NAME,grouped_material_count] )
	var distinct_grouped_materials = []
	for mat in grouped_materials:
		if(distinct_grouped_materials.has(mat) == false):
			distinct_grouped_materials.push_back(mat)
	for mat in distinct_grouped_materials:
		var material_list_item = material_override_list_item_prefab.instantiate()
		material_list_item.get_node("ICON/NAME").text = "%s (%s)"%[mat[0],mat[1]]
		material_list_item.get_node("VBoxContainer/REPLACE_MATERIAL").connect(
			"toggled",on_toggle_replace_mat_options.bind(material_list_item,mat[0]))
		material_list_item.get_node("VBoxContainer/REPLACE_MATERIAL").connect(
			"item_selected",on_select_replace_mat_options.bind(material_list_item,mat[0]))
		var override = DATA.MATERIAL_OVERRIDES.filter(func (mo:MaterialOverride):return (
			mo.OVERRIDE_SURFACE == false && mo.TARGET_MATERIAL_NAME == mat[0]))
		if(override != null && override.size()>0):
			var mat_override:MaterialOverride = override[0]
			var mat_name = mat_override.NEW_MATERIAL_NAME
			var ob:OptionButton = material_list_item.get_node("VBoxContainer/REPLACE_MATERIAL")
			ob.add_item(mat_name,0)
			ob.select(0)
		$MATERIAL_INSPECTOR/ScrollContainer/CONTAINER/MATERIALS.add_child(material_list_item)

func recursively_apply_override_material_to_scene(scene:ImportedScene,
	child:Node3D,
	new_material,
	target_mat_name:String,
	recursive_index:int=0):
	var recursive_max = 100;
	if(recursive_index>recursive_max):
		return;
	if(child is MeshInstance3D):
		var mesh_array:ArrayMesh = child.mesh;
		for surface in mesh_array.get_surface_count():
			var surf_name = mesh_array.surface_get_name(surface)
			var surface_material = mesh_array.surface_get_material(surface)
			var mat_name = surface_material.resource_name
			if(mat_name != "" && surface_material!=null && mat_name == target_mat_name):
				child.set_surface_override_material(surface,new_material)
	else:
		recursive_index+=1;
		for grand_child in child.get_children():
			recursively_apply_override_material_to_scene(scene, child,new_material,target_mat_name,recursive_index)

func recursively_apply_material_to_scene(scene:ImportedScene,
	child:Node3D,
	override:MaterialOverride,
	recursive_index:int=0):
	var recursive_max = 100;
	if(recursive_index>recursive_max):
		return;
	if(child is MeshInstance3D):
		var mesh_array:ArrayMesh = child.mesh;
		for surface in mesh_array.get_surface_count():
			var surface_material = mesh_array.surface_get_material(surface)
			if(override.OVERRIDE_SURFACE==false && surface_material.resource_name == override.TARGET_MATERIAL_NAME):
				var materials = DATA.MATERIAL_OVERRIDES.filter(
					func (mo:MaterialOverride): return mo.TARGET_MATERIAL_NAME == surface_material.resource_name)
				if(materials!=null && materials.size()>0):
					var material_ = materials[0]
					if(material_.resource_name != ""):
						child.set_surface_override_material(surface,material_)
					else:
						print("recursively_apply_material_to_scene| blank override")
			else:
				pass
				#apply override to just one mesh
	else:
		recursive_index+=1;
		for grand_child in child.get_children():
			recursively_apply_material_to_scene(scene, child,override,recursive_index)

func on_select_replace_mat_options(index:int,Container,target_mat_name:String):
		print(index)
		if(index == 0):
			select_material(target_mat_name,target_mat_name,null,index)
		else:
			selected_replacement(index-1,target_mat_name)

func get_index_for_built_in_replacement(mat_name):
	match(mat_name):
		"WATER_MATERIAL":
			return BUILT_IN_MATERIALS.WATER
		"WATER_FLOW_MATERIAL":
			return BUILT_IN_MATERIALS.WATER_FLOW
		"WINDY_MATERIAL":
			return BUILT_IN_MATERIALS.WINDY
		"GLASS_MATERIAL":
			return BUILT_IN_MATERIALS.GLASS
	return BUILT_IN_MATERIALS.DEFAULT

func selected_replacement(index,target_mat_name):
		var replacement: = DATA.MATERIAL_REPLACEMENTS[index]
		select_material(target_mat_name,replacement.NEW_MATERIAL_NAME,replacement.MATERIAL,index);

		if(AUTO_BAKE):
			auto_bake()
		#else:
			#_on_reset_pressed()

func select_material(target_mat_name,new_mat_name,material_,shader_id,is_update=false):
	if(target_mat_name == "" || new_mat_name == "" ||target_mat_name == null|| new_mat_name == null):
		return
	var existing_override_for_this_material = DATA.MATERIAL_OVERRIDES.filter(func (mat_override:MaterialOverride):
		return (mat_override.OVERRIDE_SURFACE == false && mat_override.TARGET_MATERIAL_NAME == target_mat_name ))
	var already_selected = DATA.MATERIAL_OVERRIDES.any(func (mat_override:MaterialOverride):
		return ( mat_override.OVERRIDE_SURFACE == false && mat_override.TARGET_MATERIAL_NAME == target_mat_name &&
		mat_override.NEW_MATERIAL_NAME == new_mat_name))
	if(already_selected && is_update==false):
		print("select_material | Already selected this one %s" % new_mat_name)
		return
	if(existing_override_for_this_material!=null && existing_override_for_this_material.size()>0):
		print("select_material | UPDATE %s" % new_mat_name)
		existing_override_for_this_material[0].NEW_MATERIAL_NAME= new_mat_name
		existing_override_for_this_material[0].SHADER_ID= shader_id
	else:
		print("select_material | NEW | %s" % new_mat_name)
		var new_mat_override:MaterialOverride = MaterialOverride.new()
		new_mat_override.NEW_MATERIAL_NAME = new_mat_name
		new_mat_override.SHADER_ID= shader_id
		new_mat_override.TARGET_MATERIAL_NAME = target_mat_name;
		new_mat_override.OVERRIDE_SURFACE = false
		DATA.MATERIAL_OVERRIDES.push_back(new_mat_override)
	for scene in DATA.SCENES:
		for child in scene.SCENE.get_children():
			recursively_apply_override_material_to_scene(scene,child,material_,target_mat_name);
			pass

func on_toggle_replace_mat_options(toggled_on:bool,material_list_item:VBoxContainer,mat_name:String):
	if(toggled_on):
		var mat_override = DATA.MATERIAL_OVERRIDES.filter(func (mat_override:MaterialOverride):
			return (mat_override.OVERRIDE_SURFACE == false && mat_override.TARGET_MATERIAL_NAME== mat_name))
		var options:OptionButton = material_list_item.get_node("VBoxContainer/REPLACE_MATERIAL");
		options.clear()
		options.add_item(mat_name)
		for replacement in DATA.MATERIAL_REPLACEMENTS:
			options.add_item(replacement.NEW_MATERIAL_NAME)
		if(mat_override!=null && mat_override.size()>0):
			var override_:MaterialOverride = mat_override[0];
			var option_index_target = 0
			for option_index in options.item_count:
				if(options.get_item_text(option_index) == override_.NEW_MATERIAL_NAME):
					option_index_target = option_index
			options.select(option_index_target)
		else:
			options.select(-1)

func get_mat_override_for_surface(surf:int,mesh:MeshInstance3D,scene:ImportedScene):
	var override:MaterialOverride = null
	var mesh_array:ArrayMesh = mesh.mesh
	var og_material = mesh_array.surface_get_material(surf)
	if(og_material == null):
		#print("get_mat_override_for_surface | no_og_material")
		return null
	var og_mat_name = og_material.resource_name
	for mat_override in DATA.MATERIAL_OVERRIDES:
		if( mat_override.OVERRIDE_SURFACE == false && mat_override.TARGET_MATERIAL_NAME == og_mat_name):
			override = mat_override;
		elif(mat_override.OVERRIDE_SURFACE == true && mat_override.MESH_NAME == mesh.name && mat_override.SURF_INDEX == surf && mat_override.SCENE_ID == scene.ID):
			override = mat_override;

	if(override== null):
		#print("get_mat_override_for_surface | no override")
		return null;
	var material_to_return:ShaderMaterial = null
	for mat_replacement:MaterialReplacement in DATA.MATERIAL_REPLACEMENTS:
		if(mat_replacement.NEW_MATERIAL_NAME== override.NEW_MATERIAL_NAME):
			material_to_return = mat_replacement.MATERIAL
	#if(material_to_return!=null):
		#print("get_mat_override_for_surface | '%s' was found." % material_to_return.resource_name)
	return material_to_return

func merge_materials():
	for scene in DATA.SCENES:
		for child in scene.SCENE.get_children():
			if (child is MeshInstance3D):
				var mesh:MeshInstance3D  = child
				var mesh_array:ArrayMesh = mesh.mesh
				for surf in mesh_array.get_surface_count():
					var material_: = mesh_array.surface_get_material(surf)
					var override_ = child.get_surface_override_material(surf)
					var material_override:Material = get_mat_override_for_surface(surf,mesh,scene)
					if(material_override!=null):
						mesh_array.surface_set_material(surf,material_override)

func on_edit_replacement(replacement:MaterialReplacement,material_replacement_list_item:Node):
	CURRENT_REPLACEMENT = replacement
	CURRENT_REPLACEMENT_LIST_ITEM = material_replacement_list_item
	$UPDATE_TEXTURE.show()

func update_material_replacements_window():
	for child in $REPLACEMENT_MATERIALS/ScrollContainer/CONTAINER/MATERIALS.get_children():
		child.queue_free()
	for replacement:MaterialReplacement in DATA.MATERIAL_REPLACEMENTS:
		var material_replacement_list_item = material_replacement_list_item_prefab.instantiate()
		material_replacement_list_item.get_node("ICON/SHADER_ID").text = "%s" % replacement.SHADER_ID
		material_replacement_list_item.get_node("ICON/PATH").text = replacement.TEXTURE_PATH
		if(FileAccess.file_exists(replacement.TEXTURE_PATH)==false):
			material_replacement_list_item.get_node("ICON/PATH/MISSING").show()
		else:
			material_replacement_list_item.get_node("ICON/PATH/MISSING").hide()
		material_replacement_list_item.get_node("ICON/PATH/EDIT").connect("pressed",
			on_edit_replacement.bind(replacement,material_replacement_list_item))
		material_replacement_list_item.get_node("ICON/NAME").text = replacement.NEW_MATERIAL_NAME
		$REPLACEMENT_MATERIALS/ScrollContainer/CONTAINER/MATERIALS.add_child(material_replacement_list_item)

func _on_create_material_pressed() -> void:
	var PATH = $REPLACEMENT_MATERIALS/PATH.text;
	var mat_name = $REPLACEMENT_MATERIALS/LineEdit.text;
	$REPLACEMENT_MATERIALS/LineEdit.text = ""
	var shader_id = $REPLACEMENT_MATERIALS/OptionButton.selected;
	$REPLACEMENT_MATERIALS/OptionButton.selected = 0;
	create_replacement (PATH,mat_name,shader_id)
	update_material_replacements_window();
	DATA.save_recents()


func create_replacement (PATH,mat_name,shader_id):
	var new_mat_override := MaterialReplacement.new()
	if(mat_name == ""):mat_name="UNTITLED %s" % generate_id()
	new_mat_override.NEW_MATERIAL_NAME = mat_name;
	new_mat_override.SHADER_ID = shader_id;
	var shader = get_shader(new_mat_override.SHADER_ID)
	new_mat_override.MATERIAL = ShaderMaterial.new()
	new_mat_override.MATERIAL.shader = shader;
	new_mat_override.TEXTURE_PATH = PATH;
	new_mat_override.MATERIAL.resource_name = mat_name
	if(PATH == ""):
		PATH = default_texture
	elif(FileAccess.file_exists(PATH) == false):
		PATH = missing_texture
	var texture_image = load_image(PATH)
	if(texture_image == null):
		texture_image = missing_texture_
	new_mat_override.MATERIAL.set_shader_parameter("MAIN",texture_image)
	DATA.MATERIAL_REPLACEMENTS.push_back(new_mat_override)
	DATA.update_recent_files(PATH,VBRecentFile.VB_FILE_TYPES.TEXTURE);
	update_recents_window()

func load_image(PATH:String):
	if(PATH.begins_with("res://")):
		var image = Image.new()
		var result = load(PATH)
		if(result is Image):
			return ImageTexture.create_from_image(image)
		elif(result is CompressedTexture2D):
			return (image)
		else:
			print("load_image | result was null")
			return null
	if(FileAccess.file_exists(PATH)==true):
		var result = Image.load_from_file(PATH)
		if(result != null):
			return ImageTexture.create_from_image(result)
		else:
			print("load_image | result was null")
	print("load_image | file does not exist")
	return null

func get_shader(shader_id:int):
	match(shader_id):
		SHADERS.WATER:
			return WATER_SHADER
		SHADERS.WINDY:
			return WINDY_SHADER
		SHADERS.GLASS:
			return GLASS_SHADER
		SHADERS.WATER_FLOW:
			return WATER_FLOW_SHADER
	return DEFAULT_SHADER

#func get_material_for_override_id(override_material_index:int):
	#match(override_material_index):
		#BUILT_IN_MATERIALS.DEFAULT:
			#return DEFAULT_MATERIAL
		#BUILT_IN_MATERIALS.WATER:
			#return WATER_MATERIAL
		#BUILT_IN_MATERIALS.WINDY:
			#return WINDY_MATERIAL
		#BUILT_IN_MATERIALS.GLASS:
			#return GLASS_MATERIAL
		#BUILT_IN_MATERIALS.WATER_FLOW:
			#return WATER_FLOW_MATERIAL

func _on_bake_rotation_export_toggled(toggled_on: bool) -> void:
	BAKE_ROTATION_ON_EXPORT = toggled_on

func _on_normalize_scale_on_export_toggled(toggled_on: bool) -> void:
	BAKE_SCALE_ON_EXPORT= toggled_on

func generate_id():
	return ceili(Time.get_unix_time_from_system()*100)

func _on_open_texture_file_selected(path: String) -> void:
	$REPLACEMENT_MATERIALS/PATH.text = path

func _on_open_texture_pressed() -> void:
	$OPEN_TEXTURE.show()

func _on_update_texture_file_selected(path: String) -> void:
	DATA.update_recent_files(path,VBRecentFile.VB_FILE_TYPES.TEXTURE);
	update_recents_window()
	CURRENT_REPLACEMENT.TEXTURE_PATH = path;
	CURRENT_REPLACEMENT_LIST_ITEM.get_node("ICON/PATH").text = path;
	var texture_image = load_image(path)
	CURRENT_REPLACEMENT.MATERIAL.set_shader_parameter("MAIN",texture_image)
	update_material_replacements_window()


func _on_bake_toggle_on_pressed() -> void:
	for scene in DATA.SCENES:
		scene.EXCLUDE_FROM_BAKE = false
	for child in $MESH_INSPECTOR/ScrollContainer/CONTAINER/MESHES.get_children():
		var toggle:CheckBox = child.get_node("HBoxContainer/BAKE")
		toggle.button_pressed = true
func _on_bake_toggle_off_pressed() -> void:

	for scene in DATA.SCENES:
		scene.EXCLUDE_FROM_BAKE = true
	for child in $MESH_INSPECTOR/ScrollContainer/CONTAINER/MESHES.get_children():
			var toggle:CheckBox = child.get_node("HBoxContainer/BAKE")
			toggle.button_pressed = false
func _on_export_toggle_on_pressed() -> void:

	for scene in DATA.SCENES:
		scene.EXCLUDE_FROM_EXPORT = false
	for child in $MESH_INSPECTOR/ScrollContainer/CONTAINER/MESHES.get_children():
			var toggle:CheckBox = child.get_node("HBoxContainer/EXPORT")
			toggle.button_pressed = true
func _on_export_toggle_off_pressed() -> void:
	for scene in DATA.SCENES:
		scene.EXCLUDE_FROM_EXPORT = true
	for child in $MESH_INSPECTOR/ScrollContainer/CONTAINER/MESHES.get_children():
			var toggle:CheckBox = child.get_node("HBoxContainer/EXPORT")
			toggle.button_pressed = false


func _on_expand_all_pressed() -> void:
	for child in $MESH_INSPECTOR/ScrollContainer/CONTAINER/MESHES.get_children():
		child.get_node("ICON/EXPAND").open()
		#child.get_node("VBoxContainer").show()
	pass # Replace with function body.


func _on_collapse_all_pressed() -> void:
	for child in $MESH_INSPECTOR/ScrollContainer/CONTAINER/MESHES.get_children():
		#child.get_node("VBoxContainer").hide()
		child.get_node("ICON/EXPAND").close()
	pass # Replace with function body.


func _on_windows_button_toggled(toggled_on: bool) -> void:
	if(toggled_on == false):
		$HBoxContainer.visible = false
		$MENU_BUTTON.visible = true;
		$PALETTE_INSPECTOR.hide()
		$REPLACEMENT_MATERIALS.hide()
		$LAYER_INSPECTOR.hide()
		$MATERIAL_INSPECTOR.hide()
		$MESH_INSPECTOR.hide()
		$DATA_INSPECTOR.hide()
		$RECENT_FILES.hide()
		$RECENT_MESHES.hide()
		$RECENT_TEXTURES.hide()
	else:
		$PALETTE_INSPECTOR.show()
		$REPLACEMENT_MATERIALS.show()
		$LAYER_INSPECTOR.show()
		$MATERIAL_INSPECTOR.show()
		$MESH_INSPECTOR.show()
		$DATA_INSPECTOR.show()
		$RECENT_FILES.show()
		$RECENT_MESHES.show()
		$RECENT_TEXTURES.show()
