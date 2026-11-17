extends Node

signal scene_transition_started
signal scene_transition_completed

var _scene_pool: Dictionary = {}
var _is_transitioning: bool = false
var _save_animations: SaveAnimations
var _persistent_container: Node = null

var _data_registry: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("scene_manager")
	
	_save_animations = SaveAnimations.new()
	add_child(_save_animations)
	
	_persistent_container = Node.new()
	_persistent_container.name = "PersistentContainer"
	_persistent_container.process_mode = Node.PROCESS_MODE_DISABLED
	add_child(_persistent_container)
	
	var current_scene = get_tree().current_scene
	if current_scene != null and not current_scene.scene_file_path.is_empty():
		_scene_pool[current_scene.scene_file_path] = current_scene

func load_scene_async(target_scene_path: String, target_point_id: String, source_position: Vector3, transition_volume: Area3D, player_body: Node3D) -> void:
	if _is_transitioning:
		return
	
	_is_transitioning = true
	emit_signal("scene_transition_started")

	_save_animations.cache_ui_references()
	_save_animations.show_loading_ui(true)
	await get_tree().process_frame

	get_tree().paused = true
	await _save_animations.take_freeze_layer()
	await get_tree().process_frame

	var old_scene = get_tree().current_scene
	var moved_objects_data: Array[Dictionary] = []

	if old_scene != null:
		_capture_and_store_scene_data(old_scene)
		
		if transition_volume != null:
			var bodies = await transition_volume.get_saveable_bodies()
			for body in bodies:
				var offset_pos: Vector3 = body.global_position - source_position
				moved_objects_data.append({
					"node": body,
					"offset": offset_pos
				})
				
				if body.get_parent() != null:
					body.get_parent().remove_child(body)
					_persistent_container.add_child(body)

		_put_scene_to_sleep(old_scene)

	var new_scene = await _get_or_load_scene(target_scene_path)
	
	if new_scene == null:
		push_error("[SceneManager] Failed to load new scene!")
		get_tree().paused = false
		_is_transitioning = false
		return

	_wake_up_scene(new_scene)
	get_tree().root.add_child(new_scene)
	get_tree().current_scene = new_scene

	await get_tree().process_frame
	await get_tree().physics_frame
	await RenderingServer.frame_pre_draw

	_apply_registry_data(new_scene)

	var target_point: Node3D = null
	for child in new_scene.find_children("*", "", true, false):
		if child.is_in_group("transition_points") and child.get("point_id") == target_point_id:
			target_point = child
			break

	if target_point != null:
		for data in moved_objects_data:
			var node = data["node"]
			var offset = data["offset"]
			
			var moved_id = ""
			if node.has_method("get_save_id"):
				moved_id = node.get_save_id()
				
			if not moved_id.is_empty():
				for child in new_scene.find_children("*", "", true, false):
					if child.is_in_group("saveable") and child.has_method("get_save_id"):
						if child.get_save_id() == moved_id:
							child.name = "DeletedDuplicate_" + str(Time.get_ticks_msec())
							child.get_parent().remove_child(child)
							child.queue_free()
			
			_persistent_container.remove_child(node)
			new_scene.add_child(node)
			
			node.global_position = target_point.global_position + offset
			
			if node == player_body and node is CharacterBody3D:
				node.velocity = Vector3.ZERO

			if node.has_method("on_restore_complete"):
				node.on_restore_complete()

	get_tree().paused = false

	await get_tree().create_timer(0.1, true).timeout
	_save_animations.show_loading_ui(false)
	_save_animations.delete_freeze_layer()

	_is_transitioning = false
	emit_signal("scene_transition_completed")

