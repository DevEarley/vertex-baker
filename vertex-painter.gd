extends Control
class_name VertexBakerMainWindow

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

@export var gizmo : Gizmo3D
@export var DEFAULT_SHADER:VisualShader
@export var WATER_SHADER:VisualShader
@export var WATER_FLOW_SHADER:VisualShader
@export var WINDY_SHADER:VisualShader
@export var GLASS_SHADER:VisualShader

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

var scene_prefab = preload("res://scene_prefab.tscn")
var surface_prefab = preload("res://surface_prefab.tscn")
var COMPLEXITY = 0
var previous_mix =0
var MOVING_WINDOW = false
var AUTO_BAKE = false
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
var MIN_DISTANCE = 1.0;
var CLOSE_VERTS:Array = []

var VERTS_BY_LIGHT_GROUPS:Array[VertByLightGroup]
var FLAT_LIST:Array[FlatVertex]
var CHUNKS=[]
var FLAT_MESHES:Array[FlatMesh]
var DIRTY_MESHES:Array[FlatMesh]
var CURRENT_MESH:SelectableMesh
var last_light_texture
var last_mesh_texture
var BAKED = false
var CLEANED_FLAT_LIST: Array[FlatVertex]
var FULL_BAKE=true

func _ready():
	$FULL_BAKE_CHECKBOX.disabled = true
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
	layer.BLENDING_DIRECTION  = blending_direction
	layer.BLENDING_FADE  = blending_fade
	layer.BLENDING_METHOD = blending_method
	if(imported_id == -1 || imported_id == null || imported_id == 0):
		layer.ID =generate_id()
	else:
		layer.ID = imported_id
	if(layer_name == "UNTITLED"):
		layer.NAME = "%s #%s"%[layer_name,layer.ID]
	else:
		layer.NAME = layer_name
	DATA.LAYERS.push_back(layer)
	add_layer_to_window(layer)

func add_layer_to_window(layer):
	var new_layer = layer_prefab.instantiate()
	layer.LIST_ITEM = new_layer;
	$LAYER_INSPECTOR/ScrollContainer/CONTAINER/LAYERS.add_child(new_layer)
	var button  = new_layer.get_node("NAME/ADD_LIGHT_TO_LAYER")
	var delete_button  = new_layer.get_node("MORE_MENU/DELETE")
	var move_up_button  = new_layer.get_node("MORE_MENU/MOVE_UP")
	var move_down_button  = new_layer.get_node("MORE_MENU/MOVE_DOWN")
	var blending_dropdown:OptionButton  = new_layer.get_node("NAME/BLENDING_METHOD")
	var blending_direction_dropdown:OptionButton  = new_layer.get_node("NAME/BLENDING_DIRECTION")
	var blending_fade_dropdown:OptionButton  = new_layer.get_node("NAME/BLENDING_FADE")
	var name_label  = new_layer.get_node("NAME")
	name_label.text = layer.NAME
	button.connect("pressed",on_add_light_to_layer.bind(new_layer,layer))
	delete_button.connect("pressed",on_delete_layer_pressed.bind(new_layer,layer))
	move_up_button.connect("pressed",on_layer_move_up_pressed.bind(new_layer,layer))
	move_down_button.connect("pressed",on_layer_move_down_pressed.bind(new_layer,layer))
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
		CURRENT_LAYER.BLENDING_METHOD = index as LightLayer.BLENDING_METHODS
	auto_bake()

func on_blending_method_dropdown_pressed(light_layer:LightLayer):
		CURRENT_LAYER = light_layer

func on_blending_direction_dropdown_selected(index:int):
	if(CURRENT_LAYER != null):
		CURRENT_LAYER.BLENDING_DIRECTION = index as LightLayer.BLENDING_DIRECTIONS
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

func on_layer_move_down_pressed(layer:Control,light_layer:LightLayer):
	var index_to_reorder = DATA.LAYERS.find(light_layer)
	if(index_to_reorder == DATA.LAYERS.size()-1):return;
	var target_occupant = DATA.LAYERS[index_to_reorder+1]
	DATA.LAYERS[index_to_reorder+1]=light_layer
	DATA.LAYERS[index_to_reorder]=target_occupant
	update_layers_window()
	auto_bake()

func on_layer_move_up_pressed(layer:Control,light_layer:LightLayer):
	var index_to_reorder = DATA.LAYERS.find(light_layer)
	if(index_to_reorder == 0):return;
	var target_occupant = DATA.LAYERS[index_to_reorder-1]
	DATA.LAYERS[index_to_reorder-1]=light_layer
	DATA.LAYERS[index_to_reorder]=target_occupant
	update_layers_window()
	auto_bake()

func update_layers_window():
	for child in $LAYER_INSPECTOR/ScrollContainer/CONTAINER/LAYERS.get_children():
		child.queue_free();

	for layer:LightLayer in DATA.LAYERS:
		add_layer_to_window(layer)
		for light in layer.LIGHTS:
			add_light_to_layer_list_item(light,light.RADIUS,light.MIX,layer.LIST_ITEM)

func on_add_light_to_layer(
	layer:Control,light_layer:LightLayer,
	imported_position:Vector3=Vector3.ZERO,
	imported_color:Color= Color.WHITE,
	imported_radius:float=1.0,
	imported_mix:float=1.0,id:int=-1):
	light_layer.LIST_ITEM.get_node("VBoxContainer/EXPAND").show()
	var light = VertexLight.new()
	#if(id == -1||id == null|| id == 0):
	light.ID = generate_id()
	#else:
		#light.ID=id;
	light.DIRTY_MESHES_NEED_REBAKE = true
	light.DIRTY_USE_DURING_BAKE = true
	light.COLOR = imported_color
	light.LIGHT_MESH = light_mesh.instantiate()
	light.LIGHT_MESH.position = imported_position
	light.LIGHT_MESH.LIGHT = light
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
	add_light_to_layer_list_item(light,imported_radius,imported_mix,layer)
	auto_bake()

