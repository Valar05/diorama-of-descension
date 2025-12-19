extends CharacterBody2D

@export var player : CharacterBody2D = null
@export var attack_distance = 100.0
@export var move_speed = 200.0
@export var sprite_front: Texture2D
@export var sprite_right: Texture2D
@export var sprite_back: Texture2D
@export var health: float = 40.0
@export var hyperarmor: float = 0.0

# Bobbing parameters
var bob_phase := 0.0
var bob_speed_min := 3.0
var bob_speed_max := 12.0
var bob_amplitude_walk := 70.0
var bob_amplitude_run := 50.0
var body_rest_y := 0.0
var initial_body_scale := Vector2.ONE
var initial_shadow_scale := Vector2.ONE
var last_scale_x_sign := 1.0

# Launcher elevation support (when hit by a launcher-type attack)
@export var launcher_elevation_peak := 150.0
@export var launcher_elevation_up_frac := 0.2
@export var launcher_elevation_duration := 0.6
@export var airborne_attack_elevation_add := 6.0
var elevation := 0.0
var _elevation_timer := 0.0
var elevation_active := false
var elevation_bonus := 0.0
var launcher_base_position := Vector2.ZERO
var _launcher_initial_body_scale := Vector2.ONE
var _launcher_initial_shadow_scale := Vector2.ONE
var _launcher_initial_body_pos := Vector2.ZERO
var die_on_land := false
@export var launcher_peak_increase := 0.75
@export var launcher_peak_frac := 0.3333333
@export var debug_launcher_visual := false
@export var anchor_scale_bottom := true

# Hurt pose tweening
var hurt_tween: Tween = null
var hurt_stretch_tween: Tween = null
var hurt_base_pos := Vector2.ZERO
var hurt_base_skew := 0.0
var hurt_base_root_scale := Vector2.ONE


# Hit reaction state
var hit_reacting := false
var hit_react_timer := 0.0
var hit_react_duration := 0.3
var hit_slide_dir := Vector2.ZERO
var hit_slide_speed := 600.0
var hit_knockback_mult := 1.0
var hit_facing := "south"
var dead := false

# Attack state machine
var attack_state := "idle" # idle, backing, charging, attacking
var attack_timer := 0.0
var backing_duration := 0.5
var backing_distance := 50.0
var charge_speed := 350.0
var attack_dash_speed := 600.0
var attack_extra_distance := 50.0
var attack_hit_radius := 115.0
var attack_damage := 1.0
var back_start := Vector2.ZERO
var back_target := Vector2.ZERO
var charge_target := Vector2.ZERO
var has_dealt_attack := false
var return_target := Vector2.ZERO
var return_speed := 220.0
var return_tolerance := 5.0
var cooldown_duration := 3.0
var cooldown_timer := 0.0
var attack_target := Vector2.ZERO
var attack_fail_timer := 0.0
var attack_fail_duration := 1.0 # seconds before cancelling attack if we can't reach target
var is_parryable = false

@onready var body: Sprite2D = $Sprite2D_body
@onready var shadow: Sprite2D = $Sprite2D_shadow
@onready var anim_player: AnimationPlayer = $AnimationPlayer

func _disable_all_hitboxes() -> void:
	# Disable common hitbox/hurtbox nodes and Area2D monitoring so any pending
	# attack overlaps are cancelled immediately. This is defensive: search for
	# CollisionShape2D and Area2D children and disable them where appropriate.
	# Disable main collision shapes if present.
	var cs = get_node_or_null("CollisionShape2D")
	if cs and cs is CollisionShape2D:
		cs.disabled = true
	# Disable any named hitbox/area children (common names)
	var candidate_names = ["Hitbox", "AttackHitbox", "AttackArea", "DamageArea", "HitArea", "AttackArea2D"]
	for nname in candidate_names:
		var n = get_node_or_null(nname)
		if n:
			if n is Area2D:
				n.monitoring = false
			var cs2 = n.get_node_or_null("CollisionShape2D")
			if cs2 and cs2 is CollisionShape2D:
				cs2.disabled = true
	# Recursively disable Area2D monitoring to be extra defensive
	for child in get_children():
		_disable_hitbox_descendants(child)

