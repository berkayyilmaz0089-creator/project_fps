class_name SceneTransitionPoint
extends Marker3D

@export var point_id: String = "default"

func _ready() -> void:
	add_to_group("transition_points")
