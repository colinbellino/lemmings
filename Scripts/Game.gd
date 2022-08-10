extends Node2D
class_name Game

const SCALE : int = 6
const TICK_SPEED_IN_MILLISECONDS : int = 50
const UNITS_MAX : int = 100

const PIXEL_EMPTY : int = 0
const PIXEL_SOLID : int = 1
const PIXEL_EXIT : int = 1 << 2
const TOOL_DESTROY_RECT : int = 0
const TOOL_SPAWN_UNIT : int = 1
const TOOL_JOB_DIG : int = 2

onready var scaler_node : Node2D = get_node("%Scaler")
onready var map_sprite : Sprite = get_node("%Map")
onready var collision_sprite : Sprite = get_node("%Collision")
onready var debug_label : Label = get_node("%DebugLabel")
onready var debug_draw := get_node("%DebugCanvas")
onready var action0_button := get_node("%Action0")
onready var action1_button := get_node("%Action1")
onready var action2_button := get_node("%Action2")

export var map_original_texture : Texture
export var cursor_default : Texture
export var cursor_border : Texture
export var unit_prefab : PackedScene
export var exit_prefab : PackedScene
export var exit_color: Color
export var entrance_prefab: PackedScene
export var entrance_color: Color
export var background_color : Color = Color(0, 0, 0, 0)

var tick_count : int
var next_tick_at : float
var tool_primary : int = TOOL_JOB_DIG
var tool_secondary : int = TOOL_SPAWN_UNIT
var units : Array = []
var units_count : int
var map_data : PoolIntArray = []
var map_texture : Texture
var map_image : Image
var map_width : int
var map_height : int
var collision_texture : Texture
var collision_image : Image
var entrance_position : Vector2
var entrance_node : Node
var exit_position : Vector2
var exit_node : Node

func _ready() -> void:
    units.resize(UNITS_MAX)
    scaler_node.scale = Vector2(SCALE, SCALE)

    map_image = map_original_texture.get_data()
    map_width = map_image.get_width()
    map_height = map_image.get_height()

    # Extract the map data from the image
    map_data.resize(map_width * map_height)
    map_image.lock()
    for y in range(0, map_height):
        for x in range(0, map_width):
            var index := calculate_index(x, y, map_width) 
            var color := map_image.get_pixel(x, y)
            var value := PIXEL_EMPTY
            if color.a > 0:
                value = PIXEL_SOLID
            if color.is_equal_approx(exit_color):
                exit_position = Vector2(x, y)
                value = PIXEL_EMPTY & PIXEL_EXIT
            if color.is_equal_approx(entrance_color):
                entrance_position = Vector2(x, y)
                value = PIXEL_EMPTY
            map_data.set(index, value)
    map_image.unlock()

    # Prepare the images
    map_texture = ImageTexture.new()
    map_texture.create_from_image(map_image, 0)
    map_sprite.texture = map_texture
    collision_image = Image.new()
    collision_image.create(map_width, map_height, false, map_image.get_format())
    collision_texture = ImageTexture.new()

    # Spawn the entrance and exit
    print("entrance_position: ", entrance_position)
    entrance_node = entrance_prefab.instance()
    entrance_node.position = entrance_position
    scaler_node.add_child(entrance_node)
    print("exit_position: ", exit_position)
    exit_node = exit_prefab.instance()
    exit_node.position = exit_position
    scaler_node.add_child(exit_node)

    update_map(0, 0, map_width, map_height)
    set_cursor(cursor_default)
    
    toggle_debug()
    action0_button.connect("pressed", self, "select_tool", [TOOL_DESTROY_RECT])
    action1_button.connect("pressed", self, "select_tool", [TOOL_SPAWN_UNIT])
    action2_button.connect("pressed", self, "select_tool", [TOOL_JOB_DIG])