func add_light_to_layer_list_item(light,imported_radius,imported_mix,layer_control:Control):
	var new_light = light_prefab.instantiate()
	light.LIGHT_MESH.LIST_ITEM = new_light
	light.LIST_ITEM = new_light;
	var name_label:Label = new_light.get_node("VBoxContainer/LIGHT_NAME")
	name_label.text ="%s"% light.ID
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
	layer_control.get_node("VBoxContainer/LIGHTS").add_child(new_light)

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
	if(BAKED == true):
		var groups_affected_by_move = VERTS_BY_LIGHT_GROUPS.filter(func(group:VertByLightGroup):return(
			light.ID == group.LIGHT.ID
		));

		light.DIRTY_MESHES_NEED_REBAKE = true;
		light.DIRTY_USE_DURING_BAKE = true;

		if(groups_affected_by_move!=null && groups_affected_by_move.size()>0):
			for group in groups_affected_by_move:
				mark_meshes_in_group_as_dirty(group)
				VERTS_BY_LIGHT_GROUPS = swap_n_remove(group,VERTS_BY_LIGHT_GROUPS)
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

func get_average_of_vectors(array_of_vectors:Array[Vector3]):
	if(array_of_vectors.size()==0):
		return Vector3.ZERO
	var total_vector :Vector3 = Vector3.ZERO;
	for vector in array_of_vectors:
		total_vector+= vector
	return total_vector / array_of_vectors.size()

func get_neighborhood_average(data:MeshDataTool,vertex_index,normal, mesh):
	var neighborhood_edges_indexes =  data.get_vertex_edges(vertex_index)
	var neighborhood_verticies:Array[Vector3] = []
	for edge_index in neighborhood_edges_indexes:
		if(edge_index == -1):
			print("skipped")
		else:
			var edge_vertex_index = data.get_edge_vertex(edge_index,0)
			if(edge_vertex_index == -1):
				print("skipped")
			else:
				var edge_vertex = mesh.to_global(data.get_vertex(edge_vertex_index))
				neighborhood_verticies.push_back(edge_vertex)
	return get_average_of_vectors(neighborhood_verticies)

func get_concave_mix(data:MeshDataTool,vertex_index,normal,mesh):
	pass
	var neighborhood_average =  get_neighborhood_average(data,vertex_index,normal,mesh)
	return normal - neighborhood_average

func get_convex_mix(data,vertex_index,normal,mesh):

	var neighborhood_average =  get_neighborhood_average(data,vertex_index,normal,mesh)
	return neighborhood_average - normal

func build_flat_list_for_mesh(imported_scene,mesh,dirty:bool=false):
	var new_flat_mesh = FlatMesh.new()
	new_flat_mesh.MESH_NAME = mesh.name;
	new_flat_mesh.SCENE_ID = imported_scene.ID
	new_flat_mesh.MESH = mesh;
	new_flat_mesh.SCENE = imported_scene
	var mesh_array:ArrayMesh =  mesh.mesh
	var surface_count =mesh_array.get_surface_count()
	var tools = []
	var surface_names = []
	for surf_index in surface_count:
		var masked = is_masked_by_anything(mesh,surf_index,imported_scene.ID)
		if(masked == false):
			var surf_name = mesh_array.surface_get_name(surf_index)
			surface_names.push_back(surf_name)
			tools.push_back(MeshDataTool.new())
			if(tools.size()-1<surf_index):
				print("ERROR missing tool?")
				return
			var data:MeshDataTool = tools[surf_index]
			data.create_from_surface(mesh_array, surf_index)
			for vertex_index in range(data.get_vertex_count()):
				vert_count+=1
				var edges_touching = data.get_vertex_edges(vertex_index)
				var verts_touching :Array[int]= []
				for edge in edges_touching:
					verts_touching.push_back(edge)
				var normal = data.get_vertex_normal(vertex_index)
				var vertex:Vector3 = mesh.to_global(data.get_vertex(vertex_index))
				var flat_vert: FlatVertex = FlatVertex.new()
				flat_vert.POSITION = vertex
				flat_vert.TOUCHING = verts_touching
				flat_vert.SURFACE_INDEX = surf_index
				flat_vert.VERTEX_INDEX = vertex_index
				flat_vert.SCENE_ID = imported_scene.ID
				flat_vert.MESH_NAME = mesh.name
				flat_vert.SCENE = imported_scene
				flat_vert.MESH= mesh
				flat_vert.NORMAL = normal
				FLAT_LIST.push_back(flat_vert)
				new_flat_mesh.FLAT_VERTS.push_back(flat_vert)
	FLAT_MESHES.push_back(new_flat_mesh)
	if(dirty):
		DIRTY_MESHES.push_back(new_flat_mesh)

func recursivley_update_flat_list_array_for_scene_node(imported_scene,node, number_of_recursions:int = 0):
	number_of_recursions+=1
	if(number_of_recursions>100):	return
	if(node is MeshInstance3D):
		build_flat_list_for_mesh(imported_scene,node)

	else:
		recursivley_update_flat_list_array_for_scene_node(imported_scene, node,number_of_recursions)

func is_vertex_in_close_list_already(vertex,vertex_index,surf_index,imported_scene_id):
	return CLOSE_VERTS.any(func(close_vert:CloseVertex):
		return (vertex_index == close_vert.VERTEX_INDEX &&
			surf_index == close_vert.SURFACE_INDEX &&
			close_vert.SCENE_ID == imported_scene_id) || (
			vertex_index == close_vert.OTHER_VERTEX_INDEX &&
			surf_index == close_vert.OTHER_SURFACE_INDEX &&
			close_vert.OTHER_SCENE_ID == imported_scene_id))


