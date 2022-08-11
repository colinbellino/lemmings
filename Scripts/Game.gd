extends Node2D
class_name Game

const GAME_SCALE : int = 6
const TICK_SPEED : int = 50
const TIME_SCALE : int = 1
const PIXEL_EMPTY : int = 0
const PIXEL_SOLID : int = 1
const PIXEL_PAINT : int = 1 << 2
const TOOL_DESTROY_RECT : int = 0
const TOOL_UNIT_SPAWN : int = 1
const TOOL_PAINT_RECT : int = 3
const TOOL_UNIT_DIG : int = 2
const CURSOR_DEFAULT : int = 0
const CURSOR_BORDER : int = 1
const JOB_DIG_DURATION : int = 145
const FALL_FATAL_DURATION : int = 50

# Scene stuff
var map_image : Image
var collision_image : Image
var entrance_node : Node
var exit_node : Node
onready var config : Resource = ResourceLoader.load("res://default_game_config.tres")
onready var scaler_node : Node2D = get_node("%Scaler")
onready var map_sprite : Sprite = get_node("%Map")
onready var collision_sprite : Sprite = get_node("%Collision")
onready var debug_label : Label = get_node("%DebugLabel")
onready var debug_draw : Control = get_node("%DebugCanvas")
onready var action0_button : Button = get_node("%Action0")
onready var action1_button : Button = get_node("%Action1")
onready var action2_button : Button = get_node("%Action2")
onready var audio_player_sound : AudioStreamPlayer = get_node("%SoundAudioPlayer")
onready var audio_player_music : AudioStreamPlayer = get_node("%MusicAudioPlayer")

# Game data
var current_level : int
var now : float
var now_tick : int
var is_ticking : bool
var game_scale : int
var next_tick_at : float
var tool_primary : int = TOOL_PAINT_RECT
var tool_secondary : int = TOOL_DESTROY_RECT
var tool_tertiary : int = TOOL_UNIT_DIG
var mouse_button_pressed : int
# Level data
var units : Array = []
var units_count : int
var units_exited_count : int
var units_dead_count : int
var units_max : int = 30
var units_goal_count : int = 10
var map_data : PoolIntArray = []
var map_texture : Texture
var map_width : int
var map_height : int
var collision_texture : Texture
var entrance_position : Vector2
var exit_position : Vector2
var spawn_is_active : bool
var spawn_rate : int = 50

func _ready() -> void:
    now = OS.get_ticks_msec()

    # Init scale
    game_scale = GAME_SCALE
    scaler_node.scale = Vector2(game_scale, game_scale)

    set_cursor(CURSOR_DEFAULT)

    toggle_debug()
    action0_button.connect("pressed", self, "select_tool", [TOOL_DESTROY_RECT])
    action1_button.connect("pressed", self, "select_tool", [TOOL_UNIT_SPAWN])
    action2_button.connect("pressed", self, "select_tool", [TOOL_UNIT_DIG])

    map_texture = ImageTexture.new()
    collision_image = Image.new()

    # Load and start the level
    load_level(config.levels[current_level])
    is_ticking = true
    start_level()
 
func _process(delta: float) -> void:
    now += delta * 1000 # Delta is in seconds, now in Milliseconds

    if Input.is_action_just_released("debug_1"):
        toggle_debug()
        
    if Input.is_action_just_released("debug_2"):
        map_sprite.visible = !map_sprite.visible
        
    if Input.is_action_just_released("debug_5"):
        print("Restarting level")
        is_ticking = false
        unload_level()
        load_level(config.levels[current_level])
        is_ticking = true
        start_level()

    if Input.is_action_just_released("ui_down"):
        spawn_rate = clamp(spawn_rate + 10, 10, 100)
    if Input.is_action_just_released("ui_up"):
        spawn_rate = clamp(spawn_rate - 10, 10, 100)

    if Input.is_action_just_released("ui_accept"):
        game_scale = max(1, (game_scale + 1) % (GAME_SCALE + 1))
        scaler_node.scale = Vector2(game_scale, game_scale)

    if Input.is_key_pressed(KEY_SHIFT):
        Engine.time_scale = TIME_SCALE * 6
    else:
        Engine.time_scale = TIME_SCALE
        
    if Input.is_key_pressed(KEY_ESCAPE):
        quit_game()

    var map_position = viewport_to_map_position(get_local_mouse_position())

    if Input.is_mouse_button_pressed(BUTTON_LEFT):
        use_tool(tool_primary, map_position.x, map_position.y, true)
    elif Input.is_mouse_button_pressed(BUTTON_RIGHT):
        use_tool(tool_secondary, map_position.x, map_position.y, true)
    elif Input.is_mouse_button_pressed(BUTTON_MIDDLE):
        use_tool(tool_tertiary, map_position.x, map_position.y, true)

    # Update cursor
    var mouse_position := get_viewport().get_mouse_position()
    var mouse_map_position := viewport_to_map_position(mouse_position)
    var unit_index := get_unit_at(mouse_map_position.x, mouse_map_position.y)
    if unit_index > -1:
        set_cursor(CURSOR_BORDER)
    else:
        set_cursor(CURSOR_DEFAULT)

    debug_label.set_text(JSON.print({ 
        "FPS": Performance.get_monitor(Performance.TIME_FPS),
        "Scale": game_scale,
        "Units": "%s / %s" % [units_count, units.size()],
        "Spawn rate": spawn_rate,
        "Goal": "%s / %s" % [units_exited_count, units_goal_count],
    }, "\t"))

    if now >= next_tick_at:
        tick()
        next_tick_at = now + TICK_SPEED

