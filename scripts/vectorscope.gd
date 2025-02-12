extends Node2D
class_name Vectorscope

@export_group("Configuration")
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
            line_width = 1

@export_range(1, 10) var line_width := 1:
    set(value):
        line_width = value
        _optimize_line_width()

@export_range(1, 10) var line_glow := 0.25
@export_range(0, 100) var length_penalty := 20
@export_range(0, 1) var plot_scale := 1.0
@export var line_color := Color.GREEN
@export var fade_color := Color(0, 0, 0, 0.5)

@export_group("Nodes")
@export var audio_player: AudioStreamPlayer
@export var sub_viewport_container: VectorscopeSubViewportContainer

func _ready():
    audio_player.finished.connect(_select_file)
    %FileDialog.file_selected.connect(_on_file_selected)
    

func _input(event: InputEvent):
    if event is not InputEventKey or not event.pressed or event.echo:
        return
    
    match event.keycode:
        KEY_SPACE:
            audio_player.stream_paused = !audio_player.stream_paused
        KEY_ESCAPE:
            if not loopback and not %FileDialog.visible:
                _select_file()


func _on_file_selected(path: String):
    audio_player.stream = AudioLoader.loadfile(path)
    audio_player.play()
    

func _select_file():
    %FileDialog.visible = true


func _optimize_line_width():
    if not line_antialiasing and is_equal_approx(line_width, 1):
        line_width = -1
