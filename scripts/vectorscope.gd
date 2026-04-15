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
        paused = false
        plot_scale = 1.0 if loopback else db_to_linear(audio_player.volume_db)
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
@export_range(0.0, 1.0)  var persistence := 0.5
@export var line_color := Color.GREEN

@export_group("Nodes")
@export var audio_player: AudioStreamPlayer
@export var sub_viewport_container: FixedSubViewportContainer

const ZOOM_FACTOR := 4.0 / 3.0
const MAX_ZOOM := 64.0
const MAX_SCALE := Vector2(MAX_ZOOM, MAX_ZOOM)

var plot_scale := 1.0
var vector_transform := Transform2D.IDENTITY

var paused := false:
    set(value):
        paused = value
        if not paused: _bake_raster_to_vector()

@onready var bus_idx := AudioServer.get_bus_index(&"Player")
@onready var capture_idx := AudioServer.get_bus_effect_count(bus_idx) - 1
@onready var capture: AudioEffectCapture = AudioServer.get_bus_effect(bus_idx, capture_idx)

func _ready() -> void:
    if Engine.is_editor_hint():
        return

    WasapiLoopbackRecorder.BufferLength = buffer_length
    audio_player.finished.connect(_select_file)
    %FileDialog.file_selected.connect(_on_file_selected)


func _unhandled_input(event: InputEvent) -> void:
    if Engine.is_editor_hint():
        return

    if event is InputEventMouseMotion and not is_zero_approx(event.pressure):
        _handle_input_event_mouse_motion(event)
    elif event is InputEventMouseButton and event.pressed:
        _handle_input_event_mouse_button(event)
    elif event is InputEventKey and event.pressed and not event.echo:
        _handle_input_event_key(event)


func _handle_input_event_mouse_motion(event: InputEventMouseMotion) -> void:
    if paused:
        sub_viewport_container.position += event.relative
    else:
        vector_transform.origin += event.relative


func _handle_input_event_mouse_button(event: InputEventMouseButton) -> void:
    match event.button_index:
        MouseButton.MOUSE_BUTTON_WHEEL_UP: _apply_zoom(ZOOM_FACTOR)
        MouseButton.MOUSE_BUTTON_WHEEL_DOWN: _apply_zoom(1.0 / ZOOM_FACTOR)
        MouseButton.MOUSE_BUTTON_MIDDLE: _reset_zoom()


func _handle_input_event_key(event: InputEventKey) -> void:
    match event.keycode:
        KEY_SPACE:
            paused = not paused

            if loopback:
                WasapiLoopbackRecorder.TogglePaused()
            else:
                AudioServer.set_bus_effect_enabled(bus_idx, capture_idx, audio_player.stream_paused)
                audio_player.stream_paused = not audio_player.stream_paused
        KEY_ESCAPE when not loopback and not %FileDialog.visible:
            _select_file()
        KEY_R:
            _reset_zoom()


func _apply_zoom(multiplier: float) -> void:
    var mouse_pos := sub_viewport_container.get_local_mouse_position()

    if paused:
        var old_pivot := sub_viewport_container.pivot_offset
        sub_viewport_container.pivot_offset = mouse_pos
        sub_viewport_container.position += (mouse_pos - old_pivot) * (sub_viewport_container.scale - Vector2.ONE)
        sub_viewport_container.scale = MAX_SCALE.min(sub_viewport_container.scale * multiplier)
    else:
        var trans := Transform2D() \
            .translated(-mouse_pos) \
            .scaled(Vector2(multiplier, multiplier)) \
            .translated(mouse_pos)

        vector_transform = trans * vector_transform


func _reset_zoom() -> void:
    if paused:
        var inv := vector_transform.affine_inverse()
        sub_viewport_container.position = inv.origin
        sub_viewport_container.pivot_offset = Vector2.ZERO
        sub_viewport_container.scale = inv.get_scale()
    else:
        vector_transform = Transform2D.IDENTITY


func _bake_raster_to_vector() -> void:
    var raster_transform := sub_viewport_container.get_transform()
    vector_transform = raster_transform * vector_transform
    sub_viewport_container.position = Vector2.ZERO
    sub_viewport_container.pivot_offset = Vector2.ZERO
    sub_viewport_container.scale = Vector2.ONE

    if not raster_transform.is_equal_approx(Transform2D.IDENTITY):
        sub_viewport_container.sub_viewport.render_target_clear_mode = SubViewport.CLEAR_MODE_ONCE


func _on_file_selected(path: String) -> void:
    audio_player.stream = AudioLoader.loadfile(path)
    audio_player.play()
    AudioServer.set_bus_effect_enabled(bus_idx, capture_idx, true)


func _select_file() -> void:
    %FileDialog.visible = true


func _optimize_line_width() -> void:
    if not line_antialiasing and is_equal_approx(line_width, 1.0):
        line_width = -1.0
