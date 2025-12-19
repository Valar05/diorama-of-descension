# Attack system

extends CharacterBody2D

@export var sprite_front: Texture2D
@export var sprite_right: Texture2D
@export var sprite_back: Texture2D
@export var Slash: PackedScene
@export var health: float = 15.0
@export var damage: float = 10.0
@export var hyperarmor: float = 0.0
@export var joystick: Control = null

var attacks = {}
var attack_sequence = []
var attack_index = 0
var attack_active = false
var attack_timer = 0.0
var attack_duration = 1.0
var attack_buffered = false
var attack_buffer_timer = 0.0
var attack_buffer_max = 0.25
var attack_lockout = false
var attack_lockout_timer = 0.0
var attack_lockout_duration = 1.0
@export var kick_pause_delay := 0.4
@export var kick_window_max := 0.95
var kick_pending := false
var kick_timer := 0.0
var kick_ready := false
var kick_arm_time := 0.0
var kick_knockback_mult := 1.0
var kick_shake_intensity := 1.0
var kick_hit_intensity := 1.0
var kick_damage := 8.0

var tap_position: Vector2 = Vector2.ZERO
var last_tap_release_position: Vector2 = Vector2.ZERO
var tap_timer: float = 0.0
var tap_start_pos: Vector2 = Vector2.ZERO
var tap_start_time: float = 0.0
var tap_detected: bool = false
var movement_pending: bool = false
var moving: bool = false
var drag_current_pos: Vector2 = Vector2.ZERO
@export var debug_movement := false
@export var debug_touch_state := false
@export var debug_attack_input := false
@export var debug_dash_direction := true
# Movement speed variables
var walk_speed := 400.0 # pixels per second
var run_speed := walk_speed * 1.5
var current_speed := walk_speed
	
var acceleration_delay := 0.8 # seconds before acceleration starts
var acceleration_time := 0.25 # seconds to reach run speed
var acceleration_timer := 0.0
var deceleration_time := 0.3 # seconds to decelerate to zero
var deceleration_timer := 0.0
var stick_raw := Vector2.ZERO
var stick_dir := Vector2.ZERO
var stick_mag := 0.0
@export var use_stick_easing := true

# Bobbing effect variables
var bob_phase := 0.0
var bob_amplitude := 50.0
var bob_base_y := 0.0 # legacy, not used for rest
var body_rest_y := 0.0
var bob_speed_min := 3.0 # minimum bob speed (walk)
var bob_speed_max := 12.0 # maximum bob speed (run, about 2x walk)
var bob_amplitude_walk := 70.0 # amplitude at walk
var bob_amplitude_run := 50.0 # amplitude at run

var last_scale_x_sign := 1.0
var print_facing_debug := false
var _prev_facing_texture = null
var _prev_facing_sign := 1.0

var movement_disabled_time := 0.0 # (unused now)

# Slash dash state
var slash_dash_active := false
var slash_dash_timer := 0.0
var slash_dash_duration := 0.07
var slash_dash_direction := Vector2.ZERO
var slash_inst: Node = null
@export var stick_dash_threshold := 0.9 # fraction of stick radius to trigger dash (last 10%)
@export var stick_dash_hysteresis := 0.8 # release threshold to re-arm dash
@export var stick_dash_duration := 0.15
@export var stick_dash_speed_mult := 4.0
# --- Stick flick (radial impulse) dash detection ---
@export var dash_edge := 0.90              # outer ring threshold
@export var dash_rearm := 0.75             # must fall below to re-arm
@export var dash_flick_mag_delta := 0.20   # how much magnitude must jump
@export var dash_flick_time := 0.060       # seconds allowed for that jump

var _prev_stick_mag := 0.0
var _mag_jump_timer := 0.0
var stick_dir_frame := Vector2.ZERO

var stick_dash_ready := true
var stick_dash_active := false
var stick_dash_start := Vector2.ZERO
var stick_dash_total_distance := 0.0
var stick_dash_timer := 0.0
var stick_dash_direction := Vector2.ZERO
@export var stick_dash_trigger_fraction := 1.0 # fraction of input-vector length that must move
@export var stick_dash_trigger_time := 0.03 # seconds window to detect the movement
@export var stick_dash_trigger_min_mag := 0.35 # require current stick magnitude at/above this to trigger rolling dash
var stick_last_vector := Vector2.ZERO
var stick_last_time := 0.0

# Hold-to-dash state (separate from slash dash)
var hold_dash_active := false
var hold_dash_timer := 0.0
var hold_dash_duration := 0.14 # will be set to twice slash_dash_duration in _ready
var hold_dash_direction := Vector2.ZERO
var hold_dash_start := Vector2.ZERO
var hold_dash_target := Vector2.ZERO
var hold_dash_total_distance := 0.0

var hold_dash_consumed := false
@export var hold_dash_threshold := 0.25
@export var swipe_threshold := 120.0
@export var attack_tap_time := 0.2
@export var swipe_max_time := 0.4
@export var hold_move_time := 0.15
@export var movement_drag_threshold := 30.0
@export var swipe_min_speed := 1500.0 # pixels per second; short fast swipes trigger even if distance is small
@export var launcher_tap_window := 0.4 # max time for two-finger press+release to be considered simultaneous
@export var launcher_press_window := 0.25 # max time between first and second press to be simultaneous-ish
@export var launcher_buffer_max := 0.6 # how long a buffered launcher remains valid (s)
@export var gesture_cleanup_time := 3.0 # seconds after which stale touch_gestures are pruned
@export var combo_cancel_time := 0.7 # seconds before attack end when a buffered attack can cancel into the next
@export var combo_cancel_early_frac := 0.3 # allow cancel early once this fraction of attack_duration has passed

# Post-dash lockout
var post_dash_lockout := false
var post_dash_lockout_timer := 0.0
var post_dash_lockout_duration := 0.2

# Dash lockout to prevent infinite dashing
@export var dash_lockout_time := 0.25
var _last_dash_time := -100.0

# Hit reaction state
var hit_reacting := false
var hit_react_timer := 0.0
var hit_react_duration := 0.3
var hit_slide_dir := Vector2.ZERO
var hit_slide_speed := 300.0
var hit_facing := "south"
var active_touch_count := 0
var launcher_press_detected := false
var launcher_press_start := 0.0
var launcher_buffered := false
var launcher_buffer_timer := 0.0
var launcher_target := Vector2.ZERO
var active_touch_ids := []
var multi_touch_sequence := false
var kick_active := false

# Launcher elevation variables
@export var launcher_elevation_peak := 150.0
@export var launcher_elevation_up_frac := 0.2 # fraction of attack_duration used for rising phase (up is half the time of down)
var elevation := 0.0
var _elevation_timer = 0.0
var elevation_active = false
var _prev_collision_disabled = false
var _prev_hitbox_monitoring = false
var launcher_base_position := Vector2.ZERO
var _launcher_base_body_scale := Vector2.ONE
var _elevation_scale_factor := 1.0
var _launcher_shadow_base_pos := Vector2.ZERO
var _launcher_shadow_base_scale := Vector2.ONE
var _prev_facing_locked := false
@export var airborne_attack_elevation_add := 25.0
var elevation_bonus := 0.0
var last_press_index := -1
var hold_touch_id := -1
var touch_gestures := {}
var gesture_sequence_start_time := 0.0
var gesture_sequence_indices := []
var swipe_samples := []
var swipe_vecs := []
var swipe_sample_times := []
var last_swipe_sample_pos := Vector2.ZERO
@export var enable_touch_swipe_sampling := false

# Track time since last successful attack dealt (reset attack_index if exceeds threshold)
var time_since_last_attack := 0.0
var reset_attack_after := 1.5

@onready var body = $Sprite2D_body
@onready var shadow = $Sprite2D_shadow
@onready var anim_player = $AnimationPlayer
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var facing_sprite: Sprite3D = $SubViewport/FacingSprite
@export var facing_sprite_y_offset := 0.0 # radians; tweak if the 3D sprite's forward axis differs

@export var clamp_to_viewport := true
@export var clamp_margin := 16.0
@onready var dash_slash_hitbox = $DashSlashHitbox
var dash_hit_targets := []
var release_block_timer := 0.0
@export var release_block_duration := 0.08
var facing_locked: bool = false
var moving_by_joystick: bool = false
var dash_invulnerable := false
@export var facing_preserve_time := 0.12 # seconds to preserve facing after joystick release
var facing_preserve_timer := 0.0
var preserved_facing_dir := Vector2.ZERO
var last_stick_dir := Vector2.ZERO

func _apply_facing(dir: Vector2) -> void:
	if not body:
		return
	if dir.length() == 0:
		return
	# Diagnostics: log when _apply_facing is invoked so we can find conflicting writers
	if Engine.is_editor_hint() == false and false:
		# disabled by default; flip to `true` manually when running to avoid log spam
		print("[apply_facing] dir:", dir, "time:", Time.get_ticks_msec())
	var d = dir.normalized()
	if abs(d.x) > abs(d.y):
		body.texture = sprite_right
		if d.x < 0:
			body.scale.x = -abs(body.scale.x)
			last_scale_x_sign = -1.0
		else:
			body.scale.x = abs(body.scale.x)
			last_scale_x_sign = 1.0
	else:
		if d.y > 0:
			body.texture = sprite_front
		else:
			body.texture = sprite_back
		body.scale.x = abs(body.scale.x)
		last_scale_x_sign = 1.0

func _set_moving(val: bool, reason: String = "") -> void:
	# centralized setter so we can log transitions during debugging
	# Prevent re-enabling movement immediately after a release to avoid race conditions
	if val and release_block_timer > 0.0:
		if debug_movement:
			print("[moving-state] suppress-enable due to release_block (reason):", reason, "timer:", release_block_timer)
		return
	if debug_movement and moving != val:
		print("[moving-state] from:", moving, "to:", val, "reason:", reason, "tap_timer:", tap_timer, "tap_position:", tap_position, "global:", global_position)
	moving = val
	# Unlock facing when the player explicitly starts moving
	if moving:
		facing_locked = false


func _get_attack_direction() -> Vector2:
	# Prefer current joystick input direction, fall back to last stick dir,
	# then fall back to the tap vector if present, otherwise default right.
	var dir = Vector2.ZERO
	if joystick and joystick.has_method("get_input_vector"):
		dir = joystick.get_input_vector()
		if dir.length() > 0.0:
			stick_raw = dir
			stick_mag = dir.length()
			stick_dir = dir.normalized()
			return dir.normalized()
	if last_stick_dir.length() > 0.0:
		return last_stick_dir.normalized()
	if tap_position != Vector2.ZERO:
		var dv = (tap_position - global_position)
		if dv.length() > 0.0:
			return dv.normalized()
	return Vector2.RIGHT
	# Prefer the canonical per-frame stick vector (set in _process),
	# then the last stick direction, then the tap vector, otherwise right.
	if stick_dir_frame and stick_dir_frame.length() > 0.001:
		return stick_dir_frame.normalized()
	if last_stick_dir and last_stick_dir.length() > 0.0:
		return last_stick_dir.normalized()
	if tap_position != Vector2.ZERO:
		var dv = (tap_position - global_position)
		if dv.length() > 0.0:
			return dv.normalized()
	return Vector2.RIGHT


func _attack_target_point(dist: float = 60.0) -> Vector2:
	var d = _get_attack_direction()
	return global_position + d * dist

