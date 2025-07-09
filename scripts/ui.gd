extends Control

@export var volume_label: Label
@export var volume_slider: VSlider
@export var loopback_button: CheckButton
@export var longevity_slider: HSlider
@export var penalty_slider: HSlider
@export var pan_control: Control
@export var speed_control: Control
@export var seek_slider: HSlider

var dragging := false

func _ready() -> void:
    loopback_button.button_pressed = %Vectorscope.loopback
    get_tree().root.mouse_entered.connect(func(): visible = true)
    get_tree().root.mouse_exited.connect(func(): visible = false)


func _process(_delta: float) -> void:
    var player: AudioStreamPlayer = %Vectorscope.audio_player

    if not dragging and player.stream:
        seek_slider.value = player.get_playback_position() / player.stream.get_length()
    

func _on_volume_value_changed(value: float) -> void:
    %Vectorscope.plot_scale = value
    
    if %Vectorscope.loopback:
        WasapiLoopbackRecorder.Scale = value
    else:
        %Vectorscope.audio_player.volume_db = linear_to_db(value)


func _on_penalty_value_changed(value: float) -> void:
    %Vectorscope.length_penalty = value


func _on_width_value_changed(value: float) -> void:
    %Vectorscope.line_width = value


func _on_glow_value_changed(value: float) -> void:
    %Vectorscope.line_glow = value


func _on_antialiasing_toggled(toggled_on: bool) -> void:
    %Vectorscope.line_antialiasing = toggled_on


func _on_longevity_value_changed(value: float) -> void:
    %Vectorscope.fade_color.a = 1 - value


func _on_pan_value_changed(value: float) -> void:
    var panner: AudioEffectPanner = AudioServer.get_bus_effect(0, 0)
    panner.pan = value


func _on_speed_value_changed(value: float) -> void:
    %Vectorscope.audio_player.pitch_scale = value
    
    
func _on_seek_drag_started() -> void:
    dragging = true


func _on_seek_drag_ended(value_changed: bool) -> void:
    if value_changed and %Vectorscope.audio_player.stream:
        %Vectorscope.audio_player.seek(seek_slider.value * %Vectorscope.audio_player.stream.get_length())

    dragging = false


func _on_loopback_toggled(toggled_on: bool) -> void:
    WasapiLoopbackRecorder.SetRecording(toggled_on)
    pan_control.visible = not toggled_on
    speed_control.visible = not toggled_on
    seek_slider.visible = not toggled_on
    %Vectorscope.loopback = toggled_on
    
    if toggled_on:
        volume_slider.value = WasapiLoopbackRecorder.Scale
        volume_label.text = "Scale"
    else:
        volume_slider.value = db_to_linear(%Vectorscope.audio_player.volume_db)
        volume_label.text = "Volume"
