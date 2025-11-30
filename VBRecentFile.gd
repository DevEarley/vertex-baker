class_name VBRecentFile extends Resource
enum VB_FILE_TYPES{
	TEXTURE=0,
	PROJECT_FILE_OPENED=1,
	PROJECT_FILE_SAVED=2,
	EXPORTED=3,
	IMPORTED=4
}

@export var DATE_OPENED:float
@export var DATE_SAVED:float
@export var PATH:String
@export var TYPE:VB_FILE_TYPES
