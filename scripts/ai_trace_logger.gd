extends Node

@export var max_frames: int = 180
@export var sample_every_frames: int = 1
@export var spawn_extra_enemies: int = 4
@export var fail_on_multiple_attackers: bool = true

var _main: Node = null
var _frame: int = 0
var _started: bool = false


func _ready() -> void:
	call_deferred("_start")


func _start() -> void:
	_main = get_tree().current_scene
	if _main == null:
		push_error("[AI_TRACE] no current scene")
		get_tree().quit(1)
		return
	print("[AI_TRACE] logger start scene=", _main.name, " max_frames=", max_frames, " sample_every=", sample_every_frames, " extra_enemies=", spawn_extra_enemies)
	if _main.has_method("spawn_enemy"):
		for _i in range(spawn_extra_enemies):
			_main.call("spawn_enemy")
	_started = true
	set_process(true)


func _process(_delta: float) -> void:
	if not _started:
		return
	_frame += 1
	if _frame % sample_every_frames == 0:
		if _frame == sample_every_frames:
			print("[AI_TRACE] first sample frame=", _frame)
		_dump_snapshot()
		if fail_on_multiple_attackers and _count_attackers() > 1:
			push_error("[AI_TRACE] multiple simultaneous attackers detected")
			get_tree().quit(1)
			return
	if _frame >= max_frames:
		get_tree().quit(0)


func _count_attackers() -> int:
	var count := 0
	for enemy in _get_enemies():
		if enemy != null and is_instance_valid(enemy) and enemy.has_method("is_attacking") and bool(enemy.call("is_attacking")):
			count += 1
	return count


func _get_enemies() -> Array:
	return get_tree().get_nodes_in_group(&"enemies")


func _vector_dict(v: Vector2) -> Dictionary:
	return {"x": v.x, "y": v.y}


func _enemy_snapshot(enemy: Node) -> Dictionary:
	if enemy == null or not is_instance_valid(enemy):
		return {"valid": false}
	if enemy.has_method("debug_snapshot"):
		return enemy.call("debug_snapshot")
	var snap: Dictionary = {
		"name": enemy.name,
		"valid": true,
	}
	if enemy is Node2D:
		snap["pos"] = _vector_dict((enemy as Node2D).global_position)
	return snap


func _conductor_snapshot() -> Dictionary:
	var conductors = get_tree().get_nodes_in_group("ai_conductor")
	if conductors.is_empty():
		return {"present": false}
	var conductor = conductors[0]
	if conductor != null and is_instance_valid(conductor) and conductor.has_method("debug_snapshot"):
		return conductor.call("debug_snapshot")
	return {"present": true}


func _dump_snapshot() -> void:
	var snapshots: Array = []
	for enemy in _get_enemies():
		snapshots.append(_enemy_snapshot(enemy))
	snapshots.sort_custom(func(a, b): return String(a.get("name", "")) < String(b.get("name", "")))
	var payload := {
		"frame": _frame,
		"attackers": _count_attackers(),
		"conductor": _conductor_snapshot(),
		"enemies": snapshots,
	}
	print("[AI_TRACE] ", JSON.stringify(payload))
