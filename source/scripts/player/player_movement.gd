class_name PlayerMovement
extends CharacterBody3D

signal stamina_changed(current, max_value)
signal on_jump
signal on_land

@export_group("Movement Settings")
@export var walk_speed: float = 4.0
@export var sprint_speed: float = 7.0
@export var crouch_speed: float = 2.0
@export var jump_force: float = 5.0

@export_group("Physics Settings")
@export var gravity: float = 19.62
@export var acceleration: float = 10.0
@export var deceleration: float = 12.0
@export var air_control: float = 2.0
@export var coyote_time: float = 0.15
@export var jump_buffer_time: float = 0.15

@export_group("Crouch Settings")
@export var normal_height: float = 1.8
@export var crouch_height: float = 0.9
@export var crouch_transition_speed: float = 10.0

@export_group("Stamina Settings")
@export var max_stamina: float = 5.0
@export var drain_rate: float = 1.0
@export var regen_rate: float = 1.0

@export_group("References")
@export var body_collider: CollisionShape3D
@export var head_node: Node3D
@export var ceiling_check: ShapeCast3D

var _current_stamina: float
var _is_exhausted: bool = false
var _is_crouching: bool = false
var _skip_next_crouch_release: bool = false
var _original_capsule_height: float
var _original_head_y: float

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _was_moving_last_frame: bool = false
var _was_grounded: bool = true
var _last_stamina: float = 0.0

func _ready() -> void:
	add_to_group("saveable")
	
	_current_stamina = max_stamina
	_last_stamina = _current_stamina
	
	floor_snap_length = 0.2
	floor_max_angle = deg_to_rad(45.0)

	if body_collider.shape is CapsuleShape3D:
		var new_capsule = body_collider.shape.duplicate() as CapsuleShape3D
		new_capsule.height = normal_height
		body_collider.shape = new_capsule
		_original_capsule_height = normal_height
		body_collider.position = Vector3(0.0, normal_height * 0.5, 0.0)

	if head_node != null:
		_original_head_y = normal_height * 0.85
		head_node.position = Vector3(0.0, _original_head_y, 0.0)

func _physics_process(delta: float) -> void:
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_backward", "move_forward")
	var sprint_held: bool = Input.is_action_pressed("sprint")
	var crouch_held: bool = Input.is_action_pressed("crouch")

	var is_grounded: bool = is_on_floor()

	if is_grounded and not _was_grounded:
		emit_signal("on_land")
		
	_was_grounded = is_grounded

	_update_jump_timers(delta)
	_apply_gravity(delta)
	
	var is_moving_input: bool = input_dir != Vector2.ZERO
	var needs_movement_update: bool = is_moving_input or not is_grounded or _was_moving_last_frame

	if needs_movement_update:
		_handle_movement(input_dir, sprint_held, delta)
	else:
		if abs(velocity.x) > 0.01 or abs(velocity.z) > 0.01:
			velocity.x = move_toward(velocity.x, 0, deceleration * delta)
			velocity.z = move_toward(velocity.z, 0, deceleration * delta)

	_handle_jump()
	_handle_crouch(crouch_held, delta)
	_handle_stamina(sprint_held, input_dir, delta)
	
	move_and_slide()
	
	_was_moving_last_frame = is_moving_input

