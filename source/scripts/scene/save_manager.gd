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

func manual_save(custom_name: String = "") -> void:
	if _is_busy:
		return

	var timestamp: String = Time.get_datetime_string_from_system().replace(":", "-").replace(" ", "_")
	var save_name: String = "ManualSave_" + timestamp
	if not custom_name.is_empty():
		save_name = custom_name
		
	await save_game(save_name)

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

	var master_data: Dictionary = {
		"version": SAVE_VERSION,
		"timestamp": Time.get_datetime_string_from_system(),
		"scene_path": get_tree().current_scene.scene_file_path,
		"saved_nodes": {}
	}

	var saved_nodes_dict: Dictionary = master_data["saved_nodes"]
	var saveables: Array[Node] = get_tree().current_scene.find_children("*", "", true, false)
	
	for node in saveables:
		if node.is_in_group("saveable"):
			if node.has_method("get_save_id") and node.has_method("capture_state"):
				var id: String = node.get_save_id()
				if not id.is_empty():
					saved_nodes_dict[id] = node.capture_state()

	var json_string: String = JSON.stringify(master_data)
	
	if json_string.is_empty():
		push_error("JSON serialization resulted in empty string.")
		_finish_save()
		return

	var file: FileAccess = FileAccess.open_encrypted_with_pass(temp_path, FileAccess.WRITE, SECRET_KEY)
	if file == null:
		push_error("Failed to open temporary file for writing encryption.")
		_finish_save()
		return

	file.store_string(json_string)
	file.close()

	if FileAccess.file_exists(file_path):
		DirAccess.remove_absolute(file_path)

	var rename_error: Error = DirAccess.rename_absolute(temp_path, file_path)
	if rename_error != OK:
		push_error("Failed to rename temporary file to target save path.")
		if FileAccess.file_exists(temp_path):
			DirAccess.remove_absolute(temp_path)

	await get_tree().create_timer(0.1).timeout
	await _save_animations.hide_save_icon()

	_is_busy = false
	emit_signal("save_completed")

func load_game(file_name: String) -> void:
	_is_busy = true
	emit_signal("load_started")

	var file_path: String = _directory_handler.get_save_path(file_name)

	if not FileAccess.file_exists(file_path):
		push_error("Load failed: File does not exist -> " + file_name)
		_finish_loading()
		return

	_save_animations.show_loading_ui(true)
	await get_tree().process_frame

	get_tree().paused = true
	await _save_animations.take_freeze_layer()
	await get_tree().process_frame

	var file: FileAccess = FileAccess.open_encrypted_with_pass(file_path, FileAccess.READ, SECRET_KEY)
	if file == null:
		push_error("Failed to open save file for decryption.")
		_finish_loading()
		return

	var json_string: String = file.get_as_text()
	var json: JSON = JSON.new()

	if json.parse(json_string) != OK:
		push_error("JSON parse error during load.")
		_finish_loading()
		return

	var master_data: Dictionary = json.data
	
	if master_data.has("saved_nodes"):
		var saved_nodes_dict: Dictionary = master_data["saved_nodes"]
		var saveables: Array[Node] = get_tree().current_scene.find_children("*", "", true, false)

		for node in saveables:
			if node.is_in_group("saveable"):
				if node.has_method("get_save_id") and node.has_method("restore_state"):
					var id: String = node.get_save_id()
					if saved_nodes_dict.has(id):
						var state: Dictionary = saved_nodes_dict[id]
						node.restore_state(state)
						if node.has_method("on_restore_complete"):
							node.on_restore_complete()

	get_tree().paused = false

	await get_tree().create_timer(0.1, true).timeout
	_save_animations.show_loading_ui(false)
	_save_animations.delete_freeze_layer()

	_finish_loading()
	emit_signal("load_completed")

func _finish_save() -> void:
	_is_busy = false

func _finish_loading() -> void:
	_is_busy = false
