class_name Game
extends Node2D

enum JOBS {
    NONE = 1 << 0,
    CLIMB = 1 << 1,
    FLOAT = 1 << 2,
    EXPLODE = 1 << 3,
    BLOCK = 1 << 4, 
    BRIDGE = 1 << 5,
    DIG_HORIZONTAL = 1 << 6,
    MINE = 1 << 7,
    DIG_VERTICAL = 1 << 8,
}

enum TOOLS {
    NONE = 0,
    JOB_CLIMB = 1,
    JOB_FLOAT = 2,
    JOB_EXPLODE = 3,
    JOB_BLOCK = 4,
    JOB_BRIDGE = 5,
    JOB_DIG_HORIZONTAL = 6,
    JOB_MINE = 7,
    JOB_DIG_VERTICAL = 8,
    PAINT_RECT = 9,
    PAINT_CIRCLE = 10
    ERASE_RECT = 11,
    SPAWN_UNIT = 12,
    EXPLODE_ALL = 13,
}

enum PIXELS {
    EMPTY = 1 << 0
    BLOCK = 1 << 1
    PAINT = 1 << 2
}

signal level_unloaded
signal level_loaded

const GAME_SCALE : int = 6
const TICK_SPEED : int = 70
const TIME_SCALE : int = 1
const CURSOR_DEFAULT : int = 0
const CURSOR_BORDER : int = 1
const JOB_DIG_HORIZONTAL_DURATION : int = 750
const JOB_DIG_HORIZONTAL_STEP : int = 10
const JOB_DIG_VERTICAL_DURATION : int = 300
const JOB_DIG_VERTICAL_STEP : int = 10
const JOB_MINE_DURATION : int = 300
const JOB_MINE_STEP : int = 10
const JOB_EXPLODE_DURATION : int = 100
const JOB_EXPLODE_ANIM_DURATION : int = 27
const JOB_EXPLODE_STEP : int = 20
const JOB_FLOAT_DELAY : int = 10
const FALL_DURATION_FATAL : int = 55
const FALL_DURATION_FLOAT : int = 25
const FALL_SPLAT_ANIM_DURATION : int = 27

# Scene stuff
var map_image : Image
var collision_image : Image
var entrance_node : Node
var exit_node : Node
onready var config : Resource = ResourceLoader.load("res://default_game_config.tres")
onready var camera : Camera2D = get_node("%Camera")
onready var scaler_node : Node2D = get_node("%Scaler")
onready var map_sprite : Sprite = get_node("%Map")
onready var collision_sprite : Sprite = get_node("%Collision")
onready var debug_label : Label = get_node("%DebugLabel")
onready var debug_draw : Control = get_node("%DebugCanvas")
onready var title : Title = get_node("%Title")
onready var hud : HUD = get_node("%HUD")
onready var transitions : Transitions = get_node("%Transitions")
onready var action0_button : Button = get_node("%Action0")
onready var action1_button : Button = get_node("%Action1")
onready var action2_button : Button = get_node("%Action2")
onready var units_spawned_label : Label = get_node("%UnitsSpawnedLabel")
onready var units_exited_label : Label = get_node("%UnitsExitedLabel")
onready var units_dead_label : Label = get_node("%UnitsDeadLabel")
onready var audio_player_sound : AudioStreamPlayer = get_node("%SoundAudioPlayer")
onready var audio_player_music : AudioStreamPlayer = get_node("%MusicAudioPlayer")
onready var audio_bus_master : int = AudioServer.get_bus_index("Master")

# Game data
var current_level : int
var now : float
var now_tick : int
var is_ticking : bool
var game_scale : int
var next_tick_at : float
var tool_primary : int = TOOLS.JOB_DIG_VERTICAL
var tool_secondary : int = TOOLS.PAINT_RECT
var tool_tertiary : int = TOOLS.ERASE_RECT
var mouse_button_pressed : int
var debug_is_visible : bool
var global_explosion_at : int

# Level data
var units : Array = []
var units_spawned : int
var units_exited : int
var units_dead : int
var units_max : int
var units_goal : int
var map_data : PoolIntArray = []
var map_width : int
var map_height : int
var map_texture : Texture
var collision_texture : Texture
var entrance_position : Vector2
var exit_position : Vector2
var spawn_is_active : bool
var spawn_rate : int
var jobs_count : Dictionary

