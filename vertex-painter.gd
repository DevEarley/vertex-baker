extends Control
class_name VertexBakerMainWindow
var MOVING_WINDOW = false
var layer_prefab = preload("res://layer_prefab.tscn")
var light_prefab = preload("res://light_prefab.tscn")
var mesh_list_item_prefab = preload("res://list_item_mesh_prefab.tscn")
var scene_list_item_prefab = preload("res://list_item_scene_prefab.tscn")
var surface_list_item_prefab = preload("res://list_item_surface_prefab.tscn")
var material_list_item_prefab = preload("res://list_item_material_prefab.tscn")
var material_override_list_item_prefab = preload("res://list_item_material_override_prefab.tscn")
var light_mesh = preload("res://light_mesh_prefab.tscn")
var imported_mesh_prefab = preload("res://imported_mesh_prefab.tscn")
var scene_prefab = preload("res://scene_prefab.tscn")
var surface_prefab = preload("res://surface_prefab.tscn")

@export var gizmo : Gizmo3D
enum OVERRIDE_MATERIALS {
	DEFAULT = 0,
	WATER = 1,
	WATER_FLOW = 2,
	WINDY = 3,
	GLASS = 4
	}
@export var DEFAULT_MATERIAL:Material
@export var WATER_MATERIAL:Material
@export var WATER_FLOW_MATERIAL:Material
@export var WINDY_MATERIAL:Material
@export var GLASS_MATERIAL:Material

var OG_MESH
var brush_hardness = 1.0
var calculated_size:float = 5.0
var PREVIOUS_COLOR:Color = Color.WHITE
var LIGHT_SPHERES_ON = true

var CURRENT_WINDOW:WindowMover

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
	imported_id:int=-1) -> void:
	$HBoxContainer.visible = false
	$MENU_BUTTON.visible = true;
	var layer:LightLayer = LightLayer.new()
	layer.LIGHTS = []
	layer.BLENDING_METHOD = blending_method
	if(imported_id == -1):
		layer.ID = Time.get_unix_time_from_system()
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
	var delete_button  = new_layer.get_node("NAME/MORE_MENU/DELETE")
	var blending_dropdown:OptionButton  = new_layer.get_node("NAME/BLENDING_METHOD")
	var name_label  = new_layer.get_node("NAME")
	name_label.text = layer.NAME
	button.connect("pressed",on_add_light_to_layer.bind(new_layer,layer))
	delete_button.connect("pressed",on_delete_layer_pressed.bind(new_layer,layer))
	blending_dropdown.select(layer.BLENDING_METHOD)
	blending_dropdown.connect("pressed",on_blending_method_dropdown_pressed.bind(layer))
	blending_dropdown.connect("item_selected",on_blending_method_dropdown_selected)

var CURRENT_LAYER:LightLayer = null

func on_blending_method_dropdown_selected(index:int):
	if(CURRENT_LAYER != null):
		CURRENT_LAYER.BLENDING_METHOD = index
	_on_bake_pressed()

func on_blending_method_dropdown_pressed(light_layer:LightLayer):
		CURRENT_LAYER = light_layer

func on_delete_layer_pressed(layer:Control,light_layer:LightLayer):
	var index_to_remove = DATA.LAYERS.find(light_layer)
	#remove all of the lights
	for light in light_layer.LIGHTS:
		on_delete_light(light)
	#remove from UI
	light_layer.LIST_ITEM.queue_free()
	DATA.LAYERS.remove_at(index_to_remove)
	_on_bake_pressed()

