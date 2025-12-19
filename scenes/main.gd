extends Node2D

@export var enemies: Array[PackedScene] = []
@export var max_enemies := 15
var live_enemies: Array = []

var spawn_timer: float = 0.0
var spawn_interval: float = 3.0
var screen_size: Vector2

@onready var player: CharacterBody2D = $Player

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	screen_size = get_viewport().get_visible_rect().size
	spawn_enemy()


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
