extends Node2D

@export var player_path: NodePath = NodePath("../Player")
@export var enemy_group_name: StringName = &"enemies"
@export var support_slot_distance: float = 420.0
@export var retreat_ring_distance: float = 520.0
@export var flee_distance: float = 560.0
@export var flee_screen_margin: float = 48.0
@export var player_damage_attack_lockout_duration: float = 1.25
@export_range(4, 16, 1) var support_slot_count: int = 8
@export var debug_ai_conductor: bool = false

var _current_attack_enemy: Node2D = null
var _last_attack_enemy: Node2D = null
var _player_damage_attack_lock_remaining: float = 0.0
var _player_damage_combo_enemy: Node2D = null
var _enemy_slot_assignments: Dictionary = {}


func _ready() -> void:
	add_to_group("ai_conductor")
	process_priority = -100


func _get_player_node() -> Node2D:
	if player_path != NodePath(""):
		var player_node = get_node_or_null(player_path)
		if player_node is Node2D:
			return player_node
	var players = get_tree().get_nodes_in_group("player")
	for candidate in players:
		if candidate is Node2D:
			return candidate as Node2D
	return null


func _get_enemy_nodes() -> Array:
	var enemies: Array = []
	var grouped = get_tree().get_nodes_in_group(enemy_group_name)
	for candidate in grouped:
		if candidate is Node2D and is_instance_valid(candidate) and candidate.is_inside_tree():
			enemies.append(candidate)
	return enemies


func _is_enemy_alive(enemy: Node2D) -> bool:
	if enemy == null or not is_instance_valid(enemy) or not enemy.is_inside_tree():
		return false
	if "dead" in enemy and bool(enemy.dead):
		return false
	if "health" in enemy and float(enemy.health) <= 0.0:
		return false
	return true


func _is_enemy_wounded(enemy: Node2D) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.has_method("is_wounded"):
		return bool(enemy.call("is_wounded"))
	if "health" in enemy and "max_health" in enemy:
		var max_health = max(1.0, float(enemy.max_health))
		return float(enemy.health) > 0.0 and float(enemy.health) <= max_health * 0.35
	return false


func _is_enemy_fleeing(enemy: Node2D) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.has_method("is_fleeing"):
		return bool(enemy.call("is_fleeing"))
	if "is_fleeing" in enemy:
		return bool(enemy.is_fleeing)
	return false


func _is_enemy_pending_flee(enemy: Node2D) -> bool:
	if enemy == null or not is_instance_valid(enemy):
		return false
	if enemy.has_method("is_pending_flee"):
		return bool(enemy.call("is_pending_flee"))
	if "pending_flee" in enemy:
		return bool(enemy.pending_flee)
	return false


func _can_enemy_receive_attack_permission(enemy: Node2D) -> bool:
	if not _is_enemy_alive(enemy):
		return false
	if enemy.has_method("can_seek_attack_player"):
		return bool(enemy.call("can_seek_attack_player"))
	if "attack_reentry_lock_remaining" in enemy and float(enemy.attack_reentry_lock_remaining) > 0.0:
		return false
	if _is_enemy_fleeing(enemy) or _is_enemy_pending_flee(enemy):
		return false
	return true


func _clamp_to_viewport(point: Vector2) -> Vector2:
	var viewport = get_viewport()
	if viewport == null:
		return point
	var rect = viewport.get_visible_rect()
	var min_x = rect.position.x + flee_screen_margin
	var max_x = rect.end.x - flee_screen_margin
	var min_y = rect.position.y + flee_screen_margin
	var max_y = rect.end.y - flee_screen_margin
	return Vector2(clampf(point.x, min_x, max_x), clampf(point.y, min_y, max_y))


func _get_support_slots(player_pos: Vector2, count: int) -> Array:
	var slots: Array = []
	var slot_count = max(4, count)
	var angle_offset = -PI * 0.5
	for idx in range(slot_count):
		var angle = angle_offset + TAU * float(idx) / float(slot_count)
		var slot = player_pos + Vector2(cos(angle), sin(angle)) * support_slot_distance
		slots.append(_clamp_to_viewport(slot))
	return slots


