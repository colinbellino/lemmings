class_name Game
extends Node2D

signal level_unloaded
signal level_loaded

const JOB_CLIMBER_ANIM_DURATION : int = 0
const JOB_FLOATER_ANIM_DURATION : int = 0
const JOB_FLOATER_FLOATER_DELAY : int = 7
const JOB_BOMBER_DURATION : int = 100
const JOB_BOMBER_STEP : int = 20
const JOB_BLOCKER_ANIM_DURATION : int = 0
const JOB_BUILDER_DURATION : int = 200
const JOB_BUILDER_STEP : int = 10
const JOB_BUILDER_DESTROY_RADIUS : int = 5
const JOB_BUILDER_ANIM_DURATION : int = 0
const JOB_BASHER_DURATION : int = 300
const JOB_BASHER_STEP : int = 10
const JOB_BASHER_ANIM_DURATION : int = 0
const JOB_MINER_DURATION : int = 300
const JOB_MINER_STEP : int = 10
const JOB_MINER_DESTROY_RADIUS : int = 5
const JOB_MINER_ANIM_DURATION : int = 0
const JOB_DIGGER_DURATION : int = 300
const JOB_DIGGER_STEP : int = 10
const JOB_DIGGER_ANIM_DURATION : int = 0

const GAME_SCALE : int = 6
const TICK_SPEED : int = 70
const TIME_SCALE : int = 1
const CURSOR_DEFAULT : int = 0
const CURSOR_BORDER : int = 1
const FALL_DURATION_FATAL : int = 55
const FALL_DURATION_FLOAT : int = 25
const FALL_SPLAT_ANIM_DURATION : int = 27
const LEVEL_END_DELAY : int = 20

class GameData:
    var now : float
    var now_tick : int
    var is_ticking : bool
    var next_tick_at : float
    var trigger_end_at : int
    var map_data : PoolIntArray
    var units : Array
    var units_spawned : int
    var units_exited : int
    var units_dead : int

class LevelData:
    var units_max : int
    var units_goal : int
    var map_width : int
    var map_height : int
    var map_texture : ImageTexture
    var collision_texture : ImageTexture
    var entrance_position : Vector2
    var exit_position : Vector2
    var spawn_is_active : bool
    var spawn_rate : int
    var jobs_count : Dictionary
    var color : Color

# Scene stuff
onready var config : GameConfig
onready var camera : Camera2D = get_node("%Camera")
onready var scaler_node : Node2D = get_node("%Scaler")
onready var map_sprite : Sprite = get_node("%Map")
onready var collision_sprite : Sprite = get_node("%Collision")
onready var debug_label : Label = get_node("%DebugLabel")
onready var debug_draw : DebugDraw = get_node("%DebugCanvas")
onready var title : Title = get_node("%Title")
onready var hud : HUD = get_node("%HUD")
onready var transitions : Transitions = get_node("%Transitions")
onready var action0_button : Button = get_node("%Action0")
onready var action1_button : Button = get_node("%Action1")
onready var action2_button : Button = get_node("%Action2")
onready var audio_player_sound : AudioStreamPlayer = get_node("%SoundAudioPlayer")
onready var audio_player_music : AudioStreamPlayer = get_node("%MusicAudioPlayer")
onready var audio_bus_master : int = AudioServer.get_bus_index("Master")
var map_image : Image
var collision_image : Image
var entrance_node : AnimatedSprite
var exit_node : Node2D

# Game data
var current_level : int
var tool_primary : int = Enums.TOOLS.JOB_DIGGER
var tool_secondary : int = Enums.TOOLS.PAINT_RECT
var tool_tertiary : int = Enums.TOOLS.ERASE_RECT
var mouse_button_pressed : int
var debug_is_visible : bool
var game_scale : int
var game_data : GameData
var level_data : LevelData

func _ready() -> void:
    game_data = GameData.new()
    config = ResourceLoader.load("res://default_game_config.tres")

    # Init UI
    action0_button.connect("pressed", self, "select_tool", [Enums.TOOLS.PAINT_RECT])
    action1_button.connect("pressed", self, "select_tool", [Enums.TOOLS.ERASE_RECT])
    action2_button.connect("pressed", self, "select_tool", [Enums.TOOLS.SPAWN_UNIT])
    hud.connect("tool_selected", self, "select_tool")
    hud.connect("spawn_rate_up_pressed", self, "spawn_rate_up")
    hud.connect("spawn_rate_down_pressed", self, "spawn_rate_down")

    set_toggle_debug_visibility(false)

    if OS.is_debug_build():
        AudioServer.set_bus_mute(audio_bus_master, true)
        start_game()
        return

    start_title()

