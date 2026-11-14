class_name SaveDirectoryHandler
extends Node

const SAVE_DIR: String = "user://GameSaveData"
const MAX_SAVE_FILES: int = 200

func ensure_directory_exists() -> void:
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		DirAccess.make_dir_recursive_absolute(SAVE_DIR)

func manage_saves() -> void:
	ensure_directory_exists()
	var files: Array[Dictionary] = get_save_files()

	while files.size() >= MAX_SAVE_FILES:
		var oldest: Dictionary = files[files.size() - 1]
		var path_to_remove: String = oldest["path"]
		DirAccess.remove_absolute(path_to_remove)
		files.remove_at(files.size() - 1)

func get_save_files() -> Array[Dictionary]:
	ensure_directory_exists()
	var file_list: Array[Dictionary] = []
	var dir: DirAccess = DirAccess.open(SAVE_DIR)

	if dir != null:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()

		while not file_name.is_empty():
			if not dir.current_is_dir() and file_name.ends_with(".sav"):
				var full_path: String = SAVE_DIR + "/" + file_name
				var modified_time: int = FileAccess.get_modified_time(full_path)

				var file_info: Dictionary = {
					"name": file_name,
					"path": full_path,
					"time": modified_time
				}
				file_list.append(file_info)
			file_name = dir.get_next()
		dir.list_dir_end()

	file_list.sort_custom(func(a, b): return a["time"] > b["time"])
	return file_list

func get_latest_save_file() -> String:
	var files: Array[Dictionary] = get_save_files()
	if files.size() > 0:
		return files[0]["name"]
	return ""

func get_save_path(file_name: String) -> String:
	if not file_name.ends_with(".sav"):
		file_name += ".sav"
	return SAVE_DIR + "/" + file_name

func get_temp_path(file_name: String) -> String:
	if not file_name.ends_with(".tmp"):
		file_name += ".tmp"
	return SAVE_DIR + "/" + file_name
