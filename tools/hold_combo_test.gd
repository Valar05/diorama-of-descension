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
	var heavy_ok: bool = heavy_buffered_ok and player.attack_active and _has_named_child(player, "Stab")
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
	var multi_ok: bool = multi_buffered_ok and player.attack_active and _has_named_child(player, "MultiStab")
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
	if not idle_hold_waits_ok:
		push_error("[HOLD_COMBO_TEST] fail idle_hold_waits_ok=%s followup_kind=%s timer=%s has_stab=%s has_multi=%s" % [idle_hold_waits_ok, player.boot_followup_kind, player.boot_followup_timer, _has_named_child(player, "Stab"), _has_named_child(player, "MultiStab")])
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
	var live_heavy_ok: bool = live_boot_armed_ok and player.attack_active and _has_named_child(player, "Stab") and not _has_named_child(player, "MultiStab")
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
	var live_multi_ok: bool = live_multi_armed_ok and player.attack_active and _has_named_child(player, "MultiStab")
	if not live_multi_ok:
		push_error("[HOLD_COMBO_TEST] fail live_multi_ok=%s live_multi_armed_ok=%s followup_kind=%s elevation_active=%s attack_active=%s" % [live_multi_ok, live_multi_armed_ok, player.boot_followup_kind, player.elevation_active, player.attack_active])
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(1)
		return

	print("[HOLD_COMBO_TEST] pass launcher_ok=%s heavy_ok=%s multi_ok=%s live_neutral_launcher_ok=%s idle_hold_waits_ok=%s live_heavy_ok=%s live_multi_ok=%s" % [launcher_ok, heavy_ok, multi_ok, live_neutral_launcher_ok, idle_hold_waits_ok, live_heavy_ok, live_multi_ok])
	player.queue_free()
	await get_tree().process_frame
	get_tree().quit(0)