func _process(_delta) -> void:
    if Input.is_action_just_released("debug_1"):
        toggle_debug()
        
    if Input.is_action_just_released("debug_2"):
        print("Toggle map")
        map_sprite.visible = !map_sprite.visible

    if Input.is_action_just_released("ui_select"):
        update_map(0, 0, map_width, map_height)

    if Input.is_action_just_released("ui_accept"):
        pass
        
    if Input.is_key_pressed(KEY_ESCAPE):
        quit_game()

    var mouse_position := get_viewport().get_mouse_position()
    var mouse_map_position := viewport_to_map_position(mouse_position)
    var unit_index := get_unit_at(mouse_map_position.x, mouse_map_position.y)
    if unit_index > -1:
        set_cursor(cursor_border)
    else:
        set_cursor(cursor_default)

    debug_label.set_text("FPS: %s" % Performance.get_monitor(Performance.TIME_FPS))

    var now := OS.get_ticks_msec()
    if now >= next_tick_at:
        tick()
        next_tick_at = now + TICK_SPEED_IN_MILLISECONDS

func _unhandled_input(event) -> void:
    if event is InputEventMouseMotion:
        pass
    elif event is InputEventMouseButton:
        if event.button_index == BUTTON_LEFT:
            if not event.pressed:
                var map_position = viewport_to_map_position(event.position)
                use_tool(tool_primary, map_position.x, map_position.y)
        if event.button_index == BUTTON_RIGHT:
            if not event.pressed:
                var map_position = viewport_to_map_position(event.position)
                use_tool(tool_secondary, map_position.x, map_position.y)

func get_unit_at(x: int, y: int) -> int:
    if not is_in_bounds(x, y):
        return -1

    for unit_index in range(0, units_count):
        var unit = units[unit_index]
        if is_inside_rect(Vector2(x, y), unit.get_bounds()):
            return unit_index

    return -1

func is_inside_rect(point: Vector2, rect: Rect2) -> bool:
    return (point.x >= rect.position.x && point.x <= rect.position.x + rect.size.x) \
        && (point.y >= rect.position.y && point.y <= rect.position.y + rect.size.y)

func set_cursor(cursor: Texture) -> void:
    Input.set_custom_mouse_cursor(cursor, Input.CURSOR_ARROW, Vector2(cursor.get_size() / 2))

func use_tool(tool_id: int, x: int, y: int) -> void: 
    if not is_in_bounds(x, y):
        return

    match tool_id:
        TOOL_DESTROY_RECT:
            var size = 20
            destroy_rect(x - size / 2, y - size / 2, size, size)
        TOOL_SPAWN_UNIT:
            if not has_flag(x, y, PIXEL_SOLID):
                var unit := spawn_unit(x, y)
                print("%s spawned" % unit.name)
        TOOL_JOB_DIG:
            var unit_index := get_unit_at(x, y)
            if unit_index > -1:
                var unit : Unit = units[unit_index]
                if unit.job_id == Unit.JOB_DIG:
                    unit.job_id = Unit.JOB_NONE
                else: 
                    unit.job_id = Unit.JOB_DIG
                    unit.job_duration = 300
                unit.job_started_at = tick_count

func select_tool(tool_id: int) -> void: 
    tool_primary = tool_id

func toggle_debug() -> void: 
    print("Toggle debug")
    collision_sprite.visible = !collision_sprite.visible
    debug_draw.visible = !debug_draw.visible