func _ready() -> void:
    now = OS.get_ticks_msec()
    game_scale = GAME_SCALE
    scaler_node.scale = Vector2(game_scale, game_scale)

    set_toggle_debug_visibility(false)
    if OS.is_debug_build():
        AudioServer.set_bus_mute(audio_bus_master, true)
        start_game()
        return

    title.open()
    var action = yield(title, "action_selected")
    match action:
        0: start_game()
        1: quit_game()
 
func _process(delta: float) -> void:
    now += delta * 1000 # Delta is in seconds, now in Milliseconds

    if Input.is_action_just_released("debug_1"):
        print("Toggling debug mode")
        set_toggle_debug_visibility(!debug_is_visible)
        
    if Input.is_action_just_released("debug_2"):
        print("Toggling map")
        map_sprite.visible = !map_sprite.visible

    if Input.is_action_just_released("debug_4"):
        print("Toggling audio mute")
        AudioServer.set_bus_mute(audio_bus_master, !AudioServer.is_bus_mute(audio_bus_master))
        
    if Input.is_action_just_released("debug_5"):
        print("Restarting level")
        unload_level()
        yield(self, "level_unloaded")
        load_level(config.levels[current_level])
        yield(self, "level_loaded")
        is_ticking = true
        start_level()
        
    if Input.is_action_just_released("debug_11"):
        print("Previous level")
        unload_level()
        yield(self, "level_unloaded")
        current_level -= 1
        load_level(config.levels[current_level])
        yield(self, "level_loaded")
        is_ticking = true
        start_level()

    if Input.is_action_just_released("debug_12"):
        print("Next level")
        unload_level()
        yield(self, "level_unloaded")
        current_level += 1
        load_level(config.levels[current_level])
        yield(self, "level_loaded")
        is_ticking = true
        start_level()

    if Input.is_key_pressed(KEY_ESCAPE):
        quit_game()

    if is_ticking:
        if Input.is_action_just_released("ui_down"):
            spawn_rate = clamp(spawn_rate + 10, 10, 100)
        if Input.is_action_just_released("ui_up"):
            spawn_rate = clamp(spawn_rate - 10, 10, 100)
        if Input.is_action_just_released("ui_left"):
            camera.position.x = clamp(camera.position.x - 10, 0, map_width - camera.get_viewport().size.x / game_scale)
        if Input.is_action_just_released("ui_right"):
            camera.position.x = clamp(camera.position.x + 10, 0, map_width - camera.get_viewport().size.x / game_scale)

        if Input.is_action_just_released("ui_accept"):
            game_scale = max(1, (game_scale + 1) % (GAME_SCALE + 1))
            scaler_node.scale = Vector2(game_scale, game_scale)

        if Input.is_key_pressed(KEY_SHIFT):
            Engine.time_scale = TIME_SCALE * 20
        else:
            Engine.time_scale = TIME_SCALE

        var mouse_map_position = get_mouse_position()

        # Update cursor
        var unit_index := get_unit_at(mouse_map_position.x, mouse_map_position.y)
        if unit_index > -1:
            set_cursor(CURSOR_BORDER)
        else:
            set_cursor(CURSOR_DEFAULT)

        if Input.is_mouse_button_pressed(BUTTON_LEFT):
            use_tool(tool_primary, mouse_map_position.x, mouse_map_position.y, true)
        elif Input.is_mouse_button_pressed(BUTTON_RIGHT):
            use_tool(tool_secondary, mouse_map_position.x, mouse_map_position.y, true)
        elif Input.is_mouse_button_pressed(BUTTON_MIDDLE):
            use_tool(tool_tertiary, mouse_map_position.x, mouse_map_position.y, true)

        debug_label.set_text(JSON.print({ 
            "FPS": Performance.get_monitor(Performance.TIME_FPS),
            "Scale": game_scale,
            "Units": "%s / %s" % [units_spawned, units.size()],
            "Spawn rate": spawn_rate,
            "Goal": "%s / %s" % [units_exited, units_goal],
            "Jobs": jobs_count,
        }, "  "))

        if now >= next_tick_at:
            tick()
            next_tick_at = now + TICK_SPEED

