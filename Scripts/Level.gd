class_name Level
extends Resource

export var texture : Texture
export var music : AudioStream
export var entrance: PackedScene = load("res://Prefabs/Exit_00.tscn")
export var exit : PackedScene = load("res://Prefabs/Entrance_00.tscn")
export var camera_x : int
export var camera_y : int
export(int, 1, 100, 1) var units_max : int = 30
export(int, 1, 100, 1) var units_goal : int = 10
export(int, 10, 100, 1) var spawn_rate : int = 50
