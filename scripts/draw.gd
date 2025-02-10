class_name VectorscopeDraw

static var frame_buffer := PackedVector2Array([Vector2.ZERO])
static var line_positions := PackedVector2Array()
static var line_colors := PackedColorArray()
static var capture: AudioEffectCapture = AudioServer.get_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
    
static func draw_vectorscope(vectorscope: Vectorscope):
    var available: int = WasapiLoopbackRecorder.GetFramesAvailable() \
        if vectorscope.loopback \
        else capture.get_frames_available()
        
    if available == 0:
        return

    if vectorscope.loopback:
        frame_buffer = WasapiLoopbackRecorder.ReadStereo(available)
    elif vectorscope.audio_player.stream_paused:
        return
    else:
        frame_buffer = capture.get_buffer(available)
        
    line_positions.resize(available * 2)
    line_colors.resize(available)
    var previous_frame := frame_buffer[-1]

    for i in range(available):
        var frame := frame_buffer[i]
        line_positions[i * 2] = _get_point_from_frame(previous_frame, vectorscope)
        line_positions[i * 2 + 1] = _get_point_from_frame(frame, vectorscope)
        line_colors[i] = _calc_color(previous_frame, frame, vectorscope)
        previous_frame = frame
        
    var sub_viewport := vectorscope.sub_viewport_container.sub_viewport
    var rect := Rect2(Vector2.ZERO, sub_viewport.size)
    sub_viewport.drawer.draw_rect(rect, vectorscope.fade_color, true)
    
    # We have to use multiline instead of polyline because
    # multiline uses segment-by-segment coloring, while
    # polyline uses point-by-point coloring
    sub_viewport.drawer.draw_multiline_colors(
        line_positions,
        line_colors,
        vectorscope.line_width,
        vectorscope.line_antialiasing
    )


static func _get_point_from_frame(frame: Vector2, vectorscope: Vectorscope) -> Vector2:
    frame.y = -frame.y
    var viewport_size := Vector2(vectorscope.sub_viewport_container.sub_viewport.size)
    var min_aspect := mini(viewport_size.x, viewport_size.y)
    return (frame * min_aspect + viewport_size) / 2


static func _calc_color(previous_frame: Vector2, current_frame: Vector2, vectorscope: Vectorscope) -> Color:
    var distance := sqrt(previous_frame.distance_squared_to(current_frame) / 8)
    var color := Color(vectorscope.line_color)
    color.a = maxf(0, 1 - distance * vectorscope.length_penalty)
    return color
