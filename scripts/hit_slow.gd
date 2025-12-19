extends Node2D

var active: bool = false
var start_time_ms: int = 0
var duration_ms: int = 0
var _time_slow_end_ms: int = 0
var start_scale := 1.0

# Shake parameters
@export var shake_amplitude := 12.0 # pixels
# Easing power for the time-scale curve: values >1 produce an "ease-in" (hold slow longer)
@export var easing_power := 5.0
var _scene_to_shake: Node2D = null
var _original_scene_pos := Vector2.ZERO
var _rng := RandomNumberGenerator.new()
@export var default_intensity := Vector2(1.0, 1.0)
var _intensity_multiplier := default_intensity
var _recenter_in_progress := false
@export var recenter_duration := 0.15 # seconds to lerp back to original position when overlapping shakes
var _recenter_start_pos := Vector2.ZERO
var _recenter_start_time_ms := 0
var _recenter_duration_ms := 0

func _process(_delta: float) -> void:
	if not active:
		return
	var now_ms = Time.get_ticks_msec()
	# compute overall duration based on the current merged end time
	var dur = max(0.001, float(_time_slow_end_ms - start_time_ms) / 1000.0)
	var elapsed = float(now_ms - start_time_ms) / 1000.0
	# if current time has passed the merged end time, finish the slow
	if now_ms >= _time_slow_end_ms:
		Engine.time_scale = 1.0
		# restore shaken scene position
		if _scene_to_shake:
			_scene_to_shake.position = _original_scene_pos
			_scene_to_shake = null
		active = false
		# reset intensity multiplier for next usage
		_intensity_multiplier = default_intensity
		return
	var t = clamp(elapsed / dur, 0.0, 1.0)
	# Use an ease-in curve so the slow persists longer and eases back near the end.
	var ease_val = pow(t, easing_power)
	Engine.time_scale = lerp(start_scale, 1.0, ease_val)

	# scene shake: strongest at start, eases out with (1 - ease_val)
	if _scene_to_shake:
		# If we are currently recentering from a previous shake, lerp back first
		if _recenter_in_progress:
			var rec_elapsed = (Time.get_ticks_msec() - _recenter_start_time_ms) / 1000.0
			var rec_dur = _recenter_duration_ms / 1000.0
			var rt = clamp(rec_elapsed / rec_dur, 0.0, 1.0)
			_scene_to_shake.position = _recenter_start_pos.lerp(_original_scene_pos, rt)
			if rt >= 1.0:
				_recenter_in_progress = false
		else:
				var intensity = (1.0 - ease_val) # 1 -> 0 over time
				var amp_x = shake_amplitude * _intensity_multiplier.x
				var amp_y = shake_amplitude * _intensity_multiplier.y
				var ox = _rng.randf_range(-1.0, 1.0) * amp_x * intensity
				var oy = _rng.randf_range(-1.0, 1.0) * amp_y * intensity
				_scene_to_shake.position = _original_scene_pos + Vector2(ox, oy)

func start(realtime_duration: float, from_scale: float = 0.2, intensity = 1.0) -> void:
	# If already active, start from current time_scale for smooth transition
	var now_ms = Time.get_ticks_msec()
	var req_dur_ms = int(realtime_duration * 1000)
	var req_end_ms = now_ms + req_dur_ms
	if active:
		# already slowing: start from current timescale so easing is smooth
		start_scale = Engine.time_scale
		# extend the merged end time so this new request is honored
		_time_slow_end_ms = max(_time_slow_end_ms, req_end_ms)
	else:
		# new slow: initialize timers
		start_scale = from_scale
		duration_ms = req_dur_ms
		start_time_ms = now_ms
		_time_slow_end_ms = req_end_ms
		active = true
		Engine.time_scale = start_scale
	# prepare scene shake: capture current scene root if it's a Node2D
	_rng.randomize()
	var current = get_tree().get_current_scene()
	if current and current is Node2D:
		# If this is the first activation, capture the original position
		if _scene_to_shake == null:
			_scene_to_shake = current
			_original_scene_pos = _scene_to_shake.position
		else:
			# If a previous shake moved the scene, ensure we recenter before applying new offsets.
			if _scene_to_shake.position != _original_scene_pos:
				_recenter_in_progress = true
				_recenter_start_pos = _scene_to_shake.position
				_recenter_start_time_ms = Time.get_ticks_msec()
				_recenter_duration_ms = int(recenter_duration * 1000)
	else:
		_scene_to_shake = null
	# If a slow is already active, do NOT modify the active time-slow (discard new slow requests' time component)
	# but allow visual intensity to merge component-wise.
	# This prevents many enemies from lengthening or deepening the time slow; only the first slow controls time.
	var req_intensity_vec: Vector2
	if typeof(intensity) == TYPE_VECTOR2:
		req_intensity_vec = intensity
	else:
		req_intensity_vec = Vector2(float(intensity), float(intensity))
	if active:
		_intensity_multiplier = Vector2(max(_intensity_multiplier.x, req_intensity_vec.x), max(_intensity_multiplier.y, req_intensity_vec.y))
		return
	# set intensity multiplier for shake (component-wise)
	_intensity_multiplier = req_intensity_vec

func _ready() -> void:
	set_process(true)
	# leave default pause behavior