func start_game() -> void:
    title.close()
    yield(title, "closed")
    
    transitions.open(0.0)
    yield(transitions, "opened")

    set_cursor(CURSOR_DEFAULT)

    # Init UI
    action0_button.connect("pressed", self, "select_tool", [TOOLS.PAINT_RECT])
    action1_button.connect("pressed", self, "select_tool", [TOOLS.ERASE_RECT])
    action2_button.connect("pressed", self, "select_tool", [TOOLS.SPAWN_UNIT])
    hud.connect("tool_selected", self, "select_tool")

    collision_image = Image.new()

    # Load and start the level
    load_level(config.levels[current_level])
    yield(self, "level_loaded")
    is_ticking = true
    start_level()

func get_mouse_position() -> Vector2 :
    return camera.get_local_mouse_position() + camera.position

func _unhandled_input(event) -> void:
    if event is InputEventMouseMotion:
        pass

    if event is InputEventMouseButton:
        var map_position = get_mouse_position()
        if event.button_index == BUTTON_LEFT:
            use_tool(tool_primary, map_position.x, map_position.y, event.pressed)
        if event.button_index == BUTTON_RIGHT:
            use_tool(tool_secondary, map_position.x, map_position.y, event.pressed)
        if event.button_index == BUTTON_MIDDLE:
            use_tool(tool_tertiary, map_position.x, map_position.y, event.pressed)

func load_level(level: Level) -> void:
    # Initialize level data
    map_image = level.texture.get_data()
    units_max = level.units_max
    units_goal = level.units_goal
    spawn_rate = level.spawn_rate
    jobs_count = {}
    jobs_count[JOBS.CLIMB] = level.job_climb
    jobs_count[JOBS.FLOAT] = level.job_float
    jobs_count[JOBS.EXPLODE] = level.job_explode
    jobs_count[JOBS.BLOCK] = level.job_stop
    jobs_count[JOBS.BRIDGE] = level.job_bridge
    jobs_count[JOBS.DIG_HORIZONTAL] = level.job_dig_horizontal
    jobs_count[JOBS.MINE] = level.job_mine
    jobs_count[JOBS.DIG_VERTICAL] = level.job_dig_vertical

    var keys := jobs_count.keys()
    var first_selected := false
    for job_index in range(0, keys.size()):
        var job_id : int = keys[job_index]
        var count : int = jobs_count[job_id]
        if count > 0 && first_selected == false:
            select_tool(job_index + 1)
            first_selected = true

    units.resize(units_max)

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
            var value : int = PIXELS.EMPTY
            if color.a > 0:
                value = PIXELS.BLOCK
            if color.is_equal_approx(config.exit_color):
                exit_position = Vector2(x, y)
                value = PIXELS.EMPTY
            if color.is_equal_approx(config.entrance_color):
                entrance_position = Vector2(x, y)
                value = PIXELS.EMPTY
            map_data.set(index, value)
    map_image.unlock()

    # Prepare the images
    map_texture = ImageTexture.new()
    map_texture.create_from_image(map_image, 0)
    map_sprite.texture = map_texture
    collision_texture = ImageTexture.new()
    collision_image.create(map_width, map_height, false, map_image.get_format())

    # Spawn the entrance and exit
    if entrance_position == Vector2.ZERO:
        printerr("Could not find entrance position.")
        quit_game()
        return
    print("exit_position: ", exit_position)
    if exit_position == Vector2.ZERO:
        printerr("Could not find exit position.")
        quit_game()
        return
    entrance_node = level.entrance.instance()
    entrance_node.position = entrance_position
    map_sprite.add_child(entrance_node)
    exit_node = level.exit.instance()
    exit_node.position = exit_position
    map_sprite.add_child(exit_node)

    update_map(0, 0, map_width, map_height)

    yield(get_tree(), "idle_frame")
    # yield(get_tree().create_timer(1), "timeout")

    emit_signal("level_loaded")

func unload_level() -> void:
    transitions.open()
    yield(transitions, "opened")

    for unit_index in units_spawned:
        var unit : Unit = units[unit_index]
        unit.queue_free()
    units_spawned = 0
    units_exited = 0
    units_dead = 0

    debug_draw.update()

    collision_sprite.texture = null
    map_sprite.texture = null
    entrance_node.queue_free()
    exit_node.queue_free()

    audio_player_music.stop()

    emit_signal("level_unloaded")

