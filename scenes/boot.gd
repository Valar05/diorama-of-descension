extends Node2D

@export var attack_intensity := 1.0
@export var is_dash_slash := false
@export var is_launcher := false
@export var knockback_mult := 1.5
@export var knockback_dir: Vector2 = Vector2.RIGHT
@export var parry_damage: float = 0.0
@export var parry_intensity: float = 1.0
@export var exclude_group = "player"
var damage: float = 10.0
var active = false
var hit_targets := []
@onready var hitbox = $Boot/Area2D

func toggle():
	active = not active

func _process(_delta):
	var parent_player = get_parent()
	if active:
		var hits = hitbox.get_overlapping_areas()
		for hit in hits:
			if hit.get_parent().has_method("take_damage") and not hit.get_parent() in hit_targets:
				# trigger hit-slow centrally from the slash so it always runs before the target might die
				# Prefer an autoload singleton at /root/HitSlow; fall back to creating one
				var hs = null
				if has_node("/root/HitSlow"):
					hs = get_node("/root/HitSlow")
				# If this is a dash slash and the target is parryable, apply parry damage/slow
				var target = hit.get_parent()
				if target.is_in_group(exclude_group):
					continue
				var applied = false
				if is_dash_slash and target and target.has_method("is_parryable") == false:
					# some enemy nodes may expose `is_parryable` as a variable rather than a method
					# fall back to checking property existence
					pass
				var target_parryable := false
				if target and ("is_parryable" in target):
					target_parryable = bool(target.is_parryable)
				if is_dash_slash and target_parryable:
					if hs:
						hs.start(0.10, 0.2, parry_intensity)
					var parry_dir = knockback_dir
					if parry_dir.length() < 0.001:
						parry_dir = Vector2.RIGHT
					if parent_player and parent_player.has_method("on_parry_success"):
						var parry_travel_distance: float = 0.0
						if parent_player.has_method("get_parry_bounce_distance"):
							parry_travel_distance = float(parent_player.call("get_parry_bounce_distance"))
						parent_player.call("on_parry_success", parry_dir, parry_intensity, parry_travel_distance)
					if target.has_method("take_damage"):
						target.take_damage(parry_damage, parry_dir, self, is_launcher)
					applied = true
				if not applied:
					if hs:
						hs.start(0.15, 0.2, attack_intensity)
					if target and target.has_method("take_damage"):
						var dir2 = knockback_dir
						if dir2.length() < 0.001:
							dir2 = Vector2.RIGHT
						target.take_damage(damage, dir2, self, is_launcher, knockback_mult)
				hit_targets.append(target)


func _on_animation_player_animation_finished(_anim_name: StringName) -> void:
	queue_free()