func update_close_verts_array():
	CLOSE_VERTS = []
	for verts_by_light:VertByLightGroup in VERTS_BY_LIGHT_GROUPS:
		if(verts_by_light.LIGHT.LAYER.BLENDING_DIRECTION == LightLayer.BLENDING_DIRECTIONS.FLAT_AO
		|| verts_by_light.LIGHT.LAYER.BLENDING_DIRECTION == LightLayer.BLENDING_DIRECTIONS.AO):
			CLEANED_FLAT_LIST = verts_by_light.FLAT_VERTS.duplicate(true)
			for flat_vert_a in verts_by_light.FLAT_VERTS:
				var closest_distance = INF
				var closest_flat_vert = null
				var closest_dot = 0.0
				for flat_vert_b in CLEANED_FLAT_LIST:
					var continue_with_op =  (
						flat_vert_a.VERTEX_INDEX != flat_vert_b.VERTEX_INDEX
					)
					if(continue_with_op):
						var dist_to_vert = flat_vert_b.POSITION.distance_to(flat_vert_a.POSITION)
						var distance_vector =  flat_vert_b.POSITION - (flat_vert_a.POSITION)
						var facing_each_other =  flat_vert_a.NORMAL.dot(distance_vector.normalized())
						var distance = flat_vert_b.POSITION.distance_to(flat_vert_a.POSITION)
						if( facing_each_other > 0.5 && distance < closest_distance):
							closest_flat_vert = flat_vert_b
							closest_distance = distance
							closest_dot = facing_each_other
				if(closest_flat_vert !=null):
					var close_vert = CloseVertex.new()
					close_vert.DOT = closest_dot
					close_vert.DISTANCE = closest_distance
					close_vert.OTHER_POSITION = closest_flat_vert.POSITION
					close_vert.OTHER_VERTEX_INDEX = closest_flat_vert.VERTEX_INDEX
					close_vert.OTHER_SURFACE_INDEX = closest_flat_vert.SURFACE_INDEX
					close_vert.OTHER_SCENE_ID = closest_flat_vert.SCENE_ID
					close_vert.POSITION = flat_vert_a.POSITION
					close_vert.VERTEX_INDEX = flat_vert_a.VERTEX_INDEX
					close_vert.SURFACE_INDEX = flat_vert_a.SURFACE_INDEX
					close_vert.SCENE_ID= flat_vert_a.SCENE_ID
					CLOSE_VERTS.push_back(close_vert)
					update_CLEANED_FLAT_LIST(flat_vert_a,closest_flat_vert)

func update_CLEANED_FLAT_LIST(flat_vert_a,flat_vert_b):
	if(CLEANED_FLAT_LIST.size()>0):
		var index_of_a = CLEANED_FLAT_LIST.find(flat_vert_a)
		CLEANED_FLAT_LIST.remove_at(index_of_a)

func get_smallest_distance_to_other_verts(surf_index,vertex,scene_id):
	var matching_vertex:CloseVertex;
	COMPLEXITY-=1
	for close_vertex:CloseVertex in CLOSE_VERTS:
		COMPLEXITY+=1
		if(close_vertex.POSITION == vertex &&
			close_vertex.SCENE_ID == scene_id &&
			close_vertex.SURFACE_INDEX == surf_index):
				matching_vertex = close_vertex;
		elif(close_vertex.POSITION == vertex &&
			close_vertex.OTHER_SCENE_ID == scene_id &&
			close_vertex.OTHER_SURFACE_INDEX == surf_index):
				matching_vertex = close_vertex;
	return matching_vertex

func blend_light_into_vertex_colors(
	mesh:MeshInstance3D,
	imported_scene:ImportedScene,
	layer,
	light :VertexLight,
	data,
	vertex,
	vertex_distance,
	vertex_index:int,
	old_color,
	surf_index):
		var normal:Vector3 = data.get_vertex_normal(vertex_index)
		var distance_vector:Vector3 = (vertex - light.LIGHT_MESH.global_position)
		var normalized_distance_vector = distance_vector.normalized()
		var tangent = data.get_vertex_tangent(vertex_index).normal
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
				mix =  light.MIX * linear_distance

		match(layer.BLENDING_DIRECTION):
			LightLayer.BLENDING_DIRECTIONS.EVERYTHING:
				mix =  mix
			LightLayer.BLENDING_DIRECTIONS.AO:
				var concave_mix = get_concave_mix(data,vertex_index,normal,mesh)
				var convex_mix = get_convex_mix(data,vertex_index,normal,mesh)
				var smallest_vert = get_smallest_distance_to_other_verts(surf_index,vertex,imported_scene.ID)
				if(smallest_vert == null):
					mix =  0
				else:
					var smallest_distance_to_other_verts = clamp(1.0/smallest_vert.DISTANCE,0.0,1.0)
					var AO_MIX = clamp(concave_mix - convex_mix + smallest_distance_to_other_verts,0.0,1.0)
					mix *= AO_MIX
			LightLayer.BLENDING_DIRECTIONS.FLAT_AO:
				var smallest_vert:CloseVertex = get_smallest_distance_to_other_verts(surf_index,vertex,imported_scene.ID)
				if(smallest_vert == null):
					mix = 0
				else:
					mix *= clamp(1.0/smallest_vert.DISTANCE,0.0,1.0)
					previous_mix = mix

			LightLayer.BLENDING_DIRECTIONS.CONVEX_EDGES:
				var convex_mix = get_convex_mix(data,vertex_index,normal,mesh)
				mix *= convex_mix
			LightLayer.BLENDING_DIRECTIONS.CONCAVE_EDGES:
				var concave_mix = get_concave_mix(data,vertex_index,normal,mesh)
				mix *= concave_mix
			LightLayer.BLENDING_DIRECTIONS.POINT_LIGHTS:
				var facing_light_mix = 1.0- normal.dot(distance_vector)
				mix *=facing_light_mix
			LightLayer.BLENDING_DIRECTIONS.FACING_UP:
				mix *=normal.y
			LightLayer.BLENDING_DIRECTIONS.FACING_DOWN:
				mix *=(1.0-normal.y)
			LightLayer.BLENDING_DIRECTIONS.INVERTED_POINT_LIGHT:
				var facing_light_mix = normal.dot(distance_vector)
				mix *=facing_light_mix
			LightLayer.BLENDING_DIRECTIONS.DIRECTIONAL:
				var light_direction = (mesh.global_position - light.LIGHT_MESH.global_position).normalized()
				var facing_light_mix =  1.0 - normal.dot(light_direction)
				mix *=facing_light_mix
			LightLayer.BLENDING_DIRECTIONS.INVERSE_DIRECTIONAL:
				var light_direction = (mesh.global_position - light.LIGHT_MESH.global_position).normalized()
				var facing_light_mix = normal.dot(light_direction)
				mix *=facing_light_mix

		data.set_vertex_color(vertex_index,lerp(old_color,mixed_color,mix))

