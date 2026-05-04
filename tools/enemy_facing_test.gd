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

	if horizontal_ok and locked_ok and vertical_ok:
		print("[ENEMY_FACING_TEST] pass horizontal_ok=%s locked_ok=%s vertical_ok=%s" % [horizontal_ok, locked_ok, vertical_ok])
		enemy.queue_free()
		player.queue_free()
		await get_tree().process_frame
		get_tree().quit(0)
		return

	push_error("[ENEMY_FACING_TEST] fail horizontal_ok=%s locked_ok=%s vertical_ok=%s texture=%s scale_x=%s" % [horizontal_ok, locked_ok, vertical_ok, body.texture, body.scale.x])
	enemy.queue_free()
	player.queue_free()
	await get_tree().process_frame
	get_tree().quit(1)
