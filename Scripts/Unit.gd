class_name Unit
extends AnimatedSprite

enum STATES {
    WALKING = 0,
    FALLING = 1,
}

enum JOBS {
    NONE = 0,
    DIG_VERTICAL = 1,
    DIG_HORIZONTAL = 1 << 2,
}

enum STATUSES {
    ACTIVE = 0
    DEAD = 1
    EXITED = 2
}

var status : int
var state : int
var state_entered_at : int
var job : int
var job_started_at : int
var job_duration : int
var width : int = 8
var height : int = 10
var climb_step : int = 5
# Left: -1 | Right: 1
var direction : int = 1

func get_bounds() -> Rect2:
    return Rect2(position.x - width / 2, position.y - height / 2, width, height)
