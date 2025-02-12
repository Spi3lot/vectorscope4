extends Node2D

const SQRT_8 = sqrt(8)
var frame_buffer := PackedVector2Array([Vector2.ZERO])
var line_positions := PackedVector2Array()
var line_colors := PackedColorArray()
var line_whites := PackedColorArray()
var capture: AudioEffectCapture = AudioServer.get_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)

func _process(delta: float) -> void:
    queue_redraw()


func _draw() -> void:
    var available: int = WasapiLoopbackRecorder.GetFramesAvailable() \
        if %Vectorscope.loopback \
        else capture.get_frames_available()
        
    if available == 0 or (not %Vectorscope.loopback and %Vectorscope.audio_player.stream_paused):
        return

    var previous_frame := frame_buffer[-1]
    
    if %Vectorscope.loopback:
        frame_buffer = WasapiLoopbackRecorder.ReadStereo(available)
    else:
        frame_buffer = capture.get_buffer(available)
        
    line_positions.resize(available * 2)
    line_colors.resize(available)
    line_whites.resize(available)

    for i in range(available):
        var frame := frame_buffer[i]
        line_positions[i * 2] = _get_point_from_frame(previous_frame)
        line_positions[i * 2 + 1] = _get_point_from_frame(frame)
        line_colors[i] = _calc_color(previous_frame, frame)
        line_whites[i] = Color(Color.WHITE, line_colors[i].a)
        previous_frame = frame
        
    var sub_viewport: VectorscopeSubViewport = %Vectorscope.sub_viewport_container.sub_viewport
    var rect := Rect2(Vector2.ZERO, sub_viewport.size)
    sub_viewport.drawer.draw_rect(rect, %Vectorscope.fade_color, true)
    
    # We have to use multiline instead of polyline because
    # multiline uses segment-by-segment coloring, while
    # polyline uses point-by-point coloring
    sub_viewport.drawer.draw_multiline_colors(
        line_positions,
        line_colors,
        %Vectorscope.line_width,
        %Vectorscope.line_antialiasing
    )
    
    sub_viewport.drawer.draw_multiline_colors(
        line_positions,
        line_whites,
        abs(%Vectorscope.line_width) * %Vectorscope.line_glow,
        %Vectorscope.line_antialiasing
    )


func _get_point_from_frame(frame: Vector2) -> Vector2:
    frame.y = -frame.y
    var viewport_size := Vector2(%Vectorscope.sub_viewport_container.sub_viewport.size)
    var min_aspect := mini(viewport_size.x, viewport_size.y)
    return (frame * min_aspect + viewport_size) / 2


func _calc_color(previous_frame: Vector2, current_frame: Vector2) -> Color:
    var distance := previous_frame.distance_to(current_frame)
    var normalized_distance: float = distance / (%Vectorscope.plot_scale * SQRT_8)
    var color := Color(%Vectorscope.line_color)
    color.a = maxf(0, 1 - normalized_distance * %Vectorscope.length_penalty)
    return color
