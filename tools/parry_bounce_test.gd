extends Node

class MockPlayer:
	extends Node2D

	var parry_bounce_active := false
	var parry_call_count := 0
	var last_parry_dir := Vector2.ZERO
	var last_parry_intensity := 0.0
	var last_parry_travel_distance := 0.0
	var slash_dash_active := true
	var elevation := 0.0
	var airborne_attack_elevation_add := 8.0
	var dash_course_length := 60.0

	func get_parry_bounce_distance() -> float:
		return dash_course_length

	func on_parry_success(hit_dir: Vector2, intensity: float = 1.0, travel_distance: float = -1.0) -> void:
		parry_call_count += 1
		last_parry_dir = hit_dir
		last_parry_intensity = intensity
		last_parry_travel_distance = travel_distance
		parry_bounce_active = true
		slash_dash_active = false
		var bounce_distance := 24.0
		if travel_distance > 0.0:
			bounce_distance = travel_distance
		global_position += (-hit_dir.normalized()) * bounce_distance


class MockEnemy:
	extends Node2D

	var is_parryable := true
	var dead := false
	var health := 1.0

	func take_damage(amount: float, _dir: Vector2, _hitter: Node, _is_launcher: bool = false, _knockback_mult: float = 1.0) -> void:
		health -= amount
		if health <= 0.0:
			dead = true


func _ready() -> void:
	call_deferred("_run_test")


func _run_test() -> void:
	var player := MockPlayer.new()
	var enemy := MockEnemy.new()
	add_child(player)
	add_child(enemy)

	player.global_position = Vector2(200.0, 200.0)
	enemy.global_position = Vector2(248.0, 200.0)
	var expected_travel_distance := player.get_parry_bounce_distance()

	var slash := Node2D.new()
	slash.set_script(load("res://scenes/slash.gd"))
	var hitbox := Area2D.new()
	hitbox.name = "Hitbox"
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 48.0
	shape.shape = circle
	hitbox.add_child(shape)
	slash.add_child(hitbox)
	player.add_child(slash)

	slash.active = true
	slash.is_dash_slash = true
	slash.parry_damage = 999.0
	slash.parry_intensity = 1.0
	slash.knockback_dir = Vector2.RIGHT

	var enemy_hurtbox := Area2D.new()
	enemy_hurtbox.name = "Hurtbox"
	var enemy_shape := CollisionShape2D.new()
	var enemy_circle := CircleShape2D.new()
	enemy_circle.radius = 48.0
	enemy_shape.shape = enemy_circle
	enemy_hurtbox.add_child(enemy_shape)
	enemy.add_child(enemy_hurtbox)

	await get_tree().physics_frame
	var start_x := player.global_position.x
	slash._process(0.016)
	await get_tree().physics_frame

	var bounced := player.global_position.x <= start_x - expected_travel_distance + 0.5
	var bounce_active := player.parry_bounce_active or player.parry_call_count > 0
	var dash_cleared := not player.slash_dash_active
	var enemy_dead := enemy.dead

	if bounced and bounce_active and dash_cleared and enemy_dead and player.parry_call_count == 1 and absf(player.last_parry_travel_distance - expected_travel_distance) < 0.5:
		print("[PARRY_BOUNCE_TEST] pass moved_back=%s bounce_active=%s dash_cleared=%s enemy_dead=%s" % [bounced, bounce_active, dash_cleared, enemy_dead])
		get_tree().quit(0)
		return

	push_error("[PARRY_BOUNCE_TEST] fail moved_back=%s bounce_active=%s dash_cleared=%s enemy_dead=%s calls=%s travel=%s expected=%s" % [bounced, bounce_active, dash_cleared, enemy_dead, player.parry_call_count, player.last_parry_travel_distance, expected_travel_distance])
	get_tree().quit(1)
