extends Node
var LAYERS:Array[LightLayer]=[]
var SCENES:Array[ImportedScene]=[]
var MATERIALS:Array[ImportedMaterial]=[]
var LAYER_MASKS:Array[LightLayerMask]=[]

func to_project_data():
	var project_data:VBData = VBData.new()
	project_data.SCENES = []
	project_data.LAYERS = []
	project_data.LIGHTS = []
	project_data.LAYER_MASKS = []

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
		scene_data.SCALE = scene.NODE.scale
		project_data.SCENES.push_back(scene_data)

	for layer in LAYERS:
		var layer_data:VBLayerData = VBLayerData.new()
		layer_data.ID = layer.ID;
		layer_data.NAME = layer.NAME;
		layer_data.BLENDING_METHOD = layer.BLENDING_METHOD;

		project_data.LAYERS.push_back(layer_data)
		for light in layer.LIGHTS:
			var light_data:VBLightData = VBLightData.new()
			light_data.COLOR = Vector3(light.COLOR.r,light.COLOR.g,light.COLOR.b)

			light_data.POSITION = light.LIGHT_MESH.global_position
			light_data.PARENT_LAYER_ID = layer.ID
			light_data.MIX = light.MIX
			light_data.RADIUS = light.RADIUS
			project_data.LIGHTS.push_back(light_data)

	return project_data
