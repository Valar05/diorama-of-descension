extends Node


func _ready() -> void:
	call_deferred("_run_test")


func _reset_player_state(player: Node) -> void:
	player.attack_active = false
	player.attack_timer = 0.0
	player.attack_buffered = false
	player.attack_buffer_timer = 0.0
	player.attack_lockout = false
	player.attack_lockout_timer = 0.0
	player.attack_index = 0
	player.boot_followup_armed = false
	player.boot_followup_use_multi = false
	player.boot_followup_timer = 0.0
	player.boot_followup_input_timer = 0.0
	player.boot_followup_kind = ""
	player.consecutive_light_attacks = 0
	player.cross_slash_armed = false
	player.hold_combo_buffered = false
	player.hold_combo_buffer_hits = 0
	player.kick_active = false
	player.kick_pending = false
	player.kick_ready = false
	player.kick_timer = 0.0
	player.kick_arm_time = 0.0
	player.launcher_buffered = false
	player.launcher_buffer_timer = 0.0
	player.movement_pending = false
	player.tap_detected = false
	player.tap_timer = 0.0
	player.elevation_active = false
	player.elevation = 0.0
	player.elevation_bonus = 0.0
	player.slash_dash_active = false
	player.slash_dash_timer = 0.0
	player.slash_dash_direction = Vector2.ZERO
	player.velocity = Vector2.ZERO


func _has_named_child(player: Node, child_name: String) -> bool:
	for child in player.get_children():
		if child and child.name == child_name:
			return true
	return false


func _prime_hold_input(player: Node) -> void:
	player.tap_detected = true
	player.tap_timer = player.launcher_hold_time
	player.tap_position = Vector2(10000.0, 200.0)
	player.last_press_index = 0
	player.active_touch_count = 1
	player.active_touch_ids = [0]
	player.multi_touch_sequence = false
	player.movement_pending = true


