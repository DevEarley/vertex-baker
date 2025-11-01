extends Control

var layer_prefab = preload("res://layer_prefab.tscn")
var light_prefab = preload("res://light_prefab.tscn")
var light_mesh = preload("res://light_mesh_prefab.tscn")
var CURRENT_MESH
var OG_MESH
var brush_hardness = 1.0
var calculated_size:float = 5.0
var PREVIOUS_COLOR:Color = Color.WHITE
func _on_add_layer_pressed() -> void:
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
	$IMPORT.show()

func _on_save_button_pressed() -> void:
	$SAVE.show()

func _on_export_button_pressed() -> void:
	$EXPORT.show()

func _on_open_button_pressed() -> void:
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
		for index in count:
			var data = tools[index-1]
			data.create_from_surface(mesh.mesh, index)
			for layer in DATA.LAYERS:
				for light in layer.LIGHTS:
					for i in range(data.get_vertex_count()):
						var vertex = mesh.to_global(data.get_vertex(i))
						var vertex_distance:float = vertex.distance_to(light.ACTUAL_LIGHT.global_position)
						if vertex_distance < light.RADIUS:
							light.ACTUAL_LIGHT.hide()
							print("in")
							var linear_distance = 1 - (vertex_distance / (light.RADIUS))

							var old_color:Color = data.get_vertex_color(i)
							var new_color:Color = lerp(old_color,light.COLOR, linear_distance* light.MIX)
							data.set_vertex_color(i,new_color )
						#else:
							#data.set_vertex_color(i,light.COLOR )

		mesh.mesh.clear_surfaces()

		for index in count:
			print("commit_to_surface")

			var data = tools[index-1]
			data.commit_to_surface(mesh.mesh)



func _on_save_file_selected(path: String) -> void:
	pass # Replace with function body.


func _on_export_file_selected(path: String) -> void:
	pass # Replace with function body.

var CURRENT_PATH=""
func _on_import_file_selected(path: String) -> void:
	CURRENT_PATH = path;
	load_from_current_path()

func load_from_current_path():
	if(CURRENT_PATH == ""):return;
	if(CURRENT_MESH!= null):
		$SubViewportContainer/SubViewport.remove_child(CURRENT_MESH)
	var gltf_state_load = GLTFState.new()
	var gltf_document_load = GLTFDocument.new()
	var error = gltf_document_load.append_from_file(CURRENT_PATH, gltf_state_load)
	var file:FileAccess = FileAccess.open(CURRENT_PATH, FileAccess.READ_WRITE)

	if error == OK:
		CURRENT_MESH = gltf_document_load.generate_scene(gltf_state_load)
		CURRENT_MESH.name = "MESH"
		var node= $SubViewportContainer/SubViewport
		node.add_child(CURRENT_MESH)
	else:
		print("Couldn't load glTF scene (error code: %s)." % error_string(error))

func _on_open_file_selected(path: String) -> void:
	pass # Replace with function body.


func _on_bake_pressed() -> void:
	$SubViewportContainer/SubViewport.remove_child(CURRENT_MESH)
	load_from_current_path()

	for child:MeshInstance3D in CURRENT_MESH.get_children():

			update_mesh(child)


func _on_gizmo_3d_transform_begin(mode: Gizmo3D.TransformMode) -> void:
	print(_on_gizmo_3d_transform_begin)
	pass # Replace with function body.


func _on_gizmo_3d_transform_changed(mode: Gizmo3D.TransformMode, value: Vector3) -> void:
	print(_on_gizmo_3d_transform_changed)

	pass # Replace with function body.


func _on_gizmo_3d_transform_end(mode: Gizmo3D.TransformMode) -> void:
	print(_on_gizmo_3d_transform_end)
	for layer in DATA.LAYERS:
			for light in layer.LIGHTS:
				light.ACTUAL_LIGHT.show()
	load_from_current_path()
