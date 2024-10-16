extends Control

@export var seek_slider: HSlider

var dragging := false

func _ready() -> void:
    _respond()
    get_tree().root.size_changed.connect(_respond)
    get_tree().root.mouse_entered.connect(_show_ui)
    get_tree().root.mouse_exited.connect(_hide_ui)


func _process(_delta: float) -> void:
    if !dragging:
        var audio_player: AudioStreamPlayer = %Vectorscope.audio_player
        seek_slider.value = audio_player.get_playback_position() / audio_player.stream.get_length()

    
func _show_ui():
    visible = true
    
    
func _hide_ui():
    visible = false
    
    
func _respond():
    var viewport_size: Vector2i = get_viewport().size
    var min_aspect := mini(viewport_size.x, viewport_size.y)
    seek_slider.size.x = viewport_size.x
    seek_slider.position.y = viewport_size.y - 36
    %Vectorscope.sub_viewport_container.position.x = (viewport_size.x - min_aspect) / 2
    %Vectorscope.sub_viewport_container.sub_viewport.size = Vector2i(min_aspect, min_aspect)


func _on_volume_value_changed(value: float) -> void:
    %Vectorscope.audio_player.volume_db = linear_to_db(value)


func _on_pan_value_changed(value: float) -> void:
    var panner: AudioEffectPanner = AudioServer.get_bus_effect(0, 0)
    panner.pan = value


func _on_speed_value_changed(value: float) -> void:
    %Vectorscope.audio_player.pitch_scale = value


func _on_penalty_value_changed(value: float) -> void:
    %Vectorscope.length_penalty = value


func _on_seek_drag_started() -> void:
    dragging = true


func _on_longevity_value_changed(value: float) -> void:
    %Vectorscope.fade_color.a = 1 - value


func _on_seek_drag_ended(value_changed: bool) -> void:
    if value_changed:
        %Vectorscope.audio_player.seek(seek_slider.value * %Vectorscope.audio_player.stream.get_length())
        
    dragging = false