func _unhandled_input(event) -> void:
    if event is InputEventMouseMotion:
        pass

    if event is InputEventMouseButton:
        var map_position = viewport_to_map_position(event.position)
        if event.button_index == BUTTON_LEFT:
            use_tool(tool_primary, map_position.x, map_position.y, event.pressed)
        if event.button_index == BUTTON_RIGHT:
            use_tool(tool_secondary, map_position.x, map_position.y, event.pressed)
        if event.button_index == BUTTON_MIDDLE:
            use_tool(tool_tertiary, map_position.x, map_position.y, event.pressed)

# TODO: Init goal, rate, tools, etc
func load_level(texture: Texture) -> void:
    units.resize(units_max)
    
    map_image = texture.get_data()
    map_width = map_image.get_width()
    map_height = map_image.get_height()

    entrance_position = Vector2.ZERO
    exit_position = Vector2.ZERO

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
            if color.is_equal_approx(config.exit_color):
                exit_position = Vector2(x, y)
                value = PIXEL_EMPTY
            if color.is_equal_approx(config.entrance_color):
                entrance_position = Vector2(x, y)
                value = PIXEL_EMPTY
            map_data.set(index, value)
    map_image.unlock()

    if entrance_position == Vector2.ZERO:
        printerr("Could not find entrance position.")
        quit_game()
        return
    if exit_position == Vector2.ZERO:
        printerr("Could not find exit position.")
        quit_game()
        return

    # Prepare the images
    map_texture.create_from_image(map_image, 0)
    map_sprite.texture = map_texture
    collision_image.create(map_width, map_height, false, map_image.get_format())
    collision_texture = ImageTexture.new()

    # Spawn the entrance and exit
    print("entrance_position: ", entrance_position)
    entrance_node = config.entrance_prefab.instance()
    entrance_node.position = entrance_position
    map_sprite.add_child(entrance_node)
    print("exit_position: ", exit_position)
    exit_node = config.exit_prefab.instance()
    exit_node.position = exit_position
    map_sprite.add_child(exit_node)

    update_map(0, 0, map_width, map_height)

func unload_level() -> void:
    for unit_index in units_count:
        var unit : Unit = units[unit_index]
        unit.queue_free()
    units_count = 0
    units_exited_count = 0
    units_dead_count = 0

    collision_sprite.texture = null
    map_sprite.texture = null
    entrance_node.queue_free()
    exit_node.queue_free()

func start_level() -> void:
    print_stray_nodes()

    audio_player_music.stream = config.musics[0]
    audio_player_music.play()

    yield(get_tree().create_timer(1), "timeout")

    audio_player_sound.stream = config.sound_door_open
    audio_player_sound.play()

    entrance_node.play("opening")
    yield(entrance_node, "animation_finished")
    spawn_is_active = true

    audio_player_sound.stream = config.sound_start
    audio_player_sound.play()

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