func blend_lights_into_vertex_colors(
	mesh:MeshInstance3D,
	imported_scene:ImportedScene,
	layer,
	light :VertexLight,
	surf_index,
	tools):
		var data:MeshDataTool = tools[surf_index]
		var mesh_array:ArrayMesh = mesh.mesh
		data.create_from_surface(mesh_array, surf_index)
		for vertex_index in range(data.get_vertex_count()):
			var vertex:Vector3 = mesh.to_global(data.get_vertex(vertex_index))
			var vertex_distance:float = vertex.distance_to(light.LIGHT_MESH.global_position)
			if vertex_distance < light.RADIUS:
				var is_masked = is_masked(layer,mesh,surf_index,imported_scene)
				var old_color:Color = data.get_vertex_color(vertex_index)
				if(is_masked==false):
					blend_light_into_vertex_colors(
						mesh,
						imported_scene,
						layer,
						light ,
						data,
						vertex,
						vertex_distance,
						vertex_index,
						old_color,
						surf_index)
				else:
					data.set_vertex_color(vertex_index,old_color)

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

func is_masked_by_anything(mesh,surf,imported_scene_id):
	return DATA.LAYER_MASKS.any(func(layer_mask:LightLayerMask):
						return (
						layer_mask.MESH_NAME == mesh.name &&
						layer_mask.SURFACE_ID == surf &&
						layer_mask.SCENE_ID == imported_scene_id))

func build_FLAT_MESHES():
	var LIGHT_WITH_MESHES = []
	var meshes_to_bake
	var groups
	var stuff_to_bake

	if(DIRTY_MESHES.size()>0):
		stuff_to_bake = DIRTY_MESHES
	else:
		stuff_to_bake = FLAT_MESHES

	for flat_mesh in stuff_to_bake:
		var tools = []
		var surface_names = []
		var mesh_array = flat_mesh.MESH.mesh;
		var surface_count =mesh_array.get_surface_count()
		for surf  in surface_count:
			var surf_name = mesh_array.surface_get_name(surf)
			surface_names.push_back(surf_name)
			var data = MeshDataTool.new()
			tools.insert(surf,data)
			data.create_from_surface(mesh_array,surf)
			for verts_by_light_group:VertByLightGroup in VERTS_BY_LIGHT_GROUPS:
				if(verts_by_light_group.SCENE_ID == flat_mesh.SCENE_ID && verts_by_light_group.MESH_NAME == flat_mesh.MESH_NAME):
					LIGHT_WITH_MESHES.push_back([flat_mesh.SCENE,flat_mesh.MESH,tools,surface_count,surface_names,verts_by_light_group])
	return LIGHT_WITH_MESHES

func bake_FLAT_MESHES(LIGHT_WITH_MESHES):
	var index_= 0
	var _flat_mesh

	for flat_mesh in LIGHT_WITH_MESHES:
		var imported_scene = flat_mesh[0]
		var mesh = flat_mesh[1]
		var mesh_array:ArrayMesh =  flat_mesh[1].mesh
		var tools:Array = flat_mesh[2]
		var surface_count =flat_mesh[3]
		var surface_names = flat_mesh[4]
		var verts_by_light_group:VertByLightGroup = flat_mesh[5]
		var flat_verts = verts_by_light_group.FLAT_VERTS
		var light = verts_by_light_group.LIGHT
		for flat_vert:FlatVertex in flat_verts: #subset of flat-verts for a light
			COMPLEXITY+=1;
			var layer = light.LAYER;
			var is_masked_ = is_masked(layer,mesh,flat_vert.SURFACE_INDEX,imported_scene)
			var data = tools.get(flat_vert.SURFACE_INDEX)
			var old_color:Color = data.get_vertex_color(flat_vert.VERTEX_INDEX)
			if(is_masked_==false):
				blend_light_into_vertex_colors(
					mesh,
					imported_scene,
					layer,
					light ,
					data,
					flat_vert.POSITION,
					flat_vert.POSITION.distance_to(light.LIGHT_MESH.global_position),
					flat_vert.VERTEX_INDEX,
					old_color,
					flat_vert.SURFACE_INDEX)
			else:
				data.set_vertex_color(flat_vert.SURFACE_INDEX,old_color)

func replace_surface_with_new_vertex_colors(LIGHT_WITH_MESHES):
		for flat_mesh in LIGHT_WITH_MESHES:
				var mesh_array:ArrayMesh =  flat_mesh[1].mesh
				var surface_count =flat_mesh[3]
				var tools = flat_mesh[2]
				var mesh = flat_mesh[1]
				var imported_scene = flat_mesh[0]
				var surface_names = flat_mesh[4]
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
				recent_prefab.get_node("Control/IMPORT_BUTTON").connect("pressed",_on_import_file_selected.bind(recent_file.PATH))
				$RECENT_MESHES/ScrollContainer/CONTAINER/RECENTS.add_child(recent_prefab)
			VBRecentFile.VB_FILE_TYPES.EXPORTED:
				recent_prefab.get_node("Control/ICON").hide()
				recent_prefab.get_node("Control/OPEN_BUTTON").hide()
				recent_prefab.get_node("Control/SAVE_BUTTON").hide()
				recent_prefab.get_node("Control/IMPORT_BUTTON").hide()
				recent_prefab.get_node("Control/EXPORT_BUTTON").show()
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
	for child in $DATA_INSPECTOR/ScrollContainer/CONTAINER/DATA.get_children():
		child.queue_free()
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
						light_data.MIX,
						light_data.ID
						)

	for scene:VBSceneData in result.SCENES:
		#p2log(scene.PATH)
		#await WAIT.for_seconds(0)
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
	$RECENT_FILES.size = Vector2(500,40)

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
		$RECENT_SAVES.size = Vector2(500,40)