func _get_retreat_target(enemy: Node2D, player_pos: Vector2) -> Vector2:
	var away = enemy.global_position - player_pos
	if away.length() <= 0.001:
		away = Vector2.RIGHT
	var target = player_pos + away.normalized() * retreat_ring_distance
	return _clamp_to_viewport(target)


func _get_flee_target(enemy: Node2D, player_pos: Vector2) -> Vector2:
	var away = enemy.global_position - player_pos
	if away.length() <= 0.001:
		away = Vector2.RIGHT
	var direction = away.normalized()
	var candidate = enemy.global_position + direction * flee_distance
	var viewport = get_viewport()
	if viewport == null:
		return candidate
	var rect = viewport.get_visible_rect()
	if abs(direction.x) >= abs(direction.y):
		candidate.x = rect.end.x + flee_screen_margin if direction.x > 0.0 else rect.position.x - flee_screen_margin
	else:
		candidate.y = rect.end.y + flee_screen_margin if direction.y > 0.0 else rect.position.y - flee_screen_margin
	return candidate


func _pick_attack_owner(enemies: Array, player_pos: Vector2) -> Node2D:
	if _current_attack_enemy != null and is_instance_valid(_current_attack_enemy) and _can_enemy_receive_attack_permission(_current_attack_enemy):
		return _current_attack_enemy
	if _player_damage_attack_lock_remaining > 0.0 and _player_damage_combo_enemy != null and is_instance_valid(_player_damage_combo_enemy):
		if _can_enemy_receive_attack_permission(_player_damage_combo_enemy):
			return _player_damage_combo_enemy
	var best_enemy: Node2D = null
	var best_score := INF
	for enemy in enemies:
		if not _can_enemy_receive_attack_permission(enemy):
			continue
		var score = enemy.global_position.distance_to(player_pos)
		if enemy == _last_attack_enemy:
			score += 120.0
		if _is_enemy_wounded(enemy):
			score += 1000.0
		if score < best_score:
			best_score = score
			best_enemy = enemy
	return best_enemy


func _assign_support_targets(enemies: Array, attack_owner: Node2D, player_pos: Vector2) -> void:
	var slots = _get_support_slots(player_pos, max(support_slot_count, enemies.size()))
	var claimed_slots: Array[int] = []

	# Keep support enemies on stable slots so they stop swapping targets every frame.
	for enemy in enemies:
		if enemy == attack_owner:
			continue
		if not _can_enemy_receive_attack_permission(enemy):
			continue
		var enemy_id = int(enemy.get_instance_id())
		if not _enemy_slot_assignments.has(enemy_id):
			continue
		var assigned_slot = int(_enemy_slot_assignments[enemy_id])
		if assigned_slot >= 0 and assigned_slot < slots.size() and not (assigned_slot in claimed_slots):
			claimed_slots.append(assigned_slot)

	for enemy in enemies:
		if enemy == attack_owner:
			_enemy_slot_assignments.erase(int(enemy.get_instance_id()))
			continue
		if not _can_enemy_receive_attack_permission(enemy):
			_enemy_slot_assignments.erase(int(enemy.get_instance_id()))
			continue
		var enemy_id = int(enemy.get_instance_id())
		var assigned_slot = -1
		if _enemy_slot_assignments.has(enemy_id):
			assigned_slot = int(_enemy_slot_assignments[enemy_id])
		var best_index := -1
		var best_score := INF
		if assigned_slot >= 0 and assigned_slot < slots.size() and not (assigned_slot in claimed_slots):
			best_index = assigned_slot
		else:
			for idx in range(slots.size()):
				if idx in claimed_slots:
					continue
				var score = enemy.global_position.distance_to(slots[idx])
				if score < best_score:
					best_score = score
					best_index = idx
		if best_index >= 0 and enemy.has_method("set_target_point"):
			_enemy_slot_assignments[enemy_id] = best_index
			enemy.call("set_target_point", slots[best_index])
			if not (best_index in claimed_slots):
				claimed_slots.append(best_index)