func load_scene_for_save(target_scene_path: String, saved_nodes_dict: Dictionary) -> void:
	if _is_transitioning:
		return
	_is_transitioning = true
	
	_clear_all_scenes()
	
	for id in saved_nodes_dict:
		_data_registry[id] = saved_nodes_dict[id]
	
	var new_scene = await _get_or_load_scene(target_scene_path)
	
	if new_scene != null:
		_wake_up_scene(new_scene)
		get_tree().root.add_child(new_scene)
		get_tree().current_scene = new_scene
		
		await get_tree().process_frame
		await get_tree().physics_frame
		await RenderingServer.frame_pre_draw
		
		_apply_registry_data(new_scene)
		
	_is_transitioning = false

func _capture_and_store_scene_data(scene: Node) -> void:
	var saveables = scene.find_children("*", "", true, false)
	for node in saveables:
		if node.is_in_group("saveable") and node.has_method("capture_state") and node.has_method("get_save_id"):
			var id = node.get_save_id()
			if not id.is_empty():
				_data_registry[id] = node.capture_state()

func _apply_registry_data(scene: Node) -> void:
	var saveables = scene.find_children("*", "", true, false)
	for node in saveables:
		if node.is_in_group("saveable") and node.has_method("restore_state") and node.has_method("get_save_id"):
			var id = node.get_save_id()
			if _data_registry.has(id):
				node.restore_state(_data_registry[id])
				if node.has_method("on_restore_complete"):
					node.on_restore_complete()

func get_registry_data() -> Dictionary:
	_capture_and_store_scene_data(get_tree().current_scene)
	return _data_registry.duplicate(true)

func _clear_all_scenes() -> void:
	if get_tree().current_scene != null:
		get_tree().current_scene.queue_free()
		get_tree().current_scene = null
		
	for path in _scene_pool:
		var scene = _scene_pool[path]
		if is_instance_valid(scene):
			scene.queue_free()
			
	_scene_pool.clear()
	
	for child in _persistent_container.get_children():
		child.queue_free()

func _put_scene_to_sleep(scene: Node) -> void:
	scene.process_mode = Node.PROCESS_MODE_DISABLED
	scene.visible = false
	_disable_all_physics_and_audio(scene)
	get_tree().root.remove_child(scene)
	_scene_pool[scene.scene_file_path] = scene

func _wake_up_scene(scene: Node) -> void:
	scene.process_mode = Node.PROCESS_MODE_INHERIT
	scene.visible = true
	_enable_all_physics_and_audio(scene)

func _disable_all_physics_and_audio(node: Node) -> void:
	if node is CollisionObject3D:
		if not node.has_meta("orig_layer"):
			node.set_meta("orig_layer", node.collision_layer)
			node.set_meta("orig_mask", node.collision_mask)
		node.set_deferred("collision_layer", 0)
		node.set_deferred("collision_mask", 0)
	elif node is AudioStreamPlayer3D or node is AudioStreamPlayer:
		node.stop()
	elif node is AnimationPlayer:
		node.pause()
		
	for child in node.get_children():
		_disable_all_physics_and_audio(child)

func _enable_all_physics_and_audio(node: Node) -> void:
	if node is CollisionObject3D:
		if node.has_meta("orig_layer"):
			node.set_deferred("collision_layer", node.get_meta("orig_layer"))
			node.set_deferred("collision_mask", node.get_meta("orig_mask"))
	elif node is AnimationPlayer:
		node.play()
		
	for child in node.get_children():
		_enable_all_physics_and_audio(child)

func _get_or_load_scene(target_scene_path: String) -> Node:
	if _scene_pool.has(target_scene_path):
		return _scene_pool[target_scene_path]

	ResourceLoader.load_threaded_request(target_scene_path)

	var status: int = ResourceLoader.load_threaded_get_status(target_scene_path)
	while status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		await get_tree().process_frame
		status = ResourceLoader.load_threaded_get_status(target_scene_path)

	if status != ResourceLoader.THREAD_LOAD_LOADED:
		return null

	var packed: PackedScene = ResourceLoader.load_threaded_get(target_scene_path)
	var instance: Node = packed.instantiate()
	_scene_pool[target_scene_path] = instance
	return instance

func get_active_scene_path() -> String:
	if get_tree().current_scene != null:
		return get_tree().current_scene.scene_file_path
	return ""
