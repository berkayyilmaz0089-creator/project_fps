extends Node

signal save_started
signal save_completed
signal load_started
signal load_completed

const SECRET_KEY: String = "project_fps_1234"
const SAVE_VERSION: int = 1

var _directory_handler: SaveDirectoryHandler
var _save_animations: SaveAnimations
var _is_busy: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_directory_handler = SaveDirectoryHandler.new()
	_save_animations = SaveAnimations.new()
	add_child(_save_animations)
	_directory_handler.ensure_directory_exists()

func _unhandled_input(event: InputEvent) -> void:
	if _is_busy:
		return
	if event.is_action_pressed("quick_save"):
		quick_save()
	elif event.is_action_pressed("quick_load"):
		quick_load()

func quick_save() -> void:
	if _is_busy:
		return
	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	await save_game("QuickSave_" + timestamp)

func quick_load() -> void:
	if _is_busy:
		return
	var latest: String = _directory_handler.get_latest_save_file()
	if not latest.is_empty():
		await load_game(latest)

func save_game(save_name: String) -> void:
	_is_busy = true
	emit_signal("save_started")
	
	_save_animations.cache_ui_references()
	await _save_animations.show_save_icon()
	_directory_handler.manage_saves()

	var file_path: String = _directory_handler.get_save_path(save_name)
	var temp_path: String = _directory_handler.get_temp_path(save_name)

	var scene_manager = get_tree().get_first_node_in_group("scene_manager")
	var master_data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"scene_path": "",
		"saved_nodes": {}
	}

	if scene_manager != null:
		master_data["scene_path"] = scene_manager.get_active_scene_path()
		master_data["saved_nodes"] = scene_manager.get_registry_data()

	var json_string: String = JSON.stringify(master_data)
	var file: FileAccess = FileAccess.open_encrypted_with_pass(temp_path, FileAccess.WRITE, SECRET_KEY)
	
	if file != null:
		file.store_string(json_string)
		file.close()

		if FileAccess.file_exists(file_path):
			DirAccess.remove_absolute(file_path)
			
		DirAccess.rename_absolute(temp_path, file_path)

	await get_tree().create_timer(0.1).timeout
	await _save_animations.hide_save_icon()
	_is_busy = false
	emit_signal("save_completed")

func load_game(file_name: String) -> void:
	_is_busy = true
	emit_signal("load_started")

	var file_path: String = _directory_handler.get_save_path(file_name)
	
	if not FileAccess.file_exists(file_path):
		_finish_loading()
		return

	_save_animations.show_loading_ui(true)
	await get_tree().process_frame
	get_tree().paused = true
	await _save_animations.take_freeze_layer()
	await get_tree().process_frame

	var file: FileAccess = FileAccess.open_encrypted_with_pass(file_path, FileAccess.READ, SECRET_KEY)
	
	if file == null:
		_finish_loading()
		return

	var json_string: String = file.get_as_text()
	var json: JSON = JSON.new()
	
	if json.parse(json_string) != OK:
		_finish_loading()
		return

	var master_data: Dictionary = json.data
	var scene_manager = get_tree().get_first_node_in_group("scene_manager")
	
	if scene_manager != null:
		var saved_scene_path = master_data.get("scene_path", "")
		var saved_nodes_dict = master_data.get("saved_nodes", {})
		
		if not saved_scene_path.is_empty():
			await scene_manager.load_scene_for_save(saved_scene_path, saved_nodes_dict)

	get_tree().paused = false
	await get_tree().create_timer(0.1, true).timeout
	_save_animations.show_loading_ui(false)
	_save_animations.delete_freeze_layer()
	_finish_loading()
	emit_signal("load_completed")

func _finish_loading() -> void:
	_is_busy = false