func _process(delta: float) -> void:
    game_data.now += delta * 1000 # Delta is in seconds, now in Milliseconds

    for i in range(1, 12):
        if Input.is_key_pressed(KEY_SHIFT) && Input.is_action_just_released("debug_%s" % i):
            current_level = i - 1
            print("[DEBUG] Loading level: %s" % [current_level])

            unload_level()
            yield(self, "level_unloaded")

            load_level(config.levels[current_level])
            yield(self, "level_loaded")
            start_level()

            return

    if Input.is_action_just_released("debug_1"):
        print("[DEBUG] Toggling debug mode")
        set_toggle_debug_visibility(!debug_is_visible)
        debug_draw.update()
        return

    if Input.is_action_just_released("debug_2"):
        print("[DEBUG] Toggling map")
        map_sprite.visible = !map_sprite.visible
        return

    if Input.is_action_just_released("debug_4"):
        print("[DEBUG] Toggling audio mute")
        AudioServer.set_bus_mute(audio_bus_master, !AudioServer.is_bus_mute(audio_bus_master))
        return

    if Input.is_action_just_released("debug_5"):
        print("[DEBUG] Restarting level")

        unload_level()
        yield(self, "level_unloaded")

        load_level(config.levels[current_level])
        yield(self, "level_loaded")

        start_level()
        return

    if Input.is_action_just_released("debug_6"):
        var filename := "res://Screenshots/%s.png" % OS.get_system_time_msecs()
        var image := get_viewport().get_texture().get_data()#.get_rect(Rect2(0, get_viewport().size.y - 180, 320, 180))
        image.flip_y()
        image.save_png(filename)
        print("[DEBUG] Screenshot taken: ", filename)
        return

    if Input.is_action_just_released("debug_11"):
        print("[DEBUG] Previous level")

        unload_level()
        yield(self, "level_unloaded")

        current_level -= 1

        load_level(config.levels[current_level])
        yield(self, "level_loaded")

        start_level()
        return

    if Input.is_action_just_released("debug_12"):
        print("[DEBUG] Next level")

        unload_level()
        yield(self, "level_unloaded")

        current_level += 1

        if current_level > config.levels.size() - 1:
            current_level = 0
            start_title()
        else:
            load_level(config.levels[current_level])
            yield(self, "level_loaded")

            start_level()

        return

    if Input.is_key_pressed(KEY_ESCAPE):
        quit_game()
        return

    if Input.is_action_just_released("ui_select"):
        game_data.is_ticking = !game_data.is_ticking
        if game_data.is_ticking:
            Engine.time_scale = TIME_SCALE
        else:
            Engine.time_scale = 0
        print("[DEBUG] Toggling pause")

    # if Input.is_action_just_released("ui_accept"):
    #     game_scale = int(max(1, (game_scale + 1) % (GAME_SCALE + 1)))
    #     scaler_node.scale = Vector2(game_scale, game_scale)
    #     debug_draw.update()
    #     return

    # Update cursor
    var mouse_map_position := get_mouse_position()
    if level_data != null:
        var unit_index := get_unit_at(int(mouse_map_position.x), int(mouse_map_position.y))
        if unit_index > -1:
            set_cursor(CURSOR_BORDER)
        else:
            set_cursor(CURSOR_DEFAULT)

    if game_data.is_ticking:
        if Input.is_action_just_released("ui_down"):
            increase_spawn_rate(-10)
        if Input.is_action_just_released("ui_up"):
            increase_spawn_rate(10)
        if Input.is_action_just_released("ui_left"):
            camera.position.x = clamp(camera.position.x - 10, 0, level_data.map_width - camera.get_viewport().size.x / game_scale)
        if Input.is_action_just_released("ui_right"):
            camera.position.x = clamp(camera.position.x + 10, 0, level_data.map_width - camera.get_viewport().size.x / game_scale)

        if Input.is_key_pressed(KEY_SHIFT):
            Engine.time_scale = TIME_SCALE * 100
        else:
            Engine.time_scale = TIME_SCALE

        if Input.is_mouse_button_pressed(BUTTON_LEFT):
            use_tool(tool_primary, int(mouse_map_position.x), int(mouse_map_position.y), true)
        elif Input.is_mouse_button_pressed(BUTTON_RIGHT):
            use_tool(tool_secondary, int(mouse_map_position.x), int(mouse_map_position.y), true)
        elif Input.is_mouse_button_pressed(BUTTON_MIDDLE):
            use_tool(tool_tertiary, int(mouse_map_position.x), int(mouse_map_position.y), true)

        debug_label.set_text(JSON.print({
            "FPS": Performance.get_monitor(Performance.TIME_FPS),
            "Scale": game_scale,
            "Units": "%s / %s" % [game_data.units_spawned, game_data.units.size()],
            "Spawn rate": level_data.spawn_rate,
            "Goal": "%s / %s" % [game_data.units_exited, level_data.units_goal],
            "Jobs": level_data.jobs_count,
        }, "  "))

        if game_data.now >= game_data.next_tick_at:
            tick()
            game_data.now_tick += 1
            game_data.next_tick_at = game_data.now + TICK_SPEED / Engine.time_scale

    else:
        if OS.is_debug_build():
            if Input.is_action_just_released("ui_left"):
                # game_data.now_tick -= 1
                # tick()
                # print("Previous tick: ", game_data.now_tick)
                pass
            if Input.is_action_just_released("ui_right"):
                print("Next tick: ", game_data.now_tick)
                tick()
                debug_draw.update()
                game_data.now_tick += 1

func start_title() -> void:
    print("Opening title screen")
    audio_player_music.stream = config.music_title
    audio_player_music.volume_db = 0.0
    audio_player_music.play()

    transitions.close(0.0)
    yield(transitions, "closed")

    title.open()
    var action = yield(title, "action_selected")
    match action:
        0: start_game()
        1: quit_game()

func start_game() -> void:
    game_data = GameData.new()
    game_data.now = OS.get_ticks_msec()

    var tween := create_tween()
    tween.tween_property(audio_player_music, "volume_db", -80.0, 1.0)

    game_scale = GAME_SCALE
    scaler_node.scale = Vector2(game_scale, game_scale)

    title.close()
    yield(title, "closed")

    transitions.open(0.0)
    yield(transitions, "opened")

    set_cursor(CURSOR_DEFAULT)

    collision_image = Image.new()

    # Load and start the level
    load_level(config.levels[current_level])
    yield(self, "level_loaded")
    game_data.is_ticking = true
    start_level()