func set_cursor(cursor_id: int) -> void:
    var cursor : Texture
    match cursor_id:
        CURSOR_DEFAULT:
            cursor = config.cursor_default_x1
            if game_scale >= 2:
                cursor = config.cursor_default_x2
            if game_scale >= 4:
                cursor = config.cursor_default_x4
        CURSOR_BORDER:
            cursor = config.cursor_border_x1
            if game_scale >= 2:
                cursor = config.cursor_border_x2
            if game_scale >= 4:
                cursor = config.cursor_border_x4

    Input.set_custom_mouse_cursor(cursor, Input.CURSOR_ARROW, Vector2(cursor.get_size() / 2))

func use_tool(tool_id: int, x: int, y: int, pressed: bool) -> void: 
    if not is_in_bounds(x, y):
        return

    match tool_id:
        TOOL_DESTROY_RECT:
            var size = 20
            destroy_rect(x - size / 2, y - size / 2, size, size)
        TOOL_PAINT_RECT:
            var size = 20
            paint_rect(x - size / 2, y - size / 2, size, size)
        TOOL_UNIT_SPAWN:
            if not pressed:
                if not has_flag(x, y, PIXEL_SOLID):
                    var unit := spawn_unit(x, y)
                    print("%s spawned" % unit.name)
        TOOL_UNIT_DIG:
            if not pressed:
                var unit_index := get_unit_at(x, y)
                if unit_index > -1:
                    var unit : Unit = units[unit_index]
                    if unit.job == Unit.JOBS.DIG_VERTICAL:
                        unit.job = Unit.JOBS.NONE
                    else: 
                        unit.job = Unit.JOBS.DIG_VERTICAL
                        unit.job_duration = JOB_DIG_DURATION
                        audio_player_sound.stream = config.sound_assign_job
                        audio_player_sound.play()
                    unit.job_started_at = now_tick

func select_tool(tool_id: int) -> void: 
    tool_primary = tool_id

func toggle_debug() -> void: 
    collision_sprite.visible = !collision_sprite.visible
    debug_draw.visible = !debug_draw.visible
    debug_label.visible = !debug_label.visible

func tick() -> void: 
    if not is_ticking:
        return

    if spawn_is_active:
        if now_tick % spawn_rate == 0:
            spawn_unit(entrance_position.x, entrance_position.y)
            if units_count >= units.size():
                spawn_is_active = false

    for unit_index in range(0, units_count):
        var unit : Unit = units[unit_index]

        debug_draw.add_text(
            unit.position + Vector2(-10, -10),
            "%s | %s" % [Unit.STATES.keys()[unit.state], Unit.JOBS.keys()[unit.job]],
            Color.white
        )

        if unit.status != Unit.STATUSES.ACTIVE:
            continue

        var destination := unit.position
        var ground_check_pos_x : int = unit.position.x
        var ground_check_pos_y : int = unit.position.y + unit.height / 2

        if not is_in_bounds(ground_check_pos_x, ground_check_pos_y):
            # print("%s: OOB" % unit.name)
            unit.state = Unit.STATES.DEAD
            unit.state_entered_at = now_tick

        if is_inside_rect(exit_position, Rect2(unit.position.x, unit.position.y, 1, unit.height)):
            unit.play("exit")
            unit.status = Unit.STATUSES.EXITED
            audio_player_sound.stream = config.sound_yippee
            audio_player_sound.pitch_scale = rand_range(0.9, 1.2)
            audio_player_sound.play()
            continue

        debug_draw.add_rect(unit.get_bounds(), Color.green)

        # TODO: Check if we can walk down a pixel before falling
        var is_grounded := has_flag(ground_check_pos_x, ground_check_pos_y, PIXEL_SOLID)
        debug_draw.add_rect(Rect2(ground_check_pos_x, ground_check_pos_y, 1, 1), Color.yellow)

        match unit.state:
            Unit.STATES.FALLING:
                if is_grounded:
                    if now_tick >= unit.state_entered_at + FALL_FATAL_DURATION:
                        unit.state = Unit.STATES.DEAD
                        unit.state_entered_at = now_tick
                    else:
                        unit.state = Unit.STATES.WALKING
                        unit.state_entered_at = now_tick
                else:
                    unit.play("fall")
                    destination.y += 1

            Unit.STATES.WALKING:
                if is_grounded:
                    match unit.job:
                        Unit.JOBS.DIG_VERTICAL:
                            unit.play("dig")
                            if (now_tick - unit.state_entered_at) % 10 == 0:
                                var unit_rect := Rect2(unit.position.x - unit.width / 2, unit.position.y + 3, unit.width, 3)
                                debug_draw.add_rect(unit_rect, Color.red)
                                destroy_rect(unit_rect.position.x, unit_rect.position.y, unit_rect.size.x, unit_rect.size.y)
        
                                var is_not_done := now_tick < unit.state_entered_at + JOB_DIG_DURATION
                                if is_not_done:
                                    destination.y += 1
                        Unit.JOBS.NONE:
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
                                for offset_y in range(1, unit.climb_step):
                                    var step_down_pos_y_with_offset := wall_check_pos_y + offset_y
                                    debug_draw.add_rect(Rect2(wall_check_pos_x, step_down_pos_y_with_offset, 1, 1), Color.teal)
                                    if has_flag(wall_check_pos_x, step_down_pos_y_with_offset, PIXEL_SOLID):
                                        break
                                    destination_offset_y = offset_y

                                # Walk forward
                                destination.y += destination_offset_y
                                destination.x += unit.direction

                                unit.play("walk")
                else:
                    unit.state = Unit.STATES.FALLING
                    unit.state_entered_at = now_tick

            Unit.STATES.DEAD:
                unit.status = Unit.STATUSES.DEAD
                unit.play("dead_fall")
                audio_player_sound.stream = config.sound_splat
                audio_player_sound.pitch_scale = rand_range(0.9, 1.2)
                audio_player_sound.play()
                
        unit.position = destination
        
        if unit.job_duration > -1 && now_tick >= unit.job_started_at + unit.job_duration:
            unit.job = Unit.JOBS.NONE

    now_tick += 1

    units_exited_count = 0
    units_dead_count = 0
    for unit_index in range(0, units_count):
        var unit : Unit = units[unit_index]
        if unit.status == Unit.STATUSES.EXITED:
            units_exited_count += 1
        if unit.status == Unit.STATUSES.DEAD:
            units_dead_count += 1

    if units_dead_count + units_exited_count == units_max:
        is_ticking = false

        if units_exited_count >= units_goal_count:
            if current_level >= config.levels.size() - 1:
                print("Game over")
                unload_level()
            else:
                print("Loading next level")
                yield(get_tree().create_timer(2), "timeout")
                unload_level()
                current_level += 1
                load_level(config.levels[current_level])
                is_ticking = true
                start_level()
        else:
            print("Restarting current level")
            yield(get_tree().create_timer(2), "timeout")
            unload_level()
            load_level(config.levels[current_level])
            is_ticking = true
            start_level()

