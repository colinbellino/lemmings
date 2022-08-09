extends Node2D

onready var map_sprite : Sprite = get_node("%Map")
onready var collision_sprite : Sprite = get_node("%Collision")
onready var debug_label : Label = get_node("%Debug")

var map_data : PoolIntArray = []

var map_texture : Texture
var map_image : Image
var collision_texture : Texture
var collision_image : Image

func _ready():
    map_texture = ResourceLoader.load("res://map_00.png")
    map_image = map_texture.get_data()

    var size := map_image.get_size()
    map_data.resize(size.x * size.y)
    
    map_image.lock()
    for y in range(0, size.y):
        for x in range(0, size.x):
            var index := calculate_index(x, y, size.x as int) 
            var color := map_image.get_pixel(x, y)
            var value := 1
            if color.a == 0:
                value = 0
            map_data.set(index, value)
    map_image.unlock()

    map_sprite.texture = map_texture

    collision_image = Image.new()
    collision_image.create(size.x as int, size.y as int, false, map_image.get_format())
    collision_texture = ImageTexture.new()
    collision_sprite.texture = collision_texture

    update_collision()

func _process(_delta):
    debug_label.set_text("FPS: %s" % Performance.get_monitor(Performance.TIME_FPS))

    if Input.is_action_just_released("debug_1"):
        collision_sprite.visible = !collision_sprite.visible

    if Input.is_action_just_released("debug_2"):
        map_sprite.visible = !map_sprite.visible

    if Input.is_key_pressed(KEY_SPACE):
        update_collision()
        
    if Input.is_key_pressed(KEY_ESCAPE):
        quit_game()

func quit_game() -> void :
    print("Quitting game...")
    get_tree().quit()

func update_collision() -> void :
    var start := OS.get_ticks_usec()

    var size := map_image.get_size()

    collision_image.lock()
    for index in range(0, map_data.size()):
        var pixel := map_data[index]
        var x := index % size.x as int
        var y := index / size.x as int
        var color := Color.transparent
        if pixel > 0:
            color = Color.red
            color.a = 0.5
        collision_image.set_pixel(x, y, color)
    collision_image.unlock()

    collision_texture.create_from_image(collision_image, 0)
    
    var end := OS.get_ticks_usec()
    var time := (end - start) / 1000.0

    print("collision_update: %sms" % [time])

static func calculate_index(x: int, y: int, width: int) -> int:
    return y * width + x

static func calculate_position(index: int, width: int) -> Vector2:
    return Vector2(index % width, index / width)