func on_add_light_to_layer(
	layer:Control,light_layer:LightLayer,
	imported_position:Vector3=Vector3.ZERO,
	imported_color:Color= Color.WHITE,
	imported_radius:float=1.0,
	imported_mix:float=1.0):
	var light = VertexLight.new()
	#var actual_light = OmniLight3D.new()
	light.COLOR = imported_color
	light.LIGHT_MESH = light_mesh.instantiate()
	#light.LIGHT_MESH.add_child(actual_light)
	light.LIGHT_MESH.position = imported_position
	var mesh:MeshInstance3D = light.LIGHT_MESH.get_node("MeshInstance3D")
	mesh.visible = LIGHT_SPHERES_ON;
	mesh.scale = Vector3.ONE *imported_radius;
	#light.ACTUAL_LIGHT = actual_light;
	#light.ACTUAL_LIGHT.omni_range = imported_radius;
	#light.ACTUAL_LIGHT.light_color =light.COLOR;
	light.LIGHT_MESH.modulate = light.COLOR
	light.RADIUS = imported_radius
	light.LAYER = light_layer
	light.PARENT_LAYER_ID = light_layer.ID
	#if(imported_mix ==0):
		#light.ACTUAL_LIGHT.hide()
	#else:
		#light.ACTUAL_LIGHT.show()

	#light.ACTUAL_LIGHT.omni_attenuation =2-imported_mix;
	light.MIX = imported_mix
	#light.LAYER = light_layer.LIGHTS.size()
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
	_on_bake_pressed()

var CURRENT_LIGHT: VertexLight= null

func on_scale_light_pressed(light:VertexLight):
	gizmo.clear_selection()
	CURRENT_LIGHT = light
	gizmo.mode = Gizmo3D.ToolMode.SCALE
	gizmo.select(light.LIGHT_MESH)
	_on_bake_pressed()

func on_radius_value_changed(value:float,light:VertexLight,radius:SpinBox):
	light.RADIUS = value

	#light.ACTUAL_LIGHT.omni_range = value;
	var mesh:MeshInstance3D = light.LIGHT_MESH.get_node("MeshInstance3D")
	mesh.scale = Vector3.ONE *value;
	_on_bake_pressed()

func on_color_picker_changed(color:Color,light:VertexLight,color_button:ColorPickerButton):
	light.COLOR = color_button.color;
	#light.ACTUAL_LIGHT.light_color =light.COLOR;
	light.LIGHT_MESH.modulate = light.COLOR
	PREVIOUS_COLOR = light.COLOR
	_on_bake_pressed()

func on_mix_value_changed(value:float,light:VertexLight,mix:SpinBox):
	light.MIX = value
	#if(value ==0):
		#light.ACTUAL_LIGHT.hide()
	#else:
		#light.ACTUAL_LIGHT.show()

	#light.ACTUAL_LIGHT.omni_attenuation =2-value;
	_on_bake_pressed()


func on_duplicate_light(light:VertexLight):
	on_add_light_to_layer(light.LAYER.LIST_ITEM,
		light.LAYER,
		light.LIGHT_MESH.global_position,
		light.COLOR,
		light.RADIUS,
		light.MIX)

