extends Node
var LAYERS:Array[LightLayer]=[]
var SCENES:Array[ImportedScene]=[]
var MATERIALS:Array[ImportedMaterial]=[]
var LAYER_MASKS:Array[LightLayerMask]=[]
var MATERIAL_OVERRIDES:Array[MaterialOverride]=[]
var MATERIAL_REPLACEMENTS:Array[MaterialReplacement]=[]
var RECENTS:Array[VBRecentFile]=[]

func load_recents():
	var recents_file_path = "user://recents.tres"
	var result:VBRecentFiles
	if ResourceLoader.exists(recents_file_path):
		result =  load(recents_file_path)
		RECENTS = result.RECENTS
	else:
		var new_recents_file = VBRecentFiles.new()
		var new_array:Array[VBRecentFile] = []
		new_recents_file.RECENTS = new_array
		ResourceSaver.save(new_recents_file,recents_file_path)

func save_recents():
	var recents_file_path = "user://recents.tres"
	var recents = VBRecentFiles.new()
	recents.RECENTS = RECENTS;
	ResourceSaver.save(recents,recents_file_path)

func update_recent_files(path,type:VBRecentFile.VB_FILE_TYPES):
	var recents_file_path = "user://recents.tres"
	var existing_files = RECENTS.filter(func (recent:VBRecentFile): return recent.PATH == path && type == recent.TYPE)
	if(existing_files!=null && existing_files.size()>0):
		match(type):
			VBRecentFile.VB_FILE_TYPES.PROJECT_FILE_OPENED,VBRecentFile.VB_FILE_TYPES.TEXTURE,VBRecentFile.VB_FILE_TYPES.IMPORTED:
				existing_files[0].DATE_OPENED = Time.get_unix_time_from_system()
			VBRecentFile.VB_FILE_TYPES.PROJECT_FILE_SAVED,VBRecentFile.VB_FILE_TYPES.EXPORTED:
				existing_files[0].DATE_SAVED = Time.get_unix_time_from_system()
	else:
		var recent_file = VBRecentFile.new()
		recent_file.PATH = path
		recent_file.TYPE = type
		recent_file.DATE_OPENED = Time.get_unix_time_from_system()
		recent_file.DATE_SAVED = Time.get_unix_time_from_system()
		RECENTS.push_back(recent_file);

func to_project_data():
	var project_data:VBData = VBData.new()
	project_data.SCENES = []
	project_data.LAYERS = []
	project_data.LIGHTS = []
	project_data.LAYER_MASKS = []
	project_data.MATERIAL_OVERRIDES = []
	project_data.MATERIAL_REPLACEMENTS = []
	for mat_override in MATERIAL_OVERRIDES:
		var vb_mat_override:VBMaterialOverride =VBMaterialOverride.new()
		vb_mat_override.NEW_MATERIAL_NAME = mat_override.NEW_MATERIAL_NAME
		vb_mat_override.TARGET_MATERIAL_NAME = mat_override.TARGET_MATERIAL_NAME
		vb_mat_override.SHADER_ID = mat_override.SHADER_ID
		vb_mat_override.MESH_NAME = mat_override.MESH_NAME
		vb_mat_override.SCENE_ID = mat_override.SCENE_ID
		vb_mat_override.SURF_INDEX = mat_override.SURF_INDEX
		vb_mat_override.OVERRIDE_SURFACE = mat_override.OVERRIDE_SURFACE
		project_data.MATERIAL_OVERRIDES.push_back(vb_mat_override);

	for mat_replacement in MATERIAL_REPLACEMENTS:
		var vb_mat_replacement:VBMaterialReplacement =VBMaterialReplacement.new()
		vb_mat_replacement.NEW_MATERIAL_NAME = mat_replacement.NEW_MATERIAL_NAME
		vb_mat_replacement.SHADER_ID = mat_replacement.SHADER_ID
		vb_mat_replacement.TEXTURE_PATH = mat_replacement.TEXTURE_PATH
		project_data.MATERIAL_REPLACEMENTS.push_back(vb_mat_replacement);

	for layer_mask in LAYER_MASKS:
		var vb_layer_mask:VBLayerMaskData =VBLayerMaskData.new()
		vb_layer_mask.LAYER_ID = layer_mask.LAYER_ID
		vb_layer_mask.SURFACE_ID = layer_mask.SURFACE_ID
		vb_layer_mask.SCENE_ID = layer_mask.SCENE_ID
		vb_layer_mask.MESH_NAME = layer_mask.MESH_NAME
		project_data.LAYER_MASKS.push_back(vb_layer_mask);

	for scene in SCENES:
		var scene_data:VBSceneData = VBSceneData.new()
		scene_data.NAME = scene.NAME;
		scene_data.PATH = scene.PATH;
		scene_data.ID = scene.ID;
		scene_data.POSITION = scene.NODE.global_position
		scene_data.ROTATION = scene.NODE.rotation
		scene_data.SCALE = scene.NODE.scale
		project_data.SCENES.push_back(scene_data)

	for layer in LAYERS:
		var layer_data:VBLayerData = VBLayerData.new()
		layer_data.ID = layer.ID;
		layer_data.NAME = layer.NAME;
		layer_data.BLENDING_METHOD = layer.BLENDING_METHOD;
		layer_data.BLENDING_FADE = layer.BLENDING_FADE;
		layer_data.BLENDING_DIRECTION = layer.BLENDING_DIRECTION;
		project_data.LAYERS.push_back(layer_data)
		for light in layer.LIGHTS:
			var light_data:VBLightData = VBLightData.new()
			light_data.COLOR = Vector3(light.COLOR.r,light.COLOR.g,light.COLOR.b)
			light_data.POSITION = light.LIGHT_MESH.global_position
			light_data.PARENT_LAYER_ID = layer.ID
			light_data.MIX = light.MIX
			light_data.ID = light.ID
			light_data.RADIUS = light.RADIUS
			project_data.LIGHTS.push_back(light_data)
	return project_data
