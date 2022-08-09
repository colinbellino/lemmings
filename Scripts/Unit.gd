class_name Unit
extends AnimatedSprite

# Left: -1 | Right: 1
var direction : int = 1
var width : int = 6
var height : int = 10

func get_bounds() -> Rect2:
    return Rect2(position.x - width / 2, position.y - height / 2, width, height)