func on_move_light(light:VertexLight):
	gizmo.clear_selection()
	gizmo.mode = Gizmo3D.ToolMode.MOVE
	gizmo.select(light.LIGHT_MESH)

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
	light,
	index,
	tools):
	var is_masked = DATA.LAYER_MASKS.any(func(layer_mask:LightLayerMask):
						return (layer_mask.LAYER_ID == layer.ID &&
						layer_mask.MESH_NAME == mesh.name &&
						layer_mask.SURFACE_ID == index &&
						layer_mask.SCENE_ID == imported_scene.ID))

	var data:MeshDataTool = tools[index-1]
	data.create_from_surface(mesh.mesh, index)
	if(is_masked == false):
		for i in range(data.get_vertex_count()):
			var vertex = mesh.to_global(data.get_vertex(i))
			var vertex_distance:float = vertex.distance_to(light.LIGHT_MESH.global_position)
			if vertex_distance < light.RADIUS:
				var linear_distance = 1 - (vertex_distance / (light.RADIUS))
				var old_color:Color = data.get_vertex_color(i)
				var new_color:Color = light.COLOR
				var mixed_color:Color = light.COLOR
				var mix = 1.0
				match(layer.BLENDING_METHOD):

					LightLayer.BLENDING_METHODS.MIN:
						var max_r = minf(old_color.r,new_color.r)
						var max_g = minf(old_color.g,new_color.g)
						var max_b = minf(old_color.b,new_color.b)
						mix = light.MIX*linear_distance

					LightLayer.BLENDING_METHODS.MAX:
						var max_r = maxf(old_color.r,new_color.r)
						var max_g = maxf(old_color.g,new_color.g)
						var max_b = maxf(old_color.b,new_color.b)
						mix = light.MIX*linear_distance

					LightLayer.BLENDING_METHODS.DIVIDE:
						mixed_color = Color(
							old_color.r/(new_color.r+0.001),
							old_color.g/(new_color.g+0.001),
							old_color.b/(new_color.b+0.001))
						mix = light.MIX*linear_distance

					LightLayer.BLENDING_METHODS.MULTIPLY,LightLayer.BLENDING_METHODS.DEFAULT:

						mixed_color = Color(old_color.r*new_color.r,old_color.g*new_color.g,old_color.b*new_color.b)
						mix = light.MIX*linear_distance

					LightLayer.BLENDING_METHODS.ADD:
						var clamped_r = clamp(old_color.r+new_color.r,0,1)
						var clamped_g = clamp(old_color.g+new_color.g,0,1)
						var clamped_b = clamp(old_color.b+new_color.b,0,1)
						mixed_color = Color(clamped_r,clamped_g,clamped_b)

						mix = light.MIX*linear_distance

					LightLayer.BLENDING_METHODS.MIX:
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
						mix = light.MIX*linear_distance

					LightLayer.BLENDING_METHODS.MIN_FLAT:
						var max_r = minf(old_color.r,new_color.r)
						var max_g = minf(old_color.g,new_color.g)
						var max_b = minf(old_color.b,new_color.b)
						mix = light.MIX

					LightLayer.BLENDING_METHODS.MAX_FLAT:
						var max_r = maxf(old_color.r,new_color.r)
						var max_g = maxf(old_color.g,new_color.g)
						var max_b = maxf(old_color.b,new_color.b)
						mix = light.MIX

					LightLayer.BLENDING_METHODS.DIVIDE_FLAT:
						mixed_color = Color(
							old_color.r/(new_color.r+0.001),
							old_color.g/(new_color.g+0.001),
							old_color.b/(new_color.b+0.001))
						mix = light.MIX

					LightLayer.BLENDING_METHODS.MULTIPLY_FLAT:
						mixed_color = Color(old_color.r*new_color.r,old_color.g*new_color.g,old_color.b*new_color.b)
						mix = light.MIX

					LightLayer.BLENDING_METHODS.SUBTRACT_FLAT:
						var clamped_r = clamp(old_color.r-new_color.r,0,1)
						var clamped_g = clamp(old_color.g-new_color.g,0,1)
						var clamped_b = clamp(old_color.b-new_color.b,0,1)
						mixed_color = Color(clamped_r,clamped_g,clamped_b)
						mix = light.MIX
				data.set_vertex_color(i,lerp(old_color,mixed_color,mix))


func update_mesh(mesh:MeshInstance3D, imported_scene:ImportedScene) -> void:
		var surface_count =mesh.mesh.get_surface_count()
		var tools = []
		for index in surface_count:
			tools.push_back(MeshDataTool.new())
		for layer in DATA.LAYERS:
			for light in layer.LIGHTS:
				for index in surface_count:
					blend_lights_into_vertex_colors(
						mesh,
						imported_scene,
						layer,
						light,
						index,
						tools)
				var mesh_:Mesh = mesh.mesh;
				mesh_.clear_surfaces()
				for index in surface_count:
					var data = tools[index-1]
					data.commit_to_surface(mesh.mesh)