func _ready():
	# Load attacks from JSON
	add_to_group("player")
	var file = FileAccess.open("res://player_attacks.json", FileAccess.READ)
	body.set("shader_parameter/dissolve_noise_offset", Vector2(randf() / 0.65, randf() / 0.65))
	if file:
		var json = file.get_as_text()
		attacks = JSON.parse_string(json)
		if attacks and attacks.has("light"):
			attack_sequence = attacks["light"]
			# Load kick knockback multiplier if present
			if attacks.has("kick"):
				var kdata = attacks["kick"]
				if kdata and kdata.has("knockback"):
					kick_knockback_mult = float(kdata["knockback"])
				if kdata and kdata.has("intensity_x"):
					kick_shake_intensity = float(kdata["intensity_x"])
				if kdata and kdata.has("intensity_x"):
					kick_hit_intensity = float(kdata["intensity_x"])
				if kdata and kdata.has("damage"):
					kick_damage = float(kdata["damage"])
		file.close()
	if body:
		_launcher_base_body_scale = body.scale
		body_rest_y = body.position.y
	anim_player.play("RESET")
	# Ensure hold dash duration is twice the slash dash by default
	hold_dash_duration = slash_dash_duration * 2.0
	stick_dir_frame = Vector2.ZERO


# Ease-out function (fast start, slow end)
func ease_out(t: float) -> float:
	return t * t

func take_damage(amount: float, dir: Vector2, _hitter: Node) -> void:
	# If performing the hold-to-dash, ignore damage (invulnerable during this dash)
	# Ignore damage while in hold dash or stick-driven dash invulnerability
	if hold_dash_active or dash_invulnerable:
		return
	# If elevated (launcher) above safe threshold, ignore damage
	if elevation > 20.0:
		return

	health -= amount
	if health <= 0.0:
		get_tree().reload_current_scene()
	else:
		anim_player.play("hurt")
	# If taking damage while attacking and it exceeds hyperarmor, interrupt the attack
	if (attack_active or slash_dash_active) and amount > hyperarmor:
		attack_active = false
		attack_timer = 0.0
		slash_dash_active = false
		slash_dash_timer = 0.0
		velocity = Vector2.ZERO
		attack_buffered = false
		_on_attack_end("interrupted_by_damage")
	hit_reacting = true
	hit_react_timer = 0.0
	hit_slide_dir = dir.normalized()
	# start hit slow for the player being hit: 0.3s realtime from 20% to 100%
	var hs = _ensure_hit_slow()
	if hs:
		hs.start(1.0, 0.05, 1.0)
	# Determine facing direction (NESW) towards the hitter
	if abs(dir.x) > abs(dir.y):
		if dir.x > 0:
			hit_facing = "west"
			body.texture = sprite_right
			body.scale.x = -abs(body.scale.x)
		else:
			hit_facing = "east"
			body.texture = sprite_right
			body.scale.x = abs(body.scale.x)
	else:
		if dir.y < 0:
			hit_facing = "south"
			body.texture = sprite_front
		else:
			hit_facing = "north"
			body.texture = sprite_back
		body.scale.x = abs(body.scale.x)

