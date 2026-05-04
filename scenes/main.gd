extends Node2D

@export var enemies: Array[PackedScene] = []
@export var max_enemies := 15
var live_enemies: Array = []

var spawn_timer: float = 0.0
var spawn_interval: float = 3.0
var screen_size: Vector2

@onready var player: CharacterBody2D = $Player
const AI_TRACE_LOGGER := preload("res://scripts/ai_trace_logger.gd")

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size
	spawn_enemy()
	_maybe_attach_ai_trace_logger()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	spawn_timer += delta
	if spawn_timer >= spawn_interval:
		spawn_enemy()
		spawn_timer = 0.0
		spawn_interval = max(0.5, spawn_interval - 0.07)

func spawn_enemy():
	# Prune invalid or dead entries from live_enemies
	var pruned := []
	for e in live_enemies:
		if not is_instance_valid(e):
			continue
		if not e.is_inside_tree():
			continue
		if "dead" in e:
			if e.dead:
				continue
			pruned.append(e)
		else:
			# fallback: only count nodes that look like enemies
			if e.has_method("take_damage"):
				pruned.append(e)
	live_enemies = pruned
	# enforce cap
	if live_enemies.size() >= max_enemies:
		return

	if enemies.is_empty():
		return
	var enemy_scene = enemies[randi() % enemies.size()]
	var enemy = enemy_scene.instantiate()
	enemy.player = player
	# Set spawn position along screen edges, just outside
	var margin = 20.0
	var edge = randi() % 4
	var pos = Vector2.ZERO
	if edge == 0:  # top
		pos.x = randf_range(0, screen_size.x)
		pos.y = -margin
	elif edge == 1:  # bottom
		pos.x = randf_range(0, screen_size.x)
		pos.y = screen_size.y + margin
	elif edge == 2:  # left
		pos.x = -margin
		pos.y = randf_range(0, screen_size.y)
	else:  # right
		pos.x = screen_size.x + margin
		pos.y = randf_range(0, screen_size.y)
	enemy.global_position = pos
	add_child(enemy)
	live_enemies.append(enemy)


func _maybe_attach_ai_trace_logger() -> void:
	var trace_config := _get_ai_trace_config()
	if not bool(trace_config.get("enabled", false)):
		return
	print("[AI_TRACE] enabling logger frames=", trace_config.get("frames"), " extra_enemies=", trace_config.get("extra_enemies"))
	var trace_logger = AI_TRACE_LOGGER.new()
	trace_logger.max_frames = int(trace_config.get("frames", 180))
	trace_logger.sample_every_frames = int(trace_config.get("sample_every", 1))
	trace_logger.spawn_extra_enemies = int(trace_config.get("extra_enemies", 4))
	trace_logger.fail_on_multiple_attackers = bool(trace_config.get("fail_on_multi", true))
	add_child(trace_logger)
	print("[AI_TRACE] logger attached")


func _get_ai_trace_config() -> Dictionary:
	var cfg := {
		"enabled": false,
		"frames": 180,
		"sample_every": 1,
		"extra_enemies": 4,
		"fail_on_multi": true,
	}
	for arg in OS.get_cmdline_user_args():
		if arg == "--ai-trace":
			cfg["enabled"] = true
		elif arg.begins_with("--ai-trace-frames="):
			cfg["enabled"] = true
			cfg["frames"] = max(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--ai-trace-sample-every="):
			cfg["enabled"] = true
			cfg["sample_every"] = max(1, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--ai-trace-extra-enemies="):
			cfg["enabled"] = true
			cfg["extra_enemies"] = max(0, int(arg.get_slice("=", 1)))
		elif arg.begins_with("--ai-trace-fail-on-multi-attackers="):
			cfg["enabled"] = true
			cfg["fail_on_multi"] = arg.get_slice("=", 1) != "0"
	return cfg