func _on_open_file_selected(path: String) -> void:
	var result:VBData;
	if ResourceLoader.exists(path):
		result =  load(path)
	else:
		return

	for vb_material_override:VBMaterialOverride in result.MATERIAL_OVERRIDES:
		var material_override:MaterialOverride = MaterialOverride.new()
		material_override.MATERIAL_NAME = vb_material_override.MATERIAL_NAME
		material_override.OVERRIDE_ID = vb_material_override.OVERRIDE_ID
		DATA.MATERIAL_OVERRIDES.push_back(material_override)


	for layer_mask_data:VBLayerMaskData in result.LAYER_MASKS:
		var layer_mask:LightLayerMask = LightLayerMask.new()
		layer_mask.LAYER_ID = layer_mask_data.LAYER_ID
		layer_mask.MESH_NAME = layer_mask_data.MESH_NAME
		layer_mask.SCENE_ID = layer_mask_data.SCENE_ID
		layer_mask.SURFACE_ID = layer_mask_data.SURFACE_ID
		DATA.LAYER_MASKS.push_back(layer_mask)
	for layer_data:VBLayerData in result.LAYERS:
		_on_add_layer_pressed(layer_data.NAME,layer_data.BLENDING_METHOD,layer_data.ID)
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
		print(scene.PATH)
		load_from_path(scene.PATH, scene.POSITION,scene.ROTATION,scene.SCALE,scene.ID)
	_on_bake_pressed()

	for override in DATA.MATERIAL_OVERRIDES:
		for scene in DATA.SCENES:
			for child in scene.SCENE.get_children():
				recursively_apply_material_to_scene(
					scene,
					child,
					override.OVERRIDE_ID,
					override.MATERIAL_NAME);

func _on_save_file_selected(path: String) -> void:
	var data = DATA.to_project_data();
	var err=ResourceSaver.save(data,path,ResourceSaver.FLAG_NONE)
	if(err != OK):
			print("uh oh: %s" % err)
	else:
		print("ok")

func _on_export_file_selected(path: String) -> void:
	var gltf_scene_root_node = Node3D.new()
	for imported_scene:ImportedScene in DATA.SCENES:
		for child_mesh in imported_scene.SCENE.get_children():
			child_mesh.reparent(gltf_scene_root_node)
	var gltf_document_save := GLTFDocument.new()
	var gltf_state_save := GLTFState.new()
	gltf_document_save.append_from_scene(gltf_scene_root_node, gltf_state_save)
	gltf_document_save.write_to_filesystem(gltf_state_save, path)

func _on_import_file_selected(path: String) -> void:
	load_from_path(path)

func on_rotate_pressed(node):
	gizmo.clear_selection()
	gizmo.mode = Gizmo3D.ToolMode.ROTATE
	gizmo.select(node)

func on_scale_pressed(node):
	gizmo.clear_selection()
	gizmo.mode = Gizmo3D.ToolMode.SCALE
	gizmo.select(node)

func on_move_scene_pressed(node):
	gizmo.clear_selection()
	gizmo.mode = Gizmo3D.ToolMode.MOVE
	gizmo.select(node)

func on_scale_changed(node,scene_list_item):
	gizmo.clear_selection()
	var value = scene_list_item.get_node("HBoxContainer/SCALE_VALUE").text
	node.scale = Vector3.ONE * float(value)

func on_scale_value_changed(value,mesh):
	print(value)
	mesh.scale = Vector3.ONE * float(value)

func on_focus():
	$MESH_INSPECTOR.unfocusable =false;
var max_recursion = 100

func on_assign_layers_to_mesh_pressed(
	mesh_list_item:VBoxContainer,
	imported_scene:ImportedScene,
	child_mesh:MeshInstance3D,
	surface:int):
	print("on_assign_layers_to_mesh_pressed")
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
	print("on_assign_layers_to_mesh_done")
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
			var index_to_remove = DATA.LAYER_MASKS.find(light_layer)
			DATA.LAYER_MASKS.remove_at(index_to_remove)
	_on_bake_pressed()

func on_assign_layer_mask_state_changed(index:int,
	mesh_list_item:VBoxContainer,
	imported_scene:ImportedScene,
	child_mesh:MeshInstance3D,
	surface:int):
	print("on_assign_layer_mask_state_changed")

	var assign_layers:MenuButton = mesh_list_item.get_node("ICON/ASSIGN_LAYERS")
	var popup_menu:PopupMenu = assign_layers.get_popup()
	var item_is_checked = popup_menu.is_item_checked(index)
	popup_menu.set_item_checked(index,!item_is_checked)