func get_mouse_position() -> Vector2 :
    return camera.get_local_mouse_position() + camera.position

func _unhandled_input(event) -> void:
    if event is InputEventMouseMotion:
        pass

    if event is InputEventMouseButton:
        var map_position := get_mouse_position()
        if event.button_index == BUTTON_LEFT:
            use_tool(tool_primary, int(map_position.x), int(map_position.y), event.pressed)
        if event.button_index == BUTTON_RIGHT:
            use_tool(tool_secondary, int(map_position.x), int(map_position.y), event.pressed)
        if event.button_index == BUTTON_MIDDLE:
            use_tool(tool_tertiary, int(map_position.x), int(map_position.y), event.pressed)

func load_level(level: Level) -> void:
    var level_type : LevelType = level.type
    # Initialize level data
    map_image = level.texture.get_data()
    level_data = LevelData.new()
    level_data.units_max = level.units_max
    level_data.units_goal = level.units_goal
    level_data.spawn_rate = level.spawn_rate
    level_data.color = level_type.color
    increase_spawn_rate(0) # Just to make sure it's clamped to a valid value
    level_data.jobs_count = {}
    level_data.jobs_count[Enums.JOBS.CLIMBER] = level.job_climber
    level_data.jobs_count[Enums.JOBS.FLOATER] = level.job_floater
    level_data.jobs_count[Enums.JOBS.BOMBER] = level.job_bomber
    level_data.jobs_count[Enums.JOBS.BLOCKER] = level.job_blocker
    level_data.jobs_count[Enums.JOBS.BUILDER] = level.job_builder
    level_data.jobs_count[Enums.JOBS.BASHER] = level.job_basher
    level_data.jobs_count[Enums.JOBS.MINER] = level.job_miner
    level_data.jobs_count[Enums.JOBS.DIGGER] = level.job_digger

    var keys := level_data.jobs_count.keys()
    var first_selected := false
    for job_index in range(0, keys.size()):
        var job_id : int = keys[job_index]
        var count : int = level_data.jobs_count[job_id]
        if count > 0 && first_selected == false:
            select_tool(job_index + 1)
            first_selected = true

    var units := []
    units.resize(level_data.units_max)
    game_data.units = units

    level_data.map_width = map_image.get_width()
    level_data.map_height = map_image.get_height()

    level_data.entrance_position = Vector2.ZERO
    level_data.exit_position = Vector2.ZERO

    # Extract the map data from the image
    var map_data : PoolIntArray = []
    map_data.resize(level_data.map_width * level_data.map_height)
    map_image.lock()
    for y in range(0, level_data.map_height):
        for x in range(0, level_data.map_width):
            var index := calculate_index(x, y, level_data.map_width)
            var color := map_image.get_pixel(x, y)
            var value : int = Enums.PIXELS.EMPTY
            if color.a > 0:
                value = Enums.PIXELS.BLOCK
            if color.is_equal_approx(config.exit_color):
                level_data.exit_position = Vector2(x, y)
                value = Enums.PIXELS.EMPTY
            if color.is_equal_approx(config.entrance_color):
                level_data.entrance_position = Vector2(x, y)
                value = Enums.PIXELS.EMPTY
            map_data.set(index, value)
    map_image.unlock()
    game_data.map_data = map_data

    # Prepare the images
    level_data.map_texture = ImageTexture.new()
    level_data.map_texture.create_from_image(map_image, 0)
    map_sprite.texture = level_data.map_texture
    level_data.collision_texture = ImageTexture.new()
    collision_image.create(level_data.map_width, level_data.map_height, false, map_image.get_format())

    # Spawn the entrance and exit
    # print("level_data.entrance_position: ", level_data.entrance_position)
    if level_data.entrance_position == Vector2.ZERO:
        printerr("Could not find entrance position.")
        quit_game()
        return
    # print("level_data.exit_position: ", level_data.exit_position)
    if level_data.exit_position == Vector2.ZERO:
        printerr("Could not find exit position.")
        quit_game()
        return
    entrance_node = level_type.entrance.instance()
    entrance_node.position = level_data.entrance_position
    map_sprite.add_child(entrance_node)
    exit_node = level_type.exit.instance()
    exit_node.position = level_data.exit_position + Vector2(0, 1)
    map_sprite.add_child(exit_node)

    update_map(0, 0, level_data.map_width, level_data.map_height)

    yield(get_tree(), "idle_frame")
    # yield(get_tree().create_timer(1), "timeout")

    emit_signal("level_loaded")

func unload_level() -> void:
    var tween := create_tween()
    tween.tween_property(audio_player_music, "volume_db", -80.0, 1.0)

    transitions.open()
    yield(transitions, "opened")
    hud.close()
    yield(hud, "closed")

    for unit_index in game_data.units_spawned:
        var unit : Unit = game_data.units[unit_index]
        unit.queue_free()
    game_data.units_spawned = 0
    game_data.units_exited = 0
    game_data.units_dead = 0
    game_data.trigger_end_at = 0

    debug_draw.update()

    collision_sprite.texture = null
    map_sprite.texture = null
    entrance_node.queue_free()
    exit_node.queue_free()

    game_data.is_ticking = false

    emit_signal("level_unloaded")

