class_name DebugDraw
extends Control

var _game : Game
var _font : Font
var _updated : bool
var _rects : Array = []
var _rects_count : int = 0
var _texts : Array = []
var _texts_count : int = 0

func _ready() -> void:
    _game = get_node("/root/Game")
    _font = self.get_font("font")
    _rects.resize(300)
    _texts.resize(300)

func _process(_delta) -> void:
    if _updated:
        update()
        _updated = false

    pass

func _draw() -> void:
    for rect_index in range(0, _rects_count):
        var rect = _rects[rect_index]
        draw_rect(Rect2(rect.rect.position * _game.game_scale, rect.rect.size * _game.game_scale), rect.color)
    _rects_count = 0
    
    for text_index in range(0, _texts_count):
        var text = _texts[text_index]
        draw_string(_font, text.position, text.text, text.color)
    _texts_count = 0

func add_rect(rect: Rect2, color: Color) -> void: 
    if _rects_count >= _rects.size():
        # printerr("Maximum rects drawn (%s)" % _rects.size())
        return

    _rects[_rects_count] = {
        "rect": rect,
        "color": color,
    }
    _rects_count += 1

    _updated = true

func add_text(pos: Vector2, text: String, color: Color) -> void:
    if _texts_count >= _texts.size():
        # printerr("Maximum texts drawn (%s)" % _texts.size())
        return
    
    _texts[_texts_count] = { 
        "position": pos * _game.game_scale,
        "text": text,
        "color": color,
    }
    _texts_count += 1

    _updated = true