func load_mesh(child_mesh,scene_list_item, recursion,imported_scene, imported_scale:Vector3=Vector3.ONE):
	print("load_mesh")

	if(child_mesh is MeshInstance3D):
		var mesh_list_item = mesh_list_item_prefab.instantiate()
		mesh_list_item.get_node("ICON/NAME").text = child_mesh.name
		scene_list_item.get_node("VBoxContainer/MESHES").add_child(mesh_list_item)
		for surface in child_mesh.mesh.get_surface_count():
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
			var material:Material = child_mesh.get_active_material(surface)
			var material_list_item = material_list_item_prefab.instantiate()
			var imported_material = ImportedMaterial.new()
			imported_material.SCENE = imported_scene
			imported_scene.MATERIALS.push_back(imported_material)
			imported_material.MATERIAL = material
			imported_material.NAME = material.resource_name
			imported_material.LIST_ITEM = material_list_item;
			DATA.MATERIALS.push_back(imported_material)
			material_list_item.get_node("ICON/NAME").text = material.resource_name
			surface_list_item.get_node("VBoxContainer/MATERIALS").add_child(material_list_item)
	elif(child_mesh is Node3D && child_mesh.get_children().size()>0):
				for grand_child_mesh in child_mesh.get_children():
					print("grand-child | level %s" % recursion)
					recursion+=1;
					if(recursion>max_recursion):
						print("ERR too much recursion in this mesh")
						return
					load_mesh(grand_child_mesh,scene_list_item,imported_scene,recursion)

func on_duplicated_pressed(imported_scene:ImportedScene):
	load_from_path(
		imported_scene.PATH,
		imported_scene.SCENE.global_position,
		imported_scene.SCENE.rotation,
		imported_scene.SCENE.scale)

func on_bake_toggle_pressed(imported_scene:ImportedScene):
	var check_box:CheckBox = imported_scene.LIST_ITEM.get_node("HBoxContainer/BAKE");
	imported_scene.EXCLUDE = !check_box.button_pressed
	if(imported_scene.EXCLUDE==true):
		imported_scene.LIST_ITEM.get_node("ICON/ICON_NO_BAKE").show()
	elif(imported_scene.EXCLUDE==false):
		imported_scene.LIST_ITEM.get_node("ICON/ICON_NO_BAKE").hide()

func on_delete_light(light:VertexLight):
	_on_reset_pressed()
	gizmo.clear_selection()

	var index = 	light.LAYER.LIGHTS.find(light)
	light.LIGHT_MESH.queue_free()
	light.LIST_ITEM.queue_free()
	var lights = light.LAYER.LIGHTS
	lights.remove_at(index)
	_on_bake_pressed()


func on_delete_scene_pressed(imported_scene:ImportedScene):
	_on_reset_pressed()
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
	print("load_from_current_path")

	var gltf_state_load = GLTFState.new()
	var gltf_state_load_2 = GLTFState.new()
	var gltf_document_load_2 = GLTFDocument.new()
	var gltf_document_load = GLTFDocument.new()
	var error = gltf_document_load.append_from_file(path, gltf_state_load)
	var error_2 = gltf_document_load_2.append_from_file(path, gltf_state_load_2)
	var file:FileAccess = FileAccess.open(path, FileAccess.READ_WRITE)
	if error == OK:
		var scene = gltf_document_load.generate_scene(gltf_state_load)
		var scene_2 = gltf_document_load_2.generate_scene(gltf_state_load_2)
		scene.name = "MESH"
		var imported_scene = ImportedScene.new()
		var node= $SubViewportContainer/SubViewport
		var mesh = scene_prefab.instantiate()
		imported_scene.NODE = mesh;
		imported_scene.SCENE = scene;
		imported_scene.IMPORTED_POSITION = imported_position
		imported_scene.IMPORTED_ROTATION = imported_rotation
		imported_scene.PATH = path
		imported_scene.OG_SCENE = scene_2;
		if(imported_ID==-1):
			imported_scene.ID = Time.get_unix_time_from_system()
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
		scene_list_item.get_node("HBoxContainer/SCALE_VALUE").connect("mouse_entered",on_focus)
		scene_list_item.get_node("HBoxContainer/SCALE_VALUE").connect("text_submitted",on_scale_value_changed.bind(mesh))
		scene_list_item.get_node("HBoxContainer/SCALE_VALUE").connect("focus_exited",on_scale_changed.bind(mesh,scene_list_item))
		imported_scene.NAME = mesh.name
		DATA.SCENES.push_back(imported_scene)
		scene_list_item.get_node("ICON/NAME").text = path
		$MESH_INSPECTOR/ScrollContainer/CONTAINER/MESHES.add_child(scene_list_item)

		for child_mesh in scene.get_children():
			load_mesh(child_mesh,scene_list_item,0,imported_scene)
		update_material_inspector()
	else:
		print("Couldn't load glTF scene (error code: %s)." % error_string(error))

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
		material_list_item.get_node("VBoxContainer/SHADER_OPTIONS").connect(
			"toggled",on_toggle_shader_options.bind(material_list_item,mat[0]))
		material_list_item.get_node("VBoxContainer/SHADER_OPTIONS").connect(
			"item_selected",on_select_shader_option.bind(material_list_item,mat[0]))
		$MATERIAL_INSPECTOR/ScrollContainer/CONTAINER/MATERIALS.add_child(material_list_item)

