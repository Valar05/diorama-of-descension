extends Control

@export var max_distance: float = 50.0
@export var return_speed: float = 8.0
@export var hide_threshold: float = 2.0
@export var deadzone: float = 0.2

var base
var pip

var input_vector: Vector2 = Vector2.ZERO
var input_magnitude: float = 0.0
var origin_pos: Vector2 = Vector2.ZERO
var active_touch_id: int = -1

func _ready():
	base = $base
	pip = $base/JoystickPip
	base.visible = false
	pip.visible = false

func _input(event):
	if event is InputEventScreenTouch:
		if event.pressed and event.position.x < get_viewport().get_visible_rect().size.x / 2.0 and active_touch_id == -1:
			# Begin joystick with this finger only
			active_touch_id = event.index
			origin_pos = event.position
			base.global_position = origin_pos
			pip.global_position = origin_pos
			base.visible = true
			pip.visible = true
		elif not event.pressed and event.index == active_touch_id:
			# Release only if it's the one we started with
			active_touch_id = -1

	elif event is InputEventScreenDrag and event.index == active_touch_id:
		var delta = event.position - origin_pos
		var dist = delta.length()
		# Use deadzone as fraction of max_distance
		var mag = min(dist / max_distance, 1.0)
		if mag < deadzone:
			input_vector = Vector2.ZERO
			input_magnitude = 0.0
			pip.global_position = origin_pos
			return
		var dir = delta.normalized()
		# Direction-only input: ignore magnitude and return normalized direction
		input_vector = dir
		# Store magnitude as fraction [0,1] so callers can detect edge pushes
		input_magnitude = mag
		var clamped = dir * min(dist, max_distance)
		pip.global_position = origin_pos + clamped

func _process(_delta):
	if active_touch_id == -1:
		# Immediately teleport the pip back to the base and clear input so
		# no residual lerp causes unexpected movement when the stick is released.
		if base:
			pip.global_position = base.global_position
		input_vector = Vector2.ZERO
		input_magnitude = 0.0
		# Hide immediately when released
		base.visible = false
		pip.visible = false

func get_input_vector() -> Vector2:
	if input_vector.length() < deadzone:
		return Vector2.ZERO
	return input_vector

func get_input_magnitude() -> float:
	# Returns magnitude in range [0,1] representing how far the pip is
	# from center relative to `max_distance`.
	return input_magnitude