func start_level() -> void:
    print_stray_nodes()

    game_data.is_ticking = true

    var level : Level = config.levels[current_level]

    camera.position.x = level.camera_x
    camera.position.y = level.camera_y
    level_data.spawn_is_active = false

    hud.open()
    var keys := level_data.jobs_count.keys()
    for job_index in range(0, keys.size()):
        var job_id : int = keys[job_index]
        var count : int = level_data.jobs_count[job_id]
        hud.set_job_button_data(job_index + 1, String(count))

    yield(hud, "opened")

    transitions.close()
    yield(transitions, "closed")

    play_sound(config.sound_door_open)

    entrance_node.play("opening")
    yield(entrance_node, "animation_finished")
    level_data.spawn_is_active = true

    play_sound(config.sound_start)

    yield(get_tree().create_timer(2), "timeout")

    audio_player_music.stream = level.music
    audio_player_music.volume_db = 0.0
    audio_player_music.play()

func get_unit_at(x: int, y: int) -> int:
    if not is_in_bounds(x, y):
        return -1

    for unit_index in range(0, game_data.units_spawned):
        var unit : Unit = game_data.units[unit_index]
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
        Enums.TOOLS.JOB_CLIMBER, Enums.TOOLS.JOB_FLOATER, Enums.TOOLS.JOB_BOMBER, Enums.TOOLS.JOB_BLOCKER, Enums.TOOLS.JOB_BASHER, Enums.TOOLS.JOB_MINER, Enums.TOOLS.JOB_DIGGER, Enums.TOOLS.JOB_BUILDER:
            use_job_tool(x, y, pressed, tool_id, Enums.JOBS.values()[tool_id])
            return

        Enums.TOOLS.PAINT_RECT:
            var size := 20
            paint_rect(x, y, size, size, Enums.PIXELS.BLOCK | Enums.PIXELS.PAINT)

        Enums.TOOLS.PAINT_CIRCLE:
            var size := 10
            paint_circle(x, y, size, Enums.PIXELS.BLOCK | Enums.PIXELS.PAINT)

        Enums.TOOLS.ERASE_RECT:
            var size := 20
            paint_rect(x, y, size, size, Enums.PIXELS.EMPTY)

        Enums.TOOLS.SPAWN_UNIT:
            if pressed:
                return
            if has_flag(x, y, Enums.PIXELS.BLOCK):
                return

            var unit := spawn_unit(x, y)
            print("%s spawned" % unit.name)

        Enums.TOOLS.BOMB_ALL:
            if pressed:
                return

            level_data.spawn_is_active = false
            play_sound(config.sound_assign_job)

            if game_data.units_spawned == 0:
                return

            game_data.trigger_end_at = game_data.now_tick + JOB_BOMBER_DURATION + game_data.units[0].frames.get_frame_count("explode") + LEVEL_END_DELAY

            for unit_index in range(0, game_data.units_spawned):
                var unit : Unit = game_data.units[unit_index]
                add_job(unit, Enums.JOBS.BOMBER)
        _:
            if pressed:
                return

            print("Tool not implemented: ", Enums.TOOLS.keys()[tool_id])
            return

    # print("Used tool: %s at (%s,%s)" % [Enums.TOOLS.keys()[tool_id], x, y])

func select_tool(tool_id: int) -> void:
    # print("Tool selected: ", Enums.TOOLS.keys()[tool_id])
    if tool_id < Enums.JOBS.size():
        tool_primary = tool_id
        hud.select_job(tool_id)
        return

    if tool_id == Enums.TOOLS.SPAWN_UNIT:
        tool_primary = tool_id

    use_tool(tool_id, 0, 0, false)

func spawn_rate_up() -> void:
    increase_spawn_rate(1)

func spawn_rate_down() -> void:
    increase_spawn_rate(-1)

func increase_spawn_rate(value: int) -> void:
    level_data.spawn_rate = int(clamp(level_data.spawn_rate + value, 1, 99))
    # print("spawn_rate: ", level_data.spawn_rate)

func use_job_tool(x: int, y: int, pressed: bool, tool_id: int, job_id: int) -> void:
    if not is_in_bounds(x, y):
        return

    if pressed:
        return

    if level_data.jobs_count[job_id] < 1:
        return

    var unit_index := get_unit_at(x, y)
    if unit_index == -1:
        return

    var unit : Unit = game_data.units[unit_index]
    if has_job(unit, job_id):
        return

    if not can_add_job(unit, job_id):
        return

    add_job(unit, job_id)
    play_sound(config.sound_assign_job)
    level_data.jobs_count[job_id] -= 1
    hud.set_job_button_data(tool_id, String(level_data.jobs_count[job_id]))

func set_toggle_debug_visibility(value: bool) -> void:
    collision_sprite.visible = value
    debug_draw.visible = value
    debug_label.visible = value
    debug_is_visible = value

