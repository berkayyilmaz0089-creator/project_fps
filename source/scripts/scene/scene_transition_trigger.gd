class_name SceneTransitionTrigger
extends Area3D

@export_file("*.scn", "*.tscn") var target_scene_path: String = ""
@export var target_point_id: String = "default"
@export var trigger_group: String = "player"
@export var transition_volume: Area3D = null

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node3D) -> void:
	if not body.is_in_group(trigger_group):
		return

	if target_scene_path.is_empty():
		return

	if SceneManager != null and not SceneManager._is_transitioning:
		SceneManager.load_scene_async(target_scene_path, target_point_id, global_position, transition_volume, body)
