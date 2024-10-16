extends Node2D
class_name Vectorscope

@export_group("Configuration")
@export_range(0, 100) var length_penalty := 20
@export var line_color := Color.GREEN
@export var fade_color := Color(0, 0, 0, 0.5)

@export_group("Nodes")
@export var audio_player: AudioStreamPlayer
@export var select_file_dialog: FileDialog
@export var sub_viewport_container: VectorscopeSubViewportContainer

func _ready():
    audio_player.finished.connect(_select_file)
    select_file_dialog.file_selected.connect(_on_file_selected)
    sub_viewport_container.sub_viewport.drawer.draw.connect(VectorscopeDraw.draw_vectorscope.bind(self))
    _select_file()
    
    
func _process(_delta: float) -> void:
    sub_viewport_container.sub_viewport.drawer.queue_redraw()
    

func _input(event: InputEvent):
    if event is InputEventKey:
        if event.pressed && !event.echo:
            if event.keycode == KEY_ESCAPE:
                if !select_file_dialog.visible:
                    _select_file()
            elif event.keycode == KEY_SPACE:
                audio_player.stream_paused = !audio_player.stream_paused


func _on_file_selected(path: String):
    var loader := AudioLoader.new()
    audio_player.stream = loader.loadfile(path)
    audio_player.play()
    

func _select_file():
    select_file_dialog.visible = true
