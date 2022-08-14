class_name JobButton
extends Button

onready var label : Label = get_node("%Label")
onready var sprite : Sprite = get_node("%Sprite")

var _default_region_rect : Rect2

func _ready() -> void :
    _default_region_rect = sprite.region_rect

func set_data(job_id: int, text: String) -> void :
    sprite.region_rect.position.x = _default_region_rect.size.x * job_id 
    label.text = text
