extends Node2D
class_name Vectorscope

@export_group("Configuration")
@export var loopback := true
@export_range(0, 100) var length_penalty := 20
@export_range(1, 10) var line_width := 1
@export var line_antialiasing := true
@export var line_color := Color.GREEN
@export var fade_color := Color(0, 0, 0, 0.5)

@export_group("Nodes")
@export var audio_player: AudioStreamPlayer
@export var sub_viewport_container: VectorscopeSubViewportContainer

func _ready():
    audio_player.finished.connect(_select_file)
    %FileDialog.file_selected.connect(_on_file_selected)
    
    sub_viewport_container.sub_viewport.drawer.draw.connect(
        VectorscopeDraw.draw_vectorscope.bind(self)
    )

func _process(_delta: float) -> void:
    sub_viewport_container.sub_viewport.drawer.queue_redraw()
    

func _input(event: InputEvent):
    if event is InputEventKey:
        if event.pressed and not event.echo:
            if event.keycode == KEY_ESCAPE:
                if not %FileDialog.visible:
                    _select_file()
            elif event.keycode == KEY_SPACE:
                audio_player.stream_paused = !audio_player.stream_paused


func _on_file_selected(path: String):
    audio_player.stream = AudioLoader.loadfile(path)
    audio_player.play()
    

func _select_file():
    %FileDialog.visible = true