func _run_test() -> void:
	var player_scene := load("res://scenes/player.tscn")
	if player_scene == null:
		push_error("[HOLD_COMBO_TEST] fail could_not_load_player_scene")
		get_tree().quit(1)
		return

	var player = player_scene.instantiate()
	add_child(player)
	await get_tree().process_frame

	_reset_player_state(player)
	var boot_hold_time_ok: bool = absf(float(player.launcher_hold_time) - 0.2) < 0.001
	if not boot_hold_time_ok:
		push_error("[HOLD_COMBO_TEST] fail boot_hold_time_ok=%s launcher_hold_time=%s" % [boot_hold_time_ok, player.launcher_hold_time])
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return
	player.call("_resolve_hold_combo")
	var launcher_ok: bool = player.elevation_active and player.attack_active and not player.boot_followup_armed
	if not launcher_ok:
		push_error("[HOLD_COMBO_TEST] fail launcher_ok=%s elevation_active=%s attack_active=%s boot_followup_armed=%s" % [launcher_ok, player.elevation_active, player.attack_active, player.boot_followup_armed])
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return

	player.queue_free()
	await get_tree().process_frame

	player = player_scene.instantiate()
	add_child(player)
	await get_tree().process_frame
	_reset_player_state(player)
	player.attack_active = true
	player.attack_timer = 0.10
	player.consecutive_light_attacks = 1
	player.call("_resolve_hold_combo")
	var heavy_buffered_ok: bool = player.hold_combo_buffered and player.hold_combo_buffer_hits == 1 and not player.boot_followup_armed
	player.call("_process", 1.0)
	player.call("_process", 0.35)
	await get_tree().process_frame
	var heavy_waits_for_tap_ok: bool = heavy_buffered_ok and player.boot_followup_armed and player.boot_followup_kind == "HeavyStab" and not player.attack_active and not _has_named_child(player, "Stab")
	player.attack_buffered = true
	player.attack_buffer_timer = 0.0
	player.call("_process", 0.016)
	await get_tree().process_frame
	var heavy_ok: bool = heavy_waits_for_tap_ok and player.attack_active and _has_named_child(player, "Stab")
	var heavy_multi_ok: bool = not _has_named_child(player, "MultiStab")
	if not heavy_ok or not heavy_multi_ok:
		push_error("[HOLD_COMBO_TEST] fail heavy_ok=%s heavy_multi_ok=%s attack_active=%s boot_followup_armed=%s" % [heavy_ok, heavy_multi_ok, player.attack_active, player.boot_followup_armed])
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return

	player.queue_free()
	await get_tree().process_frame

	player = player_scene.instantiate()
	add_child(player)
	await get_tree().process_frame
	_reset_player_state(player)
	player.attack_active = true
	player.attack_timer = 0.10
	player.consecutive_light_attacks = 2
	player.call("_resolve_hold_combo")
	var multi_buffered_ok: bool = player.hold_combo_buffered and player.hold_combo_buffer_hits == 2 and not player.boot_followup_armed
	player.call("_process", 1.0)
	player.call("_process", 0.35)
	await get_tree().process_frame
	var multi_waits_for_tap_ok: bool = multi_buffered_ok and player.boot_followup_armed and player.boot_followup_kind == "MultiStab" and not player.attack_active and not _has_named_child(player, "MultiStab")
	player.attack_buffered = true
	player.attack_buffer_timer = 0.0
	player.call("_process", 0.016)
	await get_tree().process_frame
	var multi_ok: bool = multi_waits_for_tap_ok and player.attack_active and _has_named_child(player, "MultiStab")
	if not multi_ok:
		push_error("[HOLD_COMBO_TEST] fail multi_ok=%s attack_active=%s boot_followup_armed=%s" % [multi_ok, player.attack_active, player.boot_followup_armed])
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return

	player.queue_free()
	await get_tree().process_frame

	player = player_scene.instantiate()
	add_child(player)
	await get_tree().process_frame
	_reset_player_state(player)
	_prime_hold_input(player)
	player.call("_process", 0.016)
	var live_neutral_launcher_ok: bool = player.elevation_active and player.attack_active and not player.boot_followup_armed
	if not live_neutral_launcher_ok:
		push_error("[HOLD_COMBO_TEST] fail live_neutral_launcher_ok=%s elevation_active=%s attack_active=%s boot_followup_armed=%s" % [live_neutral_launcher_ok, player.elevation_active, player.attack_active, player.boot_followup_armed])
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return

	player.queue_free()
	await get_tree().process_frame

	player = player_scene.instantiate()
	add_child(player)
	await get_tree().process_frame
	_reset_player_state(player)
	player.consecutive_light_attacks = 1
	_prime_hold_input(player)
	player.call("_process", 0.016)
	var idle_hold_waits_ok: bool = player.boot_followup_armed and player.boot_followup_kind == "HeavyStab" and player.boot_followup_timer > 0.0 and not _has_named_child(player, "Stab") and not _has_named_child(player, "MultiStab")
	player.call("_process", 0.35)
	var idle_hold_requires_tap_ok: bool = idle_hold_waits_ok and player.boot_followup_armed and player.boot_followup_timer <= 0.0 and not player.attack_active and not _has_named_child(player, "Stab") and not _has_named_child(player, "MultiStab")
	if not idle_hold_waits_ok:
		push_error("[HOLD_COMBO_TEST] fail idle_hold_waits_ok=%s followup_kind=%s timer=%s has_stab=%s has_multi=%s" % [idle_hold_waits_ok, player.boot_followup_kind, player.boot_followup_timer, _has_named_child(player, "Stab"), _has_named_child(player, "MultiStab")])
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return
	if not idle_hold_requires_tap_ok:
		push_error("[HOLD_COMBO_TEST] fail idle_hold_requires_tap_ok=%s followup_kind=%s timer=%s attack_active=%s has_stab=%s has_multi=%s" % [idle_hold_requires_tap_ok, player.boot_followup_kind, player.boot_followup_timer, player.attack_active, _has_named_child(player, "Stab"), _has_named_child(player, "MultiStab")])
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return

	player.queue_free()
	await get_tree().process_frame

	player = player_scene.instantiate()
	add_child(player)
	await get_tree().process_frame
	_reset_player_state(player)
	player.consecutive_light_attacks = 1
	player.attack_active = true
	player.attack_timer = player.attack_duration - 0.01
	player.tap_detected = true
	player.tap_timer = player.launcher_hold_time - 0.02
	player.tap_position = Vector2(10000.0, 200.0)
	player.active_touch_count = 1
	player.active_touch_ids = [0]
	player.multi_touch_sequence = false
	player.call("_process", 0.03)
	var hold_survives_attack_end_ok: bool = player.boot_followup_armed and player.boot_followup_kind == "HeavyStab" and not player.tap_detected
	if not hold_survives_attack_end_ok:
		push_error("[HOLD_COMBO_TEST] fail hold_survives_attack_end_ok=%s boot_followup_armed=%s kind=%s tap_detected=%s tap_timer=%s" % [hold_survives_attack_end_ok, player.boot_followup_armed, player.boot_followup_kind, player.tap_detected, player.tap_timer])
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return

	player.queue_free()
	await get_tree().process_frame

	player = player_scene.instantiate()
	add_child(player)
	await get_tree().process_frame
	_reset_player_state(player)
	player.consecutive_light_attacks = 1
	player.tap_detected = true
	player.tap_timer = player.launcher_hold_time - 0.01
	player.tap_position = Vector2(10000.0, 200.0)
	player.active_touch_count = 1
	player.active_touch_ids = [0]
	player.multi_touch_sequence = false
	var mid_x: float = player.get_viewport().get_visible_rect().size.x / 2.0
	var release_hold_ok: bool = player.call("_should_resolve_hold_combo_on_release", {
		"released_duration": player.launcher_hold_time + 0.01,
		"start_pos": Vector2(mid_x + 10.0, 200.0)
	}, 0.0, mid_x)
	if not release_hold_ok:
		push_error("[HOLD_COMBO_TEST] fail release_hold_ok=%s tap_detected=%s tap_timer=%s" % [release_hold_ok, player.tap_detected, player.tap_timer])
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return
	player.call("_resolve_hold_combo")
	var release_boot_buffered_ok: bool = player.boot_followup_armed and player.boot_followup_kind == "HeavyStab"
	if not release_boot_buffered_ok:
		push_error("[HOLD_COMBO_TEST] fail release_boot_buffered_ok=%s boot_followup_armed=%s kind=%s" % [release_boot_buffered_ok, player.boot_followup_armed, player.boot_followup_kind])
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return

	player.queue_free()
	await get_tree().process_frame

	player = player_scene.instantiate()
	add_child(player)
	await get_tree().process_frame
	_reset_player_state(player)
	var body: Sprite2D = player.get_node_or_null("Sprite2D_body")
	player.call("_start_attack", player.global_position + Vector2.RIGHT * 60.0, "SlashLeft")
	player.stick_dir_frame = Vector2.LEFT
	player.call("_process", 0.016)
	var attack_facing_owns_sprite_ok: bool = body != null and body.texture == player.sprite_right and body.scale.x > 0.0 and player.attack_facing_direction.dot(Vector2.RIGHT) > 0.99
	if not attack_facing_owns_sprite_ok:
		push_error("[HOLD_COMBO_TEST] fail attack_facing_owns_sprite_ok=%s texture=%s scale_x=%s attack_facing=%s" % [attack_facing_owns_sprite_ok, body.texture if body else null, body.scale.x if body else 0.0, player.attack_facing_direction])
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return

	player.queue_free()
	await get_tree().process_frame

	player = player_scene.instantiate()
	add_child(player)
	await get_tree().process_frame
	_reset_player_state(player)
	player.consecutive_light_attacks = 1
	player.attack_active = true
	player.attack_timer = player.attack_duration * player.combo_cancel_early_frac + 0.01
	_prime_hold_input(player)
	player.call("_process", 0.016)
	var live_boot_cancel_buffered_ok: bool = player.hold_combo_buffered and player.hold_combo_buffer_hits == 1 and not player.boot_followup_armed
	player.call("_process", 0.016)
	var live_boot_cancel_window_ok: bool = live_boot_cancel_buffered_ok and player.boot_followup_armed and player.boot_followup_kind == "HeavyStab" and not player.attack_active
	if not live_boot_cancel_window_ok:
		push_error("[HOLD_COMBO_TEST] fail live_boot_cancel_window_ok=%s buffered_ok=%s boot_followup_armed=%s kind=%s attack_active=%s attack_timer=%s" % [live_boot_cancel_window_ok, live_boot_cancel_buffered_ok, player.boot_followup_armed, player.boot_followup_kind, player.attack_active, player.attack_timer])
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return

	player.queue_free()
	await get_tree().process_frame

	player = player_scene.instantiate()
	add_child(player)
	await get_tree().process_frame
	_reset_player_state(player)
	player.consecutive_light_attacks = 1
	player.attack_active = true
	player.attack_timer = 0.10
	_prime_hold_input(player)
	player.call("_process", 0.016)
	var live_boot_buffered_ok: bool = player.hold_combo_buffered and player.hold_combo_buffer_hits == 1 and not player.boot_followup_armed and not player.elevation_active
	player.call("_process", 1.0)
	var live_boot_armed_ok: bool = live_boot_buffered_ok and player.boot_followup_armed and player.boot_followup_kind == "HeavyStab" and not player.elevation_active
	player.call("_process", 0.35)
	await get_tree().process_frame
	var live_heavy_waits_for_tap_ok: bool = live_boot_armed_ok and not player.attack_active and not _has_named_child(player, "Stab") and not _has_named_child(player, "MultiStab")
	player.call("_process", 1.6)
	var live_heavy_window_ok: bool = live_heavy_waits_for_tap_ok and player.boot_followup_armed and player.boot_followup_input_timer > 0.0
	player.attack_buffered = true
	player.attack_buffer_timer = 0.0
	player.call("_process", 0.016)
	await get_tree().process_frame
	var live_heavy_ok: bool = live_heavy_window_ok and player.attack_active and _has_named_child(player, "Stab") and not _has_named_child(player, "MultiStab")
	if not live_heavy_ok:
		push_error("[HOLD_COMBO_TEST] fail live_heavy_ok=%s live_boot_armed_ok=%s followup_kind=%s elevation_active=%s attack_active=%s" % [live_heavy_ok, live_boot_armed_ok, player.boot_followup_kind, player.elevation_active, player.attack_active])
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return

	player.queue_free()
	await get_tree().process_frame

	player = player_scene.instantiate()
	add_child(player)
	await get_tree().process_frame
	_reset_player_state(player)
	player.consecutive_light_attacks = 1
	player.call("_resolve_hold_combo")
	player.call("_process", 0.35)
	var followup_release_buffer_ok: bool = player.boot_followup_armed and player.call("_should_buffer_attack_on_release", {
		"released_duration": min(player.boot_followup_tap_time - 0.01, player.boot_followup_input_window),
		"start_pos": Vector2(player.get_viewport().get_visible_rect().size.x * 0.75, 200.0)
	}, 0.0, player.get_viewport().get_visible_rect().size.x / 2.0)
	if not followup_release_buffer_ok:
		push_error("[HOLD_COMBO_TEST] fail followup_release_buffer_ok=%s boot_followup_armed=%s tap_limit=%s" % [followup_release_buffer_ok, player.boot_followup_armed, player.boot_followup_tap_time])
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return

	player.queue_free()
	await get_tree().process_frame

	player = player_scene.instantiate()
	add_child(player)
	await get_tree().process_frame
	_reset_player_state(player)
	player.consecutive_light_attacks = 2
	player.attack_active = true
	player.attack_timer = 0.10
	_prime_hold_input(player)
	player.call("_process", 0.016)
	var live_multi_buffered_ok: bool = player.hold_combo_buffered and player.hold_combo_buffer_hits == 2 and not player.boot_followup_armed and not player.elevation_active
	player.call("_process", 1.0)
	var live_multi_armed_ok: bool = live_multi_buffered_ok and player.boot_followup_armed and player.boot_followup_kind == "MultiStab" and not player.elevation_active
	player.call("_process", 0.35)
	await get_tree().process_frame
	var live_multi_waits_for_tap_ok: bool = live_multi_armed_ok and not player.attack_active and not _has_named_child(player, "MultiStab")
	player.attack_buffered = true
	player.attack_buffer_timer = 0.0
	player.call("_process", 0.016)
	await get_tree().process_frame
	var live_multi_ok: bool = live_multi_waits_for_tap_ok and player.attack_active and _has_named_child(player, "MultiStab")
	if not live_multi_ok:
		push_error("[HOLD_COMBO_TEST] fail live_multi_ok=%s live_multi_armed_ok=%s followup_kind=%s elevation_active=%s attack_active=%s" % [live_multi_ok, live_multi_armed_ok, player.boot_followup_kind, player.elevation_active, player.attack_active])
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return

	print("[HOLD_COMBO_TEST] pass boot_hold_time_ok=%s launcher_ok=%s heavy_ok=%s multi_ok=%s live_neutral_launcher_ok=%s idle_hold_waits_ok=%s idle_hold_requires_tap_ok=%s hold_survives_attack_end_ok=%s attack_facing_owns_sprite_ok=%s live_boot_cancel_window_ok=%s live_heavy_window_ok=%s live_heavy_ok=%s live_multi_ok=%s" % [boot_hold_time_ok, launcher_ok, heavy_ok, multi_ok, live_neutral_launcher_ok, idle_hold_waits_ok, idle_hold_requires_tap_ok, hold_survives_attack_end_ok, attack_facing_owns_sprite_ok, live_boot_cancel_window_ok, live_heavy_window_ok, live_heavy_ok, live_multi_ok])
	player.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
