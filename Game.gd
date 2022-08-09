extends Node2D
class_name Game

const SCALE : int = 5
const BACKGROUND_COLOR : Color = Color(0, 0.1, 0.2, 1)
const TICK_SPEED_IN_MILLISECONDS : int = 50

const PIXEL_EMPTY : int = 0
const PIXEL_BLOCK : int = 1
const UNITS_MAX : int = 100

onready var scaler_node : Node2D = get_node("%Scaler")
onready var map_sprite : Sprite = get_node("%Map")
onready var collision_sprite : Sprite = get_node("%Collision")
onready var debug_label : Label = get_node("%DebugLabel")
onready var debug_draw := get_node("%DebugCanvas")

var map_data : PoolIntArray = []
var units : Array = []
var units_count : int
var spawn_position : Vector2 = Vector2()
var next_tick : float
var original_texture : Texture
var map_texture : Texture
var map_image : Image
var collision_texture : Texture
var collision_image : Image

func _ready() -> void :
    units.resize(UNITS_MAX)
    scaler_node.scale = Vector2(SCALE, SCALE)

    original_texture = ResourceLoader.load("res://map_00.png")
    map_image = original_texture.get_data()

    var width := map_image.get_width()
    var height := map_image.get_height()
    map_data.resize(width * height)
    
    map_image.lock()
    for y in range(0, height):
        for x in range(0, width):
            var index := calculate_index(x, y, width as int) 
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
    collision_image.create(width, height, false, map_image.get_format())
    collision_texture = ImageTexture.new()

    update_map(0, 0, map_image.get_width(), map_image.get_height())

func _process(_delta) -> void :
    if Input.is_action_just_released("debug_1"):
        print("Toggle debug")
        collision_sprite.visible = !collision_sprite.visible
        debug_draw.visible = !debug_draw.visible
        
    if Input.is_action_just_released("debug_2"):
        print("Toggle map")
        map_sprite.visible = !map_sprite.visible

    if Input.is_action_just_released("ui_select"):
        update_map(0, 0, map_image.get_width(), map_image.get_height())

    if Input.is_action_just_released("ui_accept"):
        pass
        
    if Input.is_key_pressed(KEY_ESCAPE):
        quit_game()

    debug_label.set_text("FPS: %s" % Performance.get_monitor(Performance.TIME_FPS))

    var now := OS.get_ticks_msec()
    if now >= next_tick:
        tick()
        next_tick = now + TICK_SPEED_IN_MILLISECONDS

func _unhandled_input(event) -> void :
    if event is InputEventMouseButton:
        if event.button_index == BUTTON_LEFT:
            if not event.pressed:
                var map_position = pointer_to_map_position(event.position)
                destroy_rect(map_position.x, map_position.y, 26, 26)
        if event.button_index == BUTTON_RIGHT:
            if not event.pressed:
                var map_position = pointer_to_map_position(event.position)
                var unit := spawn_unit(map_position.x, map_position.y)
                print("%s spawned" % unit.name)

func tick() -> void : 
    var map_width := map_image.get_width()
    var map_height := map_image.get_height()

    for unit_index in range(0, units_count):
        var unit : Unit = units[unit_index]

        var destination := unit.position
        var unit_width := unit.texture.get_width()
        var unit_height := unit.texture.get_height()
        var ground_check_pos_x := unit.position.x
        var ground_check_pos_y := unit.position.y + unit_height / 2

        if not is_in_bounds(ground_check_pos_x, ground_check_pos_y, map_width, map_height):
            print("%s: OOB" % unit.name)
            continue
            
        var ground_check_index := calculate_index(ground_check_pos_x, ground_check_pos_y, map_width)
        var is_grounded := map_data[ground_check_index] == PIXEL_BLOCK
        debug_draw.add_rect(Rect2(ground_check_pos_x, ground_check_pos_y, 1, 1), Color.yellow)
        if is_grounded:
            var wall_check_pos_x : int = unit.position.x + unit.direction
            var wall_check_pos_y : int = unit.position.y + (unit_height / 2) - 1
            var destination_offset_y := 0
            var hit_wall := false

            for offset_y in range(0, -3, -1):
                var wall_check_pos_y_with_offset := wall_check_pos_y + offset_y
                var wall_check_index := calculate_index(wall_check_pos_x, wall_check_pos_y_with_offset, map_width)
                debug_draw.add_rect(Rect2(wall_check_pos_x, wall_check_pos_y_with_offset, 1, 1), Color.magenta)
                hit_wall = map_data[wall_check_index] == PIXEL_BLOCK

                if not hit_wall:
                    destination_offset_y = offset_y
                    break

            if hit_wall:
                # Turn around
                unit.direction *= -1
                unit.flip_h = unit.direction == -1
            else:
                # Walk forward
                destination.y += destination_offset_y
                destination.x += unit.direction
        else:
            # Fall down
            destination.y += 1
        
        unit.position = destination

func pointer_to_map_position(pos: Vector2) -> Vector2 :
    return pos / SCALE

func spawn_unit(x: int, y: int) -> Unit : 
    var unit := Unit.new()
    unit.name = "Unit %s" % units_count
    unit.texture = ResourceLoader.load("res://unit.png")
    unit.position.x = x
    unit.position.y = y

    units[units_count] = unit
    scaler_node.add_child(unit)

    units_count += 1

    return unit

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
    return x > 0 && x < width && y > 0 && y < height

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
