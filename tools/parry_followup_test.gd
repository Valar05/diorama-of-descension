extends Node


func _ready() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var player_scene := load("res://scenes/player.tscn")
	if player_scene == null:
		push_error("[PARRY_FOLLOWUP_TEST] fail could_not_load_player_scene")
		get_tree().quit(1)
		return

	var player: CharacterBody2D = player_scene.instantiate() as CharacterBody2D
	add_child(player)
	await get_tree().process_frame

	player.global_position = Vector2(200.0, 200.0)
	player.attack_active = false
	player.slash_dash_active = false
	player.parry_bounce_active = false
	player.attack_index = 0
	if "dash_meter" in player:
		player.dash_meter = 0.0

	player.call("on_parry_success", Vector2.RIGHT, 1.0, 48.0)

	var followup_started: bool = player.attack_active and player.attack_lockout and player.attack_index == 0
	var bounce_started: bool = player.parry_bounce_active
	var dash_suppressed: bool = not player.slash_dash_active
	var dash_meter_consumed: bool = true
	if "dash_meter" in player and "dash_meter_max" in player:
		dash_meter_consumed = absf(float(player.dash_meter)) < 0.001

	if followup_started and bounce_started and dash_suppressed and dash_meter_consumed:
		print("[PARRY_FOLLOWUP_TEST] pass followup_started=%s bounce_started=%s dash_suppressed=%s dash_meter_consumed=%s" % [followup_started, bounce_started, dash_suppressed, dash_meter_consumed])
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(0)
		return

	push_error("[PARRY_FOLLOWUP_TEST] fail followup_started=%s bounce_started=%s dash_suppressed=%s dash_meter_consumed=%s attack_index=%s attack_active=%s attack_lockout=%s slash_dash_active=%s" % [followup_started, bounce_started, dash_suppressed, dash_meter_consumed, player.attack_index, player.attack_active, player.attack_lockout, player.slash_dash_active])
	player.queue_free()
	await get_tree().process_frame
	get_tree().quit(1)
