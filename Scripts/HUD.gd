class_name HUD
extends CanvasLayer

onready var root : Control = get_node("Root")
onready var job_buttons : Array = [
    get_node("%JobButton1"),
    get_node("%JobButton2"),
    get_node("%JobButton3"),
    get_node("%JobButton4"),
    get_node("%JobButton5"),
    get_node("%JobButton6"),
    get_node("%JobButton7"),
    get_node("%JobButton8"),
]
onready var explode_button : Button = get_node("%ExplodeButton")
onready var spawn_rate_label : Label = get_node("%SpawnRateLabel")
onready var spawn_rate_up_button : Button = get_node("%SpawnRateUpButton")
onready var spawn_rate_down_button : Button = get_node("%SpawnRateDownButton")
onready var units_spawned_label : Label = get_node("%UnitsSpawnedLabel")
onready var units_exited_label : Label = get_node("%UnitsExitedLabel")
onready var units_dead_label : Label = get_node("%UnitsDeadLabel")

signal opened
signal closed
signal tool_selected
signal spawn_rate_up_pressed
signal spawn_rate_down_pressed

func _ready() -> void:
    root.modulate.a = 0.0

    for index in range(0, job_buttons.size()):
        job_buttons[index].connect("pressed", self, "job_button_pressed", [index])
    explode_button.connect("pressed", self, "explode_button_pressed")
    spawn_rate_up_button.connect("pressed", self, "spawn_rate_up_button_pressed")
    spawn_rate_down_button.connect("pressed", self, "spawn_rate_down_button_pressed")

func _process(_delta: float) -> void:
    if spawn_rate_up_button.pressed:
        emit_signal("spawn_rate_up_pressed")
    if spawn_rate_down_button.pressed:
        emit_signal("spawn_rate_down_pressed")

func open() -> void:
    root.modulate.a = 1.0
    yield(get_tree(), "idle_frame")
    emit_signal("opened")

func close() -> void:
    root.modulate.a = 0.0
    yield(get_tree(), "idle_frame")
        emit_signal("closed")

func job_button_pressed(index: int) -> void:
    var job_id : int = Enums.TOOLS.values()[index + 1]
    emit_signal("tool_selected", job_id)

func set_job_button_data(job_id: int, text: String) -> void:
    job_buttons[job_id - 1].set_data(job_id, text)

func select_job(tool_id: int) -> void:
    job_buttons[tool_id - 1].grab_focus()

func explode_button_pressed() -> void:
    emit_signal("tool_selected", Enums.TOOLS.BOMB_ALL)

func spawn_rate_up_button_pressed() -> void:
    # emit_signal("spawn_rate_up_pressed")
    pass

func spawn_rate_down_button_pressed() -> void:
    # emit_signal("spawn_rate_down_pressed")
    pass

func set_spawned_label(value: String) -> void:
    units_spawned_label.text = value

func set_exited_label(value: String) -> void:
    units_exited_label.text = value

func set_dead_label(value: String) -> void:
    units_dead_label.text = value

func set_spawn_rate_label(value: String) -> void:
    spawn_rate_label.text = value
