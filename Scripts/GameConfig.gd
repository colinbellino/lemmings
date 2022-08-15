extends Resource
class_name GameConfig

export(Array, Resource) var levels : Array
export var cursor_default_x1 : Texture
export var cursor_default_x2 : Texture
export var cursor_default_x4 : Texture
export var cursor_border_x1 : Texture
export var cursor_border_x2 : Texture
export var cursor_border_x4 : Texture
export var unit_prefab : PackedScene
export var exit_color: Color
export var entrance_color: Color
export var background_color : Color = Color(0, 0, 0, 0)
export var sound_start : AudioStreamSample
export var sound_door_open : AudioStreamSample
export var sound_yippee : AudioStreamSample
export var sound_splat : AudioStreamSample
export var sound_assign_job : AudioStreamSample
export var sound_explode : AudioStreamSample
export var sound_deathrattle : AudioStreamSample
