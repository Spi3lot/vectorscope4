extends Node2D

# 0.1 means we consume the dt amount + 10% of the backlog (=> backlog decays exponentially).
# 10% feels safer to me than e.g. 25% as that increases the
# backlog's half-life from ~2 frames to ~6 frames which leaves more room for high fps
const CATCH_UP_SPEED: float = 0.1
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
    if dt == 0.0 or (not %Vectorscope.loopback and %Vectorscope.audio_player.stream_paused):
        return

    var previous_frame := Vector2.ZERO \
        if frame_buffer.is_empty() \
        else frame_buffer[-1]

    var time_multiplier: float
    var sample_rate: float

    if %Vectorscope.loopback:
        time_multiplier = 1.0
        sample_rate = WasapiLoopbackRecorder.SampleRate
        var available: int = WasapiLoopbackRecorder.GetFramesAvailable()
        var size: int = _optimal_frame_buffer_size(sample_rate, available)
        frame_buffer = WasapiLoopbackRecorder.GetBuffer(size)
    else:
        time_multiplier = %Vectorscope.audio_player.pitch_scale
        sample_rate = AudioServer.get_mix_rate()
        var available: int = capture.get_frames_available()
        var size: int = _optimal_frame_buffer_size(sample_rate, available)
        frame_buffer = capture.get_buffer(size)

    var frame_buffer_size := len(frame_buffer)

    if frame_buffer_size == 0:
        return

    _update_line_properties(frame_buffer_size, previous_frame)
    _draw_fade_rect(frame_buffer_size, sample_rate, time_multiplier)
    _draw_multilines()


func _optimal_frame_buffer_size(sample_rate: float, frames_available: int) -> int:
    var ideal_frames: float = sample_rate * dt

    if frames_available < ideal_frames:
        return frames_available

    return roundi(lerpf(ideal_frames, frames_available, CATCH_UP_SPEED))


func _update_line_properties(frame_buffer_size: int, previous_frame: Vector2) -> void:
    line_positions.resize(frame_buffer_size * 2)
    line_colors.resize(frame_buffer_size)
    line_whites.resize(frame_buffer_size)

    for i in range(frame_buffer_size):
        var frame := frame_buffer[i]
        line_positions[i * 2] = _get_point_from_frame(previous_frame)
        line_positions[i * 2 + 1] = _get_point_from_frame(frame)
        line_colors[i] = _calc_line_color(previous_frame, frame)
        line_whites[i] = Color(Color.WHITE, line_colors[i].a)
        previous_frame = frame


func _get_point_from_frame(frame: Vector2) -> Vector2:
    frame.y = -frame.y
    var viewport_size: Vector2i = %Vectorscope.sub_viewport_container.sub_viewport.size
    var min_aspect := mini(viewport_size.x, viewport_size.y)
    return (frame * min_aspect + Vector2(viewport_size)) / 2


func _calc_line_color(previous_frame: Vector2, current_frame: Vector2) -> Color:
    var distance := previous_frame.distance_to(current_frame)
    var normalized_distance: float = distance / (%Vectorscope.plot_scale * SQRT_8)
    var penalty: float = %Vectorscope.length_penalty / sqrt(%Vectorscope.audio_player.pitch_scale)
    var alpha := maxf(0, 1 - normalized_distance * penalty)
    return Color(%Vectorscope.line_color, alpha)


func _draw_fade_rect(frame_buffer_size: int, sample_rate: float, time_multiplier: float) -> void:
    var sub_viewport: VectorscopeSubViewport = %Vectorscope.sub_viewport_container.sub_viewport
    var rect := Rect2(Vector2.ZERO, sub_viewport.size)
    var audio_duration := frame_buffer_size / sample_rate
    var exponent: float = 25.0 * time_multiplier * audio_duration
    var alpha: float = 1 - %Vectorscope.persistence ** exponent
    draw_rect(rect, Color(Color.BLACK, alpha), true)


# We have to use multiline instead of polyline because
# multiline uses segment-by-segment coloring, while
# polyline uses point-by-point coloring
func _draw_multilines() -> void:
    draw_multiline_colors(
        line_positions,
        line_colors,
        %Vectorscope.line_width,
        %Vectorscope.line_antialiasing
    )

    draw_multiline_colors(
        line_positions,
        line_whites,
        %Vectorscope.line_glow * (1 if %Vectorscope.line_width < 0 else %Vectorscope.line_width),
        %Vectorscope.line_antialiasing
    )
