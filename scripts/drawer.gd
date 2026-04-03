extends Node2D

const SQRT_8 := sqrt(8)
var frame_buffer := PackedVector2Array()
var line_positions := PackedVector2Array()
var line_colors := PackedColorArray()
var line_whites := PackedColorArray()
var capture: AudioEffectCapture = AudioServer.get_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)

func _process(_delta: float) -> void:
    queue_redraw()


func _draw() -> void:
    # TODO: Remove
    if Engine.get_frames_drawn() % 60 == 0:
        print(WasapiLoopbackRecorder.Fps)
        print(Engine.get_frames_per_second())
        print(DisplayServer.screen_get_refresh_rate())
        print()

    var sample_rate: float = WasapiLoopbackRecorder.SampleRate \
        if %Vectorscope.loopback \
        else AudioServer.get_mix_rate()

    var frame_buffer_size: int = WasapiLoopbackRecorder.OptimalFrameBufferSize(sample_rate)

    if not %Vectorscope.loopback and (capture.get_frames_available() < frame_buffer_size or %Vectorscope.audio_player.stream_paused):
        return

    var previous_frame := Vector2.ZERO \
        if frame_buffer.is_empty() \
        else frame_buffer[-1]

    # TODO: fix non-loopback
    frame_buffer = WasapiLoopbackRecorder.GetBuffer(frame_buffer_size) \
        if %Vectorscope.loopback \
        else capture.get_buffer(frame_buffer_size)

    if frame_buffer.is_empty():
        return

    WasapiLoopbackRecorder.UpdateFps()
    line_positions.resize(frame_buffer_size * 2)
    line_colors.resize(frame_buffer_size)
    line_whites.resize(frame_buffer_size)

    for i in range(frame_buffer_size):
        var frame := frame_buffer[i]
        line_positions[i * 2] = _get_point_from_frame(previous_frame)
        line_positions[i * 2 + 1] = _get_point_from_frame(frame)
        line_colors[i] = _calc_color(previous_frame, frame)
        line_whites[i] = Color(Color.WHITE, line_colors[i].a)
        previous_frame = frame
        
    var sub_viewport: VectorscopeSubViewport = %Vectorscope.sub_viewport_container.sub_viewport
    var rect := Rect2(Vector2.ZERO, sub_viewport.size)
    var exponent: float = 1000 * frame_buffer_size / (sample_rate * WasapiLoopbackRecorder.Fps)
    var alpha: float = 1 - %Vectorscope.persistence ** exponent
    sub_viewport.drawer.draw_rect(rect, Color(Color.BLACK, alpha), true)
    
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
        %Vectorscope.line_glow * (1 if %Vectorscope.line_width < 0 else %Vectorscope.line_width),
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
