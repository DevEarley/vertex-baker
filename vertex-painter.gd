extends Control
class_name VertexBakerMainWindow
var MOVING_WINDOW = false
var layer_prefab = preload("res://layer_prefab.tscn")
var light_prefab = preload("res://light_prefab.tscn")
var mesh_list_item_prefab = preload("res://list_item_mesh_prefab.tscn")
var scene_list_item_prefab = preload("res://list_item_scene_prefab.tscn")
var surface_list_item_prefab = preload("res://list_item_surface_prefab.tscn")
var material_list_item_prefab = preload("res://list_item_material_prefab.tscn")
var light_mesh = preload("res://light_mesh_prefab.tscn")
var imported_mesh_prefab = preload("res://imported_mesh_prefab.tscn")
var scene_prefab = preload("res://scene_prefab.tscn")
var surface_prefab = preload("res://surface_prefab.tscn")
var CURRENT_MESH
var OG_MESH
var brush_hardness = 1.0
var calculated_size:float = 5.0
var PREVIOUS_COLOR:Color = Color.WHITE

var CURRENT_WINDOW:WindowMover

func _input(event:InputEvent):
	# Mouse in viewport coordinates.
	#if event is InputEventMouseButton && event.is_released():
		#self.position = event
		#print("Mouse Click/Unclick at: ", event.position)
	if event is InputEventMouseMotion:
		print("vp movement")
		if(CURRENT_WINDOW != null && MOVING_WINDOW == true):
			CURRENT_WINDOW.position = Vector2i(event.position-CURRENT_WINDOW.LAST_POSITION)

	if(event is InputEventMouseButton && event.is_released()):
		print("is_released from main")
		if(CURRENT_WINDOW != null && MOVING_WINDOW == true):
			print("is_released from main | MOVING_WINDOW = true")
			MOVING_WINDOW = false
			CURRENT_WINDOW.mouse_passthrough = false
			CURRENT_WINDOW.unfocusable = true

func _on_add_layer_pressed() -> void:

	$HBoxContainer.visible = false
	$MENU_BUTTON.visible = true;
	var layer:Layer = Layer.new()
	layer.LIGHTS = []
	layer.ID = DATA.LAYERS.size()
	DATA.LAYERS.push_back(layer)
	var new_layer = layer_prefab.instantiate()
	$LAYER_INSPECTOR/ScrollContainer/CONTAINER/LAYERS.add_child(new_layer)
	var button  = new_layer.get_node("VBoxContainer/ADD_LIGHT_TO_LAYER")
	var toggle  = new_layer.get_node("VBoxContainer/TOGGLE")
	var name_label  = new_layer.get_node("NAME")
	name_label.text = "Layer #%s"%layer.ID
	button.connect("pressed",on_add_light_to_layer.bind(new_layer,layer))
	toggle.connect("pressed",on_toggle_layer.bind(new_layer))

func on_add_light_to_layer(layer:Control,layer_:Layer):
	var light = VertexLight.new()
	var actual_light = OmniLight3D.new()
	light.COLOR = PREVIOUS_COLOR
	light.LIGHT_MESH = light_mesh.instantiate()
	light.LIGHT_MESH.add_child(actual_light)
	light.ACTUAL_LIGHT = actual_light;
	light.RADIUS = 1.0
	light.MIX = 0.5
	light.ID = layer_.LIGHTS.size()
	layer_.LIGHTS.push_back(light)
	$SubViewportContainer/SubViewport.add_child(light.LIGHT_MESH)
	var new_light = light_prefab.instantiate()
	var radius_control:SpinBox = new_light.get_node("VBoxContainer/RADIUS_CONTAINER/SpinBox")
	radius_control.value = 1.0;
	radius_control.connect("value_changed",on_radius_value_changed.bind(light,radius_control))

	var color_control = new_light.get_node("VBoxContainer/COLOR_CONTAINER/ColorPickerButton")
	color_control.connect("color_changed",on_color_picker_changed.bind(light,color_control))
	var mix_control:SpinBox = new_light.get_node("VBoxContainer/MIX_CONTAINER/SpinBox")
	mix_control.value = 0.5;
	mix_control.connect("value_changed",on_mix_value_changed.bind(light,mix_control))

	var delete_button = new_light.get_node("VBoxContainer/BUTTON_ROW_1/DELETE")
	delete_button.connect("pressed",on_delete_light.bind(light))
	var duplicate_button = new_light.get_node("VBoxContainer/BUTTON_ROW_1/DUPLICATE")
	duplicate_button.connect("pressed",on_duplicate_light.bind(light))
	var move_button = new_light.get_node("VBoxContainer/BUTTON_ROW_2/MOVE")
	move_button.connect("pressed",on_duplicate_light.bind(light))
	var toggle_visible_button = new_light.get_node("VBoxContainer/BUTTON_ROW_2/TOGGLE_VISIBLE")
	toggle_visible_button.connect("pressed",on_toggle_light.bind(light))
	layer.get_node("VBoxContainer/LIGHTS").add_child(new_light)

func on_radius_value_changed(value:float,light:VertexLight,radius:SpinBox):
	light.RADIUS = value
	light.ACTUAL_LIGHT.omni_range = value;

func on_color_picker_changed(color:Color,light:VertexLight,color_button:ColorPickerButton):
	light.COLOR = color_button.color;
	light.ACTUAL_LIGHT.light_color =light.COLOR;
	light.LIGHT_MESH.modulate = light.COLOR
	PREVIOUS_COLOR = light.COLOR