func tick() -> void:
    if level_data.spawn_is_active:
        if game_data.now_tick % (100 - level_data.spawn_rate + 5) == 0:
            spawn_unit(int(level_data.entrance_position.x), int(level_data.entrance_position.y))
            if game_data.units_spawned >= game_data.units.size():
                level_data.spawn_is_active = false

    for unit_index in range(0, game_data.units_spawned):
        var unit : Unit = game_data.units[unit_index]

        if OS.is_debug_build():
            var jobs_str := ""
            for job_index in range(0, Enums.JOBS.size()):
                var job_id : int = Enums.JOBS.values()[job_index]
                if has_job(unit, job_id):
                    jobs_str += "%s " % Enums.JOBS.keys()[job_index]

            debug_draw.add_text(unit.position + Vector2(-5, -10), Unit.STATES.keys()[unit.state])
            debug_draw.add_text(unit.position + Vector2(-5, -7), jobs_str)

        if unit.status != Unit.STATUSES.ACTIVE:
            continue

        var destination := unit.position
        var ground_check_pos_x := int(unit.position.x + 1 * unit.direction)
        var ground_check_pos_y := int(unit.position.y + unit.height / 2)

        if not is_in_bounds(ground_check_pos_x, ground_check_pos_y):
            # print("%s: OOB" % unit.name)
            unit.state = Unit.STATES.DEAD_FALL
            unit.state_entered_at = game_data.now_tick

        if is_inside_rect(level_data.exit_position, Rect2(unit.position.x, unit.position.y, 1, unit.height)):
            unit.play("exit")
            unit.status = Unit.STATUSES.EXITED
            play_sound(config.sound_yippee, rand_range(0.9, 1.2))
            continue

        var is_grounded := has_flag(ground_check_pos_x, ground_check_pos_y, Enums.PIXELS.BLOCK)
        debug_draw.add_rect(Rect2(ground_check_pos_x, ground_check_pos_y, 1, 1), Color.yellow)

        var color := Color.red
        color.a = 0.6
        debug_draw.add_rect(Rect2(unit.position.x, unit.position.y, 1, 1), color)

        var frames_count := unit.frames.get_frame_count(unit.animation)
        var state_tick := game_data.now_tick - unit.state_entered_at

        if has_job(unit, Enums.JOBS.BOMBER):
            var job_started_at := get_job_started_at(unit, Enums.JOBS.BOMBER)
            if game_data.now_tick <= job_started_at + JOB_BOMBER_DURATION:
                if (game_data.now_tick - job_started_at) % JOB_BOMBER_STEP == 0:
                    var countdown : int = JOB_BOMBER_DURATION / JOB_BOMBER_STEP - (game_data.now_tick - job_started_at) / JOB_BOMBER_STEP
                    unit.set_text(String(countdown))

            var timer_done : int = game_data.now_tick == job_started_at + JOB_BOMBER_DURATION
            if timer_done:
                unit.set_text("")
                if is_grounded:
                    unit.state = Unit.STATES.IDLE
                    unit.state_entered_at = game_data.now_tick
                    unit.play("explode")
                play_sound(config.sound_deathrattle)

            var exploding := game_data.now_tick >= job_started_at + JOB_BOMBER_DURATION
            if exploding:
                unit.frame = state_tick % frames_count
                var animation_done : int = unit.frame == frames_count - 1
                if animation_done:
                    unit.status = Unit.STATUSES.DEAD
                    play_sound(config.sound_explode, rand_range(1.0, 1.1))
                    paint_circle(int(unit.position.x), int(unit.position.y), 9, Enums.PIXELS.EMPTY)
                    var dust_particle = config.dust_particle_prefab.instance()
                    dust_particle.position = unit.position
                    dust_particle.emitting = true
                    scaler_node.add_child(dust_particle)

        match unit.state:

            Unit.STATES.IDLE:
                pass

            Unit.STATES.FALLING:
                remove_job(unit, Enums.JOBS.BLOCKER)
                remove_job(unit, Enums.JOBS.BASHER)
                remove_job(unit, Enums.JOBS.MINER)
                remove_job(unit, Enums.JOBS.DIGGER)
                remove_job(unit, Enums.JOBS.BUILDER)

                if is_grounded:
                    if game_data.now_tick >= unit.state_entered_at + FALL_DURATION_FATAL:
                        unit.state = Unit.STATES.DEAD_FALL
                        unit.state_entered_at = game_data.now_tick
                    else:
                        unit.state = Unit.STATES.WALKING
                        unit.state_entered_at = game_data.now_tick
                else:
                    if has_job(unit, Enums.JOBS.FLOATER) && game_data.now_tick >= unit.state_entered_at + FALL_DURATION_FLOAT:
                        unit.state = Unit.STATES.FLOATING
                        unit.state_entered_at = game_data.now_tick
                    else:
                        unit.play("fall")
                        destination.y += 1

            Unit.STATES.FLOATING:
                if is_grounded:
                    unit.state = Unit.STATES.WALKING
                    unit.state_entered_at = game_data.now_tick
                else:
                    if game_data.now_tick == unit.state_entered_at + JOB_FLOATER_FLOATER_DELAY:
                        unit.play("float")
                        unit.stop()
                        unit.frame = 0
                    elif game_data.now_tick > unit.state_entered_at + JOB_FLOATER_FLOATER_DELAY:
                        var frame := unit.frame
                        if unit.frame + 1 > 9:
                            frame = 4
                        else:
                            frame += 1

                        if frame <= 4 || game_data.now_tick % 4 == 0:
                            unit.frame = frame

                        if game_data.now_tick % 3 == 0:
                            destination.y += 1
                    else:
                        destination.y += 1

            Unit.STATES.CLIMBING:
                var wall_pos_x := int(unit.position.x + 4 * unit.direction)
                var hit_top_wall := has_flag(wall_pos_x, int(unit.position.y - 1), Enums.PIXELS.EMPTY)
                var hit_ceiling := has_flag(int(unit.position.x), int(unit.position.y - unit.height / 2), Enums.PIXELS.BLOCK)

                if hit_ceiling:
                    unit.direction *= -1
                    unit.state = Unit.STATES.FALLING
                    unit.state_entered_at = game_data.now_tick
                elif hit_top_wall:
                    unit.state = Unit.STATES.CLIMBING_END
                    unit.state_entered_at = game_data.now_tick
                else:
                    unit.play("climb")
                    unit.frame = state_tick % frames_count
                    destination.y -= 1

            Unit.STATES.CLIMBING_END:
                unit.play("climb_end")
                unit.frame = state_tick % frames_count

                var done := unit.frame == frames_count - 1
                if done:
                    destination.x = unit.position.x + 4 * unit.direction
                    destination.y = unit.position.y - 5
                    unit.state = Unit.STATES.WALKING
                    unit.state_entered_at = game_data.now_tick

            Unit.STATES.WALKING:
                if is_grounded:
                    if has_job(unit, Enums.JOBS.CLIMBER):
                        var pos_x := int(unit.position.x + 4 * unit.direction)
                        var wall_in_front := has_flag(pos_x, int(unit.position.y), Enums.PIXELS.BLOCK)
                        if wall_in_front:
                            unit.state = Unit.STATES.CLIMBING
                            unit.state_entered_at = game_data.now_tick

                    if has_job(unit, Enums.JOBS.BASHER):
                        var job_started_at := get_job_started_at(unit, Enums.JOBS.BASHER)

                        var job_first_tick := game_data.now_tick == job_started_at
                        if job_first_tick:
                            unit.play("dig_horizontal")
                            unit.stop()

                        var is_done : int = game_data.now_tick >= job_started_at + JOB_BASHER_DURATION
                        if is_done:
                            remove_job(unit, Enums.JOBS.BASHER)
                        else:
                            var job_tick := game_data.now_tick - job_started_at
                            unit.frame = job_tick % unit.frames.get_frame_count(unit.animation)

                            # Dig only on the frames where the unit is digging in animation
                            if (unit.frame == 3 || unit.frame == 19):
                                var pos_x := int(unit.position.x + 4 * unit.direction)
                                var dig_radius := int(unit.height / 2)
                                paint_circle(pos_x, int(unit.position.y), dig_radius, Enums.PIXELS.EMPTY)

                                var wall_in_front = has_flag(pos_x + dig_radius - 1, int(unit.position.y) + dig_radius - 1, Enums.PIXELS.BLOCK)
                                if not wall_in_front:
                                    remove_job(unit, Enums.JOBS.BASHER)

                            # Move only on the frames where the unit moves forward in animation
                            if (unit.frame == 11 || unit.frame == 12 || unit.frame == 13 || unit.frame == 14 ||
                                unit.frame == 27 || unit.frame == 28 || unit.frame == 29 || unit.frame == 30
                            ):
                                destination.x += 1 * unit.direction

                        continue

                    if has_job(unit, Enums.JOBS.MINER):
                        var job_started_at := get_job_started_at(unit, Enums.JOBS.MINER)

                        var job_first_tick = game_data.now_tick == job_started_at
                        if job_first_tick:
                            unit.play("mine")
                            unit.stop()

                        var is_done : int = game_data.now_tick >= job_started_at + JOB_MINER_DURATION
                        if is_done:
                            remove_job(unit, Enums.JOBS.MINER)
                        else:
                            var job_tick := game_data.now_tick - job_started_at
                            unit.frame = job_tick % unit.frames.get_frame_count(unit.animation)

                            # Dig only on the frames where the unit is digging in animation
                            if (unit.frame == 4):
                                var pos_x := int(unit.position.x + 6 * unit.direction)
                                var pos_y := int(unit.position.y + 2)
                                paint_circle(pos_x, pos_y, JOB_MINER_DESTROY_RADIUS, Enums.PIXELS.EMPTY)

                            # Move only on the frames where the unit moves forward in animation
                            if (unit.frame == 4 || unit.frame == 15):
                                destination.x += 2 * unit.direction
                                destination.y += 1

                        continue

                    if has_job(unit, Enums.JOBS.BUILDER):
                        var job_started_at := get_job_started_at(unit, Enums.JOBS.BUILDER)

                        var job_first_tick := game_data.now_tick == job_started_at
                        if job_first_tick:
                            unit.play("build")
                            unit.stop()

                        var hit_wall := has_flag(int(unit.position.x + 4 * unit.direction), int(unit.position.y + 2), Enums.PIXELS.BLOCK)
                        var hit_ceiling := has_flag(int(unit.position.x + 4 * unit.direction), int(unit.position.y - unit.height / 2), Enums.PIXELS.BLOCK)
                        if hit_wall || hit_ceiling:
                            remove_job(unit, Enums.JOBS.BUILDER)
                            continue

                        var is_done : int = game_data.now_tick >= job_started_at + JOB_BUILDER_DURATION
                        if is_done:
                            remove_job(unit, Enums.JOBS.BUILDER)
                        else:
                            var job_tick := game_data.now_tick - job_started_at
                            unit.frame = job_tick % unit.frames.get_frame_count(unit.animation)

                            # Dig only on the frames where the unit is digging in animation
                            if (unit.frame == 9):
                                var pos_x := int(unit.position.x + 4 * unit.direction)
                                var pos_y := int(unit.position.y + unit.height / 2 - 1)
                                paint_rect(pos_x, pos_y, 4, 1, Enums.PIXELS.BLOCK | Enums.PIXELS.PAINT)

                            # Move only on the frames where the unit moves forward in animation
                            if (unit.frame == 16):
                                destination.x += 2 * unit.direction
                                destination.y -= 1

                        continue

                    if has_job(unit, Enums.JOBS.DIGGER):
                        var job_started_at := get_job_started_at(unit, Enums.JOBS.DIGGER)

                        unit.play("dig_vertical")
                        var job_tick := game_data.now_tick - job_started_at
                        unit.frame = job_tick % frames_count

                        if (game_data.now_tick - job_started_at) % JOB_DIGGER_STEP == 0:
                            var rect := Rect2(unit.position.x, unit.position.y + 3, unit.width, 6)
                            debug_draw.add_rect(rect, Color.red)
                            paint_rect(int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y), Enums.PIXELS.EMPTY)

                            var is_not_done : int = game_data.now_tick < job_started_at + JOB_DIGGER_DURATION
                            if is_not_done:
                                destination.y += 1

                        continue

                    if has_job(unit, Enums.JOBS.BLOCKER):
                        var job_started_at := get_job_started_at(unit, Enums.JOBS.BLOCKER)

                        var rect := Rect2(unit.position.x, unit.position.y, unit.width, unit.height)
                        debug_draw.add_rect(rect, Color.red)
                        if game_data.now_tick == job_started_at:
                            unit.play("block")
                            paint_rect(int(rect.position.x), int(rect.position.y), int(rect.size.x), int(rect.size.y), Enums.PIXELS.BLOCK)
                        else:
                            var job_tick := game_data.now_tick - job_started_at
                            unit.frame = job_tick % frames_count

                        continue

                    var wall_check_pos_x := int(unit.position.x + 2 * unit.direction)
                    var wall_check_pos_y := int(unit.position.y + (unit.height / 2) - 1)
                    var destination_offset_y := 0
                    var hit_wall := false

                    for offset_y in range(0, -unit.climb_step, -1):
                        var wall_check_pos_y_with_offset := wall_check_pos_y + offset_y
                        debug_draw.add_rect(Rect2(wall_check_pos_x, wall_check_pos_y_with_offset, 1, 1), Color.magenta)
                        hit_wall = has_flag(wall_check_pos_x, wall_check_pos_y_with_offset, Enums.PIXELS.BLOCK)

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
                            if has_flag(wall_check_pos_x, step_down_pos_y_with_offset, Enums.PIXELS.BLOCK):
                                break
                            destination_offset_y = offset_y

                        var is_over_hole := has_flag(wall_check_pos_x, wall_check_pos_y + destination_offset_y + 1, Enums.PIXELS.EMPTY)
                        if is_over_hole:
                            destination.x += unit.direction * 2
                            unit.state = Unit.STATES.FALLING
                            unit.state_entered_at = game_data.now_tick
                        else:
                            # Walk forward
                            unit.play("walk")
                            unit.frame = state_tick % frames_count
                            destination.y += destination_offset_y
                            destination.x += unit.direction

                else:
                    unit.state = Unit.STATES.FALLING
                    unit.state_entered_at = game_data.now_tick

            Unit.STATES.DEAD_FALL:
                if game_data.now_tick == unit.state_entered_at + 1:
                    unit.play("dead_fall")
                    play_sound(config.sound_splat)

                if game_data.now_tick == unit.state_entered_at + FALL_SPLAT_ANIM_DURATION:
                    unit.status = Unit.STATUSES.DEAD

        unit.flip_h = unit.direction == -1
        unit.position = destination

    game_data.units_exited = 0
    game_data.units_dead = 0
    for unit_index in range(0, game_data.units_spawned):
        var unit : Unit = game_data.units[unit_index]
        if unit.status == Unit.STATUSES.EXITED:
            game_data.units_exited += 1
            unit.set_text("")
        if unit.status == Unit.STATUSES.DEAD:
            remove_all_jobs(unit)
            unit.set_text("")
            unit.visible = false
            game_data.units_dead += 1

    if game_data.trigger_end_at == 0 && game_data.units_dead + game_data.units_exited == level_data.units_max:
        game_data.trigger_end_at = game_data.now_tick + 50

    # Update UI
    hud.set_spawned_label("Out: %s" % game_data.units_spawned)
    hud.set_exited_label("In: %s" % game_data.units_exited)
    hud.set_dead_label("Dead: %s" % game_data.units_dead)
    hud.set_spawn_rate_label(String(level_data.spawn_rate))

    if game_data.trigger_end_at > 0 && game_data.now_tick == game_data.trigger_end_at:
        var goal_reached := game_data.units_exited >= level_data.units_goal

        unload_level()
        yield(self, "level_unloaded")

        if goal_reached:
            current_level += 1
            if current_level > config.levels.size() - 1:
                print("Last level finished")
                current_level = 0
                start_title()
                return
            else:
                print("Loading next level")

                load_level(config.levels[current_level])
                yield(self, "level_loaded")

                start_level()
        else:
            print("Restarting current level")

            load_level(config.levels[current_level])
            yield(self, "level_loaded")

            start_level()