func tick() -> void: 
    for unit_index in range(0, units_count):
        var unit : Unit = units[unit_index]

        debug_draw.add_rect(unit.get_bounds(), Color.green)

        var destination := unit.position
        var ground_check_pos_x : int = unit.position.x
        var ground_check_pos_y : int = unit.position.y + unit.height / 2

        if not is_in_bounds(ground_check_pos_x, ground_check_pos_y):
            print("%s: OOB" % unit.name)
            continue

        if is_inside_rect(exit_position, Rect2(unit.position.x, unit.position.y, 1, unit.height)):
            unit.job_id = Unit.JOB_EXIT
            unit.job_started_at = tick_count
            unit.job_duration = 10

        if unit.job_id != Unit.JOB_NONE:
            if tick_count >= unit.job_started_at + unit.job_duration:
                unit.job_id = Unit.JOB_NONE

        # TODO: Check if we can walk down a pixel before falling
        var is_grounded := has_flag(ground_check_pos_x, ground_check_pos_y, PIXEL_SOLID)
        debug_draw.add_rect(Rect2(ground_check_pos_x, ground_check_pos_y, 1, 1), Color.yellow)
        if is_grounded:
            match unit.job_id:
                Unit.JOB_DIG:
                    unit.play("dig")
                    if (tick_count - unit.job_started_at) % 10 == 0:
                        var unit_rect := unit.get_bounds();
                        destroy_rect(unit_rect.position.x, unit_rect.position.y, unit_rect.size.x, unit_rect.size.y)
                        destination.y += 1
                Unit.JOB_EXIT:
                    unit.play("exit")
                    if (tick_count - unit.job_started_at) == unit.job_duration:
                        unit.visible = false
                _:
                    var wall_check_pos_x : int = unit.position.x + unit.direction
                    var wall_check_pos_y : int = unit.position.y + (unit.height / 2) - 1
                    var destination_offset_y := 0
                    var hit_wall := false
                    
                    for offset_y in range(0, -unit.climb_step, -1):
                        var wall_check_pos_y_with_offset := wall_check_pos_y + offset_y
                        debug_draw.add_rect(Rect2(wall_check_pos_x, wall_check_pos_y_with_offset, 1, 1), Color.magenta)
                        hit_wall = has_flag(wall_check_pos_x, wall_check_pos_y_with_offset, PIXEL_SOLID)

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

                        unit.play("walk")
        else:
            # Fall down
            unit.play("fall")
            destination.y += 1
        
        unit.position = destination

    tick_count += 1

func viewport_to_map_position(pos: Vector2) -> Vector2:
    return pos / SCALE

func spawn_unit(x: int, y: int) -> Unit: 
    var unit : Unit = unit_prefab.instance()
    unit.name = "Unit %s" % units_count
    unit.position.x = x
    unit.position.y = y - unit.height / 2

    units[units_count] = unit
    scaler_node.add_child(unit)

    units_count += 1

    return unit

func destroy_rect(origin_x: int, origin_y: int, width: int, height: int) -> void:
    var pixels_to_delete : PoolIntArray = []

    for offset_x in range(0, width):
        for offset_y in range(0, height):
            var pos_x = origin_x + offset_x
            var pos_y = origin_y + offset_y
            if is_in_bounds(pos_x, pos_y):
                var index := calculate_index(pos_x, pos_y, map_width)
                pixels_to_delete.append(index)

    if pixels_to_delete.size() <= 0:
        return

    for index in pixels_to_delete:
        map_data[index] = PIXEL_EMPTY

    update_map(origin_x, origin_y, width, height)

func has_flag(x: int, y: int, flag: int) -> bool: 
    if not is_in_bounds(x, y):
        return false
    var index := calculate_index(x, y, map_width)
    return map_data[index] & flag != 0

func is_in_bounds(x: int, y: int) -> bool:
    return x > 0 && x < map_width && y > 0 && y < map_height

func quit_game() -> void:
    print("Quitting game...")
    get_tree().quit()

func update_map(x: int, y: int, width: int, height: int) -> void:
    # print("update_map: ", [x, y, width, height])
    var start := OS.get_ticks_usec()

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
            if pixel == PIXEL_EMPTY:
                map_image.set_pixel(pos_x, pos_y, Color.transparent)
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

static func calculate_index(x: int, y: int, width: int) -> int:
    return y * width + x

static func calculate_position(index: int, width: int) -> Vector2:
    return Vector2(index % width, index / width)