func _on_export_file_selected(path: String) -> void:
	merge_materials()
	var flat_list_of_mesh
	var gltf_scene_root_node = Node3D.new()
	var tools_for_mesh_with_col = []
	#var tools_for_mesh_without_col = []
	var node_with_col= MeshInstance3D.new()
	#var node_without_col= MeshInstance3D.new()
	node_with_col.mesh = ArrayMesh.new()
	node_with_col.mesh.resource_name = "with-col"
	node_with_col.name = "with-col"
	var scene_index = 0
	for imported_scene:ImportedScene in DATA.SCENES:
		if(imported_scene.EXCLUDE_FROM_EXPORT == false):
			var scene_scale =imported_scene.NODE.scale
			var scene_rotation = imported_scene.SCENE.rotation
			var node_rotation = imported_scene.NODE.rotation
			for child_mesh:MeshInstance3D in imported_scene.SCENE.get_children():
				var count = child_mesh.mesh.get_surface_count()
				var target_scale =scene_scale *child_mesh.scale*imported_scene.SCENE.scale
				for index_ in count:
					tools_for_mesh_with_col.push_back(MeshDataTool.new())
				for index in count:
					var data:MeshDataTool = tools_for_mesh_with_col[index+scene_index]
					data.create_from_surface( child_mesh.mesh, index)
					for i in range(data.get_vertex_count()):
						var vertex = (data.get_vertex(i)*target_scale)
						var normal = data.get_vertex_normal(i)*target_scale
						var z = vertex.rotated(Vector3(0,0,1),scene_rotation.z)
						var x = vertex.rotated(Vector3(1,0,0),scene_rotation.x)
						var y =vertex.rotated(Vector3(0,1,0),scene_rotation.y)
						z = vertex.rotated(Vector3(0,0,1),node_rotation.z)
						x = vertex.rotated(Vector3(1,0,0),node_rotation.x)
						y =vertex.rotated(Vector3(0,1,0),node_rotation.y)
						data.set_vertex_normal(i, normal)
						data.set_vertex(i, z+imported_scene.SCENE.global_position)
						data.set_vertex(i, x+imported_scene.SCENE.global_position)
						data.set_vertex(i, y++imported_scene.SCENE.global_position)
					data.commit_to_surface(node_with_col.mesh 	)
				scene_index+=count
	gltf_scene_root_node.add_child(node_with_col)
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
	FLAT_LIST = []
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
	FLAT_LIST = []
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
	FLAT_LIST = []
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

		var scene_list_item = scene_list_item_prefab.instantiate()
		var scene = gltf_document_load.generate_scene(gltf_state_load)
		var scene_2 = gltf_document_load_2.generate_scene(gltf_state_load_2)
		scene.name = "MESH"
		var imported_scene = ImportedScene.new()
		var node= $SubViewportContainer/SubViewport
		var mesh:SelectableMesh = scene_prefab.instantiate()
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
		mesh.MESH =scene
		mesh.SCENE =imported_scene
		mesh.LIST_ITEM = scene_list_item
		mesh.add_child(scene)
		node.add_child(mesh)
		mesh.scale = imported_scale
		mesh.position = imported_position
		mesh.rotation = imported_rotation
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
var vert_count = 0
func update_flat_list():
	FLAT_LIST = []
	FLAT_MESHES = []
	vert_count =  0

	for imported_scene:ImportedScene in DATA.SCENES:
		if(imported_scene.EXCLUDE_FROM_BAKE == false):
			for child in imported_scene.SCENE.get_children():
				recursivley_update_flat_list_array_for_scene_node(imported_scene, child)

var CHUNK_SIZE=1000

func chunk_flat_list():
	CHUNK_SIZE=1000
	CHUNKS =[]
	for flat_vert:FlatVertex in FLAT_LIST:
		var x:int = roundi(flat_vert.POSITION.x/CHUNK_SIZE)
		var z:int = roundi(flat_vert.POSITION.z/CHUNK_SIZE)
		var existing_chunk_index = CHUNKS.find_custom(func (chunk:Chunk):return (chunk.x == x) && (chunk.z==z),0)
		if(existing_chunk_index==-1):
			var new_chunk:Chunk = Chunk.new()
			new_chunk.x = x
			new_chunk.z =z
			new_chunk.FLAT_VERTS.push_back(flat_vert)
			CHUNKS.push_back(new_chunk)
		else:
			var old_chunk = CHUNKS[existing_chunk_index]
			old_chunk.FLAT_VERTS.push_back(flat_vert)

func get_chunk_for_vertex(vertex):
	var x_:int = roundi(vertex.x/CHUNK_SIZE)
	var z_:int = roundi(vertex.z/CHUNK_SIZE)
	var chunk_index = CHUNKS.find_custom(func(chunk:Chunk):return (chunk.x == x_ && chunk.z == z_),0)
	if(chunk_index == -1):return null
	else:
		return CHUNKS[chunk_index]

func update_vert_by_light_group(layer,light):
		for flat_vert in FLAT_LIST:
			COMPLEXITY+=1;
			var distance = light.LIGHT_MESH.global_position.distance_to(flat_vert.POSITION )
			if(distance < light.RADIUS):
				add_vertex_to_group(layer,light,flat_vert)


func add_vertex_to_group(layer,light,flat_vert:FlatVertex):
	var existing_group_index = VERTS_BY_LIGHT_GROUPS.find_custom(
		func (group:VertByLightGroup): return (
			 group.SCENE_ID == flat_vert.SCENE_ID &&
			 group.MESH_NAME == flat_vert.MESH_NAME &&
			 group.LIGHT.ID == light.ID))
	var existing_group:VertByLightGroup;
	if(existing_group_index == -1):
		existing_group = VertByLightGroup.new()
		existing_group.SCENE_ID = flat_vert.SCENE_ID
		existing_group.MESH_NAME = flat_vert.MESH_NAME
		existing_group.SCENE = flat_vert.SCENE
		existing_group.MESH = flat_vert.MESH
		existing_group.LIGHT = light
		VERTS_BY_LIGHT_GROUPS.push_back(existing_group)
		existing_group.FLAT_VERTS.push_back(flat_vert);
	else:
		existing_group = VERTS_BY_LIGHT_GROUPS[existing_group_index]
		existing_group.FLAT_VERTS.push_back(flat_vert);