func start_level() -> void:
    print_stray_nodes()
    
    var level : Level = config.levels[current_level]

    camera.position.x = level.camera_x
    camera.position.y = level.camera_y
    spawn_is_active = false

    hud.open()
    var keys := jobs_count.keys()
    for job_index in range(0, keys.size()):
        var job_id : int = keys[job_index]
        var count : int = jobs_count[job_id]
        hud.set_job_button_data(job_index + 1, String(count))
    
    yield(hud, "opened")

    transitions.close()
    yield(transitions, "closed")

    play_sound(config.sound_door_open)

    entrance_node.play("opening")
    yield(entrance_node, "animation_finished")
    spawn_is_active = true

    play_sound(config.sound_start)

    yield(get_tree().create_timer(2), "timeout")

    audio_player_music.stream = level.music
    audio_player_music.play()

func get_unit_at(x: int, y: int) -> int:
    if not is_in_bounds(x, y):
        return -1

    for unit_index in range(0, units_spawned):
        var unit = units[unit_index]
        if is_inside_rect(Vector2(x, y), unit.get_bounds_centered()):
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
    match tool_id:
        TOOLS.JOB_CLIMB, TOOLS.JOB_FLOAT, TOOLS.JOB_EXPLODE, TOOLS.JOB_BLOCK, TOOLS.JOB_DIG_HORIZONTAL, TOOLS.JOB_MINE, TOOLS.JOB_DIG_VERTICAL:
            use_job_tool(x, y, pressed, tool_id, JOBS.values()[tool_id])
            return

        TOOLS.PAINT_RECT:
            var size = 20
            paint_rect(x, y, size, size, PIXELS.BLOCK | PIXELS.PAINT)

        TOOLS.PAINT_CIRCLE:
            var size = 10
            paint_circle(x, y, size, PIXELS.BLOCK | PIXELS.PAINT)

        TOOLS.ERASE_RECT:
            var size = 20
            paint_rect(x, y, size, size, PIXELS.EMPTY)

        TOOLS.SPAWN_UNIT:
            if pressed:
                return
            if has_flag(x, y, PIXELS.BLOCK):
                return
                
            var unit := spawn_unit(x, y)
            print("%s spawned" % unit.name)

        TOOLS.EXPLODE_ALL:
            if pressed:
                return

            spawn_is_active = false
            global_explosion_at = now_tick + JOB_EXPLODE_DURATION + JOB_EXPLODE_ANIM_DURATION + 20

            for unit_index in range(0, units_spawned):
                var unit : Unit = units[unit_index]
                add_job(unit, JOBS.EXPLODE)

            play_sound(config.sound_assign_job)

        _:
            if pressed:
                return

            print("Tool not implemented: ", TOOLS.keys()[tool_id])
            return

    print("Used tool: %s at (%s,%s)" % [TOOLS.keys()[tool_id], x, y])

func select_tool(tool_id: int) -> void:
    print("Tool selected: ", TOOLS.keys()[tool_id])
    if tool_id < JOBS.size():
        tool_primary = tool_id
        hud.select_job(tool_id)
        return

    if tool_id == TOOLS.SPAWN_UNIT:
        tool_primary = tool_id

    use_tool(tool_id, 0, 0, false)

func use_job_tool(x: int, y: int, pressed: bool, tool_id: int, job_id: int) -> void:
    if not is_in_bounds(x, y):
        return

    if pressed:
        return

    if jobs_count[job_id] < 1:
        return

    var unit_index := get_unit_at(x, y)
    if unit_index == -1:
        return

    var unit : Unit = units[unit_index]
    if unit.has_job(job_id):
        return

    if not can_add_job(unit, job_id):
        return
    
    add_job(unit, job_id)
    play_sound(config.sound_assign_job)
    jobs_count[job_id] -= 1

    hud.set_job_button_data(tool_id, String(jobs_count[job_id]))

func set_toggle_debug_visibility(value: bool) -> void:
    collision_sprite.visible = value
    debug_draw.visible = value
    debug_label.visible = value
    debug_is_visible = value

