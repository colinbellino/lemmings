class_name Level
extends Resource

export var texture : Texture
export var music : AudioStream
export var type : Resource
export var camera_x : int
export var camera_y : int
export(int, 1, 100, 1) var units_max : int = 10
export(int, 1, 100, 1) var units_goal : int = 10
export(int, 10, 90, 1) var spawn_rate : int = 50
export var job_climber : int
export var job_floater : int
export var job_bomber : int
export var job_blocker : int
export var job_builder : int
export var job_basher : int
export var job_miner : int
export var job_digger : int
