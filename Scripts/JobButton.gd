class_name JobButton
extends Button

onready var label : Label = get_node("%Label")
onready var sprite : Sprite = get_node("%Sprite")

var _default_region_rect : Rect2

func _ready() -> void :
    _default_region_rect = sprite.region_rect

func set_data(job_id: int, count: String) -> void :
    print("set_data: ", job_id)
    sprite.region_rect.position.x = _default_region_rect.size.x * job_id 
    label.text = count
    pass