func spawn_unit(x: int, y: int) -> Unit:
    if game_data.units_spawned >= game_data.units.size():
        print("Max units reached (%s)" % game_data.units.size())
        return null

    var unit : Unit = config.unit_prefab.instance()
    unit.name = "Unit %s" % game_data.units_spawned
    unit.state = Unit.STATES.FALLING
    unit.state_entered_at = game_data.now_tick
    unit.position.x = x
    unit.position.y = y - unit.height / 2
    unit.speed_scale = TICK_SPEED / 50
    unit.play("fall")

    game_data.units[game_data.units_spawned] = unit
    scaler_node.add_child(unit)
    unit.set_text("")

    game_data.units_spawned += 1

    return unit

func paint_rect(origin_x: int, origin_y: int, width: int, height: int, value: int) -> void:
    var pixels_to_draw : PoolIntArray = []

    for offset_x in range(0, width):
        for offset_y in range(0, height):
            var pos_x = origin_x - width / 2 + offset_x
            var pos_y = origin_y - height / 2 + offset_y
            if is_in_bounds(pos_x, pos_y):
                var index := calculate_index(pos_x, pos_y, level_data.map_width)
                pixels_to_draw.append(index)

    if pixels_to_draw.size() <= 0:
        return

    for index in pixels_to_draw:
        game_data.map_data[index] = value

    update_map(origin_x - width / 2, origin_y - height / 2, width, height)

