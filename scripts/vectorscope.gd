extends Node2D
class_name Vectorscope

@export_group("Configuration")
@export_range(1 << 11, 1 << 14, 1 << 7) var max_points := 1 << 11
@export_range(0, 100) var length_penalty := 25
@export var line_color := Color.GREEN

@export_group("Nodes")
@export var audio_player: AudioStreamPlayer
@export var select_file_dialog: FileDialog

var line_positions := PackedVector2Array()
var line_colors := PackedColorArray()
var frame_count: int = 0

# Called when the node enters the scene tree for the first time.
func _ready():
    OS.request_permissions()
    select_file_dialog.file_selected.connect(_on_file_selected)
    audio_player.finished.connect(_select_file)
    _select_file()
    
    for i in range(max_points):
        line_positions.append(Vector2.ZERO)
        line_colors.append(line_color)


func _process(_delta: float) -> void:
    queue_redraw()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _draw():
    if audio_player.stream_paused:
        return

    var capture: AudioEffectCapture = AudioServer.get_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
    var available = capture.get_frames_available()
    var buffer := capture.get_buffer(available)
    var previous_frame := Vector2()
    
    if available > max_points:
        buffer = buffer.slice(available - max_points)
        
    for i in range(len(buffer)):
        var frame := buffer[i]
        var point := _get_point_from_frame(frame)
        var index := frame_count % max_points
        line_positions[index] = point
        line_colors[index] = calc_color(frame, previous_frame)
        previous_frame = frame
        frame_count += 1
        
    draw_polyline_colors(line_positions, line_colors)


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
    var distance := sqrt(previous_frame.distance_squared_to(current_frame) / 8)
    var color := Color(line_color)
    color.a = 1 - distance * length_penalty
    return color
    

func _get_point_from_frame(frame: Vector2) -> Vector2:
    frame.y = -frame.y
    var viewport_size := get_viewport_rect().size
    var min_aspect := minf(viewport_size.x, viewport_size.y)
    return (frame * min_aspect + viewport_size) / 2
    

func _select_file():
    select_file_dialog.visible = true
