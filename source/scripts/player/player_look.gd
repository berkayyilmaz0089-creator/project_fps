class_name PlayerLook
extends Node3D

enum LookMode
{
	MOUSE,
	ACTION
}

@export_group("Look Settings")
@export var current_look_mode: LookMode = LookMode.MOUSE
@export_range(0.01, 10.0) var sensitivity: float = 2.0
@export var min_pitch: float = -85.0
@export var max_pitch: float = 85.0

@export_group("References")
@export var player_body: Node3D
@export var head_node: Node3D

var _pitch: float = 0.0

func _ready() -> void:
	if current_look_mode == LookMode.MOUSE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _unhandled_input(event: InputEvent) -> void:
	if current_look_mode == LookMode.MOUSE and event is InputEventMouseMotion:
		var look_delta: Vector2 = event.relative * 0.1
		_apply_look(look_delta)

func _process(_delta: float) -> void:
	if current_look_mode == LookMode.ACTION:
		var look_delta: Vector2 = Input.get_vector("look_left", "look_right", "look_up", "look_down") * 0.25
		_apply_look(look_delta)

func _apply_look(look_delta: Vector2) -> void:
	if look_delta.x == 0.0 and look_delta.y == 0.0:
		return

	if look_delta.x != 0.0:
		var body_rot = player_body.rotation
		body_rot.y -= deg_to_rad(look_delta.x * sensitivity)
		player_body.rotation = body_rot

	if look_delta.y != 0.0:
		_pitch -= look_delta.y * sensitivity

		if _pitch > max_pitch:
			_pitch = max_pitch
		elif _pitch < min_pitch:
			_pitch = min_pitch

		var cam_rot = head_node.rotation
		cam_rot.x = deg_to_rad(_pitch)
		head_node.rotation = cam_rot

func get_save_id() -> String:
	return "PlayerLook_ID"

func capture_state() -> Dictionary:
	var body_rot_y: float = 0.0
	
	if player_body != null:
		body_rot_y = wrapf(player_body.rotation.y, -PI, PI)

	return {
		"pitch": _pitch,
		"body_rotation_y": body_rot_y
	}

func restore_state(state: Dictionary) -> void:
	if state.has("pitch"):
		_pitch = state["pitch"]
		rotation = Vector3(deg_to_rad(_pitch), 0, 0)

	if state.has("body_rotation_y") and player_body != null:
		var body_rot = player_body.rotation
		body_rot.y = state["body_rotation_y"]
		player_body.rotation = body_rot

func on_restore_complete() -> void:
	pass
