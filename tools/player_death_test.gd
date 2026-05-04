extends Node


func _ready() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var player_scene := load("res://scenes/player.tscn")
	if player_scene == null:
		push_error("[PLAYER_DEATH_TEST] fail could_not_load_player_scene")
		get_tree().quit(1)
		return

	var player: CharacterBody2D = player_scene.instantiate() as CharacterBody2D
	add_child(player)
	await get_tree().process_frame

	player.reload_on_death = false
	player.health = 1.0
	player.attack_active = true
	player.slash_dash_active = true
	player.tap_detected = true
	player.take_damage(999.0, Vector2.RIGHT, self)
	player.call("_process", 0.016)
	await get_tree().process_frame

	var death_ok: bool = player.death_pending and player.health <= 0.0
	var state_cleared_ok: bool = not player.attack_active and not player.slash_dash_active and not player.tap_detected
	var hitbox_off_ok: bool = true
	if player.dash_slash_hitbox:
		hitbox_off_ok = not player.dash_slash_hitbox.monitoring

	if death_ok and state_cleared_ok and hitbox_off_ok:
		print("[PLAYER_DEATH_TEST] pass death_ok=%s state_cleared_ok=%s hitbox_off_ok=%s" % [death_ok, state_cleared_ok, hitbox_off_ok])
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(0)
		return

	push_error("[PLAYER_DEATH_TEST] fail death_ok=%s state_cleared_ok=%s hitbox_off_ok=%s" % [death_ok, state_cleared_ok, hitbox_off_ok])
	player.queue_free()
	await get_tree().process_frame
	get_tree().quit(1)