func on_player_damaged(damager: Node2D = null, duration: float = -1.0) -> void:
	var lock_duration = player_damage_attack_lockout_duration if duration < 0.0 else duration
	_player_damage_attack_lock_remaining = max(_player_damage_attack_lock_remaining, lock_duration)
	if damager != null and is_instance_valid(damager) and _is_enemy_alive(damager):
		_player_damage_combo_enemy = damager
		_current_attack_enemy = damager
	else:
		_player_damage_combo_enemy = null


func on_player_parried(duration: float = 2.5) -> void:
	_player_damage_attack_lock_remaining = max(_player_damage_attack_lock_remaining, duration)
	_player_damage_combo_enemy = null
	_current_attack_enemy = null


func notify_enemy_died(enemy: Node2D) -> void:
	if enemy == _current_attack_enemy:
		_current_attack_enemy = null
	if enemy == _player_damage_combo_enemy:
		_player_damage_combo_enemy = null
	if enemy == _last_attack_enemy:
		_last_attack_enemy = null
	if enemy != null and is_instance_valid(enemy):
		_enemy_slot_assignments.erase(int(enemy.get_instance_id()))


func _process(delta: float) -> void:
	var player_node = _get_player_node()
	if player_node == null:
		return
	var enemies = _get_enemy_nodes()
	if _player_damage_attack_lock_remaining > 0.0:
		_player_damage_attack_lock_remaining = max(0.0, _player_damage_attack_lock_remaining - delta)
		if _player_damage_attack_lock_remaining <= 0.0:
			_player_damage_combo_enemy = null
		if debug_ai_conductor:
			print("[AI_CONDUCTOR] lock remaining=", _player_damage_attack_lock_remaining)

	for enemy in enemies:
		if not _is_enemy_alive(enemy):
			continue
		if enemy.has_method("is_pending_flee") and bool(enemy.call("is_pending_flee")):
			continue
		if enemy.has_method("needs_to_flee") and bool(enemy.call("needs_to_flee")):
			var flee_target = _get_flee_target(enemy, player_node.global_position)
			if enemy.has_method("start_flee"):
				enemy.call("start_flee", flee_target)

	var attack_owner = _pick_attack_owner(enemies, player_node.global_position)
	if attack_owner == null and _current_attack_enemy != null and is_instance_valid(_current_attack_enemy):
		if _current_attack_enemy.has_method("is_attacking") and bool(_current_attack_enemy.call("is_attacking")):
			attack_owner = _current_attack_enemy

	_current_attack_enemy = attack_owner
	_assign_support_targets(enemies, attack_owner, player_node.global_position)
	for enemy in enemies:
		if not _is_enemy_alive(enemy):
			continue
		if enemy == attack_owner:
			if enemy.has_method("set_attack_permission"):
				enemy.call("set_attack_permission", true)
			if enemy.has_method("cancel_direct_move"):
				enemy.call("cancel_direct_move")
			var owner_state := ""
			if "attack_state" in enemy:
				owner_state = String(enemy.attack_state)
			if owner_state != "idle" and enemy.has_method("set_target_point"):
				enemy.call("set_target_point", _get_retreat_target(enemy, player_node.global_position))
		elif enemy.has_method("set_attack_permission"):
			enemy.call("set_attack_permission", false)
			if enemy.has_method("force_attack_abort"):
				enemy.call("force_attack_abort")

	if attack_owner != null:
		_last_attack_enemy = attack_owner
		if debug_ai_conductor:
			print("[AI_CONDUCTOR] attack_owner=", attack_owner.name)


func debug_snapshot() -> Dictionary:
	return {
		"current_attack_enemy": _current_attack_enemy.name if _current_attack_enemy != null and is_instance_valid(_current_attack_enemy) else "",
		"last_attack_enemy": _last_attack_enemy.name if _last_attack_enemy != null and is_instance_valid(_last_attack_enemy) else "",
		"player_damage_lock": _player_damage_attack_lock_remaining,
		"combo_enemy": _player_damage_combo_enemy.name if _player_damage_combo_enemy != null and is_instance_valid(_player_damage_combo_enemy) else "",
		"enemy_count": get_tree().get_nodes_in_group(enemy_group_name).size()
	}