func tick() -> void: 
    if not is_ticking:
        return

    if spawn_is_active:
        if now_tick % spawn_rate == 0:
            spawn_unit(entrance_position.x, entrance_position.y)
            if units_spawned >= units.size():
                spawn_is_active = false

    for unit_index in range(0, units_spawned):
        var unit : Unit = units[unit_index]

        if OS.is_debug_build():
            var jobs_str := ""
            for job_index in range(0, JOBS.size()):
                var job_id : int = JOBS.values()[job_index]
                if unit.has_job(job_id):
                    jobs_str += "%s " % JOBS.keys()[job_index]

            debug_draw.add_text(unit.position + Vector2(-5, -10), Unit.STATES.keys()[unit.state])
            debug_draw.add_text(unit.position + Vector2(-5, -7), jobs_str)

        if unit.status != Unit.STATUSES.ACTIVE:
            continue

        var destination := unit.position
        var ground_check_pos_x : int = unit.position.x
        var ground_check_pos_y : int = unit.position.y + unit.height / 2

        if not is_in_bounds(ground_check_pos_x, ground_check_pos_y):
            # print("%s: OOB" % unit.name)
            unit.state = Unit.STATES.DEAD_FALL
            unit.state_entered_at = now_tick

        if is_inside_rect(exit_position, Rect2(unit.position.x, unit.position.y, 1, unit.height)):
            unit.play("exit")
            unit.status = Unit.STATUSES.EXITED
            play_sound(config.sound_yippee, rand_range(0.9, 1.2))
            continue

        var is_grounded := has_flag(ground_check_pos_x, ground_check_pos_y, PIXELS.BLOCK)
        debug_draw.add_rect(Rect2(ground_check_pos_x, ground_check_pos_y, 1, 1), Color.yellow)

        if unit.has_job(JOBS.EXPLODE):
            var job = unit.jobs[JOBS.EXPLODE]
            if now_tick <= job.started_at + JOB_EXPLODE_DURATION:
                if (now_tick - job.started_at) % JOB_EXPLODE_STEP == 0:
                    var countdown : int = JOB_EXPLODE_DURATION / JOB_EXPLODE_STEP - (now_tick - job.started_at) / JOB_EXPLODE_STEP
                    unit.set_text(String(countdown))

            var timer_done : int = now_tick == job.started_at + JOB_EXPLODE_DURATION
            if timer_done:
                unit.set_text("")
                if is_grounded:
                    unit.state = Unit.STATES.IDLE
                    unit.state_entered_at = now_tick
                    unit.play("explode")
                play_sound(config.sound_deathrattle)

            var animation_done : int = now_tick == job.started_at + JOB_EXPLODE_DURATION + JOB_EXPLODE_ANIM_DURATION
            if animation_done:
                unit.status = Unit.STATUSES.DEAD
                play_sound(config.sound_explode, rand_range(1.0, 1.1))
                paint_circle(unit.position.x, unit.position.y, 9, PIXELS.EMPTY)
                var dust_particle = config.dust_particle_prefab.instance()
                dust_particle.position = unit.position
                dust_particle.emitting = true
                scaler_node.add_child(dust_particle)

        match unit.state:

            Unit.STATES.IDLE:
                pass

            Unit.STATES.FALLING:
                unit.jobs.erase(JOBS.BLOCK)
                unit.jobs.erase(JOBS.DIG_HORIZONTAL)
                unit.jobs.erase(JOBS.MINE)
                unit.jobs.erase(JOBS.DIG_VERTICAL)

                if is_grounded:
                    if now_tick >= unit.state_entered_at + FALL_DURATION_FATAL:
                        unit.state = Unit.STATES.DEAD_FALL
                        unit.state_entered_at = now_tick
                    else:
                        unit.state = Unit.STATES.WALKING
                        unit.state_entered_at = now_tick
                else:
                    if unit.has_job(JOBS.FLOAT) && now_tick >= unit.state_entered_at + FALL_DURATION_FLOAT:
                        unit.state = Unit.STATES.FLOATING
                        unit.state_entered_at = now_tick
                    else:
                        unit.play("fall")
                        destination.y += 1

            Unit.STATES.FLOATING:
                if is_grounded:
                    unit.state = Unit.STATES.WALKING
                    unit.state_entered_at = now_tick
                else:
                    unit.play("float")
                    if now_tick >= unit.state_entered_at + JOB_FLOAT_DELAY:
                        destination.y += 0.3
                    else:
                        destination.y += 1

            Unit.STATES.CLIMBING:
                var wall_pos_x := unit.position.x + 4 * unit.direction
                var hit_top_wall := has_flag(wall_pos_x, unit.position.y, PIXELS.EMPTY)
                var hit_ceiling := has_flag(unit.position.x, unit.position.y - unit.height / 2, PIXELS.BLOCK)

                if hit_ceiling:
                    unit.direction *= -1
                    unit.state = Unit.STATES.FALLING
                    unit.state_entered_at = now_tick
                elif hit_top_wall:
                    unit.state = Unit.STATES.CLIMBING_END
                    unit.state_entered_at = now_tick
                else:
                    unit.play("climb")
                    destination.y -= 1
                    
            Unit.STATES.CLIMBING_END:
                unit.play("climb_end")
                var wall_pos_x := unit.position.x + 4 * unit.direction
                var frames_count := unit.frames.get_frame_count("climb_end")
                var done := unit.frame == frames_count - 1
                if done:
                    destination.x = wall_pos_x
                    unit.state = Unit.STATES.WALKING
                    unit.state_entered_at = now_tick

            Unit.STATES.WALKING:
                if is_grounded:
                    if unit.has_job(JOBS.CLIMB):
                        var job = unit.jobs[JOBS.CLIMB]

                        var pos_x := unit.position.x + 4 * unit.direction

                        var wall_in_front = has_flag(pos_x, unit.position.y, PIXELS.BLOCK)
                        if wall_in_front:
                            unit.state = Unit.STATES.CLIMBING
                            unit.state_entered_at = now_tick

                    if unit.has_job(JOBS.DIG_HORIZONTAL):
                        var job = unit.jobs[JOBS.DIG_HORIZONTAL]

                        var job_first_tick = now_tick == job.started_at
                        if job_first_tick:
                            unit.play("dig_horizontal")
                            unit.stop()
                            
                        var is_done : int = now_tick >= job.started_at + job.duration
                        if not is_done:
                            var job_tick = (now_tick - job.started_at)
                            unit.frame = job_tick % unit.frames.get_frame_count("dig_horizontal")

                            # Dig only on the frames where the unit is digging in animation
                            if (unit.frame == 3 || unit.frame == 19):
                                var pos_x := unit.position.x + 4 * unit.direction
                                var dig_radius := unit.height / 2
                                paint_circle(pos_x, unit.position.y, dig_radius, PIXELS.EMPTY)

                                var wall_in_front = has_flag(pos_x + dig_radius - 1, unit.position.y + dig_radius - 1, PIXELS.BLOCK)
                                if not wall_in_front:
                                    unit.jobs.erase(JOBS.DIG_HORIZONTAL)

                            # Move only on the frames where the unit moves forward in animation
                            if (unit.frame == 11 || unit.frame == 12 || unit.frame == 13 || unit.frame == 14 ||
                                unit.frame == 27 || unit.frame == 28 || unit.frame == 29 || unit.frame == 30
                            ):
                                destination.x += 1 * unit.direction

                        continue

                    if unit.has_job(JOBS.MINE):
                        var job = unit.jobs[JOBS.MINE]

                        var job_first_tick = now_tick == job.started_at
                        if job_first_tick:
                            unit.play("mine")
                            unit.stop()
                            
                        var is_done : int = now_tick >= job.started_at + job.duration
                        if not is_done:
                            var job_tick = (now_tick - job.started_at)
                            unit.frame = job_tick % unit.frames.get_frame_count("mine")

                            # Dig only on the frames where the unit is digging in animation
                            if (unit.frame == 3 || unit.frame == 19):
                                var pos_x := unit.position.x + 6 * unit.direction
                                var pos_y := unit.position.y + 4
                                var dig_radius := unit.height / 2
                                paint_circle(pos_x, pos_y, dig_radius, PIXELS.EMPTY)

                                # var wall_in_front = has_flag(pos_x + dig_radius - 1, unit.position.y + dig_radius - 1, PIXELS.BLOCK)
                                # if not wall_in_front:
                                #     unit.jobs.erase(JOBS.MINE)

                            # Move only on the frames where the unit moves forward in animation
                            if (unit.frame == 11 || unit.frame == 12 || unit.frame == 13 || unit.frame == 14 ||
                                unit.frame == 27 || unit.frame == 28 || unit.frame == 29 || unit.frame == 30
                            ):
                                destination.x += 1 * unit.direction
                                destination.y += 1

                        continue

                    if unit.has_job(JOBS.DIG_VERTICAL):
                        unit.play("dig_vertical")
                        var job = unit.jobs[JOBS.DIG_VERTICAL]
                        if (now_tick - job.started_at) % JOB_DIG_VERTICAL_STEP == 0:
                            var rect := Rect2(unit.position.x, unit.position.y + 3, unit.width, 6)
                            debug_draw.add_rect(rect, Color.red)
                            paint_rect(rect.position.x, rect.position.y, rect.size.x, rect.size.y, PIXELS.EMPTY)
    
                            var is_not_done : int = now_tick < job.started_at + job.duration
                            if is_not_done:
                                destination.y += 1

                        continue

                    if unit.has_job(JOBS.BLOCK):
                        var job = unit.jobs[JOBS.BLOCK]
                        var rect = Rect2(unit.position.x, unit.position.y, unit.width, unit.height)
                        debug_draw.add_rect(rect, Color.red)
                        if now_tick == job.started_at:
                            unit.play("block")
                            paint_rect(rect.position.x, rect.position.y, rect.size.x, rect.size.y, PIXELS.BLOCK)

                        continue

                    var wall_check_pos_x : int = unit.position.x + unit.direction
                    var wall_check_pos_y : int = unit.position.y + (unit.height / 2) - 1
                    var destination_offset_y := 0
                    var hit_wall := false
                    
                    for offset_y in range(0, -unit.climb_step, -1):
                        var wall_check_pos_y_with_offset := wall_check_pos_y + offset_y
                        debug_draw.add_rect(Rect2(wall_check_pos_x, wall_check_pos_y_with_offset, 1, 1), Color.magenta)
                        hit_wall = has_flag(wall_check_pos_x, wall_check_pos_y_with_offset, PIXELS.BLOCK)

                        if not hit_wall:
                            destination_offset_y = offset_y
                            break

                    if hit_wall:
                        # Turn around
                        unit.direction *= -1
                    else:
                        for offset_y in range(1, unit.climb_step):
                            var step_down_pos_y_with_offset := wall_check_pos_y + offset_y
                            debug_draw.add_rect(Rect2(wall_check_pos_x, step_down_pos_y_with_offset, 1, 1), Color.teal)
                            if has_flag(wall_check_pos_x, step_down_pos_y_with_offset, PIXELS.BLOCK):
                                break
                            destination_offset_y = offset_y

                        # Walk forward
                        destination.y += destination_offset_y
                        destination.x += unit.direction

                        unit.play("walk")
                else:
                    unit.state = Unit.STATES.FALLING
                    unit.state_entered_at = now_tick

            Unit.STATES.DEAD_FALL:
                if now_tick == unit.state_entered_at + 1:
                    unit.play("dead_fall")
                    play_sound(config.sound_splat)

                if now_tick == unit.state_entered_at + FALL_SPLAT_ANIM_DURATION:
                    unit.status = Unit.STATUSES.DEAD
                    
        unit.flip_h = unit.direction == -1
        unit.position = destination
        
        for job_id in unit.jobs.keys():
            var job = unit.jobs[job_id]
            if job.duration > -1 && now_tick >= job.started_at + job.duration:
                var _did_erase = unit.jobs.erase(job_id)

    now_tick += 1

    units_exited = 0
    units_dead = 0
    for unit_index in range(0, units_spawned):
        var unit : Unit = units[unit_index]
        if unit.status == Unit.STATUSES.EXITED:
            units_exited += 1
        if unit.status == Unit.STATUSES.DEAD:
            unit.jobs.clear()
            unit.set_text("")
            unit.visible = false
            units_dead += 1

    if units_dead + units_exited == units_max || now_tick == global_explosion_at:
        is_ticking = false

        if units_exited >= units_goal:
            if current_level >= config.levels.size() - 1:
                print("Game over")
                unload_level()
                yield(self, "level_unloaded")
            else:
                print("Loading next level")
                yield(get_tree().create_timer(1), "timeout")
                unload_level()
                yield(self, "level_unloaded")
                current_level += 1
                load_level(config.levels[current_level])
                yield(self, "level_loaded")
                is_ticking = true
                start_level()
        else:
            print("Restarting current level")
            yield(get_tree().create_timer(1), "timeout")
            unload_level()
            yield(self, "level_unloaded")
            load_level(config.levels[current_level])
            yield(self, "level_loaded")
            is_ticking = true
            start_level()

    # Update UI
    units_spawned_label.text = "Out: %s" % units_spawned
    units_exited_label.text = "In: %s" % units_exited
    units_dead_label.text = "Dead: %s" % units_dead

