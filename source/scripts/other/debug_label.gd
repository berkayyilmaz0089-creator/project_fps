extends Label

@export_group("Settings")
@export var update_interval: float = 0.25

var _is_visible: bool = false
var _update_timer: float = 0.0

var _fps: float = 0.0
var _average_fps: float = 0.0
var _frame_time_ms: float = 0.0

var _accumulated_frames: int = 0
var _accumulated_time: float = 0.0

func _ready() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("debug"):
		_is_visible = not _is_visible
		visible = _is_visible

func _process(delta: float) -> void:
	if not _is_visible:
		return

	if delta > 0.0:
		_fps = 1.0 / delta
		_frame_time_ms = delta * 1000.0

	_accumulated_frames += 1
	_accumulated_time += delta
	_update_timer += delta

	if _update_timer >= update_interval:
		if _accumulated_time > 0.0:
			_average_fps = _accumulated_frames / _accumulated_time

		_update_text()

		_update_timer = 0.0
		_accumulated_frames = 0
		_accumulated_time = 0.0

func _update_text() -> void:
	var ram_usage: float = Performance.get_monitor(Performance.MEMORY_STATIC) / (1024.0 * 1024.0)
	var object_count: int = Performance.get_monitor(Performance.OBJECT_COUNT)
	var node_count: int = Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
	var physics_time: float = Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
	var vram_usage: float = Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED) / (1024.0 * 1024.0)

	var stats: String = "FPS: %d (Avg: %d)\n" % [roundi(_fps), roundi(_average_fps)]
	stats += "Frame Time: %.2f ms\n" % _frame_time_ms
	stats += "Physics Time: %.2f ms\n" % physics_time
	stats += "Objects: %d\n" % object_count
	stats += "Nodes: %d\n" % node_count
	stats += "RAM (Static): %.2f MB\n" % ram_usage
	stats += "VRAM: %.2f MB" % vram_usage

	text = stats