func _update_jump_timers(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer -= delta

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	elif _jump_buffer_timer > 0:
		_jump_buffer_timer -= delta

func _apply_gravity(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= gravity * delta

func _handle_movement(input_dir: Vector2, sprint_held: bool, delta: float) -> void:
	var move_dir: Vector3 = (global_transform.basis * Vector3(input_dir.x, 0.0, -input_dir.y)).normalized()

	var is_moving_forward: bool = input_dir.y > 0.1
	var can_sprint: bool = sprint_held and not _is_exhausted and not _is_crouching and is_moving_forward

	var target_speed: float = walk_speed

	if _is_crouching:
		target_speed = crouch_speed
	elif can_sprint:
		target_speed = sprint_speed

	var accel_rate: float = air_control
	if is_on_floor():
		accel_rate = acceleration if move_dir != Vector3.ZERO else deceleration

	var target_velocity: Vector3 = move_dir * target_speed
	velocity.x = lerp(velocity.x, target_velocity.x, accel_rate * delta)
	velocity.z = lerp(velocity.z, target_velocity.z, accel_rate * delta)

func _handle_jump() -> void:
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0 and not _is_crouching:
		velocity.y = jump_force
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0
		emit_signal("on_jump")

func _handle_crouch(crouch_held: bool, delta: float) -> void:
	if _skip_next_crouch_release:
		_skip_next_crouch_release = false
		return

	if crouch_held:
		_is_crouching = true
	elif _is_crouching:
		if ceiling_check != null:
			ceiling_check.force_shapecast_update()
			_is_crouching = ceiling_check.is_colliding()
		else:
			_is_crouching = false

	_apply_crouch_smooth(delta)

func _apply_crouch_smooth(delta: float) -> void:
	var target_height: float = crouch_height if _is_crouching else _original_capsule_height

	if body_collider.shape is CapsuleShape3D:
		var capsule = body_collider.shape as CapsuleShape3D
		if abs(capsule.height - target_height) > 0.01:
			capsule.height = lerp(capsule.height, target_height, crouch_transition_speed * delta)
			body_collider.position = Vector3(0.0, capsule.height * 0.5, 0.0)

	if head_node != null:
		var target_head_y: float = (crouch_height * 0.85) if _is_crouching else _original_head_y
		if abs(head_node.position.y - target_head_y) > 0.01:
			var head_pos = head_node.position
			head_pos.y = lerp(head_pos.y, target_head_y, crouch_transition_speed * delta)
			head_node.position = head_pos

func _apply_crouch_instant() -> void:
	var target_height: float = crouch_height if _is_crouching else _original_capsule_height

	if body_collider.shape is CapsuleShape3D:
		var capsule = body_collider.shape as CapsuleShape3D
		capsule.height = target_height
		body_collider.position = Vector3(0.0, target_height * 0.5, 0.0)

	if head_node != null:
		var target_head_y: float = (crouch_height * 0.85) if _is_crouching else _original_head_y
		head_node.position = Vector3(0.0, target_head_y, 0.0)

func _handle_stamina(sprint_held: bool, input_dir: Vector2, delta: float) -> void:
	var is_moving_forward: bool = input_dir.y > 0.1
	var stamina_has_changed: bool = false

	if sprint_held and is_moving_forward and not _is_crouching and not _is_exhausted:
		_current_stamina -= drain_rate * delta

		if _current_stamina <= 0.0:
			_current_stamina = 0.0
			_is_exhausted = true
		stamina_has_changed = true
	elif not sprint_held and _current_stamina < max_stamina:
		_current_stamina += regen_rate * delta

		if _current_stamina >= max_stamina:
			_current_stamina = max_stamina
			_is_exhausted = false
		stamina_has_changed = true

	if stamina_has_changed and not is_equal_approx(_current_stamina, _last_stamina):
		emit_signal("stamina_changed", _current_stamina, max_stamina)
		_last_stamina = _current_stamina

func get_save_id() -> String:
	return "PlayerMovement_ID"

func capture_state() -> Dictionary:
	return {
		"pos_x": global_position.x,
		"pos_y": global_position.y,
		"pos_z": global_position.z,
		"vel_x": velocity.x,
		"vel_y": velocity.y,
		"vel_z": velocity.z,
		"is_crouching": _is_crouching,
		"current_stamina": _current_stamina,
		"is_exhausted": _is_exhausted
	}

func restore_state(state: Dictionary) -> void:
	if state.has("pos_x") and state.has("pos_y") and state.has("pos_z"):
		global_position = Vector3(
			state["pos_x"],
			state["pos_y"],
			state["pos_z"]
		)

	if state.has("vel_x") and state.has("vel_y") and state.has("vel_z"):
		velocity = Vector3(
			state["vel_x"],
			state["vel_y"],
			state["vel_z"]
		)

	if state.has("is_crouching"):
		_is_crouching = state["is_crouching"]
		_apply_crouch_instant()
		_skip_next_crouch_release = true

	if state.has("current_stamina"):
		_current_stamina = state["current_stamina"]
		_last_stamina = _current_stamina

	if state.has("is_exhausted"):
		_is_exhausted = state["is_exhausted"]

func on_restore_complete() -> void:
	if ceiling_check != null:
		ceiling_check.force_shapecast_update()