func spawn_unit(x: int, y: int) -> Unit: 
    if units_spawned >= units.size():
        print("Max units reached (%s)" % units.size())
        return null

    var unit : Unit = config.unit_prefab.instance()
    unit.name = "Unit %s" % units_spawned
    unit.state = Unit.STATES.FALLING
    unit.state_entered_at = now_tick
    unit.position.x = x
    unit.position.y = y - unit.height / 2
    unit.speed_scale = TICK_SPEED / 50
    unit.play("fall")

    units[units_spawned] = unit
    scaler_node.add_child(unit)
    unit.set_text("")

    units_spawned += 1

    return unit

func paint_rect(origin_x: int, origin_y: int, width: int, height: int, value: int) -> void:
    var pixels_to_draw : PoolIntArray = []

    for offset_x in range(0, width):
        for offset_y in range(0, height):
            var pos_x = origin_x - width / 2 + offset_x
            var pos_y = origin_y - height / 2 + offset_y
            if is_in_bounds(pos_x, pos_y):
                var index := calculate_index(pos_x, pos_y, map_width)
                pixels_to_draw.append(index)

    if pixels_to_draw.size() <= 0:
        return

    for index in pixels_to_draw:
        map_data[index] = value

    update_map(origin_x - width / 2, origin_y - height / 2, width, height)