func paint_circle(origin_x: int, origin_y: int, radius: int, value: int) -> void:
    # var start := Time.get_ticks_usec()
    var pixels_to_draw : PoolIntArray = []

    for y in range(2 * radius):
        for x in range(2 * radius):
            var delta_x := radius - x
            var delta_y := radius - y
            var distance := sqrt(delta_x * delta_x + delta_y * delta_y)
            var transparency = clamp(radius - distance, 0, 1);
            if transparency > 0.5:
                var index := calculate_index(origin_x - radius + x, origin_y - radius + y, level_data.map_width)
                pixels_to_draw.append(index)

    if pixels_to_draw.size() <= 0:
        return

    for index in pixels_to_draw:
        game_data.map_data[index] = value

    # var end := Time.get_ticks_usec()
    # var time := (end - start) / 1000.0
    # print("[DEBUG] paint_circle %s pixels in %sms (now_tick: %s)" % [pixels_to_draw.size(), time, game_data.now_tick])

    update_map(origin_x - radius, origin_y - radius, radius * 2, radius * 2)

func has_flag(x: int, y: int, flag: int) -> bool:
    if not is_in_bounds(x, y):
        return false
    var index := calculate_index(x, y, level_data.map_width)
    return game_data.map_data[index] & flag != 0

func is_in_bounds(x: int, y: int) -> bool:
    return x >= 0 && x < level_data.map_width && y >= 0 && y < level_data.map_height

