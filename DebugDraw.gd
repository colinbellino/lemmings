class_name DebugDraw
extends Control

var _rects : Array = []
var _rects_count : int = 0
var _updated : bool

func _ready() -> void :
    _rects.resize(100)

func _process(_delta) -> void :
    if _updated:
        update()
        _updated = false

    pass

func _draw() -> void :
    for rect_index in range(0, _rects_count):
        var rect = _rects[rect_index]
        draw_rect(Rect2(rect.rect.position * Game.SCALE, rect.rect.size * Game.SCALE), rect.color)
        pass

    _rects_count = 0

func add_rect(rect: Rect2, color: Color) -> void : 
    if _rects_count >= _rects.size():
        printerr("Maxium rects drawn (%s)" % _rects.size())
        return

    # print("add_rect: ", rect, color)
    _rects[_rects_count] = { "rect": rect, "color": color }
    _rects_count += 1

    _updated = true
