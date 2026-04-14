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
        %FileDialog.visible = not (loopback or Engine.is_editor_hint())

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

const MAX_ZOOM := 64.0
const MAX_SCALE := Vector2(MAX_ZOOM, MAX_ZOOM)

@onready var bus_idx := AudioServer.get_bus_index(&"Player")
@onready var capture_idx := AudioServer.get_bus_effect_count(bus_idx) - 1
@onready var capture: AudioEffectCapture = AudioServer.get_bus_effect(bus_idx, capture_idx)

func _ready() -> void:
    if Engine.is_editor_hint():
        return

    WasapiLoopbackRecorder.BufferLength = buffer_length
    audio_player.finished.connect(_select_file)
    %FileDialog.file_selected.connect(_on_file_selected)


# TODO: Set mouse_filter to stop
func _unhandled_input(event: InputEvent) -> void:
    if Engine.is_editor_hint():
        return

    if event is InputEventMouseButton and event.pressed:
        _handle_input_event_mouse_button(event)
        return

    if event is InputEventKey and event.pressed and not event.echo:
        _handle_input_event_key(event)
        return


func _handle_input_event_mouse_button(event: InputEventMouseButton) -> void:
    if event.button_index in [MouseButton.MOUSE_BUTTON_WHEEL_UP, MouseButton.MOUSE_BUTTON_WHEEL_DOWN]:
        var old_pivot := sub_viewport_container.pivot_offset
        var new_pivot := sub_viewport_container.get_local_mouse_position()
        sub_viewport_container.pivot_offset = new_pivot
        sub_viewport_container.position += (new_pivot - old_pivot) * (sub_viewport_container.scale - Vector2.ONE)

        if event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_UP:
            sub_viewport_container.scale *= 1.5
        elif event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_DOWN:
            sub_viewport_container.scale /= 1.5

        sub_viewport_container.scale = sub_viewport_container.scale.clamp(Vector2.ONE, MAX_SCALE)

        if sub_viewport_container.scale.is_equal_approx(Vector2.ONE):
            sub_viewport_container.pivot_offset = Vector2.ZERO
            sub_viewport_container.position = Vector2.ZERO
    elif event.button_index in [MouseButton.MOUSE_BUTTON_WHEEL_LEFT, MouseButton.MOUSE_BUTTON_WHEEL_RIGHT]:
        if event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_LEFT:
            pass
        elif event.button_index == MouseButton.MOUSE_BUTTON_WHEEL_RIGHT:
            pass


func _handle_input_event_key(event: InputEventKey) -> void:
    match event.keycode:
        KEY_SPACE:
            if loopback:
                WasapiLoopbackRecorder.TogglePaused()
            else:
                AudioServer.set_bus_effect_enabled(bus_idx, capture_idx, audio_player.stream_paused)
                audio_player.stream_paused = not audio_player.stream_paused
        KEY_ESCAPE when not loopback and not %FileDialog.visible:
            _select_file()


func _on_file_selected(path: String) -> void:
    audio_player.stream = AudioLoader.loadfile(path)
    audio_player.play()
    AudioServer.set_bus_effect_enabled(bus_idx, capture_idx, true)


func _select_file() -> void:
    %FileDialog.visible = true


func _optimize_line_width() -> void:
    if not line_antialiasing and is_equal_approx(line_width, 1.0):
        line_width = -1.0
