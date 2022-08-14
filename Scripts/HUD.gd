class_name HUD
extends CanvasLayer

var TOOLS = load("res://Scripts/Game.gd").TOOLS

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

signal opened
signal closed
signal tool_selected

func _ready() -> void:
    root.modulate.a = 0.0

    for index in range(0, job_buttons.size()):
        job_buttons[index].connect("pressed", self, "job_button_pressed", [index])
    explode_button.connect("pressed", self, "explode_button_pressed")

func open() -> void:
    root.modulate.a = 1.0
    yield(get_tree(), "idle_frame")
    emit_signal("opened")

func close() -> void:
    root.modulate.a = 0.0
    yield(get_tree(), "idle_frame")
    emit_signal("closed")

func job_button_pressed(index: int) -> void:
    var job_id : int = TOOLS.values()[index + 1]
    emit_signal("tool_selected", job_id)

func set_job_button_data(job_id: int, text: String) -> void: 
    job_buttons[job_id - 1].set_data(job_id, text)

func select_job(tool_id: int) -> void:
    job_buttons[tool_id - 1].grab_focus()

func explode_button_pressed() -> void:
    emit_signal("tool_selected", TOOLS.EXPLODE_ALL)