func update_verts_by_light_array(has_dirty_lights):
	if(has_dirty_lights && MESH_HAS_MOVED_SINCE_LAST_BAKE == false):

		#OLD_VERTS_BY_LIGHT_GROUPS = VERTS_BY_LIGHT_GROUPS

		#mark groups dirty if mesh is dirty
		for group:VertByLightGroup in VERTS_BY_LIGHT_GROUPS:
			for dirty_mesh:FlatMesh in DIRTY_MESHES:
				if(group.MESH_NAME == dirty_mesh.MESH_NAME && group.SCENE_ID == dirty_mesh.SCENE_ID):
					group.LIGHT.DIRTY_MESHES_NEED_REBAKE = false;
					group.LIGHT.DIRTY_USE_DURING_BAKE = true;

		var DIRTY_MESHES_NEED_REBAKE = []
		var DIRTY_USE_DURING_BAKE = []

		for layer in DATA.LAYERS:
			var lights_ = layer.LIGHTS.filter(func (light:VertexLight):return light.DIRTY_USE_DURING_BAKE == true)
			for light in lights_:
				DIRTY_USE_DURING_BAKE.push_back(light)

			var lights = layer.LIGHTS.filter(func (light:VertexLight):return light.DIRTY_MESHES_NEED_REBAKE == true)
			for light in lights:
				DIRTY_MESHES_NEED_REBAKE.push_back(light)

		for light_for_rendering:VertexLight in DIRTY_USE_DURING_BAKE:
			print("CREATE GROUP FOR LIGHT (ONLY FOR DIRTY MESHES)")
			#for dirty_mesh:FlatMesh in DIRTY_MESHES:
				#if(VERTS_BY_LIGHT_GROUPS.any(func (group):return (
					#group.LIGHT.ID == light_for_rendering.ID &&
					#group.MESH_NAME == dirty_mesh.MESH_NAME &&
					#group.SCENE_ID== dirty_mesh.SCENE_ID))==false):
					#update_vert_by_light_group(light_for_rendering.LAYER,light_for_rendering)

		print("1) VERTS_BY_LIGHT_GROUPS  | %s" % VERTS_BY_LIGHT_GROUPS.size())
		for dirty_vertex_light:VertexLight in DIRTY_MESHES_NEED_REBAKE:
				print("CREATE GROUP FOR DIRTY LIGHT")
				update_vert_by_light_group(dirty_vertex_light.LAYER,dirty_vertex_light)

		print("2) VERTS_BY_LIGHT_GROUPS  | %s" % VERTS_BY_LIGHT_GROUPS.size())
		#for group:VertByLightGroup in VERTS_BY_LIGHT_GROUPS:
			#if(	OLD_VERTS_BY_LIGHT_GROUPS.any(func(old:VertByLightGroup ):return (
				#old.SCENE_ID == group.SCENE_ID &&
				#old.MESH_NAME == group.MESH_NAME &&
				#old.LIGHT.ID == group.LIGHT.ID))==false):
				##OLD_VERTS_BY_LIGHT_GROUPS.push_back(group)
		#print("3) OLD_VERTS_BY_LIGHT_GROUPS | %s" % OLD_VERTS_BY_LIGHT_GROUPS.size())

	else:
		#VERTS_BY_LIGHT = []
		VERTS_BY_LIGHT_GROUPS = []
		#OLD_VERTS_BY_LIGHT_GROUPS = []
		for layer:LightLayer in DATA.LAYERS:
			for light :VertexLight in layer.LIGHTS:
				print("CREATE GROUP FOR LIGHT (CLEAN)")
				update_vert_by_light_group(layer,light)
		#OLD_VERTS_BY_LIGHT_GROUPS = VERTS_BY_LIGHT_GROUPS
#
#func add_lights_new_meshes_to_dirty_list():
		#for layer:LightLayer in DATA.LAYERS:
			#for light :VertexLight in layer.LIGHTS:
				#if(light.DIRTY_MESHES_NEED_REBAKE):
					#update_vert_by_light_group(layer,light)
##
		#for group:VertByLightGroup in VERTS_BY_LIGHT_GROUPS:
				#if(group.LIGHT.DIRTY_MESHES_NEED_REBAKE):
					#mark_meshes_in_group_as_dirty(group)
					#build_flat_list_for_mesh(group.SCENE,group.MESH,true)

var OLD_VERTS_BY_LIGHT_GROUPS:Array[VertByLightGroup] = []

func actually_bake():
	print("============= BAKE START =============")
	print("OG GROUPS| %s" % VERTS_BY_LIGHT_GROUPS.size())
	COMPLEXITY = 0
	var start_time = Time.get_unix_time_from_system()
	var end_time
	$HBoxContainer.visible = false
	$MENU_BUTTON.visible = true;
	var dirty_lights = DATA.LAYERS.filter(
			func (layer:LightLayer):return (layer.LIGHTS.any(
				func (light:VertexLight): return  light.DIRTY_MESHES_NEED_REBAKE == true)))
	var has_dirty_meshes = (DIRTY_MESHES.size()>0);
	var has_dirty_lights = dirty_lights.size() >0
	FULL_BAKE = (FULL_BAKE || MESH_HAS_MOVED_SINCE_LAST_BAKE) # todo remove this
	if( FULL_BAKE == true):
		VERTS_BY_LIGHT_GROUPS = []
	if( FULL_BAKE == true || has_dirty_lights == true || has_dirty_meshes == true ):
		print("1) DIRTY_MESHES (FROM MOVE)| %s" % DIRTY_MESHES.size())
		if((DIRTY_MESHES.size()==0)):
			update_flat_list()
		update_verts_by_light_array(has_dirty_lights )
		update_close_verts_array()
		print("VERTS_BY_LIGHT_GROUPS| %s" % VERTS_BY_LIGHT_GROUPS.size())
		print("FLAT LIST SIZE| %s" % FLAT_LIST.size())
		if(has_dirty_lights==true || has_dirty_meshes == true):
			print("2) BEFORE DIRTY_MESHES (FROM LIGHTS)| %s" % DIRTY_MESHES.size())
			for group:VertByLightGroup in VERTS_BY_LIGHT_GROUPS:
				if(group.LIGHT.DIRTY_MESHES_NEED_REBAKE):
					mark_meshes_in_group_as_dirty(group)
			print("3) AFTER DIRTY_MESHES (FROM LIGHTS)| %s" % DIRTY_MESHES.size())
		print("UPDATE GROUP FUNC COMPLEXITY| %s"%COMPLEXITY)
		reset_meshes(has_dirty_lights == true || has_dirty_meshes == true)
		COMPLEXITY = 0
		update_mesh()
	print("TOTAL DIRTY_MESHES | %s" % DIRTY_MESHES.size())
	print("TOTAL DIRTY LIGHTS | %s" % dirty_lights.size())
	print("TOTAL GROUPS | %s " % VERTS_BY_LIGHT_GROUPS.size())
	print("TOTAL old groups | %s"%OLD_VERTS_BY_LIGHT_GROUPS.size())
	end_time = Time.get_unix_time_from_system() - start_time
	print("BAKE COMPLEXITY | %s"%COMPLEXITY)
	print("BAKE TIME |  %s" % end_time)
	$BAKE.text = ("BAKE")
	$BAKE.release_focus()
	$FULL_BAKE_CHECKBOX.button_pressed = false;
	$FULL_BAKE_CHECKBOX.disabled = false;
	FULL_BAKE = false
	BAKED = true
	MESH_HAS_MOVED_SINCE_LAST_BAKE = false;
	DIRTY_MESHES = []
	for layer in DATA.LAYERS:
		for light in layer.LIGHTS:
			light.DIRTY_MESHES_NEED_REBAKE = false
			light.DIRTY_USE_DURING_BAKE = false

