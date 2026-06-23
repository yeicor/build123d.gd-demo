extends Node3D

@export var clone_scene: PackedScene
@export var count_per_tick: int = 10

func _on_spawn_timer_timeout() -> void:
	for i in range(count_per_tick):
		var scene: Node3D = clone_scene.instantiate()
		scene.translate(Vector3((randf() - 0.5) * 1.0, 0.0, (randf() - 0.5) * 0.6))
		add_child(scene)