func viewport_to_map_position(pos: Vector2) -> Vector2:
    return pos / game_scale

func spawn_unit(x: int, y: int) -> Unit: 
    if units_count >= units.size():
        print("Max units reached (%s)" % units.size())
        return null

    var unit : Unit = config.unit_prefab.instance()
    unit.name = "Unit %s" % units_count
    unit.position.x = x
    unit.position.y = y - unit.height / 2
    unit.play("fall")

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
    
func paint_rect(origin_x: int, origin_y: int, width: int, height: int) -> void:
    var pixels_to_draw : PoolIntArray = []

    for offset_x in range(0, width):
        for offset_y in range(0, height):
            var pos_x = origin_x + offset_x
            var pos_y = origin_y + offset_y
            if is_in_bounds(pos_x, pos_y):
                var index := calculate_index(pos_x, pos_y, map_width)
                pixels_to_draw.append(index)

    if pixels_to_draw.size() <= 0:
        return

    for index in pixels_to_draw:
        map_data[index] = PIXEL_SOLID | PIXEL_PAINT

    update_map(origin_x, origin_y, width, height)

func has_flag(x: int, y: int, flag: int) -> bool: 
    if not is_in_bounds(x, y):
        return false
    var index := calculate_index(x, y, map_width)
    return map_data[index] & flag != 0

func is_in_bounds(x: int, y: int) -> bool:
    return x >= 0 && x < map_width && y >= 0 && y < map_height

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
            if index < 0 || index >= map_data.size():
                continue
            var pixel := map_data[index]
            var pos_x := index % map_width
            var pos_y := index / map_width
            
            var collision_color := Color.transparent
            if pixel != PIXEL_EMPTY:
                collision_color = Color.red
            collision_image.set_pixel(pos_x, pos_y, collision_color)

            if pixel == PIXEL_EMPTY:
                map_image.set_pixel(pos_x, pos_y, Color.transparent)
            elif has_flag(pos_x, pos_y, PIXEL_PAINT):
                map_image.set_pixel(pos_x, pos_y, Color.blue)
                    
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
