extends Node


class MockPlayer:
	extends CharacterBody2D


func _ready() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var enemy_scene := load("res://scenes/Goblin.tscn")
	if enemy_scene == null:
		push_error("[ENEMY_FACING_TEST] fail could_not_load_enemy_scene")
		get_tree().quit(1)
		return

	var enemy: CharacterBody2D = enemy_scene.instantiate() as CharacterBody2D
	var player := MockPlayer.new()
	add_child(enemy)
	add_child(player)
	await get_tree().process_frame

	enemy.player = player
	enemy._attack_permission = false
	enemy.attack_state = "idle"
	enemy.support_min_distance = 0.0
	enemy.move_speed = 1.0
	enemy.global_position = Vector2(200.0, 200.0)

	var body: Sprite2D = enemy.get_node_or_null("Sprite2D_body")
	if body == null:
		push_error("[ENEMY_FACING_TEST] fail missing_body_node")
		get_tree().quit(1)
		return

	player.global_position = Vector2(310.0, 340.0)
	enemy._physics_process(0.016)
	var horizontal_ok: bool = body.texture == enemy.sprite_right and body.scale.x > 0.0

	player.global_position = Vector2(200.0, 430.0)
	enemy._physics_process(0.016)
	var locked_ok: bool = body.texture == enemy.sprite_right and body.scale.x > 0.0

	enemy._facing_lock_remaining = 0.0
	enemy._physics_process(0.016)
	var vertical_ok: bool = body.texture == enemy.sprite_front and body.scale.x > 0.0

	enemy._facing_lock_remaining = 0.0
	enemy._attack_permission = false
	enemy.attack_state = "idle"
	enemy.support_min_distance = 420.0
	enemy.move_speed = 120.0
	player.global_position = Vector2(200.0, 200.0)
	enemy.global_position = Vector2(260.0, 200.0)
	var old_distance: float = enemy.global_position.distance_to(player.global_position)
	enemy._physics_process(0.1)
	var support_moves_away_ok: bool = enemy.global_position.distance_to(player.global_position) > old_distance

	enemy.global_position = Vector2(260.0, 200.0)
	enemy.call("_enter_returning_state", player.global_position)
	var return_ring_ok: bool = enemy.return_target.distance_to(player.global_position) >= enemy.support_min_distance - 0.1

	enemy.attack_state = "idle"
	enemy._attack_permission = false
	enemy.global_position = player.global_position
	enemy._support_escape_direction = Vector2.RIGHT
	enemy._support_escape_active = true
	enemy._physics_process(0.1)
	var overlap_escape_stable_ok: bool = enemy.velocity.x > 0.0 and absf(enemy.velocity.y) < 0.001

	if horizontal_ok and locked_ok and vertical_ok and support_moves_away_ok and return_ring_ok and overlap_escape_stable_ok:
		print("[ENEMY_FACING_TEST] pass horizontal_ok=%s locked_ok=%s vertical_ok=%s support_moves_away_ok=%s return_ring_ok=%s overlap_escape_stable_ok=%s" % [horizontal_ok, locked_ok, vertical_ok, support_moves_away_ok, return_ring_ok, overlap_escape_stable_ok])
		enemy.queue_free()
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(0)
		return

	push_error("[ENEMY_FACING_TEST] fail horizontal_ok=%s locked_ok=%s vertical_ok=%s support_moves_away_ok=%s return_ring_ok=%s overlap_escape_stable_ok=%s texture=%s scale_x=%s velocity=%s" % [horizontal_ok, locked_ok, vertical_ok, support_moves_away_ok, return_ring_ok, overlap_escape_stable_ok, body.texture, body.scale.x, enemy.velocity])
	enemy.queue_free()
	player.queue_free()
	await get_tree().process_frame
	get_tree().quit(1)
