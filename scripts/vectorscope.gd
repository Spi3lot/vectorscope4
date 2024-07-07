extends Node2D

@export_group("Configuration")
@export_range(2048, 8192, 128, "or_greater") var max_points := 8192
@export var line_color := Color.GREEN

@export_group("Nodes")
@export var line: Line2D
@export var audio_player: AudioStreamPlayer
@export var select_file_dialog: FileDialog


# Called when the node enters the scene tree for the first time.
func _ready():
    audio_player.finished.connect(_select_file)
    select_file_dialog.file_selected.connect(_on_file_selected)
    _select_file()
    
    for i in range(max_points):
        line.gradient.add_point(float(i) / max_points, Color.BLACK)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
    if audio_player.stream_paused:
        return
    
    var capture := AudioServer.get_bus_effect(0, 0) as AudioEffectCapture
    var colors := line.gradient.colors
    var previous_frame := Vector2()
    
    for frame in capture.get_buffer(capture.get_frames_available()):
        _add_frame(frame)
        colors.append(calc_color(previous_frame, frame))
        previous_frame = frame

    _clean_up_points()
    _clean_up_colors(colors)
    line.gradient.colors = colors


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


func calc_color(previous_frame: Vector2, current_frame: Vector2) -> Color:
    var distance := previous_frame.distance_to(current_frame) / sqrt(8)
    return line_color / distance


func _add_frame(frame: Vector2):
    frame.y = -frame.y
    var viewport_size := get_viewport_rect().size
    var min_aspect := minf(viewport_size.x, viewport_size.y)
    var point := (frame * min_aspect + viewport_size) / 2
    line.add_point(point)
    

func _clean_up_points():
    while line.points.size() > max_points:
        line.remove_point(0)
        
        
func _clean_up_colors(colors: PackedColorArray):
    while colors.size() > max_points:
        colors.remove_at(0)
        

func _select_file():
    select_file_dialog.visible = true