func paint_circle(origin_x: int, origin_y: int, radius: int, value: int) -> void:
    var pixels_to_draw : PoolIntArray = []

    for r in range(0, radius):
        for angle in range(0, 360):
            var pos_x : int = round(origin_x + r * cos(angle * PI / 180))
            var pos_y : int = round(origin_y + r * sin(angle * PI / 180))
            if is_in_bounds(pos_x, pos_y):
                var index := calculate_index(pos_x, pos_y, map_width)
                pixels_to_draw.append(index)

    if pixels_to_draw.size() <= 0:
        return

    for index in pixels_to_draw:
        map_data[index] = value

    update_map(origin_x - radius, origin_y - radius, radius * 2, radius * 2)

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

# TODO: Don't do collision update if not in debug mode
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
            if pixel != PIXELS.EMPTY:
                collision_color = Color.red
            collision_image.set_pixel(pos_x, pos_y, collision_color)

            if pixel == PIXELS.EMPTY:
                map_image.set_pixel(pos_x, pos_y, Color.transparent)
            elif has_flag(pos_x, pos_y, PIXELS.PAINT):
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

    # print("collision_update: %s pixels in %sms" % [count, time])

static func calculate_index(x: int, y: int, width: int) -> int:
    return y * width + x

static func calculate_position(index: int, width: int) -> Vector2:
    return Vector2(index % width, index / width)

