extends Node2D

const SCALE : int = 4
const BACKGROUND_COLOR : Color = Color(0, 0.1, 0.2, 1)

const PIXEL_EMPTY : int = 0
const PIXEL_BLOCK : int = 1

onready var scaler_node : Node2D = get_node("%Scaler")
onready var map_sprite : Sprite = get_node("%Map")
onready var collision_sprite : Sprite = get_node("%Collision")
onready var debug_label : Label = get_node("%Debug")

var map_data : PoolIntArray = []

var original_texture : Texture
var map_texture : Texture
var map_image : Image
var collision_texture : Texture
var collision_image : Image

func _ready() -> void :
    scaler_node.scale = Vector2(SCALE, SCALE)

    original_texture = ResourceLoader.load("res://map_00.png")
    map_image = original_texture.get_data()

    var size := map_image.get_size()
    map_data.resize(size.x * size.y)
    
    map_image.lock()
    for y in range(0, size.y):
        for x in range(0, size.x):
            var index := calculate_index(x, y, size.x as int) 
            var color := map_image.get_pixel(x, y)
            var value := PIXEL_EMPTY
            if color.a > 0:
                value = PIXEL_BLOCK
            map_data.set(index, value)
    map_image.unlock()

    map_texture = ImageTexture.new()
    map_texture.create_from_image(map_image, 0)
    map_sprite.texture = map_texture

    collision_image = Image.new()
    collision_image.create(size.x as int, size.y as int, false, map_image.get_format())
    collision_texture = ImageTexture.new()

    update_map(0, 0, map_image.get_width(), map_image.get_height())

func _process(_delta) -> void :
    debug_label.set_text("FPS: %s" % Performance.get_monitor(Performance.TIME_FPS))

    if Input.is_action_just_released("debug_1"):
        collision_sprite.visible = !collision_sprite.visible

    if Input.is_action_just_released("debug_2"):
        map_sprite.visible = !map_sprite.visible

    if Input.is_key_pressed(KEY_SPACE):
        update_map(0, 0, map_image.get_width(), map_image.get_height())
        
    if Input.is_key_pressed(KEY_ESCAPE):
        quit_game()

func _unhandled_input(event) -> void:
    if event is InputEventMouseButton:
        if event.button_index == BUTTON_LEFT:
            if not event.pressed:
                var pointer_position_on_map = event.position / SCALE
                destroy_rect(pointer_position_on_map.x, pointer_position_on_map.y, 26, 26)

func destroy_rect(origin_x: int, origin_y: int, width: int, height: int) -> void :
    var pixels_to_delete : PoolIntArray = []
    var map_width := map_image.get_width()
    var map_height := map_image.get_height()

    for offset_x in range(-width / 2, width / 2):
        for offset_y in range(-height / 2, height / 2):
            var pos_x = origin_x + offset_x
            var pos_y = origin_y + offset_y
            if is_in_bounds(pos_x, pos_y, map_width, map_height):
                var index := calculate_index(pos_x, pos_y, map_width)
                pixels_to_delete.append(index)

    if pixels_to_delete.size() <= 0:
        return

    for index in pixels_to_delete:
        map_data[index] = PIXEL_EMPTY

    update_map(origin_x - width / 2, origin_y - height / 2, width, height)

func is_in_bounds(x: int, y: int, width: int, height: int) -> bool :
    return x > 0 && x <= width && y > 0 && y <= height

func quit_game() -> void :
    print("Quitting game...")
    get_tree().quit()

func update_map(x: int, y: int, width: int, height: int) -> void :
    # print("update_map: ", [x, y, width, height])
    var start := OS.get_ticks_usec()

    var map_width := map_image.get_width()
    var count := 0

    collision_image.lock()
    map_image.lock()
    for pixel_x in range(x, x + width):
        for pixel_y in range(y, y + height):
            var index := pixel_y * map_width + pixel_x
            var pixel := map_data[index]
            var pos_x := index % map_width
            var pos_y := index / map_width
            var color := Color.transparent
            if pixel== PIXEL_EMPTY:
                map_image.set_pixel(pos_x, pos_y, BACKGROUND_COLOR)
            else:
                color = Color.red
                color.a = 0.75
            collision_image.set_pixel(pos_x, pos_y, color)
            count += 1
    collision_image.unlock()
    map_image.unlock()

    collision_texture.create_from_image(collision_image, 0)
    collision_sprite.texture = collision_texture

    map_texture.create_from_image(map_image, 0)
    map_sprite.texture = map_texture
    
    var end := OS.get_ticks_usec()
    var time := (end - start) / 1000.0

    print("collision_update: %s pixels in %sms" % [count, time])

static func calculate_index(x: int, y: int, width: int) -> int :
    return y * width + x

static func calculate_position(index: int, width: int) -> Vector2 :
    return Vector2(index % width, index / width)
