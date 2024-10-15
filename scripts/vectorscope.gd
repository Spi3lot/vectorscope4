extends Node2D

@export_group("Configuration")
@export_range(2048, 8192, 128, "or_greater") var max_points := 2048
@export var line_color := Color.GREEN

@export_group("Scenes")
@export var line_scene: PackedScene

@export_group("Nodes")
@export var audio_player: AudioStreamPlayer
@export var select_file_dialog: FileDialog

var lines: Array[Line2D] = []
var frame_count: int = 0


# Called when the node enters the scene tree for the first time.
func _ready():
    select_file_dialog.file_selected.connect(_on_file_selected)
    audio_player.finished.connect(_select_file)
    _select_file()
    
    for i in range(max_points):
        var line := line_scene.instantiate()
        lines.append(line)
        $Lines.add_child(line)


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta):
    if audio_player.stream_paused:
        return

    var capture := AudioServer.get_bus_effect(0, 0) as AudioEffectCapture
    var previous_point := _get_point_from_frame(Vector2())
    var available = capture.get_frames_available()
    var buffer := capture.get_buffer(available)
    
    if available > max_points:
        buffer = buffer.slice(available - max_points)

    for frame in buffer:
        var point := _get_point_from_frame(frame)
        #_add_point(point, previous_point, lines[frame_count % max_points])
        previous_point = point
        frame_count += 1
        
    queue_redraw()

func _draw() -> void:
    draw_line(Vector2(), Vector2(100, 100), line_color, 1.0)    


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


func _add_point(point: Vector2, previous_point: Vector2, line: Line2D):
    line.set_point_position(0, previous_point)
    line.set_point_position(1, point)
    

func _get_point_from_frame(frame: Vector2) -> Vector2:
    frame.y = -frame.y
    var viewport_size := get_viewport_rect().size
    var min_aspect := minf(viewport_size.x, viewport_size.y)
    return (frame * min_aspect + viewport_size) / 2
    

func _select_file():
    select_file_dialog.visible = true