func to_viewport_position(pos: Vector2) -> Vector2:
    return pos - camera.position

func play_sound(sound: AudioStream, pitch: float = 1.0) -> void:
    audio_player_sound.stream = sound
    audio_player_sound.pitch_scale = pitch
    audio_player_sound.play()

func add_job(unit: Unit, job_id: int) -> void:
    match job_id:
        JOBS.CLIMB:
            unit.jobs[JOBS.CLIMB] = {
                duration = -1,
                started_at = now_tick,
            }
        JOBS.FLOAT:
            unit.jobs[JOBS.FLOAT] = {
                duration = -1,
                started_at = now_tick,
            }
        JOBS.EXPLODE: 
            unit.jobs[JOBS.EXPLODE] = {
                duration = -1,
                started_at = now_tick,
            }
        JOBS.BLOCK:
            unit.jobs[JOBS.BLOCK] = {
                duration = -1,
                started_at = now_tick,
            }
        JOBS.DIG_HORIZONTAL:
            unit.jobs[JOBS.DIG_HORIZONTAL] = {
                duration = JOB_DIG_HORIZONTAL_DURATION,
                started_at = now_tick,
            }
        JOBS.MINE:
            unit.jobs[JOBS.MINE] = {
                duration = JOB_MINE_DURATION,
                started_at = now_tick,
            }
        JOBS.DIG_VERTICAL:
            unit.jobs[JOBS.DIG_VERTICAL] = {
                duration = JOB_DIG_VERTICAL_DURATION,
                started_at = now_tick,
            }
        _: 
            print("Job not implemented: ", job_id)
            return

func can_add_job(unit: Unit, job_id: int) -> bool:
    match job_id:
        JOBS.DIG_HORIZONTAL:
            var wall_in_front = has_flag(unit.position.x + 6 * unit.direction, unit.position.y, PIXELS.BLOCK)
            return wall_in_front

        _: 
            return true
