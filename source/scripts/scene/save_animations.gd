class_name SaveAnimations
extends Node

var _freeze_layer: TextureRect
var _screen_texture: ImageTexture
var _cached_save_icon: CanvasItem
var _cached_loading_ui: CanvasItem

var _active_tween: Tween
var _ui_initialized: bool = false

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_initialize_ui()

func _initialize_ui() -> void:
	if _ui_initialized:
		return

	var canvas_layer: CanvasLayer = CanvasLayer.new()
	canvas_layer.layer = 100
	canvas_layer.process_mode = Node.PROCESS_MODE_ALWAYS
	
	get_tree().root.call_deferred("add_child", canvas_layer)

	_freeze_layer = TextureRect.new()
	_freeze_layer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_freeze_layer.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_freeze_layer.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_freeze_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	_freeze_layer.visible = false
	
	canvas_layer.call_deferred("add_child", _freeze_layer)
	_ui_initialized = true

func cache_ui_references() -> void:
	_cached_save_icon = get_tree().get_first_node_in_group("save_icon") as CanvasItem
	_cached_loading_ui = get_tree().get_first_node_in_group("loading_ui") as CanvasItem

func show_loading_ui(visible: bool) -> void:
	if not is_instance_valid(_cached_loading_ui):
		_cached_loading_ui = get_tree().get_first_node_in_group("loading_ui") as CanvasItem

	if is_instance_valid(_cached_loading_ui):
		_cached_loading_ui.visible = visible

func show_save_icon() -> void:
	if not is_instance_valid(_cached_save_icon):
		_cached_save_icon = get_tree().get_first_node_in_group("save_icon") as CanvasItem

	if not is_instance_valid(_cached_save_icon):
		return

	_cached_save_icon.visible = true
	
	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()
	
	_active_tween = create_tween()
	_active_tween.tween_property(_cached_save_icon, "modulate:a", 1.0, 0.3).from(0.0)
	await _active_tween.finished

func hide_save_icon() -> void:
	if not is_instance_valid(_cached_save_icon):
		_cached_save_icon = get_tree().get_first_node_in_group("save_icon") as CanvasItem

	if not is_instance_valid(_cached_save_icon):
		return

	if _active_tween != null and _active_tween.is_valid():
		_active_tween.kill()

	_active_tween = create_tween()
	_active_tween.tween_property(_cached_save_icon, "modulate:a", 0.0, 0.3)
	await _active_tween.finished

	if is_instance_valid(_cached_save_icon):
		_cached_save_icon.visible = false

func take_freeze_layer() -> void:
	await get_tree().process_frame
	await RenderingServer.frame_pre_draw
	
	var viewport: Viewport = get_tree().root
	var image: Image = viewport.get_texture().get_image()
	
	if image != null and _freeze_layer != null:
		_screen_texture = ImageTexture.create_from_image(image)
		_freeze_layer.texture = _screen_texture
		_freeze_layer.visible = true

func delete_freeze_layer() -> void:
	if _freeze_layer == null or not _freeze_layer.visible:
		return

	_freeze_layer.visible = false
	_freeze_layer.texture = null
	_screen_texture = null
