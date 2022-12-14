class_name Transitions
extends CanvasLayer

signal opened
signal closed

onready var rects : Array = [
    get_node("%Rect0"),
    get_node("%Rect1"),
    get_node("%Rect2"),
    get_node("%Rect3"),
    get_node("%Rect4"),
    get_node("%Rect5"),
]

func open(duration: float = 0.75) -> void:
    var tween := create_tween()

    for rect_index in range(0, rects.size()):
        var rect : ColorRect = rects[rect_index]
        var x := -10.0
        tween.parallel().tween_property(rect, "rect_position:x", x, duration)

    yield(tween, "finished")
    emit_signal("opened")

func close(duration: float = 0.75) -> void:
    var tween := create_tween()

    for rect_index in range(0, rects.size()):
        var rect : ColorRect = rects[rect_index]
        var x := rect.rect_size.x
        if rect_index % 2:
            x = -rect.rect_size.x
        tween.parallel().tween_property(rect, "rect_position:x", x, duration)

    yield(tween, "finished")
    emit_signal("closed")
