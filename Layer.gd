class_name LightLayer;

var ID:int
var LIST_ITEM:VBoxContainer
var LIGHTS:Array[VertexLight]
var BLENDING_METHOD:BLENDING_METHODS
enum BLENDING_METHODS{
	DEFAULT= 0,
	MULTIPLY= 1,
	ADD=2,
	SUBTRACT=3,
	DIVIDE=4,
	MIN=5,
	MAX=6,
	MIX=7
}