func on_mix_value_changed(value:float,light:VertexLight,mix:SpinBox):
	light.MIX = value
	if(value ==0):
		light.ACTUAL_LIGHT.hide()
	else:
		light.ACTUAL_LIGHT.show()

	light.ACTUAL_LIGHT.omni_attenuation =2-value;

func on_delete_light(light:VertexLight):
	pass

func on_duplicate_light(light:VertexLight):
	pass

func on_move_light(light:VertexLight):
	pass

func on_toggle_light(light:VertexLight):
	pass

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

func update_mesh(mesh:MeshInstance3D) -> void:

		var count =mesh.mesh.get_surface_count()

		var tools = []

		for index in count:
			tools.push_back(MeshDataTool.new())

		for layer in DATA.LAYERS:
				for light in layer.LIGHTS:
					light.ACTUAL_LIGHT.show()

		for layer in DATA.LAYERS:
			for light in layer.LIGHTS:
				for index in count:
					var data:MeshDataTool = tools[index-1]
					data.create_from_surface(mesh.mesh, index)
					for i in range(data.get_vertex_count()):
						var vertex = mesh.to_global(data.get_vertex(i))#+mesh.global_position
						var vertex_distance:float = vertex.distance_to(light.ACTUAL_LIGHT.global_position)
						if vertex_distance < light.RADIUS:
							#light.ACTUAL_LIGHT.hide()
							print("in %s"%index)
							var linear_distance = 1 - (vertex_distance / (light.RADIUS))

							var old_color:Color = data.get_vertex_color(i)
							var new_color:Color = light.COLOR#lerp(old_color,light.COLOR, linear_distance* light.MIX)
							data.set_vertex_color(i,new_color )
						#else:
							#data.set_vertex_color(i,light.COLOR )

				var mesh_:Mesh = mesh.mesh;

				mesh_.clear_surfaces()
				for index in count:
					print("commit_to_surface")
#
					var data = tools[index-1]
					data.commit_to_surface(mesh.mesh)

		for layer in DATA.LAYERS:
				for light in layer.LIGHTS:
					light.ACTUAL_LIGHT.hide()


func _on_save_file_selected(path: String) -> void:
	pass # Replace with function body.


func _on_export_file_selected(path: String) -> void:
	pass # Replace with function body.

var CURRENT_PATH=""
func _on_import_file_selected(path: String) -> void:
	CURRENT_PATH = path;
	load_from_current_path()

func remove_mesh_from_scene():
	if(CURRENT_MESH!= null):
		$SubViewportContainer/SubViewport.remove_child(CURRENT_MESH)

func load_from_current_path():
	if(CURRENT_PATH == ""):return;
	var gltf_state_load = GLTFState.new()
	var gltf_document_load = GLTFDocument.new()
	var error = gltf_document_load.append_from_file(CURRENT_PATH, gltf_state_load)
	var file:FileAccess = FileAccess.open(CURRENT_PATH, FileAccess.READ_WRITE)
	if error == OK:
		CURRENT_MESH = gltf_document_load.generate_scene(gltf_state_load)
		CURRENT_MESH.name = "MESH"
		var node= $SubViewportContainer/SubViewport
		var mesh = scene_prefab.instantiate()
		mesh.add_child(CURRENT_MESH)
		node.add_child(mesh)
		var scene_list_item = scene_list_item_prefab.instantiate()
		scene_list_item.get_node("ICON/NAME").text = CURRENT_PATH
		$MESH_INSPECTOR/ScrollContainer/CONTAINER/MESHES.add_child(scene_list_item)
		for child_mesh:MeshInstance3D in CURRENT_MESH.get_children():
			var mesh_list_item = mesh_list_item_prefab.instantiate()
			mesh_list_item.get_node("ICON/NAME").text = child_mesh.name
			scene_list_item.get_node("VBoxContainer/MESHES").add_child(mesh_list_item)
			for surface in child_mesh.mesh.get_surface_count():
				var surface_list_item = surface_list_item_prefab.instantiate()
				surface_list_item.get_node("ICON/NAME").text = "Surface %s" % surface
				mesh_list_item.get_node("VBoxContainer/SURFACES").add_child(surface_list_item)
	else:
		print("Couldn't load glTF scene (error code: %s)." % error_string(error))

func _on_open_file_selected(path: String) -> void:
	pass # Replace with function body.

func _on_bake_pressed() -> void:

	$HBoxContainer.visible = false
	$MENU_BUTTON.visible = true;
	var parent = CURRENT_MESH.get_parent()
	var old_position = parent.global_position
	$SubViewportContainer/SubViewport.remove_child(CURRENT_MESH.get_parent())
	load_from_current_path()
	CURRENT_MESH.get_parent().global_position = old_position
	for child:MeshInstance3D in CURRENT_MESH.get_children():
			update_mesh(child)


func _on_gizmo_3d_transform_begin(mode: Gizmo3D.TransformMode) -> void:
	#print(_on_gizmo_3d_transform_begin)
	pass # Replace with function body.


func _on_gizmo_3d_transform_changed(mode: Gizmo3D.TransformMode, value: Vector3) -> void:
	#print(_on_gizmo_3d_transform_changed)

	pass # Replace with function body.


func _on_gizmo_3d_transform_end(mode: Gizmo3D.TransformMode) -> void:

	$HBoxContainer.visible = false
	$MENU_BUTTON.visible = true;
	print(_on_gizmo_3d_transform_end)
	for layer in DATA.LAYERS:
			for light in layer.LIGHTS:
				light.ACTUAL_LIGHT.show()
	#load_from_current_path()


func _on_menu_button_pressed() -> void:
	$HBoxContainer.visible = true
	$MENU_BUTTON.visible = false;