func _input(event):
	# Allow inputs during post-dash lockout for buffering; block only on attack lockout
	# Normally block inputs during attack lockout, but allow drag plus all touch events so swipe/dash gestures can finish cleanly
	if attack_lockout:
		var lockout_whitelisted := event is InputEventScreenDrag or event is InputEventScreenTouch
		if not lockout_whitelisted:
			if debug_movement or debug_attack_input:
				var etype = "unknown"
				if event is InputEventScreenTouch:
					etype = "touch_press" if event.pressed else "touch_release"
				elif event is InputEventScreenDrag:
					etype = "drag"
				print("[input-blocked] attack_lockout active, ignoring event:", etype, "attack_lockout_timer:", attack_lockout_timer, "dur:", attack_lockout_duration)
			return
	# Restrict touch-based gameplay inputs to the right half of the screen.
	# Left-half touches are handled by the joystick and should not start movement/attacks here.
	var mid_x = get_viewport().get_visible_rect().size.x / 2.0
	if (event is InputEventScreenTouch or event is InputEventScreenDrag) and event.position.x < mid_x:
		return
	if event is InputEventScreenTouch and event.pressed:
		# start a per-touch gesture record
		var now_t = Time.get_ticks_msec() / 1000.0
		touch_gestures[event.index] = {
			"start_time": now_t,
			"start_pos": event.position,
			"cur_pos": event.position,
			"consumed": false,
			"state": "pending",
			"released_duration": 0.0
		}
		# sequence bookkeeping (first touch starts a new sequence)
		if active_touch_count == 0:
			gesture_sequence_start_time = now_t
			gesture_sequence_indices = []
		else:
			# If the ongoing sequence is stale (very long time since start), reset it
			if now_t - gesture_sequence_start_time > gesture_cleanup_time:
				gesture_sequence_start_time = now_t
				gesture_sequence_indices = []
		if not (event.index in gesture_sequence_indices):
			gesture_sequence_indices.append(event.index)
		# Safety: if sequence list grows unexpectedly large, clear to avoid stuck/locked inputs
		if gesture_sequence_indices.size() > 12:
			if debug_movement:
				print("[input] gesture_sequence_indices overflow -> clearing (size):", gesture_sequence_indices.size(), "indices:", gesture_sequence_indices)
			gesture_sequence_indices = []
		# keep sequence list bounded to avoid stale growth in high-touch scenarios
		if gesture_sequence_indices.size() > 8:
			gesture_sequence_indices.remove_at(0)
		# record general global state used by other systems
		last_press_index = event.index
		if active_touch_count == 0:
			launcher_press_start = now_t
		# track unique touch ids and counts
		if not (event.index in active_touch_ids):
			active_touch_ids.append(event.index)
		if active_touch_ids.size() > 1:
			multi_touch_sequence = true
		# Reconcile active_touch_count with the unique id list to avoid mismatches
		active_touch_count = active_touch_ids.size()
		if debug_movement:
			print("[input] press idx:", event.index, "active_count:", active_touch_count, "active_ids:", active_touch_ids, "gesture_seq_start:", gesture_sequence_start_time, "seq_size:", gesture_sequence_indices.size())
		# reset some global tap state so existing code relying on them stays consistent
		tap_position = event.position
		last_tap_release_position = event.position
		tap_start_pos = event.position
		drag_current_pos = event.position
		tap_start_time = now_t
		tap_timer = 0.0
		tap_detected = true
		hold_dash_consumed = false
		movement_pending = true
		_set_moving(false, "press_init")
	elif event is InputEventScreenDrag:
		# handle per-touch drag for this gesture
		if not (event.index in touch_gestures):
			# initialize a gesture if we somehow missed the press
			var now_init = Time.get_ticks_msec() / 1000.0
			touch_gestures[event.index] = {"start_time": now_init, "start_pos": event.position, "cur_pos": event.position, "consumed": false, "state": "pending", "released_duration": 0.0}
		# update current position for this gesture
		touch_gestures[event.index]["cur_pos"] = event.position
		# update global drag tracking for compatibility
		drag_current_pos = event.position
		last_tap_release_position = event.position
		# compute gesture-local drag metrics
		var g = touch_gestures[event.index]
		var drag_vec = g["cur_pos"] - g["start_pos"]
		var drag_dist = drag_vec.length()
		var swipe_elapsed = (Time.get_ticks_msec() / 1000.0) - float(g["start_time"])
		var swipe_speed = drag_dist / max(0.001, swipe_elapsed)
		# Allow swipe if this is a single-touch sequence OR it's from a different touch than the hold-touch
		var initiating_touch_ok: bool = (event.index >= 0 and (hold_touch_id == -1 or event.index != hold_touch_id))
		if swipe_elapsed <= swipe_max_time and not g["consumed"] and not hold_dash_active and (drag_dist >= swipe_threshold and swipe_speed >= swipe_min_speed) and (active_touch_ids.size() == 1 and not multi_touch_sequence or initiating_touch_ok):
			# Swipe-to-dash has been replaced by the stick-edge dash mechanic.
			# Consume the gesture to avoid accidental double-activation, but
			# do not start the legacy hold-dash.
			g["consumed"] = true
			g["state"] = "swiped"
			# Determine swipe direction: if swipe is predominantly upward, trigger Launcher
			var sdir = Vector2.ZERO
			if drag_dist > 0.0:
				sdir = drag_vec.normalized()
			# Upward in screen coordinates: negative Y and greater magnitude than X
			if abs(sdir.y) > abs(sdir.x) and sdir.y < 0.0:
					# Cannot start launcher while already elevated
				if elevation > 0.0:
					if debug_movement:
						print("[input] launcher blocked while elevated")
					return
				# If attacking, cancel so launcher can occur immediately
				if attack_active:
					attack_active = false
					attack_timer = 0.0
					attack_buffered = false
					slash_dash_active = false
					slash_dash_timer = 0.0
					velocity = Vector2.ZERO
					_on_attack_end("interrupted_by_swipe_launcher")
				# Start Launcher attack using the current movement/attack vector (not the tap)
				var atk_dir = _get_attack_direction()
				var dash_target = global_position + atk_dir * 60.0
				_start_attack(dash_target, "Launcher", 1.0, 100.0, 1.25, 0.25, 1.0)
			else:
				if debug_movement:
					print("[input] swipe-detected but not upward; ignored for launcher")
		else:
			# If cumulative drag exceeds the movement threshold, start movement immediately (drag-to-move)
			# Do not start movement during active attacks; allow only swipe-dash while attacking.
			if not attack_active and drag_dist >= movement_drag_threshold:
				# Drag-to-move disabled. Movement is controlled exclusively by the joystick.
				# Keep gesture state for swipes/attacks but do not initiate movement here.
				movement_pending = false
			else:
				# still undecided (could be an attack tap) — don't start movement yet
				# Do not cancel an already-started movement on minor drag jitter.
				# Leave movement state unchanged so hold-to-move isn't interrupted.
				pass
	elif event is InputEventScreenTouch and !event.pressed:
		# handle per-touch release
		var now_t = Time.get_ticks_msec() / 1000.0

		var g = null
		if event.index in touch_gestures:
			g = touch_gestures[event.index]
			var dur = now_t - float(g["start_time"])
			# mark gesture released so it can be inspected after sequence end
			g["state"] = "released"
			g["released_duration"] = dur
			# mark global last release position for compatibility
			last_tap_release_position = event.position
		# update active touches and detect last-finger release
		var prev_touch_count = active_touch_count
		# remove this touch id from the unique id list if present
		if event.index in active_touch_ids:
			active_touch_ids.erase(event.index)
		# Reconcile active_touch_count with the unique id list to avoid mismatches
		active_touch_count = active_touch_ids.size()
		if debug_movement:
			print("[input] release idx:", event.index, "prev_count:", prev_touch_count, "new_count:", active_touch_count, "gesture_indices:", gesture_sequence_indices)
		# If no touches remain, ensure multi-touch state is cleared to avoid blocking single taps
		if active_touch_count == 0:
			multi_touch_sequence = false
			hold_touch_id = -1
		# Opportunistic two-finger detection: if two gestures have been released recently, consider them a launcher
		var released_gests := []
		for k in touch_gestures.keys():
			var tg = touch_gestures[k]
			if tg.has("state") and tg["state"] == "released":
				released_gests.append(k)

		# If this release left exactly one active touch (i.e. we're releasing the second finger),
		# try to detect a two-finger quick-tap immediately using the still-active touch as the pair.
		if prev_touch_count == 2 and active_touch_count == 1:
			# find the remaining active id (if any)
			var other_id := -1
			if active_touch_ids.size() > 0:
				other_id = active_touch_ids[0]
			if other_id != -1 and event.index in touch_gestures and other_id in touch_gestures:
				var a = touch_gestures[event.index]
				var b = touch_gestures[other_id]
				var press_diff_ab = abs(float(a["start_time"]) - float(b["start_time"]))
				var other_dur = now_t - float(b["start_time"])
				# Both must be short taps and unconsumed
				if press_diff_ab <= launcher_press_window and a["released_duration"] < launcher_tap_window and other_dur < launcher_tap_window and not a["consumed"] and not b["consumed"]:
					# Prevent double-buffering the same launcher repeatedly
					if not launcher_buffered:
						# Only accept launcher if both touches began on the right half
						var allow_launcher = false
						if a.has("start_pos") and b.has("start_pos"):
							if a["start_pos"].x >= mid_x and b["start_pos"].x >= mid_x:
								allow_launcher = true
						if allow_launcher:
							launcher_buffered = true
							launcher_buffer_timer = 0.0
							# target the midpoint between the two touch presses
							launcher_target = (a["start_pos"] + b["start_pos"]) * 0.5
						else:
							if debug_movement:
								print("[input] ignored launcher (second-finger) not on right half")
						if debug_movement:
							print("[input] second-finger-release launcher buffered (released id:", event.index, "other:", other_id, ") press_diff:", press_diff_ab, "other_dur:", other_dur, "released_dur:", a["released_duration"])
						if debug_touch_state:
							_dump_touch_state("launcher_buffered:second_release")
					else:
						if debug_movement:
							print("[input] launcher_buffered already true -> skipping second-finger buffer")
					# remove both gestures from tracking
					touch_gestures.erase(event.index)
					if other_id in touch_gestures:
						touch_gestures.erase(other_id)
					# remove from sequence list too
					if other_id in gesture_sequence_indices:
						gesture_sequence_indices.erase(other_id)
					if event.index in gesture_sequence_indices:
						gesture_sequence_indices.erase(event.index)
					# Clear multi-touch flags because we consumed the pair
					multi_touch_sequence = false
					hold_touch_id = -1
					# skip opportunistic pair loop
					released_gests = []
		# If at least two gestures are released, try to find a qualifying pair
		if released_gests.size() >= 2:
			for i in range(released_gests.size() - 1):
				for j in range(i + 1, released_gests.size()):
					var a = touch_gestures[released_gests[i]]
					var b = touch_gestures[released_gests[j]]
					var press_diff = abs(float(a["start_time"]) - float(b["start_time"]))
					# Detailed diagnostics for why a candidate pair is accepted or rejected
					var accept_pair := false
					var reject_reasons := []
					if press_diff > launcher_press_window:
						reject_reasons.append("press_diff")
					if a["released_duration"] >= launcher_tap_window:
						reject_reasons.append("a_released_too_long")
					if b["released_duration"] >= launcher_tap_window:
						reject_reasons.append("b_released_too_long")
					if a["consumed"]:
						reject_reasons.append("a_consumed")
					if b["consumed"]:
						reject_reasons.append("b_consumed")
					if reject_reasons.size() == 0:
						accept_pair = true
					if accept_pair:
						# Buffer launcher and remove both gestures
						if not launcher_buffered:
							# Only accept a two-finger launcher if both touches began on right half
							var allow_pair_launcher = false
							if a.has("start_pos") and b.has("start_pos"):
								if a["start_pos"].x >= mid_x and b["start_pos"].x >= mid_x:
									allow_pair_launcher = true
							if allow_pair_launcher:
								launcher_buffered = true
								launcher_buffer_timer = 0.0
								# target the midpoint between the two touch presses
								launcher_target = (a["start_pos"] + b["start_pos"]) * 0.5
								if debug_movement:
									print("[input] opportunistic launcher buffered for pair:", released_gests[i], released_gests[j], "press_diff:", press_diff)
								if debug_touch_state:
									_dump_touch_state("launcher_buffered:opportunistic_pair")
							else:
								if debug_movement:
									print("[input] opportunistic launcher skipped (not on right half)")
						else:
							if debug_movement:
								print("[input] opportunistic launcher skipped (already buffered)")
						# remove both gestures from tracking so they don't linger
						if released_gests[j] in touch_gestures:
							touch_gestures.erase(released_gests[j])
						if released_gests[i] in touch_gestures:
							touch_gestures.erase(released_gests[i])
						# also remove from sequence indices if present
						if released_gests[j] in gesture_sequence_indices:
							gesture_sequence_indices.erase(released_gests[j])
						if released_gests[i] in gesture_sequence_indices:
							gesture_sequence_indices.erase(released_gests[i])
					else:
						if debug_movement:
							print("[input] opportunistic pair rejected:", released_gests[i], released_gests[j], "press_diff:", press_diff, "reasons:", reject_reasons)
						# erase both from touch_gestures
						touch_gestures.erase(released_gests[j])
						touch_gestures.erase(released_gests[i])
						# adjust gesture_sequence_indices if present
						if released_gests[j] in gesture_sequence_indices:
							gesture_sequence_indices.erase(released_gests[j])
						if released_gests[i] in gesture_sequence_indices:
							gesture_sequence_indices.erase(released_gests[i])
						# reduce prev_touch_count marker so later logic won't double-handle
						prev_touch_count = max(0, prev_touch_count - 2)
						# Clear multi-touch flags because we consumed the pair
						multi_touch_sequence = false
						hold_touch_id = -1
						break
					if launcher_buffered:
						break
					# If pair was handled, exit inner loop
					break
		# If this was the last release in the sequence, analyze the whole sequence
		if prev_touch_count >= 2 and active_touch_count == 0:
			# check for two-finger quick tap (launcher)
			var seq_count = gesture_sequence_indices.size()
			var seq_ok = false
			if seq_count == 2:
				seq_ok = true
				# Debug: show gesture info we will evaluate
				if debug_movement:
					print("[input] evaluating two-finger sequence indices:", gesture_sequence_indices)
				for idx in gesture_sequence_indices:
					if not (idx in touch_gestures):
						seq_ok = false
						break
					var gest = touch_gestures[idx]
					var press_delay = float(gest["start_time"]) - gesture_sequence_start_time
					if debug_movement:
						print("[input] gest:", idx, "start_time:", gest["start_time"], "press_delay:", press_delay, "released_duration:", gest["released_duration"], "consumed:", gest["consumed"])
					# Press must be within launcher_press_window of the first press
					if press_delay > launcher_press_window:
						seq_ok = false
						break
					# Release must be within launcher_tap_window from this gesture's press
					if gest["released_duration"] >= launcher_tap_window:
						seq_ok = false
						break
					# Gesture must not have been consumed (no swipe/hold)
					if gest["consumed"]:
						seq_ok = false
						break
				# if both gestures were short and not consumed, it's a launcher
					if seq_ok and not attack_lockout:
						if not launcher_buffered:
							# Only accept sequence two-finger launcher if both start positions are on right half
							var aidx = gesture_sequence_indices[0]
							var bidx = gesture_sequence_indices[1]
							if aidx in touch_gestures and bidx in touch_gestures:
								var aa = touch_gestures[aidx]
								var bb = touch_gestures[bidx]
								var allow_seq_launcher = false
								if aa.has("start_pos") and bb.has("start_pos"):
									if aa["start_pos"].x >= mid_x and bb["start_pos"].x >= mid_x:
										allow_seq_launcher = true
								if allow_seq_launcher:
									launcher_buffered = true
									launcher_buffer_timer = 0.0
									launcher_target = (aa["start_pos"] + bb["start_pos"]) * 0.5
									if debug_movement:
										print("[input] launcher_buffered (two-finger) seq_indices:", gesture_sequence_indices, "start_time:", gesture_sequence_start_time)
									if debug_touch_state:
										_dump_touch_state("launcher_buffered:sequence")
								else:
									if debug_movement:
										print("[input] two-finger launcher skipped (not on right half)")
						else:
							if debug_movement:
								print("[input] two-finger launcher skipped (already buffered)")
			# cleanup gesture entries for the sequence
			for idx in gesture_sequence_indices:
				if idx in touch_gestures:
					touch_gestures.erase(idx)
			gesture_sequence_indices = []
			# reset multi-touch flags and hold touch
			multi_touch_sequence = false
			hold_touch_id = -1
		else:
			# If this was a single-finger release, handle tap buffering for that gesture
			if g != null:
				if not g["consumed"]:
					# compute drag distance for this gesture
					var drag_dist = g["start_pos"].distance_to(event.position)
					# apply tap buffering rules similar to previous global logic
					if not launcher_buffered and not multi_touch_sequence and g["released_duration"] < attack_tap_time and drag_dist < swipe_threshold and (g["released_duration"] < hold_move_time or not movement_pending):
						if not attack_lockout:
							# Only buffer a single-finger attack if the gesture began on the right half
							var allow_attack = false
							if g.has("start_pos") and g["start_pos"].x >= mid_x:
								allow_attack = true
							if allow_attack:
								# Prevent stacking multiple identical buffered attacks
								if not attack_buffered:
									attack_buffered = true
									attack_buffer_timer = 0.0
									if debug_movement:
										print("[input] attack_buffered set idx:", event.index, "dur:", g["released_duration"], "drag_dist:", drag_dist)
									if debug_touch_state:
										_dump_touch_state("attack_buffered:set_idx:" + str(event.index))
								else:
									if debug_movement:
										print("[input] attack_buffered already true -> skipping")
							else:
								if debug_movement:
									print("[input] attack ignored (not on right half)")
					else:
						movement_pending = false
						_set_moving(false, "release_stop")
						acceleration_timer = 0.0
						current_speed = 0.0
						release_block_timer = release_block_duration
				# clear this gesture now
				touch_gestures.erase(event.index)
				# Ensure this released index doesn't linger in the global sequence indices
				if event.index in gesture_sequence_indices:
					gesture_sequence_indices.erase(event.index)
		# clear touch tracking globals for compatibility
		velocity = Vector2(0.0, 0.0)
		tap_detected = false
		drag_current_pos = Vector2.ZERO
		# Defensive: if no touches remain, clear any lingering gesture state
		if active_touch_count == 0:
			if touch_gestures.size() > 0:
				if debug_movement:
					print("[input] clearing lingering touch_gestures and gesture_sequence_indices (no active touches)")
				touch_gestures.clear()
				gesture_sequence_indices = []

