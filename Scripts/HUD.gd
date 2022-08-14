class_name HUD
extends CanvasLayer

signal opened
signal closed

onready var root : Control = get_node("Root")

func _ready() -> void:
    root.modulate.a = 0.0

func open() -> void:
    root.modulate.a = 1.0
    yield(get_tree(), "idle_frame")
    emit_signal("opened")
    
func close() -> void:
    root.modulate.a = 0.0
    yield(get_tree(), "idle_frame")
    emit_signal("closed")
