extends Control

@export var loopback_button: CheckButton
@export var loopback_error_label: Label
@export var persistence_slider: Slider
@export var penalty_slider: Slider
@export var pan_control: Control
@export var speed_control: Control
@export var volume_control: Control
@export var seek_slider: Slider

var dragging := false

@onready var vectorscope: Vectorscope = %Vectorscope

func _ready() -> void:
    loopback_button.button_pressed = vectorscope.loopback
    persistence_slider.value = vectorscope.persistence
    penalty_slider.value = vectorscope.length_penalty
    get_tree().root.mouse_entered.connect(show)
    get_tree().root.mouse_exited.connect(hide)


func _process(_delta: float) -> void:
    var player: AudioStreamPlayer = vectorscope.audio_player

    if not dragging and player.stream:
        seek_slider.value = player.get_playback_position() / player.stream.get_length()


func _on_volume_value_changed(value: float) -> void:
    vectorscope.audio_player.volume_db = value
    vectorscope.plot_scale = db_to_linear(value)


func _on_penalty_value_changed(value: float) -> void:
    vectorscope.length_penalty = value


func _on_width_value_changed(value: float) -> void:
    vectorscope.line_width = value


func _on_glow_value_changed(value: float) -> void:
    vectorscope.line_glow = value


func _on_antialiasing_toggled(toggled_on: bool) -> void:
    vectorscope.line_antialiasing = toggled_on


func _on_persistence_value_changed(value: float) -> void:
    vectorscope.persistence = value


func _on_color_changed(color: Color) -> void:
    vectorscope.line_color = color


func _on_pan_value_changed(value: float) -> void:
    var panner: AudioEffectPanner = AudioServer.get_bus_effect(vectorscope.bus_idx, 0)
    panner.pan = value


func _on_speed_value_changed(value: float) -> void:
    vectorscope.audio_player.pitch_scale = value
    
    
func _on_seek_drag_started() -> void:
    dragging = true


func _on_seek_drag_ended(value_changed: bool) -> void:
    if value_changed and vectorscope.audio_player.stream:
        vectorscope.audio_player.seek(seek_slider.value * vectorscope.audio_player.stream.get_length())
        vectorscope.capture.clear_buffer()

    dragging = false


func _on_loopback_toggled(toggled_on: bool) -> void:
    var error: Error = WasapiLoopbackRecorder.SetRecording(toggled_on)
    loopback_error_label.text = _get_error_text(error)
    loopback_error_label.visible = not loopback_error_label.text.is_empty()

    if error != OK:
        loopback_button.set_pressed_no_signal(not toggled_on)
        return

    pan_control.visible = not toggled_on
    speed_control.visible = not toggled_on
    volume_control.visible = not toggled_on
    seek_slider.visible = not toggled_on
    vectorscope.loopback = toggled_on


func _get_error_text(error: Error) -> String:
    match error:
        OK: return ""
        ERR_CANT_OPEN: return "Can't open audio device for loopback"
        ERR_CANT_RESOLVE: return "Can't decode audio stream"
        _: return "An error occurred"
