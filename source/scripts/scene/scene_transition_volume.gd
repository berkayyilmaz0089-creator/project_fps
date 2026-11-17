class_name SceneTransitionVolume
extends Area3D

func _ready() -> void:
	add_to_group("scene_transition_volume")

func get_saveable_bodies() -> Array[Node]:
	await get_tree().physics_frame
	await get_tree().physics_frame

	var result: Array[Node] = []
	var bodies: Array[Node3D] = get_overlapping_bodies()

	for body in bodies:
		if body.is_in_group("saveable") and not result.has(body):
			result.append(body)

	return result
