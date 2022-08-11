class_name Unit
extends AnimatedSprite

const JOB_NONE : int = 0
const JOB_DIG : int = 1

const STATUS_ACTIVE : int = 0
const STATUS_DEAD : int = 1
const STATUS_EXITED : int = 2

# Left: -1 | Right: 1
var direction : int = 1
var width : int = 8
var height : int = 10
var climb_step : int = 5
var job_id : int
var job_started_at : int
var job_duration : int
var status : int

func get_bounds() -> Rect2:
    return Rect2(position.x - width / 2, position.y - height / 2, width, height)