func recursively_apply_material_to_scene(scene:ImportedScene,
	child:Node3D,
	override_material_index:int,
	material_name:String,
	recursive_index:int=0):
	var recursive_max = 100;
	if(recursive_index>recursive_max):
		return;
	if(child is MeshInstance3D):
		for surface in child.mesh.get_surface_count():
			var surface_material = child.mesh.surface_get_material(surface)
			if(surface_material.resource_name == material_name):
				child.set_surface_override_material(surface,null)
				var new_material:Material = get_material_for_override_id(override_material_index)
				if(override_material_index== 0):
					child.set_surface_override_material(surface,null)
				else:
					child.set_surface_override_material(surface,new_material)
	else:
		recursive_index+=1;
		for grand_child in child.get_children():
			recursively_apply_material_to_scene(scene, child,override_material_index,material_name,recursive_index)


func get_material_for_override_id(override_material_index:int):
	match(override_material_index):
		OVERRIDE_MATERIALS.DEFAULT:
			return DEFAULT_MATERIAL
		OVERRIDE_MATERIALS.WATER:
			return WATER_MATERIAL
		OVERRIDE_MATERIALS.WINDY:
			return WINDY_MATERIAL
		OVERRIDE_MATERIALS.GLASS:
			return GLASS_MATERIAL
		OVERRIDE_MATERIALS.WATER_FLOW:
			return WATER_FLOW_MATERIAL

func on_select_shader_option(index:int,material_list_item:VBoxContainer,mat_name:String):
	var matching_override = DATA.MATERIAL_OVERRIDES.filter(func (mat_override:MaterialOverride):
			return mat_override.MATERIAL_NAME== mat_name;)
	if(matching_override!=null && matching_override.size()>0):
		matching_override[0].OVERRIDE_ID = index;
	else:
		var new_mat_override:MaterialOverride = MaterialOverride.new()
		new_mat_override.MATERIAL_NAME = mat_name;
		new_mat_override.OVERRIDE_ID = index;

		DATA.MATERIAL_OVERRIDES.push_back(new_mat_override)
	for scene in DATA.SCENES:
		for child in scene.SCENE.get_children():
			recursively_apply_material_to_scene(scene,child,index,mat_name);
func on_toggle_shader_options(toggled_on:bool,material_list_item:VBoxContainer,mat_name:String):
	if(toggled_on):
		var mat_override = DATA.MATERIAL_OVERRIDES.filter(func (mat_override:MaterialOverride):
			return mat_override.MATERIAL_NAME== mat_name;)
		var options:OptionButton = material_list_item.get_node("VBoxContainer/SHADER_OPTIONS");
		if(mat_override!=null && mat_override.size()>0):
			options.select(mat_override[0].OVERRIDE_ID)
		else:
			options.select(-1)


var baking_timer:Timer
func _ready():
	baking_timer = Timer.new()
	baking_timer.one_shot = true;
	baking_timer.connect("timeout", actually_bake)
	baking_timer.wait_time = 0.25;
	add_child(baking_timer)