func _spawn_slash(tap_pos: Vector2, anim_name: String, intensity: float = 1.0, vertical_offset: float = 0.0, target_scale: float = 1.0, tween_dur: float = 0.25, knockback_mult: float = 1.0):
	if Slash:
		var slash_instance = Slash.instantiate()
		slash_instance.damage = damage
		# mark whether this instance is a launcher so hit targets can respond
		if anim_name == "Launcher" and slash_instance.has_method("set") == false and slash_instance.has_variable("is_launcher"):
			slash_instance.is_launcher = true
		elif anim_name == "Launcher" and slash_instance.has_method("set"):
			# safe fallback for different script interfaces
			slash_instance.set("is_launcher", true)
		add_child(slash_instance)
		var direction = (tap_pos - global_position).normalized()
		var base_pos = global_position + direction * 60.0
		# apply vertical offset (raise = negative y)
		var target_pos = base_pos + Vector2(0, -vertical_offset)
		slash_instance.global_position = base_pos
		slash_instance.rotation = direction.angle() + PI / 2
		# z-index: ensure it appears in front when requested (player's z_index + 10)
		slash_instance.z_index = int(z_index) + 10 if vertical_offset != 0.0 else int(z_index)
		# set initial scale then tween to target_scale if scaling requested
		slash_instance.scale = Vector2.ONE
		# pass intensity to the slash so it can trigger shake with attack-specific magnitude
		if slash_instance.has_method("set"):
			# set a property if the script exposes it
			slash_instance.set("attack_intensity", intensity)
		else:
			# fallback: attempt to assign directly
			if "attack_intensity" in slash_instance:
				slash_instance.attack_intensity = intensity
		var kb_mult_local = knockback_mult
		if elevation > 0.0:
			kb_mult_local = 0.0
		if "knockback_mult" in slash_instance:
			slash_instance.knockback_mult = kb_mult_local
		# pass knockback direction based on facing/attack direction
		if "knockback_dir" in slash_instance:
			slash_instance.knockback_dir = direction
		if "airborne_attack_elevation_add" in slash_instance:
			slash_instance.airborne_attack_elevation_add = airborne_attack_elevation_add
		var slash_anim = slash_instance.get_node_or_null("AnimationPlayer")
		if slash_anim:
			slash_anim.play(anim_name)
		# perform ease-out tweens for vertical movement and scale when requested
		if vertical_offset != 0.0 or target_scale != 1.0:
			var tw = slash_instance.create_tween()
			if vertical_offset != 0.0:
				tw.tween_property(slash_instance, "global_position", target_pos, tween_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
			if target_scale != 1.0:
				tw.tween_property(slash_instance, "scale", Vector2(target_scale, target_scale), tween_dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# mark that an attack started now
		time_since_last_attack = 0.0

func _ensure_hit_slow():
	# Prefer an autoload singleton at /root/HitSlow; fall back to creating one for compatibility
	var hs = null
	hs = get_node("/root/HitSlow")
	return hs


func _dump_touch_state(reason: String = "") -> void:
	if not debug_touch_state:
		return
	var keys = touch_gestures.keys()
	print("[touch-state] reason:", reason, "active_touch_ids:", active_touch_ids, "active_touch_count:", active_touch_count, "gesture_seq:", gesture_sequence_indices, "touch_keys:", keys, "attack_active:", attack_active, "attack_buffered:", attack_buffered, "launcher_buffered:", launcher_buffered)
	for k in keys:
		var tg = touch_gestures.get(k)
		if tg:
			print("[touch-state] key:", k, "start:", tg.get("start_time"), "state:", tg.get("state"), "consumed:", tg.get("consumed"), "released_dur:", tg.get("released_duration"))

func _on_attack_end(reason: String = "attack_end") -> void:
	# centralize cleanup when an attack ends to prevent unintended movement
	if debug_movement:
		print("[attack-end] reason:", reason, "tap_detected:", tap_detected, "movement_pending:", movement_pending, "moving:", moving)
	if debug_touch_state:
		_dump_touch_state("on_attack_end:" + reason)
	movement_pending = false
	_set_moving(false, reason)
	tap_detected = false
	tap_timer = 0.0
	drag_current_pos = Vector2.ZERO
	# If an elevation was active (launcher), cancel it and restore states immediately
	if elevation_active:
		elevation_active = false
		_elevation_timer = 0.0
		elevation = 0.0
		elevation_bonus = 0.0
		# restore collision/hitbox
		if collision_shape:
			collision_shape.disabled = _prev_collision_disabled
		if dash_slash_hitbox:
			dash_slash_hitbox.monitoring = _prev_hitbox_monitoring
		# restore base position
		global_position = launcher_base_position
		# restore body scale
		if body:
			body.scale = _launcher_base_body_scale
			# Reset shader stretch back to zero so the sprite returns to normal
			var _mat = body.get_material()
			if _mat and _mat is ShaderMaterial:
				_mat.set_shader_parameter("top_stretch_x", 0.0)
				_mat.set_shader_parameter("top_stretch", 0.0)
			# restore shadow local position
			if shadow:
				shadow.position = _launcher_shadow_base_pos
				shadow.scale = _launcher_shadow_base_scale
		# reset elevation scale factor
		_elevation_scale_factor = 1.0

	# Defensive reconciliation: clear any lingering per-touch bookkeeping that
	# can persist through complex multi-touch sequences and lead to input
	# lockups. We do this on every attack end to ensure a fresh input state.
	var _did_clear := false
	if touch_gestures.size() > 0 or gesture_sequence_indices.size() > 0 or active_touch_ids.size() > 0:
		_did_clear = true
		if debug_movement:
			print("[on_attack_end] Reconciling/clearing lingering touch state")
		touch_gestures.clear()
		gesture_sequence_indices = []
		active_touch_ids.clear()
		active_touch_count = 0
		multi_touch_sequence = false
		hold_touch_id = -1
		# also clear any buffered actions to avoid chained firings
		# Clear launcher buffers (we don't want chained launchers), but preserve
		# regular `attack_buffered` so legitimate combo cancels still execute.
		launcher_buffered = false
		launcher_buffer_timer = 0.0
		# Emit post-clear diagnostics so the log shows the reconciled state
		if debug_touch_state:
			_dump_touch_state("on_attack_end:cleared")
	kick_active = false

func _start_attack(dash_target: Vector2, anim_name: String, intensity: float = 1.0, vertical_offset: float = 0.0, target_scale: float = 1.0, tween_dur: float = 0.25, knockback_mult: float = 1.0) -> void:
	# Centralized attack start logic to keep timing consistent
	if debug_movement:
		print("[attack] _start_attack -> anim:", anim_name, "target:", dash_target, "intensity:", intensity, "vert:", vertical_offset)
	if debug_touch_state:
		_dump_touch_state("start_attack:" + anim_name)
	# Aggressively clear lingering per-touch state when performing a launcher to avoid
	# leftover gestures causing duplicate buffered actions shortly after.
	if anim_name == "Launcher":
		# Do not start launcher while already elevated
		if elevation > 0.0:
			return
		if debug_movement:
			print("[start_attack] Clearing lingering touch state for Launcher to avoid duplicates")
		# clear per-touch bookkeeping and any pending buffers to avoid chained launches
		touch_gestures.clear()
		gesture_sequence_indices = []
		active_touch_ids.clear()
		active_touch_count = 0
		multi_touch_sequence = false
		hold_touch_id = -1
		launcher_buffered = false
		attack_buffered = false
		launcher_buffer_timer = 0.0
		attack_buffer_timer = 0.0
		# Activate elevation wave for launcher: start timer and lock visuals
		elevation_active = true
		_elevation_timer = 0.0
		elevation = 0.0
		# remember base body scale so we can scale up during elevation
		if body:
			_launcher_base_body_scale = body.scale
		# remember the shadow's local position so we can keep it anchored to the
		# launch origin during elevation and restore it afterwards
		if shadow:
			_launcher_shadow_base_pos = shadow.position
			_launcher_shadow_base_scale = shadow.scale
		# remember base position so elevation moves relative to it
		launcher_base_position = global_position
		# lock facing for the duration of the launcher so mid-air position changes
		# (movement of global_position) don't flip the sprite unexpectedly.
		_prev_facing_locked = facing_locked
		facing_locked = true
		# store previous collision state and disable hit/collision while airborne
		if collision_shape:
			_prev_collision_disabled = collision_shape.disabled
			collision_shape.disabled = true
		if dash_slash_hitbox:
			_prev_hitbox_monitoring = dash_slash_hitbox.monitoring
			dash_slash_hitbox.monitoring = false
		# launcher always resets combo counter
		attack_index = 0
	else:
		# While airborne, add a small elevation bump on attack start
		if elevation > 0.0:
			elevation_bonus += airborne_attack_elevation_add
	_spawn_slash(dash_target, anim_name, intensity, vertical_offset, target_scale, tween_dur, knockback_mult)
	# Ensure player faces the attack direction immediately
	_apply_facing((dash_target - global_position).normalized())
	# Do not perform a movement dash for the launcher animation; launcher is a rooted attack
	if anim_name != "Launcher":
		slash_dash_active = true
		slash_dash_timer = 0.0
		slash_dash_direction = (dash_target - global_position).normalized()
		post_dash_lockout = false
		post_dash_lockout_timer = 0.0
	# freeze regular movement while attacking
	_set_moving(false, "attack_start")
	# Prevent any pending movement from triggering while attack is active
	movement_pending = false
	drag_current_pos = Vector2.ZERO
	tap_detected = false
	# Cancel any pending kick once a new attack begins
	kick_pending = true
	kick_timer = 0.0
	kick_ready = false
	kick_arm_time = Time.get_ticks_msec() / 1000.0
	kick_active = false
	velocity = Vector2.ZERO
	attack_active = true
	attack_timer = 0.0
	# If this was a normal combo attack, advance the combo index. Launcher
	# is a separate action and should NOT advance the attack sequence.
	if anim_name != "Launcher":
		attack_index += 1
		if attack_index >= attack_sequence.size():
			attack_index = 0
			attack_lockout = true
			attack_lockout_timer = 0.0
	else:
		# Launcher is a separate action: do not advance combo nor enforce lockout here.
		pass
	attack_buffered = false


func _disable_movement_for(duration: float):
	movement_disabled_time = duration

func _process(delta):
	# Hit reaction slide and facing
	if hit_reacting:
		hit_react_timer += delta
		var t = clamp(hit_react_timer / hit_react_duration, 0.0, 1.0)
		var ease_val = 1.0 - pow(1.0 - t, 2.0) # ease out
		velocity = hit_slide_dir * hit_slide_speed * (1.0 - ease_val)
		move_and_slide()
		if hit_react_timer >= hit_react_duration:
			hit_reacting = false
			velocity = Vector2.ZERO
		# Even while reacting to a hit, advance the attack_lockout timer so
		# we don't get stuck in a permanent lockout state if `_process`
		# is returning early for the hit reaction. This ensures the player
		# can attack again after the intended lockout duration.
		if attack_lockout:
			attack_lockout_timer += delta
			if attack_lockout_timer >= attack_lockout_duration:
				attack_lockout = false
		# Allow dashes to cancel hit reaction; continue processing instead of returning

	# Handle attack lockout (blocks new attacks but does not stop dash updates)
	if attack_lockout:
		attack_lockout_timer += delta
		if attack_lockout_timer >= attack_lockout_duration:
			attack_lockout = false
		# While locked out, cancel any pending/ready kick window
		kick_pending = false
		kick_ready = false
		kick_active = false
		kick_timer = 0.0
		kick_arm_time = 0.0

	# While airborne, clamp combo index to first two attacks
	if elevation > 0.0:
		attack_index = clamp(attack_index, 0, 1)

	# Handle attack buffering and combo cancel
	if debug_movement:
		print("[process] attack_active:", attack_active, "attack_buffered:", attack_buffered, "launcher_buffered:", launcher_buffered, "attack_timer:", attack_timer, "tap_detected:", tap_detected)

	if attack_active:
		# Allow a buffered attack to cancel into the next attack shortly before the current one ends.
		# This provides responsive combos: if the player buffered an input, we start the next
		# attack `combo_cancel_time` seconds before the current attack would naturally finish.
		if attack_buffered and not launcher_buffered:
			# Allow cancel either a fixed time before end or once a fraction of the attack has elapsed
			var early_threshold = attack_duration * combo_cancel_early_frac
			var can_cancel = attack_timer >= max(0.0, attack_duration - combo_cancel_time) or attack_timer >= early_threshold
			if can_cancel:
				if debug_movement:
					print("[process] combo-cancel: consuming attack_buffered early (attack_timer):", attack_timer)
				# consume buffered attack immediately
				attack_buffered = false
				attack_buffer_timer = 0.0
				if kick_ready:
					# Cancel current attack cleanly and fire kick instead of next combo step
					slash_dash_active = false
					slash_dash_timer = 0.0
					attack_active = false
					attack_timer = 0.0
					_on_attack_end("kick_cancel")
					_trigger_kick()
					return
				# start the next attack in sequence using the same logic as idle consumption
				var attack_data = null
				if attack_sequence.size() > 0 and attack_index < attack_sequence.size():
					attack_data = attack_sequence[attack_index]
				var anim_name = "SlashLeft"
				if attack_data and attack_data.has("name"):
					anim_name = attack_data["name"]
				var atk_dir = _get_attack_direction()
				var atk_dash_target = global_position + atk_dir * 60.0
				var intensity = 1.0
				if attack_data and attack_data.has("intensity"):
					intensity = float(attack_data["intensity"])
				var kb_mult = 1.0
				if attack_data and attack_data.has("knockback"):
					kb_mult = float(attack_data["knockback"])
				_start_attack(atk_dash_target, anim_name, intensity, 0.0, 1.0, 0.25, kb_mult)
				# After starting the next attack, stop processing this frame so the new
				# attack's initial state is handled next frame.
				return
		# If any buffers were created during this attack, leave them to be handled when the attack ends.
		if (launcher_buffered or attack_buffered) and debug_movement:
			print("[process] buffered while active -> will wait until attack end:", "attack_timer:", attack_timer, "launcher_buffered:", launcher_buffered, "attack_buffered:", attack_buffered)
		if attack_timer == 0.0: # Just started attack
			# Start dash and lockout (use movement direction as dash direction)
			slash_dash_active = true
			slash_dash_timer = 0.0
			slash_dash_direction = _get_attack_direction()
			post_dash_lockout = false
			post_dash_lockout_timer = 0.0
		elif attack_timer >= attack_duration:
			attack_active = false
			attack_timer = 0.0
			_on_attack_end("attack_sequence_timeout")
			if attack_index == 0 and attack_lockout:
				attack_index = 0
	else:
		# Handle attack buffering when not attacking
		# If a launcher was buffered while idle, fire it immediately (takes precedence)
		if launcher_buffered and not attack_buffered:
			# Cannot start launcher while already elevated
			if elevation > 0.0:
				launcher_buffered = false
				launcher_target = Vector2.ZERO
			else:
				if debug_movement:
					print("[process] firing launcher_buffered while idle")
				var dash_target = Vector2.ZERO
				# Prefer explicit launcher_target (midpoint between touches), fall back to release/tap position
				if launcher_target != Vector2.ZERO:
					dash_target = launcher_target
				else:
					# No explicit launcher midpoint — target along movement direction
					var ldir = _get_attack_direction()
					dash_target = global_position + ldir * 60.0
				_start_attack(dash_target, "Launcher", 1.0, 100.0, 1.25, 0.25, 1.0)
				launcher_target = Vector2.ZERO
				launcher_buffered = false
				attack_buffered = false
		
		if attack_buffered:
			if debug_movement:
				print("[process] attack_buffered while idle -> starting attack (launcher_buffered:", launcher_buffered, ")")
			# launcher takes precedence if buffered
			if launcher_buffered:
				# If a launcher is buffered alongside attack_buffered, prefer the explicit
				# `launcher_target` midpoint if available.
				var lt = Vector2.ZERO
				if launcher_target != Vector2.ZERO:
					lt = launcher_target
				else:
					lt = global_position
				_start_attack(lt, "Launcher", 1.0, 100.0, 1.25, 0.25, 1.0)
				launcher_target = Vector2.ZERO
				launcher_buffered = false
				attack_buffered = false
			# If a kick is ready and grounded, consume the buffered attack and fire kick instead
			if kick_ready and not launcher_buffered and elevation <= 0.0:
				_trigger_kick()
				attack_buffered = false
				attack_buffer_timer = 0.0
			else:
				# Start attack immediately when buffered and idle
				var attack_data = null
				if attack_sequence.size() > 0 and attack_index < attack_sequence.size():
					attack_data = attack_sequence[attack_index]
				var anim_name = "SlashLeft"
				if attack_data and attack_data.has("name"):
					anim_name = attack_data["name"]
				var atk_dir = _get_attack_direction()
				var atk_dash_target = global_position + atk_dir * 60.0
				var intensity = 1.0
				if attack_data and attack_data.has("intensity"):
					intensity = float(attack_data["intensity"])
				var kb_mult = 1.0
				if attack_data and attack_data.has("knockback"):
					kb_mult = float(attack_data["knockback"])
				_start_attack(atk_dash_target, anim_name, intensity, 0.0, 1.0, 0.25, kb_mult)

	# Kick trigger window: measure pause from attack START; timer runs while pending
	if kick_pending:
		var now_k = Time.get_ticks_msec() / 1000.0
		kick_timer = max(0.0, now_k - kick_arm_time)
		if kick_timer >= kick_pause_delay:
			kick_ready = true
			kick_pending = false
			kick_active = false
		elif kick_timer >= kick_window_max:
			# auto-expire kick window after max duration
			kick_pending = false
			kick_ready = false
			kick_active = false

	# Handle attack timer
	if attack_active:
		attack_timer += delta
		if attack_timer >= attack_duration:
			attack_active = false
			attack_timer = 0.0
			_on_attack_end("attack_timer_end")
			# Only reset attack_index if we just finished the last attack in the sequence
			if attack_index == 0 and attack_lockout:
				attack_index = 0

	# Advance any buffer timers and prune stale gesture state
	if launcher_buffered:
		launcher_buffer_timer += delta
		if launcher_buffer_timer >= launcher_buffer_max:
			# expire stale launcher buffer
			launcher_buffered = false
			launcher_buffer_timer = 0.0
			launcher_target = Vector2.ZERO

	# Periodic cleanup: remove touch_gestures entries older than gesture_cleanup_time
	var now_t = Time.get_ticks_msec() / 1000.0
	var stale_keys := []
	for k in touch_gestures.keys():
		var tg = touch_gestures[k]
		if tg and tg.has("start_time"):
			if now_t - float(tg["start_time"]) > gesture_cleanup_time:
				stale_keys.append(k)
	for k in stale_keys:
		if k in touch_gestures:
			touch_gestures.erase(k)
		if k in gesture_sequence_indices:
			gesture_sequence_indices.erase(k)

	# Elevation handling for Launcher: move player up visually and manage invulnerability
	if elevation_active:
		_elevation_timer += delta
		# Tie elevation wave length to the current attack duration so it matches animation.
		# If mid-air attacks add elevation_bonus, extend descent time so we do not snap down.
		var total_dur = max(0.001, attack_duration)
		var up_time = total_dur * launcher_elevation_up_frac
		var down_time = max(0.001, total_dur - up_time)
		# effective descent time includes extra height from elevation_bonus
		var fall_speed = launcher_elevation_peak / down_time
		var extra_down_time = 0.0
		if fall_speed > 0.0:
			extra_down_time = elevation_bonus / fall_speed
		var down_time_effective = down_time + extra_down_time
		var total_time_effective = up_time + down_time_effective
		if _elevation_timer <= up_time:
			var t = clamp(_elevation_timer / up_time, 0.0, 1.0)
			# ease out on rise
			elevation = launcher_elevation_peak * ease_out(t)
		elif _elevation_timer <= total_time_effective:
			var t2 = clamp((_elevation_timer - up_time) / down_time_effective, 0.0, 1.0)
			# ease in on fall using total height (base peak + bonus)
			var total_height = launcher_elevation_peak + elevation_bonus
			var new_total = total_height * (1.0 - (t2 * t2))
			# split new_total back into base elevation and bonus so other logic works unchanged
			if new_total > launcher_elevation_peak:
				elevation = launcher_elevation_peak
				elevation_bonus = new_total - launcher_elevation_peak
			else:
				elevation = new_total
				elevation_bonus = 0.0
		else:
			# end of effective curve: clamp to ground
			elevation = 0.0
			elevation_bonus = 0.0
		# apply vertical offset to the player's global position (visual lift), including airborne bonus
		global_position = launcher_base_position - Vector2(0, elevation + elevation_bonus)
		# Keep the shadow anchored at the launch origin (ground) while elevated
		if shadow:
			shadow.global_position = launcher_base_position
		# compute elevation scale factor (applied later after bobbing so it composes with facing/bob scale)
		var frac = clamp(elevation / launcher_elevation_peak, 0.0, 1.0)
		# shrink shadow smoothly with elevation: normal at ground -> 0.5 at peak
		if shadow:
			var base_sh = _launcher_shadow_base_scale.x if _launcher_shadow_base_scale else 1.0
			var sh_scale = lerp(base_sh, 0.5, frac)
			shadow.scale = Vector2(sh_scale, sh_scale)
		_elevation_scale_factor = 1.0 + 0.15 * frac
		# Compute shader-driven top stretch: ease with the same curve so it
		# peaks at -0.5 when elevation is at maximum and returns to 0 on ground.
		var stretch_curve = ease_out(frac)
		var stretch_val = -0.23 * stretch_curve
		# Set shader parameters if the sprite has a ShaderMaterial. We set both
		# `top_stretch_x` (new name) and `top_stretch` (compatibility name).
		if body:
			var mat = body.get_material()
			if mat and mat is ShaderMaterial:
				mat.set_shader_parameter("top_stretch_x", stretch_val)
				mat.set_shader_parameter("top_stretch", stretch_val)
		# finish elevation wave when timer exceeds effective duration AND we're back on ground height
		if _elevation_timer >= total_time_effective and elevation <= 0.001 and elevation_bonus <= 0.001:
			elevation_active = false
			_elevation_timer = 0.0
			elevation = 0.0
			elevation_bonus = 0.0
			# snap back to the launch base so any accumulated elevation offsets do not linger
			global_position = launcher_base_position
			# restore collision and hitbox states
			if collision_shape:
				collision_shape.disabled = _prev_collision_disabled
			if dash_slash_hitbox:
				dash_slash_hitbox.monitoring = _prev_hitbox_monitoring
			# restore body scale
			if body:
				body.scale = _launcher_base_body_scale
				# Reset shader stretch back to zero so the sprite returns to normal
				var _mat_end = body.get_material()
				if _mat_end and _mat_end is ShaderMaterial:
					_mat_end.set_shader_parameter("top_stretch_x", 0.0)
					_mat_end.set_shader_parameter("top_stretch", 0.0)
					_mat_end.set_shader_parameter("bottom_stretch", 0.0)
				# restore shadow local position
				if shadow:
					shadow.position = _launcher_shadow_base_pos
					shadow.scale = _launcher_shadow_base_scale
				# restore prior facing lock state
				facing_locked = _prev_facing_locked
			# reset elevation scale factor
			_elevation_scale_factor = 1.0
			# ensure player stays clamped to viewport after restoring position
			_clamp_to_viewport()

	# Track tap timer if touch is active
	if tap_detected:
		tap_timer += delta
		# Hold-to-move disabled: joystick controls movement exclusively.
		# We still track hold timing for other interactions (e.g., dash gestures),
		# but we won't start movement from a held touch.
		if movement_pending and not moving and tap_timer >= hold_move_time and not attack_active:
			movement_pending = false
			# remember which touch initiated the hold so other touches can still act
			hold_touch_id = last_press_index
		# Swipe-based dash is handled in _input during drag events; normal hold behavior continues

	# Rolling swipe sampling: sample joystick input when available, otherwise
	# fall back to touch drag sampling. Stick sampling uses `stick_last_vector`
	# to compute per-sample deltas (distance between consecutive stick samples),
	# and triggers when the sum of those deltas over `stick_dash_trigger_time`
	# exceeds `stick_dash_trigger_fraction` (measured in stick units 0..1).
	var now_t_local = Time.get_ticks_msec() / 1000.0
	# Determine current stick vector (direction * magnitude) if joystick present
	stick_mag = 0.0
	if joystick and joystick.has_method("get_input_vector"):
		var sdir_frame = joystick.get_input_vector()
		# read raw magnitude (use provided method if available)
		var raw_mag = 0.0
		if joystick.has_method("get_input_magnitude"):
			raw_mag = joystick.get_input_magnitude()
		else:
			raw_mag = sdir_frame.length()
		# Optionally apply easing so center movements have less effect
		if use_stick_easing:
			stick_mag = ease_out(clamp(raw_mag, 0.0, 1.0))
		else:
			stick_mag = raw_mag
		# compose canonical per-frame vector (direction * eased magnitude)
		stick_dir_frame = sdir_frame * stick_mag
	# If we have a non-zero stick sample, sample from the stick (preferred)
	if stick_dir_frame.length() > 0.0:
		if stick_last_vector == Vector2.ZERO:
			stick_last_vector = stick_dir_frame
			stick_last_time = now_t_local
		var delta_pos = stick_dir_frame - stick_last_vector
		var delta_len = delta_pos.length()
		if delta_len > 0.0:
			swipe_samples.append(delta_len)
			swipe_vecs.append(delta_pos)
			swipe_sample_times.append(now_t_local)
		stick_last_vector = stick_dir_frame
		stick_last_time = now_t_local
		# prune old samples
		while swipe_sample_times.size() > 0 and (now_t_local - swipe_sample_times[0]) > stick_dash_trigger_time:
			swipe_samples.remove_at(0)
			swipe_vecs.remove_at(0)
			swipe_sample_times.remove_at(0)
		# compute combined travel (in stick units) and aggregate vector
		var combined_len = 0.0
		var agg_vec = Vector2.ZERO
		for i in range(swipe_samples.size()):
			combined_len += float(swipe_samples[i])
			agg_vec += swipe_vecs[i]
		var trigger_threshold = max(0.0, stick_dash_trigger_fraction)
		var mag_ok = stick_mag >= stick_dash_trigger_min_mag
		if combined_len >= trigger_threshold and mag_ok:
			# Use canonical stick direction when available; fallback to aggregate
			# movement only if the stick is effectively zero.
			var sdir_use = Vector2.ZERO
			if stick_dir_frame.length() > 0.001:
				sdir_use = stick_dir_frame.normalized()
			elif agg_vec.length() > 0.0:
				sdir_use = agg_vec.normalized()
			else:
				sdir_use = Vector2.RIGHT
			if debug_dash_direction:
				print("[dash-debug] combined_len:", combined_len, "threshold:", trigger_threshold, "mag:", stick_mag, "mag_ok:", mag_ok, "stick_dir_frame:", stick_dir_frame, "agg_vec:", agg_vec, "chosen:", sdir_use)
			# Clear samples and reset last sample for fresh detection
			swipe_samples.clear()
			swipe_vecs.clear()
			swipe_sample_times.clear()
			last_swipe_sample_pos = Vector2.ZERO
			stick_last_vector = Vector2.ZERO
			stick_last_time = 0.0
			# Interrupt active attack and arm a stick dash via central function
			if attack_active:
				attack_active = false
				attack_timer = 0.0
				attack_buffered = false
				_on_attack_end("interrupted_by_stick_swipe")
			# Attempt to start a centralized dash; `_start_stick_dash` will
			# return false if lockout prevented it. Only run additional
			# post-dash effects if the dash actually started.
			if _start_stick_dash(sdir_use, "stick_swipe"):
				# `_start_stick_dash` already configures hitbox/anim/invuln,
				# so nothing more is required here.
				pass
	# Fallback: sample touch drags when no joystick input present and enabled
	elif tap_detected and enable_touch_swipe_sampling:
		if last_swipe_sample_pos == Vector2.ZERO:
			last_swipe_sample_pos = drag_current_pos
		var delta_pos = drag_current_pos - last_swipe_sample_pos
		var delta_len = delta_pos.length()
		if delta_len > 0.0:
			swipe_samples.append(delta_len)
			swipe_vecs.append(delta_pos)
			swipe_sample_times.append(now_t_local)
			last_swipe_sample_pos = drag_current_pos
		while swipe_sample_times.size() > 0 and (now_t_local - swipe_sample_times[0]) > stick_dash_trigger_time:
			swipe_samples.remove_at(0)
			swipe_vecs.remove_at(0)
			swipe_sample_times.remove_at(0)
		var combined_len = 0.0
		var agg_vec = Vector2.ZERO
		for i in range(swipe_samples.size()):
			combined_len += float(swipe_samples[i])
			agg_vec += swipe_vecs[i]
		var trigger_threshold = swipe_threshold * max(0.0, stick_dash_trigger_fraction)
		if combined_len >= trigger_threshold:
			# Decide direction from aggregated recent movement (preferred) or fallback
			var sdir = Vector2.ZERO
			if agg_vec.length() > 0.0:
				sdir = agg_vec.normalized()
			else:
				sdir = _get_attack_direction()
			# Only trigger a touch-driven dash for left-side drags. Right-side
			# drags are reserved for the launcher and handled in _input (separate gesture).
			var vw_x = 0.0
			if has_method("get_viewport"):
				vw_x = get_viewport().get_visible_rect().size.x
			else:
				vw_x = get_viewport_rect().size.x if Engine.has_singleton("Engine") else 0.0
			var left_side = (tap_start_pos.x >= 0.0 and vw_x > 0.0 and tap_start_pos.x < (vw_x * 0.5))
			if left_side:
				# Interrupt an active attack so dash can proceed
				if attack_active:
					attack_active = false
					attack_timer = 0.0
					attack_buffered = false
					_on_attack_end("interrupted_by_swipe_dash")
				# Attempt centralized dash startup; `_start_stick_dash` will
				# apply hitbox/anim/invuln and honor lockout.
				if _start_stick_dash(sdir, "touch_swipe"):
					pass
			# Clear samples now that we've acted on the gesture
			swipe_samples.clear()
			swipe_vecs.clear()
			swipe_sample_times.clear()
			last_swipe_sample_pos = Vector2.ZERO
	else:
		# no active input: clear rolling samples so we don't carry stale data
		if swipe_samples.size() > 0:
			swipe_samples.clear()
			swipe_vecs.clear()
			swipe_sample_times.clear()
			last_swipe_sample_pos = Vector2.ZERO

	# Track time since last attack started; reset attack index if exceeded and player is idle
	time_since_last_attack += delta
	if time_since_last_attack >= reset_attack_after and not attack_active:
		attack_index = 0
		attack_buffered = false
		# Also clear any pending or ready kick when combo resets
		kick_pending = false
		kick_ready = false
		kick_timer = 0.0
		kick_arm_time = 0.0
		# clamp to avoid repeated resets rapidly
		time_since_last_attack = 0.0

	# Decrease release_block_timer so movement can be re-enabled after the short block window
	if release_block_timer > 0.0:
		release_block_timer = max(0.0, release_block_timer - delta)

	# Decrease facing_preserve_timer so we only temporarily preserve facing
	if facing_preserve_timer > 0.0:
		facing_preserve_timer = max(0.0, facing_preserve_timer - delta)

	# Handle slash dash
	# Handle hold-to-dash (separate from slash dash). This runs before slash dash handling
	if hold_dash_active:
		hold_dash_timer += delta
		# compute speed so we would reach the target in hold_dash_duration
		var dash_speed = 0.0
		if hold_dash_total_distance > 0.0:
			dash_speed = hold_dash_total_distance / hold_dash_duration
		# move incrementally; clamp so we don't overshoot
		var move_amount = dash_speed * delta
		var traveled = (global_position - hold_dash_start).length()
		var remaining = max(0.0, hold_dash_total_distance - traveled)
		var move_now = min(move_amount, remaining)
		if move_now > 0.0:
			global_position += hold_dash_direction * move_now
		# apply dash hits each physics frame while dashing so overlaps are detected reliably
		_apply_dash_hits()
		# End dash if we reached target or duration expired
		if remaining <= 0.01 or hold_dash_timer >= hold_dash_duration:
			hold_dash_active = false
			# re-enable collision/hurtbox
			if collision_shape:
				collision_shape.disabled = false
			# disable the dash hitbox monitoring so it doesn't persist after the dash
			if dash_slash_hitbox:
				dash_slash_hitbox.monitoring = false
				dash_hit_targets.clear()
			# Determine residual distance to original tap target (tap_position may be beyond our clamped target)
			# remaining_to_tap not used; we decide movement mode based on whether we reached the dash target
			# If we reached the dash target exactly (or close), start at walk; if there's still distance to the cursor, start running
			if remaining <= 0.01:
				# reached our hold-dash target — resume movement as a walk if the player is still holding
				current_speed = walk_speed
				acceleration_timer = 0.0
				_set_moving(tap_detected, "hold-dash-end-reached")
			else:
				# dash ended due to duration — there may be remaining distance; resume movement at run speed
				current_speed = run_speed
				acceleration_timer = acceleration_delay + acceleration_time
				_set_moving(tap_detected, "hold-dash-end-duration")
			post_dash_lockout = true
			post_dash_lockout_timer = 0.0
			# ensure we process dash hits at the frame of dash end too
			_apply_dash_hits()
		return

	# Handle stick distance-based dash
	if stick_dash_active:
		stick_dash_timer += delta
		# constant speed to cover total_distance in stick_dash_duration
		var dash_speed = 0.0
		if stick_dash_duration > 0.0:
			dash_speed = stick_dash_total_distance / stick_dash_duration
		# move directly (collision disabled so we can pass through)
		var move_now = dash_speed * delta
		global_position += stick_dash_direction * move_now
		# apply hits each frame
		_apply_dash_hits()
		# check traveled distance
		var traveled = (global_position - stick_dash_start).length()
		if traveled >= stick_dash_total_distance or stick_dash_timer >= stick_dash_duration:
			# end stick dash
			stick_dash_active = false
			stick_dash_timer = 0.0
			# cleanup dash hitbox/collision
			if dash_slash_hitbox:
				dash_slash_hitbox.monitoring = false
				dash_hit_targets.clear()
			if collision_shape:
				collision_shape.disabled = false
			stick_dash_active = false
			# clear invulnerability
			dash_invulnerable = false
			kick_active = false
			post_dash_lockout = true
			post_dash_lockout_timer = 0.0
			return
	if slash_dash_active:
		slash_dash_timer += delta
		# Use stick-driven dash duration when it was triggered from the stick
		var cur_dash_duration = stick_dash_duration if stick_dash_active else slash_dash_duration
		var dash_mult = stick_dash_speed_mult if stick_dash_active else 3.0
		var t = clamp(slash_dash_timer / cur_dash_duration, 0.0, 1.0)
		var dash_speed = run_speed * dash_mult * ease_out(t)
		velocity = slash_dash_direction * dash_speed
		move_and_slide()
		# Apply dash hits each frame so overlapping enemies take damage
		_apply_dash_hits()
		var blocked := _handle_body_contact(true)
		if blocked:
			slash_dash_active = false
			velocity = Vector2.ZERO
			post_dash_lockout = true
			post_dash_lockout_timer = 0.0
			# cleanup dash hitbox/collision
			if dash_slash_hitbox:
				dash_slash_hitbox.monitoring = false
				dash_hit_targets.clear()
			if collision_shape:
				collision_shape.disabled = false
			stick_dash_active = false
			# clear invulnerability now that dash ended early due to block
			dash_invulnerable = false
			kick_active = false
			return
		if slash_dash_timer >= cur_dash_duration:
			slash_dash_active = false
			velocity = Vector2.ZERO
			post_dash_lockout = true
			post_dash_lockout_timer = 0.0
			# cleanup dash hitbox/collision
			if dash_slash_hitbox:
				dash_slash_hitbox.monitoring = false
				dash_hit_targets.clear()
			if collision_shape:
				collision_shape.disabled = false
			stick_dash_active = false
			# dash ended normally: clear invulnerability
			dash_invulnerable = false
			kick_active = false
			return # Skip normal movement while dashing

	# Handle post-dash lockout
	if post_dash_lockout:
		post_dash_lockout_timer += delta
		_set_moving(false, "post-dash-lockout")
		velocity = Vector2.ZERO
		if post_dash_lockout_timer >= post_dash_lockout_duration:
			post_dash_lockout = false
		return # Skip normal movement while locked out

	# Read joystick input robustly: treat `get_input_vector` as direction-only
	# unless `get_input_magnitude` exists. This ensures magnitude is read from
	# the special method when available and avoids wrong magnitude assumptions.
	stick_mag = 0.0
	var use_stick = false
	if joystick and joystick.has_method("get_input_vector"):
		stick_raw = joystick.get_input_vector()

		# IMPORTANT: treat input_vector as DIRECTION unless you *know* it contains magnitude
		stick_dir = stick_raw
		if stick_dir.length() > 0.001:
			stick_dir = stick_dir.normalized()

		# Get magnitude from the dedicated method if it exists (this is the key fix)
		if joystick.has_method("get_input_magnitude"):
			stick_mag = float(joystick.get_input_magnitude())
		else:
			# Fallback ONLY if your joystick vector actually includes magnitude
			# (If your get_input_vector is normalized, this will be wrong.)
			stick_mag = stick_raw.length()

		# Build the per-frame compatibility vector (direction scaled by magnitude)
		stick_dir_frame = stick_dir * stick_mag

	# Movement using stick_dir + stick_mag
	if stick_mag > 0.001:
		_set_moving(true, "joystick")
		use_stick = true
		moving_by_joystick = true
		last_stick_dir = stick_dir

		# Re-arm only when magnitude drops below dash_rearm
		if stick_mag < dash_rearm:
			stick_dash_ready = true

		# Track outward jump window
		if stick_mag > _prev_stick_mag:
			_mag_jump_timer += delta
		else:
			_mag_jump_timer = 0.0

		var mag_delta = stick_mag - _prev_stick_mag

		# Trigger only when ENTERING the edge band (prevents "always dash while moving")
		var edge_enter = (_prev_stick_mag < dash_edge and stick_mag >= dash_edge)

		var edge_trigger = (
			edge_enter
			and stick_dash_ready
			and not slash_dash_active
			and not hold_dash_active
			and not post_dash_lockout
			and not stick_dash_active
		)

		var flick_trigger = (
			stick_mag >= dash_edge
			and stick_dash_ready
			and _mag_jump_timer <= dash_flick_time
			and mag_delta >= dash_flick_mag_delta
			and not slash_dash_active
			and not hold_dash_active
			and not post_dash_lockout
			and not stick_dash_active
		)

		if edge_trigger or flick_trigger:
			stick_dash_ready = false
			if debug_dash_direction:
				print("[dash-debug] edge/flick trigger -> prev_mag:", _prev_stick_mag, "mag:", stick_mag, "delta:", mag_delta, "dir_frame:", stick_dir_frame)
			_start_stick_dash(stick_dir_frame, "stick_dash")

		_prev_stick_mag = stick_mag
	else:
		# joystick released
		if moving_by_joystick:
			moving_by_joystick = false
			_set_moving(false, "joystick_release")
			velocity = Vector2.ZERO
			current_speed = 0.0
			acceleration_timer = 0.0
			preserved_facing_dir = last_stick_dir
			facing_preserve_timer = facing_preserve_time

	# Sprite direction logic (prefer dash direction when dashing)
	var scale_x_sign = last_scale_x_sign
	if body:
		var dir_vec: Vector2 = Vector2.ZERO
		var facing_source = "none"
		# If facing was locked (e.g., by a swipe dash), don't auto-update facing
		if not facing_locked:
			# If we recently released the joystick, temporarily preserve the
			# previous stick-facing to avoid a single-frame flip.
			if facing_preserve_timer > 0.0:
				dir_vec = preserved_facing_dir
			else:
				if slash_dash_active:
					dir_vec = slash_dash_direction
					facing_source = "slash"
				elif hold_dash_active:
					dir_vec = hold_dash_direction
					facing_source = "hold"
				else:
					# Prefer joystick direction if available (direction-only input).
						# While attacking, prefer the attack/dash direction instead
						# of the tap position so the sprite remains consistent with
						# the performed attack. Only use `tap_position` for facing
						# when the player is actively moving (not attacking).
						if stick_dir_frame.length() > 0.0:
							dir_vec = stick_dir_frame
							facing_source = "stick"
						elif attack_active:
							# Use the active slash/attack direction when available;
							# fall back to the generic attack direction helper if needed.
							if slash_dash_direction.length() > 0.0:
								dir_vec = slash_dash_direction
							else:
								dir_vec = _get_attack_direction()
							facing_source = "attack"
						elif moving:
							dir_vec = tap_position - global_position
							facing_source = "tap"
						else:
							# Fallback to the last known movement direction so facing doesn't
							# snap to a default while idle.
							dir_vec = last_stick_dir
							facing_source = "laststick"
			if dir_vec.length() > 0.1:
				# Emit a compact debug line to identify what set facing this frame.
				# Enable by setting `print_facing_debug = true` in-scene or here.
				if print_facing_debug:
					print("[facing-decide] src:", facing_source, "dir:", dir_vec, "last_stick:", last_stick_dir, "time:", Time.get_ticks_msec())
					# Also print previous vs new texture/sign for direct comparison
					var prev_tex = _prev_facing_texture
					var prev_sign = _prev_facing_sign
					print("[facing-prev] tex:", prev_tex, "sign:", prev_sign, "pos:", global_position)
			# Normalize the decision vector so axis comparisons use direction
			# rather than world-space magnitude. This prevents very large
			# tap vectors from biasing the facing choice toward X or Y.
			var dir = dir_vec.normalized()
			if dir.length() == 0:
				dir = dir_vec # fallback in case normalization yields zero (shouldn't happen)
			if abs(dir.x) > abs(dir.y):
				body.texture = sprite_right
				if dir.x < 0:
					scale_x_sign = -1.0
				else:
					scale_x_sign = 1.0
			else:
				if dir.y > 0:
					body.texture = sprite_front
				else:
					body.texture = sprite_back
				scale_x_sign = 1.0
			# Immediately apply facing sign to the sprite X scale so there
			# is no intermediate frame where the visual sign disagrees with
			# the decided facing. Preserve the current magnitude until
			# bobbing calculation overwrites it later.
			if body:
				body.scale.x = abs(body.scale.x) * scale_x_sign
			# If a 3D-facing sprite exists, rotate it around Y so it precisely
			# faces the decided 2D direction. The mapping used is:
			#   angle2D = atan2(dir.y, dir.x) (0 = right, + = down)
			#   target_y = PI/2 - angle2D + facing_sprite_y_offset
			# This makes `angle2D == 0` (right) map to PI/2 (90deg), which
			# matches the sprite's default being oriented to the right.
			if facing_sprite and dir.length() > 0.001:
				var angle2d = atan2(dir.y, dir.x)
				var target_y = PI * 0.5 - angle2d + float(facing_sprite_y_offset)
				facing_sprite.rotation.y = target_y
			# record the change and optionally print it
			if print_facing_debug:
				print("[facing-change] from_tex:", _prev_facing_texture, "to_tex:", body.texture, "from_sign:", _prev_facing_sign, "to_sign:", scale_x_sign, "src:", facing_source, "time:", Time.get_ticks_msec())
			_prev_facing_texture = body.texture
			_prev_facing_sign = scale_x_sign
			last_scale_x_sign = scale_x_sign

	# Movement and velocity

	if moving:
		if debug_movement:
			var d = global_position.distance_to(tap_position)
			print("[moving] target:", tap_position, "pos:", global_position, "dist:", d, "speed:", current_speed)
		acceleration_timer += delta
		deceleration_timer = 0.0
		# Ease from walk_speed to run_speed over acceleration_time for smoother start
		var t = clamp(acceleration_timer / acceleration_time, 0.0, 1.0)
		current_speed = lerp(walk_speed, run_speed, ease_out(t))

		var direction = Vector2.ZERO
		if use_stick:
			direction = stick_dir_frame.normalized()
			# stick-driven movement doesn't use a stop threshold; it runs while stick is held
			velocity = direction * current_speed
		else:
			# No joystick input: do not move. Movement is controlled only via joystick.
			velocity = Vector2.ZERO
			_set_moving(false, "no-stick")
		move_and_slide()
		_handle_body_contact()
	else:
		if current_speed > 0.0:
			deceleration_timer += delta
			var t = clamp(deceleration_timer / deceleration_time, 0.0, 1.0)
			current_speed = lerp(current_speed, 0.0, ease_out(t))
		else:
			current_speed = 0.0
			deceleration_timer = 0.0

	# Bobbing and breathing
	var speed_fraction = clamp(current_speed / run_speed, 0.0, 1.0)
	var breath_freq = lerp(0.7, 1.5, speed_fraction)
	var breath_phase = Time.get_ticks_msec() / 1000.0
	var breath_scale = lerp(0.75, 0.8, (sin(breath_phase * breath_freq) + 1.0) * 0.5)
	if body:
		var effective_amplitude = lerp(bob_amplitude_walk, bob_amplitude_run, speed_fraction)
		if speed_fraction > 0.0:
			var bob_speed = lerp(bob_speed_min, bob_speed_max, speed_fraction)
			bob_phase += delta * bob_speed
			var bob_offset = (sin(bob_phase - PI/2) + 1.0) * 0.5 * effective_amplitude
			body.position.y = body_rest_y - bob_offset
			if shadow:
				var elev_frac = 0.0
				if launcher_elevation_peak > 0.0:
					elev_frac = clamp(elevation / launcher_elevation_peak, 0.0, 1.0)
				var shrink_factor = 1.0
				if elevation_active:
					shrink_factor = lerp(1.0, 0.5, elev_frac)
				var safe_amp = max(effective_amplitude, 0.0001)
				var shadow_scale = lerp(0.75, 0.65, bob_offset / safe_amp) * shrink_factor
				shadow.scale = Vector2(shadow_scale, shadow_scale)
		else:
			bob_phase = 0.0
			body.position.y = lerp(body.position.y, body_rest_y, min(1.0, delta * 10.0))
			if shadow:
				var elev_frac_idle = 0.0
				if launcher_elevation_peak > 0.0:
					elev_frac_idle = clamp(elevation / launcher_elevation_peak, 0.0, 1.0)
				var shrink_factor_idle = lerp(1.0, 0.5, elev_frac_idle) if elevation_active else 1.0
				shadow.scale = Vector2(0.75 * shrink_factor_idle, 0.75 * shrink_factor_idle)
		var breath_blend = 1.0 - speed_fraction
		var blended_scale_x = lerp(0.75, breath_scale, breath_blend)
		# Apply computed X scale every frame (facing/breathing/bob)
		# Log if the bobbing code would flip the sign unexpectedly.
		if print_facing_debug:
			var intended_sign = sign(scale_x_sign)
			var current_sign = sign(body.scale.x)
			if intended_sign != current_sign:
				print("[bobbing-sign] intended:", intended_sign, "current:", current_sign, "prev_facing_sign:", _prev_facing_sign, "time:", Time.get_ticks_msec())
		# Ensure the blended magnitude is positive before applying facing sign so
		# bobbing never flips the sign unexpectedly.
		body.scale.x = abs(blended_scale_x) * scale_x_sign
		# Reset/compute Y scale each frame based on base scale and optional
		# elevation ascent-driven Y stretch. We compute an ascent curve so the
		# sprite briefly scales up to +25% in Y at the halfway elevation, then
		# returns to normal by the peak. This only applies during the rising
		# phase of the launcher elevation to avoid scaling on descent.
		var base_y_scale = _launcher_base_body_scale.y
		var computed_y = base_y_scale
		if elevation_active:
			# Recompute up_time from attack_duration to know if we're ascending
			var total_dur_local = max(0.001, attack_duration)
			var up_time_local = total_dur_local * launcher_elevation_up_frac
			# Apply scale only while ascending
			if _elevation_timer <= up_time_local:
				var frac_elev = clamp(elevation / launcher_elevation_peak, 0.0, 1.0)
				if frac_elev <= 0.5:
					# scale peaks at +25% at one-third elevation; use ease_out for smoothness
					var tscale = frac_elev / 0.3333333
					var easev = ease_out(tscale)
					computed_y = base_y_scale * (1.0 + 0.75 * easev)
				else:
					computed_y = base_y_scale
			else:
				computed_y = base_y_scale
		else:
			computed_y = base_y_scale
		body.scale.y = computed_y
		# Do not apply elevation-driven scaling here; visuals handled in shader.
		# Keep Y scale locked to the stored base to avoid accumulation.

	if not moving:
		current_speed = 0.0
		acceleration_timer = 0.0

	# Keep player on-screen (clamp to viewport world rect)
	_clamp_to_viewport()


func _handle_body_contact(stop_on_any: bool = false) -> bool:
	# When stop_on_any is true (dash), halt on any CharacterBody2D hit (prevents tangential slide).
	# Otherwise, block motion into the normal or tiny residual velocities.
	var stop_threshold := 5.0
	for i in range(get_slide_collision_count()):
		var collision := get_slide_collision(i)
		if collision and collision.get_collider() is CharacterBody2D:
			if stop_on_any:
				velocity = Vector2.ZERO
				return true
			var n := collision.get_normal()
			var into := velocity.dot(n)
			if into > 0.0:
				velocity = Vector2.ZERO
				return true
			elif velocity.length() < stop_threshold:
				velocity = Vector2.ZERO
				return true
	return false


func _apply_dash_hits() -> void:
	if not dash_slash_hitbox:
		return
	if not dash_slash_hitbox.monitoring:
		return
	# If kick is active when hits land, trigger a small shake
	var dash_data = null
	if attacks and "dash_slash" in attacks:
		dash_data = attacks["dash_slash"]
	# Use facing/dash direction for knockback direction
	var hit_dir = slash_dash_direction
	if hit_dir.length() < 0.001:
		hit_dir = _get_attack_direction()
	if hit_dir.length() < 0.001:
		hit_dir = Vector2.RIGHT
	var areas = dash_slash_hitbox.get_overlapping_areas()
	for a in areas:
		var target = a.get_parent()
		# ignore self hits (player should not hit themself)
		if target == self:
			continue
		if not target:
			continue
		if not target.has_method("take_damage"):
			continue
		if target in dash_hit_targets:
			continue
		# determine damage/intensity and knockback multiplier
		var intensity = 1.0
		var dmg = damage
		var kb_mult = 1.0
		if dash_data:
			if "intensity" in dash_data:
				intensity = float(dash_data["intensity"])
			if "damage" in dash_data:
				dmg = float(dash_data["damage"])
		# If this dash is a kick, boost knockback using kick_knockback_mult
		if kick_active:
			kb_mult = kick_knockback_mult
		# While airborne, suppress dash knockback
		if elevation > 0.0:
			kb_mult = 0.0
		# check parry
		var target_parryable := false
		if "is_parryable" in target:
			target_parryable = bool(target.is_parryable)
		if target_parryable and dash_data and ("parry_damage" in dash_data):
			var pdmg = float(dash_data["parry_damage"])
			var pint = float(dash_data.get("parry_intensity", intensity))
			var hs = _ensure_hit_slow()
			if hs:
				hs.start(0.15, 0.2, pint)
			if target.has_method("take_damage"):
				target.take_damage(dmg, hit_dir, self, false, kb_mult)
				if elevation > 0.0 and "elevation" in target:
					target.elevation += airborne_attack_elevation_add
		else:
			var hs2 = _ensure_hit_slow()
			if hs2:
				hs2.start(0.15, 0.2, intensity)
			if target.has_method("take_damage"):
				target.take_damage(dmg, hit_dir, self, false, kb_mult)
		dash_hit_targets.append(target)

	# also check overlapping bodies (CharacterBody2D etc.)
	var bodies = dash_slash_hitbox.get_overlapping_bodies()
	for b in bodies:
		var targetb = b
		if targetb == self:
			continue
		if not targetb:
			continue
		if not targetb.has_method("take_damage"):
			continue
		if targetb in dash_hit_targets:
			continue
		# determine damage/intensity and knockback multiplier
		var intensity_b = 1.0
		var dmg_b = damage
		var kb_mult_b = 1.0
		if dash_data:
			if "intensity" in dash_data:
				intensity_b = float(dash_data["intensity"])
			if "damage" in dash_data:
				dmg_b = float(dash_data["damage"])
		if kick_active:
			kb_mult_b = kick_knockback_mult
		# While airborne, suppress dash knockback
		if elevation > 0.0:
			kb_mult_b = 0.0
		var targetb_parryable := false
		if "is_parryable" in targetb:
			targetb_parryable = bool(targetb.is_parryable)
		if targetb_parryable and dash_data and ("parry_damage" in dash_data):
			var pdmg_b = float(dash_data["parry_damage"])
			var pint_b = float(dash_data.get("parry_intensity", intensity_b))
			var hs_b = _ensure_hit_slow()
			if hs_b:
				hs_b.start(0.15, 0.2, pint_b)
			if targetb.has_method("take_damage"):
				targetb.take_damage(dmg_b, hit_dir, self, false, kb_mult_b)
				# While airborne, add a small elevation bump to targets
				if elevation > 0.0 and "elevation" in targetb:
					targetb.elevation += airborne_attack_elevation_add
		else:
			var hs2_b = _ensure_hit_slow()
			if hs2_b:
				hs2_b.start(0.15, 0.2, intensity_b)
			if targetb.has_method("take_damage"):
				targetb.take_damage(dmg_b, hit_dir, self, false, kb_mult_b)
		dash_hit_targets.append(targetb)


func _clamp_to_viewport() -> void:
	if not clamp_to_viewport:
		return
	# Visible rect in canvas coordinates
	var view_rect: Rect2 = get_viewport().get_visible_rect()
	# Convert canvas rect corners to world coordinates using the viewport's canvas transform
	# Prefer Camera2D if available (convert viewport size to world units using camera zoom)
	var world_tl := Vector2.ZERO
	var world_br := Vector2.ZERO
	var cam := get_viewport().get_camera_2d()
	if cam:
		var vsz = view_rect.size
		var half = vsz * 0.5
		# world half-size approximated by camera zoom
		var world_half = Vector2(half.x * cam.zoom.x, half.y * cam.zoom.y)
		var cam_pos = cam.global_position
		world_tl = cam_pos - world_half
		world_br = cam_pos + world_half
	else:
		var inv = get_viewport().get_canvas_transform().affine_inverse()
		# Use operator * to transform point by Transform2D/CanvasTransform if available
		world_tl = inv * view_rect.position
		world_br = inv * (view_rect.position + view_rect.size)
	var min_x = min(world_tl.x, world_br.x) + clamp_margin
	var max_x = max(world_tl.x, world_br.x) - clamp_margin
	var min_y = min(world_tl.y, world_br.y) + clamp_margin
	var max_y = max(world_tl.y, world_br.y) - clamp_margin
	# Apply clamp
	var px = clamp(global_position.x, min_x, max_x)
	var py = clamp(global_position.y, min_y, max_y)
	global_position = Vector2(px, py)

func _start_stick_dash(dir: Vector2, reason: String = "stick_dash") -> bool:
	if dir.length() < 0.001:
		return false
	# Cancel hit reaction immediately when dash begins
	if hit_reacting:
		hit_reacting = false
		hit_react_timer = 0.0
		velocity = Vector2.ZERO

	# Dash lockout: prevent starting a new dash if within `dash_lockout_time` seconds
	var _now = Time.get_ticks_msec() / 1000.0
	if _now - _last_dash_time < dash_lockout_time:
		if debug_dash_direction:
			print("[dash-debug] dash locked out - time_since_last:", _now - _last_dash_time, "threshold:", dash_lockout_time)
		return false

	if debug_dash_direction:
		print("[dash-debug] _start_stick_dash reason:", reason, "dir_in:", dir, "normalized:", dir.normalized(), "global_pos:", global_position)

	# Cancel attack so dash always works
	if attack_active:
		attack_active = false
		attack_timer = 0.0
		attack_buffered = false
		# stop any residual slash dash/state
		slash_dash_active = false
		slash_dash_timer = 0.0
		velocity = Vector2.ZERO
		_on_attack_end("interrupted_by_" + reason)

	# Arm dash
	stick_dash_active = true
	stick_dash_timer = 0.0
	stick_dash_start = global_position
	stick_dash_direction = dir.normalized()
	stick_dash_total_distance = run_speed * stick_dash_speed_mult * stick_dash_duration

	# record dash time for lockout enforcement
	_last_dash_time = _now

	# Hitbox + collision
	if dash_slash_hitbox:
		dash_slash_hitbox.global_position = global_position + stick_dash_direction * 60.0
		dash_slash_hitbox.rotation = stick_dash_direction.angle()
		dash_slash_hitbox.monitoring = true
		dash_hit_targets.clear()

	if collision_shape:
		collision_shape.disabled = true

	# Anim
	if anim_player:
		var anim_name = "DashSlash"
		if attacks and "dash_slash" in attacks:
			var dash_data = attacks["dash_slash"]
			if dash_data and dash_data.has("name"):
				anim_name = dash_data["name"]
		anim_player.stop()
		anim_player.play(anim_name)

	# Invuln
	dash_invulnerable = true
	# confirm dash started
	return true


# Kick playback after a pause between attacks
func _trigger_kick() -> void:
	# Block boot playback while airborne; fall back to normal combo handling
	if elevation > 0.0:
		kick_pending = false
		kick_ready = false
		kick_active = false
		kick_timer = 0.0
		kick_arm_time = 0.0
		return
	var boot_anim: AnimationPlayer = get_node_or_null("Boot/AnimationPlayer")
	var boot_node: Node2D = get_node_or_null("Boot")
	var dir = _get_attack_direction()
	if dir.length() > 0.0001:
		# Face and rotate boot like a slash
		_apply_facing(dir)
		if boot_node:
			boot_node.rotation = dir.angle() + PI / 2.0
			# Pass kick intensity/damage into the boot script
			if "attack_intensity" in boot_node:
				boot_node.attack_intensity = kick_hit_intensity
			if "knockback_mult" in boot_node:
				boot_node.knockback_mult = kick_knockback_mult
			if "knockback_dir" in boot_node:
				boot_node.knockback_dir = dir.normalized()
			if "damage" in boot_node:
				boot_node.damage = kick_damage
			if "hit_targets" in boot_node:
				boot_node.hit_targets.clear()
			if "is_dash_slash" in boot_node:
				boot_node.is_dash_slash = false
			if "is_launcher" in boot_node:
				boot_node.is_launcher = false
		# Move forward like an attack dash; flag kick knockback scaling
		slash_dash_active = true
		slash_dash_timer = 0.0
		slash_dash_direction = dir.normalized()
		post_dash_lockout = false
		post_dash_lockout_timer = 0.0
		dash_invulnerable = false
		kick_active = true
	if boot_anim:
		boot_anim.play("default")
	# Trigger a screen shake similar to an attack hit
	if debug_attack_input:
		print("[kick] triggered after pause -> dir:", dir)
	kick_pending = false
	kick_timer = 0.0
	kick_ready = false
	kick_arm_time = 0.0
