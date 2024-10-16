extends Control

@export var vectorscope: Vectorscope
@export var seek_slider: HSlider

var dragging := false

func _ready() -> void:
    get_tree().root.mouse_entered.connect(_show_ui)
    get_tree().root.mouse_exited.connect(_hide_ui)
    get_tree().root.size_changed.connect(_respond)

func _process(_delta: float) -> void:
    if !dragging:
        seek_slider.value = vectorscope.audio_player.get_playback_position() / vectorscope.audio_player.stream.get_length()

    
func _show_ui():
    visible = true
    
    
func _hide_ui():
    visible = false
    
    
func _respond():
    seek_slider.size.x = get_viewport().size.x
    seek_slider.position.y = get_viewport().size.y - 36


func _on_volume_value_changed(value: float) -> void:
    vectorscope.audio_player.volume_db = linear_to_db(value)


func _on_pan_value_changed(value: float) -> void:
    var panner: AudioEffectPanner = AudioServer.get_bus_effect(0, 0)
    panner.pan = value


func _on_speed_value_changed(value: float) -> void:
    vectorscope.audio_player.pitch_scale = value


func _on_penalty_value_changed(value: float) -> void:
    vectorscope.length_penalty = value


func _on_seek_drag_started() -> void:
    dragging = true


func _on_seek_drag_ended(value_changed: bool) -> void:
    if value_changed:
        vectorscope.audio_player.seek(seek_slider.value * vectorscope.audio_player.stream.get_length())
        
    dragging = false