func _disable_hitbox_descendants(node: Node) -> void:
	# Avoid disabling hurtbox descendants so the enemy remains hittable while
	# its attack logic is canceled. If we encounter a node named "Hurtbox",
	# skip its subtree entirely.
	if node.name == "Hurtbox":
		return
	# If this node is an Area2D used as an attack hitbox, disable monitoring
	if node is Area2D:
		node.monitoring = false
	# Only disable CollisionShape2D that are not part of a Hurtbox parent
	if node is CollisionShape2D:
		var p = node.get_parent()
		if not (p and p.name == "Hurtbox"):
			node.disabled = true
	for c in node.get_children():
		_disable_hitbox_descendants(c)

func _play_hurt_stretch(hitter: Node) -> void:
	if not body:
		return
	if hurt_stretch_tween:
		hurt_stretch_tween.kill()
		hurt_stretch_tween = null
	# Reset root scale to baseline so sprite flip does not fight tweened scale
	scale = hurt_base_root_scale
	body.skew = hurt_base_skew
	body.position = hurt_base_pos
	# Use baseline as starting pose (root scale for tween)
	var base_root_scale = scale
	var base_pos_y = body.position.y
	# Direction to hitter/player to weight vertical effect
	var rel_vec = Vector2.ZERO
	if hitter and hitter is Node2D:
		rel_vec = global_position - hitter.global_position
	elif player:
		rel_vec = global_position - player.global_position
	var denom = abs(rel_vec.x) + abs(rel_vec.y)
	if denom < 0.0001:
		return
	var vert_weight = clamp(abs(rel_vec.y) / denom, 0.0, 1.0)
	if vert_weight <= 0.0001:
		return
	var vertical_dir = -1.0 if rel_vec.y < 0.0 else 1.0 # enemy above -> move up, below -> move down
	# Compute target scales
	var x_mult = 1.0 + ( -0.25 * vert_weight if vertical_dir < 0.0 else 0.25 * vert_weight)
	var y_mult = 1.0 + ( 0.25 * vert_weight if vertical_dir < 0.0 else -0.25 * vert_weight)
	var target_scale_x = base_root_scale.x * x_mult
	var target_scale_y = base_root_scale.y * y_mult
	# Position offset based on sprite height
	var tex_h = 0.0
	if body.texture:
		tex_h = body.texture.get_size().y * abs(base_root_scale.y)
	var target_pos_y = base_pos_y + tex_h * 0.08 * vert_weight * vertical_dir
	# Tween: ease out to target over 0.15s, then back over hit_react_duration
	hurt_stretch_tween = create_tween()
	hurt_stretch_tween.set_parallel(true)
	hurt_stretch_tween.tween_property(self, "scale:x", target_scale_x, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hurt_stretch_tween.tween_property(self, "scale:y", target_scale_y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hurt_stretch_tween.tween_property(body, "position:y", target_pos_y, 0.15).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hurt_stretch_tween.set_parallel(false)
	hurt_stretch_tween.tween_property(self, "scale:x", base_root_scale.x, hit_react_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hurt_stretch_tween.parallel().tween_property(self, "scale:y", base_root_scale.y, hit_react_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hurt_stretch_tween.parallel().tween_property(body, "position:y", base_pos_y, hit_react_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func _play_hurt_shear(hitter: Node) -> void:
	if not body:
		return
	# Kill any existing hurt tween and reset to base before starting a new one
	if hurt_tween:
		hurt_tween.kill()
		hurt_tween = null
	# Reset to baseline pose (preserve current facing sign)
	var sign_x = 1.0
	if body.scale.x < 0.0:
		sign_x = -1.0
	# Reset root scale to baseline so body flip doesn't fight tweened scale
	scale = hurt_base_root_scale
	body.skew = hurt_base_skew
	body.position = hurt_base_pos
	# Determine hit side relative to hitter (player)
	var hit_from_right := false
	if hitter and hitter is Node2D:
		hit_from_right = hitter.global_position.x > global_position.x
	# Weight shear by horizontal dominance so north/south hits don't skew
	var rel_vec = Vector2.ZERO
	if hitter and hitter is Node2D:
		rel_vec = global_position - hitter.global_position
	var denom = abs(rel_vec.x) + abs(rel_vec.y)
	var horiz_weight = 0.0
	if denom > 0.0001:
		horiz_weight = abs(rel_vec.x) / denom
	# If enemy is left of the hitter, skew/offset left; otherwise right
	var target_skew = (-deg_to_rad(7.0) if hit_from_right else deg_to_rad(7.0)) * horiz_weight
	# Use texture width scaled by current abs scale to compute offset
	var tex_w = 0.0
	if body.texture:
		tex_w = body.texture.get_size().x * abs(body.scale.x)
	var target_offset = tex_w * 0.08 * horiz_weight
	if hit_from_right:
		target_offset *= -1.0
	# Build tween: ease out into pose, then ease back over hit reaction duration
	hurt_tween = create_tween()
	hurt_tween.set_parallel(true)
	hurt_tween.tween_property(body, "skew", target_skew, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hurt_tween.tween_property(body, "position:x", hurt_base_pos.x + target_offset, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	hurt_tween.set_parallel(false)
	hurt_tween.tween_property(body, "skew", hurt_base_skew, hit_react_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	hurt_tween.parallel().tween_property(body, "position:x", hurt_base_pos.x, hit_react_duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)

func _ready():
	initial_body_scale = body.scale
	initial_shadow_scale = shadow.scale
	hurt_base_pos = body.position
	hurt_base_skew = body.skew
	hurt_base_root_scale = scale

func take_damage(amount: float, dir: Vector2, _hitter: Node, is_launcher: bool = false, knockback_mult: float = 1.0) -> void:

	health -= amount
	if health <= 0.0:
		# mark dead and start death animation immediately
		dead = true
		anim_player.play("die")
		# Still play hurt shear so death reacts directionally
		_play_hurt_shear(_hitter)
		_play_hurt_stretch(_hitter)
		# move AI into cooldown so it stops active behaviors
		attack_state = "cooldown"
		cooldown_timer = 0.0
		has_dealt_attack = true
		# If currently elevated, defer disabling collision/hurtbox until after landing
		if elevation_active:
			die_on_land = true
			# keep velocity and collisions so the enemy continues to fall and can be hit
			# do not early-return; allow the elevation logic to proceed this frame
		else:
			# Not elevated: finalize death now (disable hurtbox and collision)
			velocity = Vector2.ZERO
			$Hurtbox/CollisionShape2D.disabled = true
			$CollisionShape2D.disabled = true
			return
	else:
		anim_player.stop()
		anim_player.play("hurt")
		_play_hurt_shear(_hitter)
		_play_hurt_stretch(_hitter)
	# If taking damage while in any attack phase and it exceeds hyperarmor, interrupt the attack
	if attack_state != "idle" and amount > hyperarmor:
		# prevent the attack from dealing damage (mark as already dealt)
		has_dealt_attack = true
		# move to cooldown to avoid immediate re-attack
		attack_state = "cooldown"
		cooldown_timer = 0.0
		velocity = Vector2.ZERO
		# reset any attack fail timer
		attack_fail_timer = 0.0
		# if this was a launcher hit, aggressively cancel any attack hitboxes and timers
		if is_launcher:
			_disable_all_hitboxes()
			# ensure attack finishes immediately
			has_dealt_attack = true
			attack_state = "cooldown"
			cooldown_timer = 0.0
			attack_fail_timer = 0.0
			velocity = Vector2.ZERO
	# Apply knockback/hit reaction for non-launcher hits regardless of current attack state
	if not is_launcher:
		hit_reacting = true
		hit_react_timer = 0.0
		hit_slide_dir = dir.normalized()
		hit_knockback_mult = max(0.0, knockback_mult)
		# If already airborne, add a small extra elevation bump
		if elevation > 0.0:
			elevation_bonus += airborne_attack_elevation_add
	# If this damage was caused by a launcher attack, start elevation wave
	if is_launcher:
		# immediately interrupt current behaviors: stop animations, movement and disable hitboxes
		anim_player.stop()
		_disable_all_hitboxes()
		velocity = Vector2.ZERO
		attack_state = "cooldown"
		cooldown_timer = 0.0
		has_dealt_attack = true
		attack_fail_timer = 0.0
		# start the elevation visual immediately
		elevation_active = true
		_elevation_timer = 0.0
		elevation = 0.0
		launcher_base_position = global_position
		# save scales so we can restore after elevation
		_launcher_initial_body_scale = body.scale
		_launcher_initial_shadow_scale = shadow.scale
		# save body local position so we can compensate when scaling around bottom
		if body:
			_launcher_initial_body_pos = body.position
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
			body.scale.x = abs(body.scale.x)
		else:
			hit_facing = "north"
			body.texture = sprite_back
			body.scale.x = abs(body.scale.x)
	# Restore hurt pose baseline when facing snaps the sprite
	hurt_base_pos = body.position


func _physics_process(delta: float) -> void:
	# Hit reaction slide and facing
	if hit_reacting:
		hit_react_timer += delta
		var t = clamp(hit_react_timer / hit_react_duration, 0.0, 1.0)
		var ease_val = 1.0 - pow(1.0 - t, 2.0) # ease out
		velocity = hit_slide_dir * hit_slide_speed * hit_knockback_mult * (1.0 - ease_val)
		move_and_slide()
		if hit_react_timer >= hit_react_duration:
			hit_reacting = false
			velocity = Vector2.ZERO
		return

	# Elevation handling for launcher hits: visual lift and shadow shrink
	if elevation_active:
		_elevation_timer += delta
		var total_dur = max(0.001, launcher_elevation_duration)
		var up_time = total_dur * launcher_elevation_up_frac
		var down_time = max(0.001, total_dur - up_time)
		if _elevation_timer <= up_time:
			var t = clamp(_elevation_timer / up_time, 0.0, 1.0)
			# ease out on rise
			elevation = launcher_elevation_peak * (t * t)
		else:
			var t2 = clamp((_elevation_timer - up_time) / down_time, 0.0, 1.0)
			# ease in on fall
			elevation = launcher_elevation_peak * (1.0 - (t2 * t2))
		# apply vertical offset visually (include any bonus gained while airborne)
		global_position = launcher_base_position - Vector2(0, elevation + elevation_bonus)
		# anchor shadow to launch origin and shrink
		if shadow:
			shadow.global_position = launcher_base_position
			var frac = clamp(elevation / launcher_elevation_peak, 0.0, 1.0)
			# Vector2.lerp isn't available; do component-wise lerp
			shadow.scale = Vector2(lerp(_launcher_initial_shadow_scale.x, _launcher_initial_shadow_scale.x * 0.5, frac), lerp(_launcher_initial_shadow_scale.y, _launcher_initial_shadow_scale.y * 0.5, frac))
		# Shader-driven Y-stretch during elevation: copy player's logic exactly
		if body:
			# compute normalized elevation fraction and ease curve (same as player)
			var frac = clamp(elevation / launcher_elevation_peak, 0.0, 1.0)
			var stretch_curve = frac * frac # ease_out
			# match player's stretch magnitude/sign so visuals are identical
			var stretch_val = -0.23 * stretch_curve
			# If sprite uses a ShaderMaterial, set the same shader parameters the player sets
			var mat = body.get_material()
			if mat and mat is ShaderMaterial:
				mat.set_shader_parameter("top_stretch_x", stretch_val)
				mat.set_shader_parameter("top_stretch", stretch_val)

				# Also apply node-scale Y to match player's visual composition
				var base_y_scale = _launcher_initial_body_scale.y
				var computed_y = base_y_scale
				var total_dur_local = max(0.001, launcher_elevation_duration)
				var up_time_local = total_dur_local * launcher_elevation_up_frac
				if _elevation_timer <= up_time_local:
					var frac_elev = clamp(elevation / launcher_elevation_peak, 0.0, 1.0)
					# ease out
					var easev = frac_elev * frac_elev
					if frac_elev <= launcher_peak_frac:
						computed_y = base_y_scale * (1.0 + launcher_peak_increase * easev)
					else:
						computed_y = base_y_scale
				else:
					computed_y = base_y_scale
				body.scale.y = computed_y
				# Debug output: report shader parameter value when enabled
				if debug_launcher_visual:
					var local_scale = body.scale
					var _dbg_global_scale = Vector2.ZERO
					if body and body.get_global_transform():
						_dbg_global_scale = body.get_global_transform().get_scale()
					var sh_overall = null
					var sh_top = null
					if mat and mat is ShaderMaterial:
						sh_overall = mat.get_shader_parameter("overall_size")
						sh_top = mat.get_shader_parameter("top_stretch")
					print("[enemy-elev] frac:", frac, "stretch:", stretch_val, "local_scale:", local_scale, "global_scale:", _dbg_global_scale, "shader_overall:", sh_overall, "shader_top:", sh_top)
		# finish elevation
		if _elevation_timer >= total_dur:
			elevation_active = false
			_elevation_timer = 0.0
			elevation = 0.0
			elevation_bonus = 0.0
			# restore visual scales and position
			global_position = launcher_base_position
			if body:
				# restore saved node scale (shader handled deformation so node scale was not changed)
				body.scale = _launcher_initial_body_scale
				# restore the saved local body position
				body.position = _launcher_initial_body_pos
				# Reset shader stretch back to zero so the sprite returns to normal
				var _mat_end = body.get_material()
				if _mat_end and _mat_end is ShaderMaterial:
					_mat_end.set_shader_parameter("top_stretch_x", 0.0)
					_mat_end.set_shader_parameter("top_stretch", 0.0)
			if shadow:
				shadow.scale = _launcher_initial_shadow_scale
			# continue; do not return: allow normal AI to proceed on same frame

	if player:
		# local helpers used for computing return directions
		var away_vec := Vector2.ZERO
		var away_dir := Vector2.ZERO
		var to_player = player.global_position - global_position
		# Z-index sorting relative to player
		z_index = 50 if global_position.y > player.global_position.y else -50
		var dist = to_player.length()
		if attack_state == "idle":
			is_parryable = false
			if dist <= attack_distance:
				# start backing
				attack_state = "backing"
				attack_timer = 0.0
				anim_player.play("windup")
				back_start = global_position
				# lock the attack target to the player's current position
				attack_target = player.global_position
				var dir_norm := Vector2.ZERO
				if to_player.length() > 0.1:
					dir_norm = to_player.normalized()
				else:
					dir_norm = Vector2(1, 0)
				back_target = global_position - dir_norm * backing_distance
				has_dealt_attack = false
			else:
				var direction = to_player.normalized()
				velocity = direction * move_speed
				move_and_slide()
				_handle_body_contact()
		elif attack_state == "backing":
			is_parryable = true
			attack_timer += delta
			var t = clamp(attack_timer / backing_duration, 0.0, 1.0)
			var ease_val = 1.0 - pow(1.0 - t, 2.0)
			# Face the locked attack target while backing up
			if player:
				var face_dir = (attack_target - global_position)
				if body:
					if abs(face_dir.x) > abs(face_dir.y):
						body.texture = sprite_right
						if face_dir.x < 0:
							last_scale_x_sign = -1.0
						else:
							last_scale_x_sign = 1.0
						body.scale.x = initial_body_scale.x * last_scale_x_sign
					else:
						if face_dir.y > 0:
							body.texture = sprite_front
						else:
							body.texture = sprite_back
						body.scale.x = initial_body_scale.x * 1.0
			global_position = back_start.lerp(back_target, ease_val)
			if attack_timer >= backing_duration:
				attack_state = "charging"
				attack_timer = 0.0
				# reset the fail timer when we start charging
				attack_fail_timer = 0.0
				# compute charge target based on locked attack target
				var toward_vec = attack_target - global_position
				var toward := Vector2.ZERO
				if toward_vec.length() > 0.1:
					toward = toward_vec.normalized()
				else:
					toward = Vector2(1, 0)
				charge_target = attack_target + toward * attack_extra_distance
		elif attack_state == "charging":
			is_parryable = true
			# timeout guard: increment fail timer and cancel if exceeded
			attack_fail_timer += delta
			if attack_fail_timer >= attack_fail_duration:
				# cancel attack and go to cooldown
				attack_state = "cooldown"
				cooldown_timer = 0.0
				velocity = Vector2.ZERO
				has_dealt_attack = true
			else:
				# move toward charge_target
				var to_charge = charge_target - global_position
				var dcharge = to_charge.length()
				if dcharge > 1.0:
					velocity = to_charge.normalized() * charge_speed
					move_and_slide()
					_handle_body_contact()
				if dcharge <= attack_extra_distance or global_position.distance_to(attack_target) <= attack_distance + attack_extra_distance:
					attack_state = "attacking"
					has_dealt_attack = false
					# Enemy is considered parryable while in the attacking state
					is_parryable = true
		elif attack_state == "attacking":
			is_parryable = true
			# timeout guard: increment fail timer and cancel if exceeded
			attack_fail_timer += delta
			if attack_fail_timer >= attack_fail_duration:
				# cancel attack and go to cooldown
				attack_state = "cooldown"
				cooldown_timer = 0.0
				velocity = Vector2.ZERO
				has_dealt_attack = true
			else:
				var dir_to_target = (attack_target - global_position)
				if dir_to_target.length() > 0.1:
					velocity = dir_to_target.normalized() * attack_dash_speed
					move_and_slide()
					# If the player moves into close range during the dash, immediately hit and end attack
					if player and not has_dealt_attack and global_position.distance_to(player.global_position) <= attack_hit_radius:
						if dead:
							has_dealt_attack = true
						else:
							if player and player.has_method("take_damage"):
								player.take_damage(attack_damage, (player.global_position - global_position).normalized(), self)
							has_dealt_attack = true
						# after attack, compute return target (at attack_distance from player's current position) and enter returning state
						away_vec = global_position - player.global_position
						away_dir = Vector2.ZERO
						if away_vec.length() > 0.1:
							away_dir = away_vec.normalized()
						else:
							away_dir = Vector2(1, 0) if randf() > 0.5 else Vector2(-1, 0)
						return_target = player.global_position + away_dir * attack_distance
						attack_state = "returning"
						cooldown_timer = 0.0
						velocity = Vector2.ZERO
						attack_fail_timer = 0.0
						return
				# Enemy is parryable for the entirety of the attacking state
				is_parryable = true
				# If we've reached near the locked attack target and the player is also near it, deal damage
				if global_position.distance_to(attack_target) <= attack_hit_radius and not has_dealt_attack:
					if player and player.global_position.distance_to(attack_target) <= attack_hit_radius:
						# do not deal damage if this enemy is already dead
						if dead:
							has_dealt_attack = true
						else:
							if player and player.has_method("take_damage"):
								player.take_damage(attack_damage, (player.global_position - global_position).normalized(), self)
							has_dealt_attack = true

					# after attack, compute return target (at attack_distance from locked attack target) and enter returning state
					away_vec = global_position - attack_target
					away_dir = Vector2.ZERO
					if away_vec.length() > 0.1:
						away_dir = away_vec.normalized()
					else:
						away_dir = Vector2(1, 0) if randf() > 0.5 else Vector2(-1, 0)
					return_target = attack_target + away_dir * attack_distance
					attack_state = "returning"
					cooldown_timer = 0.0
					velocity = Vector2.ZERO
		elif attack_state == "returning":
			is_parryable = false
			var to_return = return_target - global_position
			var dret = to_return.length()
			if dret > return_tolerance:
				# Face the player while returning
				if player:
					var face_dir = (player.global_position - global_position)
					if body:
						if abs(face_dir.x) > abs(face_dir.y):
							body.texture = sprite_right
							if face_dir.x < 0:
								last_scale_x_sign = -1.0
							else:
								last_scale_x_sign = 1.0
							body.scale.x = initial_body_scale.x * last_scale_x_sign
						else:
							if face_dir.y > 0:
								body.texture = sprite_front
							else:
								body.texture = sprite_back
							body.scale.x = initial_body_scale.x * 1.0
				velocity = to_return.normalized() * return_speed
				move_and_slide()
				_handle_body_contact()
			else:
				# reached desired attack-distance position
				attack_state = "cooldown"
				cooldown_timer = 0.0
				velocity = Vector2.ZERO
		elif attack_state == "cooldown":
			is_parryable = false
			cooldown_timer += delta
			# During cooldown, still follow the player to maintain attack distance
			if player:
				var to_p = player.global_position - global_position
				var d_p = to_p.length()
				if d_p > attack_distance:
					velocity = to_p.normalized() * move_speed
					move_and_slide()
					_handle_body_contact()
				else:
					velocity = Vector2.ZERO
			# After cooldown completes, go to idle (which also behaves to follow at attack distance)
			if cooldown_timer >= cooldown_duration:
				attack_state = "idle"

	# Sprite swapping based on movement direction (only when not in an attack state)
	if attack_state == "idle":
		if body:
			var scale_x_sign = last_scale_x_sign
			if velocity.length() > 0.1:
				var dir = velocity.normalized()
				if abs(dir.x) > abs(dir.y):
					body.texture = sprite_right
					scale_x_sign = -1.0 if dir.x < 0 else 1.0
				else:
					body.texture = sprite_front if dir.y > 0 else sprite_back
					scale_x_sign = 1.0
				last_scale_x_sign = scale_x_sign
			body.scale.x = initial_body_scale.x * scale_x_sign
			# Preserve Y-scale if currently elevated (so elevation-driven stretch isn't overridden)
			if not elevation_active:
				body.scale.y = initial_body_scale.y

	# Bobbing based on current velocity
	var speed_fraction = clamp(velocity.length() / move_speed, 0.0, 1.0)
	if body:
		var effective_amplitude = lerp(bob_amplitude_walk, bob_amplitude_run, speed_fraction)
		if speed_fraction > 0.0:
			var bob_speed = lerp(bob_speed_min, bob_speed_max, speed_fraction)
			bob_phase += delta * bob_speed
			var bob_offset = (sin(bob_phase - PI/2) + 1.0) * 0.5 * effective_amplitude
			# If currently elevated, preserve the elevation-driven body position
			if elevation_active:
				# keep bottom anchored when scaling is active
				if anchor_scale_bottom and body and body.texture:
					var th2 = body.texture.get_size().y
					body.position.y = _launcher_initial_body_pos.y + (th2 * (body.scale.y - _launcher_initial_body_scale.y) * 0.5)
				else:
					body.position.y = _launcher_initial_body_pos.y
			else:
				body.position.y = body_rest_y - bob_offset
			if shadow:
				var safe_amp = max(effective_amplitude, 0.0001)
				var bob_frac = clamp(bob_offset / safe_amp, 0.0, 1.0)
				var sx = lerp(initial_shadow_scale.x, initial_shadow_scale.x * 0.65, bob_frac)
				var sy = lerp(initial_shadow_scale.y, initial_shadow_scale.y * 0.65, bob_frac)
				# If currently elevated (from a launcher hit), shrink further toward 50% at peak
				if elevation_active and launcher_elevation_peak > 0.0:
					var elev_frac = clamp(elevation / launcher_elevation_peak, 0.0, 1.0)
					var shrink_factor = lerp(1.0, 0.5, elev_frac)
					sx *= shrink_factor
					sy *= shrink_factor
				shadow.scale = Vector2(sx, sy)
		else:
			bob_phase = 0.0
			# If elevated, preserve the elevation-driven body position instead of lerping back
			if elevation_active:
				if anchor_scale_bottom and body and body.texture:
					var th3 = body.texture.get_size().y
					body.position.y = _launcher_initial_body_pos.y + (th3 * (body.scale.y - _launcher_initial_body_scale.y) * 0.5)
				else:
					body.position.y = _launcher_initial_body_pos.y
			else:
				body.position.y = lerp(body.position.y, body_rest_y, min(1.0, delta * 10.0))
			if shadow:
				var t = min(1.0, delta * 10.0)
				shadow.scale = Vector2(lerp(shadow.scale.x, initial_shadow_scale.x, t), lerp(shadow.scale.y, initial_shadow_scale.y, t))


func _handle_body_contact(stop_on_any: bool = false) -> bool:
	# Block motion into other CharacterBody2D; only allow motion away or out of contact
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


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "die":
		queue_free()
