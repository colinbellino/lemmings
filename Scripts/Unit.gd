class_name Unit
extends AnimatedSprite

onready var label = get_node("%Label")

enum STATES {
    IDLE,
    WALKING,
    FALLING,
    FLOATING,
    CLIMBING,
    CLIMBING_END
    EXPLODING,
    DEAD_FALL,
}

enum STATUSES {
    ACTIVE = 0
    DEAD = 1
    EXITED = 2
}

var status : int
var state : int
var state_entered_at : int
var width : int = 8
var height : int = 10
var climb_step : int = 5
# Left: -1 | Right: 1
var direction : int = 1

var jobs_started_at : PoolIntArray = [0, 0, 0, 0, 0, 0, 0, 0, 0]

func get_bounds() -> Rect2:
    return Rect2(position.x, position.y, width, height)

func get_bounds_centered() -> Rect2:
    return Rect2(position.x - width / 2, position.y - height / 2, width, height)

func set_text(value: String) -> void:
    label.text = value
