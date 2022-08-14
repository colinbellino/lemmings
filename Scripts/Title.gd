class_name Title
extends CanvasLayer

signal opened
signal closed
signal action_selected

onready var root : Control = get_node("Root")
onready var button_start : Button = get_node("%Start")
onready var button_quit : Button = get_node("%Quit")

func _ready() -> void:
    root.modulate.a = 0.0

    button_start.connect("pressed", self, "action_pressed", [0])
    button_quit.connect("pressed", self, "action_pressed", [1])

func open() -> void:
    button_start.grab_focus()

    var tween := create_tween()
    tween.tween_property(root, "modulate:a", 1.0, 1)
    yield(tween, "finished")
    emit_signal("opened")

func close() -> void:
    var tween := create_tween()
    tween.tween_property(root, "modulate:a", 0.0, 1)
    yield(tween, "finished")
    emit_signal("closed")

func action_pressed(value: int) -> void:
    emit_signal("action_selected", value)
