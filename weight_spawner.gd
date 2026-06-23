extends Node3D

@export var clone_scene: PackedScene

func _on_spawn_timer_timeout() -> void:
	var scene: Node3D = clone_scene.instantiate()
	scene.translate(Vector3(randf() - 0.5, 0.0, randf() - 0.5) * 0.8)
	add_child(scene)
