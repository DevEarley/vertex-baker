extends Node
var LAYERS:Array[Layer]=[]
var SCENES:Array[ImportedScene]=[]
var MATERIALS:Array[ImportedMaterial]=[]

func from_project_data(project_data:VBData):
	SCENES = []
	LAYERS = []
	MATERIALS = []
	#for scene_data:VBSceneData in project_data.SCENES:
		#var imported_scene = ImportedScene.new();
		#imported_scene.NAME = scene_data.NAME
		#imported_scene.PATH = scene_data.PATH
		#imported_scene.IMPORTED_POSITION = scene_data.POSITION
		#SCENES.push_back(imported_scene);

	for layer_data:VBLayerData in project_data.LAYERS:
		var layer:Layer = Layer.new()
		layer.ID = layer_data.ID
		LAYERS.push_back(layer)
		for light_data in project_data.LIGHTS:
			if(light_data.PARENT_LAYER_ID == layer.ID):
				var light = VertexLight.new()
				light.COLOR = Color(light_data.COLOR.x,light_data.COLOR.y,light_data.COLOR.z)
				light.IMPORTED_POSITION = light_data.POSITION
				light.MIX = (light_data.MIX)
				light.ID = (light_data.ID)
				light.RADIUS = (light_data.RADIUS)
				layer.LIGHTS.push_back(light)



func to_project_data():
	var project_data:VBData = VBData.new()
	project_data.SCENES = []
	project_data.LAYERS = []
	project_data.LIGHTS = []

	for scene in SCENES:
		var scene_data:VBSceneData = VBSceneData.new()
		scene_data.NAME = scene.NAME;
		scene_data.PATH = scene.PATH;
		scene_data.POSITION = scene.NODE.global_position
		scene_data.SCALE = scene.NODE.scale
		project_data.SCENES.push_back(scene_data)
	for layer in LAYERS:
		var layer_data:VBLayerData = VBLayerData.new()
		layer_data.ID = layer.ID;

		project_data.LAYERS.push_back(layer_data)
		for light in layer.LIGHTS:
			var light_data:VBLightData = VBLightData.new()
			light_data.COLOR = Vector3(light.COLOR.r,light.COLOR.g,light.COLOR.b)

			light_data.POSITION = light.ACTUAL_LIGHT.global_position
			light_data.PARENT_LAYER_ID = layer.ID
			light_data.MIX = light.MIX
			light_data.RADIUS = light.RADIUS
			project_data.LIGHTS.push_back(light_data)

	return project_data