func quit_game() -> void:
    print("Quitting game...")
    get_tree().quit()

func update_map(x: int, y: int, width: int, height: int) -> void:
    # var start := Time.get_ticks_usec()
    # var pixel_count := 0

    collision_image.lock()
    map_image.lock()
    for pixel_x in range(x, x + width):
        for pixel_y in range(y, y + height):
            var index := pixel_y * level_data.map_width + pixel_x
            if index < 0 || index >= game_data.map_data.size():
                continue
            var pixel := game_data.map_data[index]
            var pos_x := index % level_data.map_width
            var pos_y := index / level_data.map_width

            var collision_color := Color.transparent
            if pixel != Enums.PIXELS.EMPTY:
                collision_color = Color.red
            collision_image.set_pixel(pos_x, pos_y, collision_color)

            if pixel == Enums.PIXELS.EMPTY:
                map_image.set_pixel(pos_x, pos_y, Color.transparent)
            elif has_flag(pos_x, pos_y, Enums.PIXELS.PAINT):
                map_image.set_pixel(pos_x, pos_y, level_data.color)

            # pixel_count += 1
    collision_image.unlock()
    map_image.unlock()

    level_data.collision_texture.create_from_image(collision_image, 0)
    collision_sprite.texture = level_data.collision_texture

    level_data.map_texture.create_from_image(map_image, 0)
    map_sprite.texture = level_data.map_texture

    # var end := Time.get_ticks_usec()
    # var time := (end - start) / 1000.0
    # print("[DEBUG] Updated %s pixels in %sms (now_tick: %s)" % [pixel_count, time, game_data.now_tick])

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
    unit.jobs_started_at[Enums.JOBS.values().find(job_id)] = game_data.now_tick

func remove_job(unit: Unit, job_id: int) -> void:
    unit.jobs_started_at[Enums.JOBS.values().find(job_id)] = 0

func remove_all_jobs(unit: Unit) -> void:
    unit.jobs_started_at.resize(Enums.JOBS.size())

func has_job(unit: Unit, job_id: int) -> bool:
    return unit.jobs_started_at[Enums.JOBS.values().find(job_id)] > 0

func get_job_started_at(unit: Unit, job_id: int) -> int:
    return unit.jobs_started_at[Enums.JOBS.values().find(job_id)]

func can_add_job(unit: Unit, job_id: int) -> bool:
    match job_id:
        Enums.JOBS.BLOCKER, Enums.JOBS.BUILDER, Enums.JOBS.DIGGER:
            var is_grounded = has_flag(int(unit.position.x), int(unit.position.y + unit.height / 2), Enums.PIXELS.BLOCK)
            return unit.state == Unit.STATES.WALKING && is_grounded

        Enums.JOBS.BASHER:
            var wall_in_front = has_flag(int(unit.position.x + 6 * unit.direction), int(unit.position.y), Enums.PIXELS.BLOCK)
            return unit.state == Unit.STATES.WALKING && wall_in_front

        Enums.JOBS.MINER:
            var wall_in_front = has_flag(int(unit.position.x + 6 * unit.direction), int(unit.position.y), Enums.PIXELS.BLOCK)
            var is_grounded = has_flag(int(unit.position.x), int(unit.position.y + unit.height / 2), Enums.PIXELS.BLOCK)
            return unit.state == Unit.STATES.WALKING && (wall_in_front || is_grounded)

        _:
            return true
