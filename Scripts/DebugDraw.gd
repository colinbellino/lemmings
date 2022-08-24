class_name DebugDraw
extends Control

var game
var font : Font
var updated : bool
var rects : Array = []
var rects_count : int = 0
var texts : Array = []
var texts_count : int = 0

func _ready() -> void:
    game = get_node("/root/Game")
    font = self.get_font("font")
    rects.resize(300)
    texts.resize(300)

func _process(_delta) -> void:
    if updated:
        update()
        updated = false

    pass

func _draw() -> void:
    for rect_index in range(0, rects_count):
        var rect = rects[rect_index]
        var r = Rect2(
            game.to_viewport_position(rect.rect.position - Vector2(rect.rect.size.x, rect.rect.size.y) / 2) * game.game_scale,
            rect.rect.size * game.game_scale
        )
        draw_rect(r, rect.color)
    rects_count = 0
    
    for text_index in range(0, texts_count):
        var text = texts[text_index]
        draw_string(font, game.to_viewport_position(text.position) * game.game_scale, text.text, text.color)
    texts_count = 0

func add_rect(rect: Rect2, color: Color) -> void: 
    if rects_count >= rects.size():
        # printerr("Maximum rects drawn (%s)" % rects.size())
        return

    rects[rects_count] = {
        "rect": rect,
        "color": color,
    }
    rects_count += 1

    updated = true

func add_text(pos: Vector2, text: String, color: Color = Color.white) -> void:
    if texts_count >= texts.size():
        # printerr("Maximum texts drawn (%s)" % texts.size())
        return
    
    texts[texts_count] = { 
        "position": pos,
        "text": text,
        "color": color,
    }
    texts_count += 1

    updated = true
