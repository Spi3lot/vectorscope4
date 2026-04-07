extends Node2D

const CATCH_UP_SPEED: float = 0.25 # Means we consume the dt amount + 25% of the backlog (spreading it across 4 frames)
const SQRT_8 := sqrt(8.0)
var frame_buffer := PackedVector2Array()
var line_positions := PackedVector2Array()
var line_colors := PackedColorArray()
var line_whites := PackedColorArray()
var capture: AudioEffectCapture = AudioServer.get_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)
var dt: float = 0.0

func _process(delta: float) -> void:
    dt = delta
    queue_redraw()


func _draw() -> void:
    if dt == 0.0:
        return

    var sample_rate: float = WasapiLoopbackRecorder.SampleRate \
        if %Vectorscope.loopback \
        else AudioServer.get_mix_rate()

    var frame_buffer_size: int = _optimal_frame_buffer_size(sample_rate)

    if not %Vectorscope.loopback and (%Vectorscope.audio_player.stream_paused or capture.get_frames_available() < frame_buffer_size):
        return

    var previous_frame := Vector2.ZERO \
        if frame_buffer.is_empty() \
        else frame_buffer[-1]

    frame_buffer = WasapiLoopbackRecorder.GetBuffer(frame_buffer_size) \
        if %Vectorscope.loopback \
        else capture.get_buffer(frame_buffer_size)

    frame_buffer_size = len(frame_buffer)

    if frame_buffer_size == 0:
        return

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
    var time_multiplier = 1 if %Vectorscope.loopback else %Vectorscope.audio_player.pitch_scale
    var audio_duration := frame_buffer_size / sample_rate
    var exponent: float = 50.0 * time_multiplier * audio_duration
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


func _optimal_frame_buffer_size(sample_rate: float) -> int:
    var ideal_frames: float = sample_rate * dt
    var available_frames: int = WasapiLoopbackRecorder.GetAvailableFrames()

    if available_frames < ideal_frames:
        return available_frames

    var frames_to_request: float = lerpf(ideal_frames, available_frames, CATCH_UP_SPEED)
    return roundi(frames_to_request)


func _get_point_from_frame(frame: Vector2) -> Vector2:
    frame.y = -frame.y
    var viewport_size := Vector2(%Vectorscope.sub_viewport_container.sub_viewport.size)
    var min_aspect := mini(int(viewport_size.x), int(viewport_size.y))
    return (frame * min_aspect + viewport_size) / 2


func _calc_color(previous_frame: Vector2, current_frame: Vector2) -> Color:
    var distance := previous_frame.distance_to(current_frame)
    var normalized_distance: float = distance / (%Vectorscope.plot_scale * SQRT_8)
    var penalty: float = %Vectorscope.length_penalty / sqrt(%Vectorscope.audio_player.pitch_scale)
    var alpha := maxf(0, 1 - normalized_distance * penalty)
    return Color(%Vectorscope.line_color, alpha)
