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

	var scene_manager = get_tree().get_first_node_in_group("scene_manager")
	
	if scene_manager != null and not scene_manager._is_transitioning:
		scene_manager.load_scene_async(target_scene_path, target_point_id, global_position, transition_volume, body)
