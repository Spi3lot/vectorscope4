@tool
extends Control
class_name Vectorscope

@export_group("Configuration")
@export_range(0.01, 10.0, 0.01) var buffer_length := 0.1:
    set(value):
        buffer_length = value
        if capture: capture.buffer_length = value

@export var loopback := true:
    set(value):
        loopback = value
        audio_player.stream = null
        %FileDialog.visible = not loopback

@export var line_antialiasing := true:
    set(value):
        line_antialiasing = value
        _optimize_line_width()

        if line_antialiasing and line_width < 0:
            line_width = 1.0

@export_range(1.0, 10.0) var line_width := 1.0:
    set(value):
        line_width = value
        _optimize_line_width()

@export_range(0.0, 1.0) var line_glow := 0.25
@export_range(0.0, 100.0) var length_penalty := 20
@export_range(0.0, 1.0) var plot_scale := 1.0
@export_range(0.0, 1.0)  var persistence := 0.5
@export var line_color := Color.GREEN

@export_group("Nodes")
@export var audio_player: AudioStreamPlayer
@export var sub_viewport_container: FixedSubViewportContainer

@onready var bus_idx := AudioServer.get_bus_index(&"Player")
@onready var capture_idx := AudioServer.get_bus_effect_count(bus_idx) - 1
@onready var capture: AudioEffectCapture = AudioServer.get_bus_effect(bus_idx, capture_idx)

func _ready() -> void:
    if Engine.is_editor_hint():
        return

    WasapiLoopbackRecorder.BufferLength = buffer_length
    audio_player.finished.connect(_select_file)
    %FileDialog.file_selected.connect(_on_file_selected)
    

func _input(event: InputEvent) -> void:
    if event is not InputEventKey or not event.pressed or event.echo or Engine.is_editor_hint():
        return
    
    match event.keycode:
        KEY_SPACE:
            audio_player.stream_paused = not audio_player.stream_paused
        KEY_ESCAPE when not loopback and not %FileDialog.visible:
            _select_file()


func _on_file_selected(path: String) -> void:
    audio_player.stream = AudioLoader.loadfile(path)
    audio_player.play()
    capture.clear_buffer()
    

func _select_file() -> void:
    %FileDialog.visible = true


func _optimize_line_width() -> void:
    if not line_antialiasing and is_equal_approx(line_width, 1.0):
        line_width = -1.0
