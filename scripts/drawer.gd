extends Node2D

# 0.1 means we consume the dt amount + 10% of the backlog (=> backlog decays exponentially).
# 10% feels safer to me than e.g. 25% as that increases the
# backlog's half-life from ~2 frames to ~6 frames which leaves more room for high fps
const CATCH_UP_SPEED := 0.1
const SQRT_8 := sqrt(8.0)

var frame_buffer := PackedVector2Array()
var line_positions := PackedVector2Array()
var line_colors := PackedColorArray()
var line_whites := PackedColorArray()
var paused := false

var time_multiplier: float
var sample_rate: float

func _process(delta: float) -> void:
    if %Vectorscope.paused:
        if not paused:
            paused = true
            queue_redraw()

        return

    paused = false

    var previous_frame := Vector2.ZERO \
        if frame_buffer.is_empty() \
        else frame_buffer[-1]

    if %Vectorscope.loopback:
        time_multiplier = 1.0
        sample_rate = WasapiLoopbackRecorder.SampleRate
        var available: int = WasapiLoopbackRecorder.GetFramesAvailable()
        var size: int = _optimal_frame_buffer_size(delta, available)
        frame_buffer = WasapiLoopbackRecorder.GetBuffer(size)
    else:
        time_multiplier = %Vectorscope.audio_player.pitch_scale
        sample_rate = AudioServer.get_mix_rate() * _get_stereo_channel_count()
        var available: int = %Vectorscope.capture.get_frames_available()
        var size: int = _optimal_frame_buffer_size(delta, available)
        frame_buffer = %Vectorscope.capture.get_buffer(size)

    if len(frame_buffer) > 0:
        _update_line_properties(previous_frame)
        queue_redraw()


func _draw() -> void:
    if paused:
        return

    _draw_fade_rect()
    _draw_multilines()


func _get_stereo_channel_count() -> int:
    return 1 + AudioServer.get_speaker_mode()


func _optimal_frame_buffer_size(dt: float, frames_available: int) -> int:
    var ideal_frames := sample_rate * dt

    return frames_available \
        if frames_available < ideal_frames \
        else roundi(lerpf(ideal_frames, frames_available, CATCH_UP_SPEED))


func _update_line_properties(previous_frame: Vector2) -> void:
    var frame_buffer_size := len(frame_buffer)
    line_positions.resize(frame_buffer_size * 2)
    line_colors.resize(frame_buffer_size)
    line_whites.resize(frame_buffer_size)

    for i in range(frame_buffer_size):
        var frame := frame_buffer[i]
        line_positions[i * 2] = _frame_to_screen_space(previous_frame)
        line_positions[i * 2 + 1] = _frame_to_screen_space(frame)
        line_colors[i] = _calc_line_color(previous_frame, frame)
        line_whites[i] = Color(Color.WHITE, line_colors[i].a)
        previous_frame = frame


func _frame_to_screen_space(frame: Vector2) -> Vector2:
    frame.y = -frame.y
    var viewport_size: Vector2i = %Vectorscope.sub_viewport_container.sub_viewport.size
    var min_aspect := mini(viewport_size.x, viewport_size.y)
    var screen_pos := (frame * min_aspect + Vector2(viewport_size)) / 2
    return %Vectorscope.vector_transform * screen_pos


func _calc_line_color(previous_frame: Vector2, current_frame: Vector2) -> Color:
    var distance := previous_frame.distance_to(current_frame)
    var normalized_distance: float = distance / (%Vectorscope.plot_scale * SQRT_8)
    var penalty: float = %Vectorscope.length_penalty / sqrt(%Vectorscope.audio_player.pitch_scale)
    var alpha := maxf(0, 1 - normalized_distance * penalty)
    return Color(%Vectorscope.line_color, alpha)


func _draw_fade_rect() -> void:
    var sub_viewport: SubViewport = %Vectorscope.sub_viewport_container.sub_viewport
    var rect := Rect2(Vector2.ZERO, sub_viewport.size)
    var audio_duration := len(frame_buffer) / sample_rate
    var exponent: float = 25.0 * time_multiplier * audio_duration
    var alpha: float = 1 - %Vectorscope.persistence ** exponent
    draw_rect(rect, Color(Color.BLACK, alpha), true)


# We have to use multiline instead of polyline because
# multiline uses segment-by-segment coloring, while
# polyline uses point-by-point coloring
func _draw_multilines() -> void:
    if len(line_positions) == 0:
        return

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