func update_mesh() -> void:
	# LIGHT_WITH_MESHES : [SCENE, MESH, tools, surface_count, surface_names, verts_by_light_group]
	var LIGHT_WITH_MESHES = build_FLAT_MESHES()
	print("LIGHT_WITH_MESHES | %s" % LIGHT_WITH_MESHES.size())
	bake_FLAT_MESHES(LIGHT_WITH_MESHES)
	replace_surface_with_new_vertex_colors(LIGHT_WITH_MESHES)

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
	p2log("_on_gizmo_3d_transform_begin |PRESS SPACEBAR TO DESELECT")
	disable_collision_shapes()
	mark_current_light_as_dirty()

func mark_current_light_as_dirty():
	if(CURRENT_LIGHT != null && BAKED == true):
		print("mark_current_light_as_dirty")
		CURRENT_LIGHT.DIRTY_MESHES_NEED_REBAKE = true
		#var groups_affected_by_move = VERTS_BY_LIGHT_GROUPS.filter(func(group:VertByLightGroup):return(
				#CURRENT_LIGHT.ID == group.LIGHT.ID
			#));
		#if(groups_affected_by_move.size()==0):
			#print(" OF %s groups, NO GROUPS FOR THIS LIGHT - CREATE ONE" % VERTS_BY_LIGHT_GROUPS.size() )
			##build_flat_list_for_mesh(flat_mesh.SCENE,flat_mesh.MESH)
			#update_vert_by_light_group(CURRENT_LIGHT.LAYER,CURRENT_LIGHT)
			#print("%s groups" % VERTS_BY_LIGHT_GROUPS.size() )
#
		#else:
			#print(" GROUPS FOUND FOR THIS LIGHT ALREADY |DIRTY MESHES | %s" % DIRTY_MESHES.size())
			#for group in groups_affected_by_move:
				#mark_mesh_as_dirty(group.SCENE_ID,group.MESH_NAME)
			#print("DIRTY MESHES | %s" % DIRTY_MESHES.size())

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

var MESH_HAS_MOVED_SINCE_LAST_BAKE = false

func _on_gizmo_3d_transform_end(mode: Gizmo3D.TransformMode) -> void:
	print("_on_gizmo_3d_transform_end | BAKED %s" % BAKED)
	if(CURRENT_LIGHT != null && BAKED == true):
		CURRENT_LIGHT.DIRTY_MESHES_NEED_REBAKE = true;

		var groups_affected_by_move = VERTS_BY_LIGHT_GROUPS.filter(func(group:VertByLightGroup):return(
			CURRENT_LIGHT.ID == group.LIGHT.ID
		));
		if(groups_affected_by_move!=null && groups_affected_by_move.size()>0):
			print("mark affected meshes in groups as dirty")
			print("BEFORE | DIRTY MESHES | %s" % DIRTY_MESHES.size())
			print("BEFORE | VERTS_BY_LIGHT_GROUPS | %s" % VERTS_BY_LIGHT_GROUPS.size())
			for group:VertByLightGroup in groups_affected_by_move:
				mark_meshes_in_group_as_dirty(group)
				VERTS_BY_LIGHT_GROUPS = swap_n_remove(group,VERTS_BY_LIGHT_GROUPS) # faster?\
			print("AFTER | DIRTY MESHES | %s" % DIRTY_MESHES.size())
			print("AFTER | VERTS_BY_LIGHT_GROUPS | %s" % VERTS_BY_LIGHT_GROUPS.size())
		#else:
			#print("missing vert groups")
			#print("BEFORE | DIRTY MESHES | %s" % DIRTY_MESHES.size())
			#print("BEFORE | VERTS_BY_LIGHT_GROUPS | %s" % VERTS_BY_LIGHT_GROUPS.size())
			#update_vert_by_light_group(CURRENT_LIGHT.LAYER,CURRENT_LIGHT)
			#var new_groups = VERTS_BY_LIGHT_GROUPS.filter(func(group:VertByLightGroup):return(
				#CURRENT_LIGHT.ID == group.LIGHT.ID
			#));
			#print("... | new_groups | %s" % new_groups.size())
			#for group:VertByLightGroup in new_groups:
				#mark_meshes_in_group_as_dirty(group)
				#VERTS_BY_LIGHT_GROUPS = swap_n_remove(group,VERTS_BY_LIGHT_GROUPS) # faster?\
			#print("AFTER | DIRTY MESHES | %s" % DIRTY_MESHES.size())
			#print("AFTER | VERTS_BY_LIGHT_GROUPS | %s" % VERTS_BY_LIGHT_GROUPS.size())
	if(CURRENT_LIGHT != null ):
		if(mode == Gizmo3D.TransformMode.SCALE):
			var mesh:MeshInstance3D = CURRENT_LIGHT.LIGHT_MESH.get_node("MeshInstance3D")
			mesh.scale = Vector3.ONE *CURRENT_LIGHT.RADIUS;
			CURRENT_LIGHT.LIGHT_MESH.scale =Vector3.ONE
			CURRENT_LIGHT.LIST_ITEM.get_node("VBoxContainer/RADIUS_CONTAINER/SpinBox").value = 	CURRENT_LIGHT.RADIUS
	if(CURRENT_MESH != null&& BAKED == true):
		MESH_HAS_MOVED_SINCE_LAST_BAKE = true;
		mark_mesh_as_dirty(CURRENT_MESH.SCENE.ID,CURRENT_MESH.MESH.name)
	$HBoxContainer.visible = false
	$MENU_BUTTON.visible = true;
	auto_bake()