func actually_bake():
	$BAKE.text = ("BAKING")

	$HBoxContainer.visible = false
	$MENU_BUTTON.visible = true;
	_on_reset_pressed()
	for scene in DATA.SCENES:
		for child:MeshInstance3D in scene.SCENE.get_children():
			if(scene.EXCLUDE == false):
				update_mesh(child,scene)
			#for og_child:MeshInstance3D in scene.OG_SCENE.get_children():
				#if(og_child.name == child.name):
	$BAKE.text = ("BAKE")


func _on_bake_pressed() -> void:
	$BAKE.text = ("QUEUING BAKE")
	baking_timer.start()

func _on_gizmo_3d_transform_begin(mode: Gizmo3D.TransformMode) -> void:
	#print(_on_gizmo_3d_transform_begin)
	pass # Replace with function body.


func _on_gizmo_3d_transform_changed(mode: Gizmo3D.TransformMode, value: Vector3) -> void:
	#print(_on_gizmo_3d_transform_changed)
	if(CURRENT_LIGHT != null && mode == Gizmo3D.TransformMode.SCALE):
		CURRENT_LIGHT.LIGHT_MESH.scale =Vector3.ONE
		var mesh:MeshInstance3D = CURRENT_LIGHT.LIGHT_MESH.get_node("MeshInstance3D")
		mesh.scale = Vector3.ONE *CURRENT_LIGHT.RADIUS;
		#CURRENT_LIGHT.ACTUAL_LIGHT.omni_range = CURRENT_LIGHT.RADIUS;

		CURRENT_LIGHT.RADIUS+=value.x/10.0
		CURRENT_LIGHT.RADIUS+=value.y/10.0
		CURRENT_LIGHT.RADIUS+=value.z/10.0
		CURRENT_LIGHT.LIST_ITEM.get_node("VBoxContainer/RADIUS_CONTAINER/SpinBox").value = 	CURRENT_LIGHT.RADIUS
	pass # Replace with function body.


func _on_gizmo_3d_transform_end(mode: Gizmo3D.TransformMode) -> void:
	if(CURRENT_LIGHT != null && mode == Gizmo3D.TransformMode.SCALE):

		#CURRENT_LIGHT.ACTUAL_LIGHT.omni_range = CURRENT_LIGHT.RADIUS;
		var mesh:MeshInstance3D = CURRENT_LIGHT.LIGHT_MESH.get_node("MeshInstance3D")
		mesh.scale = Vector3.ONE *CURRENT_LIGHT.RADIUS;
		CURRENT_LIGHT.LIGHT_MESH.scale =Vector3.ONE
		CURRENT_LIGHT.LIST_ITEM.get_node("VBoxContainer/RADIUS_CONTAINER/SpinBox").value = 	CURRENT_LIGHT.RADIUS
	$HBoxContainer.visible = false
	$MENU_BUTTON.visible = true;
	#print(_on_gizmo_3d_transform_end)
	#for layer in DATA.LAYERS:
			#for light in layer.LIGHTS:
				#light.ACTUAL_LIGHT.show()
	#load_from_current_path()
	_on_bake_pressed()

func _on_menu_button_pressed() -> void:
	$HBoxContainer.visible = true
	$MENU_BUTTON.visible = false;


func _on_reset_pressed() -> void:

	for scene in DATA.SCENES:
		for mesh:MeshInstance3D in scene.SCENE.get_children():
			for og_mesh:MeshInstance3D in scene.OG_SCENE.get_children():
				if(og_mesh.name == mesh.name):
					var count =mesh.mesh.get_surface_count()
					var tools = []
					for index in count:
						tools.push_back(MeshDataTool.new())

					for index in count:
						var data:MeshDataTool = tools[index-1]
						data.create_from_surface(og_mesh.mesh, index)

					mesh.mesh.clear_surfaces()
					for index in count:
						var data = tools[index-1]
						data.commit_to_surface(mesh.mesh)


func _on_light_sphere_checkbox_toggled(toggled_on: bool) -> void:
	LIGHT_SPHERES_ON = toggled_on
	for layer in DATA.LAYERS:
		for light in layer.LIGHTS:
			var sphere:MeshInstance3D = light.LIGHT_MESH.get_node("MeshInstance3D")
			sphere.visible = toggled_on;