func swap_n_remove(obj,a:Array)->Array:
	var group_index = a.find(obj)
	var size_ = a.size()
	a = swapi(group_index,size_-1,a)
	a.resize(size_-1)
	print("swap n remove | New array size | %s" % a.size())
	return a

func swap(obja , objb, a : Array) -> Array:
	var i = a.find(obja)
	var j = a.find(objb)
	var t = a[i]
	a[i] = a[j]
	a[j] = t
	return a

func swapi(i , j, a : Array) -> Array:
	var t = a[i]
	a[i] = a[j]
	a[j] = t
	return a

func _on_menu_button_pressed() -> void:
	$HBoxContainer.visible = true
	$MENU_BUTTON.visible = false;

func _on_reset_pressed() -> void:
	BAKED = false
	reset_meshes(false)

func reset_mesh(mesh,scene):
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

func reset_meshes(has_dirty):
	if(has_dirty == true):
		print("resetting DIRTY_MESHES | %s" % DIRTY_MESHES.size())
		for dirty_mesh:FlatMesh in DIRTY_MESHES:
			reset_mesh(dirty_mesh.MESH,dirty_mesh.SCENE)
	else:
		print("resetting ALL meshes ")

		for scene in DATA.SCENES:
			if(scene.EXCLUDE_FROM_BAKE):continue
			for mesh:MeshInstance3D in scene.SCENE.get_children():
				#TODO not recursive! Make this recurse to be sure it clears everything
				if(mesh is MeshInstance3D):
					reset_mesh(mesh,scene)
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
	print(str)
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

func bake_scale_and_rotation(group) -> void:
	if(BAKE_SCALE_ON_EXPORT || BAKE_ROTATION_ON_EXPORT):
		for imported_scene:ImportedScene in DATA.SCENES:
				var scene_scale =imported_scene.NODE.scale
				var scene_rotation = imported_scene.SCENE.rotation
				var node_rotation = imported_scene.NODE.rotation
				for child_mesh in imported_scene.SCENE.get_children():
					var target_scale =scene_scale *child_mesh.scale*imported_scene.SCENE.scale
					if(BAKE_SCALE_ON_EXPORT):
						scale_mesh(child_mesh,target_scale)
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

func _on_bake_rotation_export_toggled(toggled_on: bool) -> void:
	BAKE_ROTATION_ON_EXPORT = toggled_on

func _on_normalize_scale_on_export_toggled(toggled_on: bool) -> void:
	BAKE_SCALE_ON_EXPORT= toggled_on

var last_id_offset=0

func generate_id():

	var new_id = ceili(Time.get_unix_time_from_system()*100)
	last_id_offset+=1
	return new_id+last_id_offset

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

func _on_collapse_all_pressed() -> void:
	for child in $MESH_INSPECTOR/ScrollContainer/CONTAINER/MESHES.get_children():
		child.get_node("ICON/EXPAND").close()

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
		$RECENT_SAVES.hide()
	else:
		$PALETTE_INSPECTOR.show()
		$REPLACEMENT_MATERIALS.show()
		$LAYER_INSPECTOR.show()
		$MATERIAL_INSPECTOR.show()
		$MESH_INSPECTOR.show()
		$DATA_INSPECTOR.show()
		$RECENT_FILES.show()
		$RECENT_MESHES.show()
		$RECENT_SAVES.show()
		$RECENT_TEXTURES.show()

func _on_full_bake_checkbox_toggled(toggled_on: bool) -> void:
	FULL_BAKE = toggled_on

func select_light(node:SelectableLight):
	CURRENT_LIGHT = node.LIGHT
	CURRENT_MESH = null
	node.LIST_ITEM.grab_focus()
	var texture:TextureRect =node.LIST_ITEM.get_node("VBoxContainer/LIGHT_NAME/TextureRect")
	texture.self_modulate = Color(1,1,1,1)
	if(last_light_texture !=null):
		last_light_texture.self_modulate = Color(1,1,1,0.2)
	last_light_texture = texture;

func select_mesh(node:SelectableMesh):
	CURRENT_MESH = node
	CURRENT_LIGHT = null
	node.LIST_ITEM.get_node("ICON/EXPAND").open()
	node.LIST_ITEM.grab_focus()
	var texture:TextureRect =node.LIST_ITEM.get_node("ICON/TextureRect")
	texture.self_modulate = Color(1,1,1,1)
	if(last_mesh_texture !=null):
		last_mesh_texture.self_modulate = Color(1,1,1,0.2)
	last_mesh_texture = texture;

func mark_meshes_in_group_as_dirty(verts_by_light_group:VertByLightGroup):
	if(DIRTY_MESHES.any(func(flat_mesh:FlatMesh):return (
		flat_mesh.SCENE_ID == verts_by_light_group.SCENE_ID &&
	 	flat_mesh.MESH_NAME == verts_by_light_group.MESH_NAME))==false):
			mark_mesh_as_dirty(verts_by_light_group.SCENE_ID,verts_by_light_group.MESH_NAME)

func mark_mesh_as_dirty(SCENE_ID,MESH_NAME):
	var flat_mesh_index = FLAT_MESHES.find_custom(func (flat_mesh:FlatMesh):return(
				flat_mesh.SCENE_ID ==SCENE_ID &&
				flat_mesh.MESH_NAME == MESH_NAME ))
	if(flat_mesh_index!=-1):
		var flat_mesh = FLAT_MESHES[flat_mesh_index]
		DIRTY_MESHES.push_back(flat_mesh)
	#print("DIRTY_MESHES %s" % DIRTY_MESHES.size())
