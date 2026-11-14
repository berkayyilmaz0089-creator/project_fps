class_name PlayerAudio
extends Node

@export_group("Default Audio")
@export var default_walk_clip: AudioStream
@export var default_jump_clip: AudioStream
@export var default_land_clip: AudioStream

@export_group("Grouped Audio")
@export var grouped_audio_data: Array[Dictionary] = []

@export_group("Audio Settings")
@export var min_pitch: float = 0.85
@export var max_pitch: float = 1.15
@export_flags_3d_physics var ground_mask: int = 1

@export_group("Movement Intervals")
@export var walk_interval: float = 0.5
@export var sprint_interval: float = 0.35
@export var crouch_interval: float = 0.8

@export_group("References")
@export var player_body: CharacterBody3D
@export var player_movement: PlayerMovement
@export var audio_source: AudioStreamPlayer3D

var _step_timer: float = 0.0
var _was_on_floor: bool = true
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func _ready() -> void:
	if player_body == null:
		player_body = get_parent() as CharacterBody3D

	if player_movement == null and player_body != null:
		player_movement = player_body.get_node_or_null("PlayerMovement") as PlayerMovement

	if audio_source == null:
		audio_source = get_node_or_null("AudioStreamPlayer3D") as AudioStreamPlayer3D
		
	_rng.randomize()

func _process(delta: float) -> void:
	if player_body == null:
		return

	var is_on_floor: bool = player_body.is_on_floor()

	if _was_on_floor and not is_on_floor:
		if player_body.velocity.y > 0.1:
			_play_jump_audio()
	elif not _was_on_floor and is_on_floor:
		_play_land_audio()

	_was_on_floor = is_on_floor

	if not is_on_floor:
		_step_timer = 0.0
		return

	var velocity: Vector3 = player_body.velocity
	var current_speed_sqr: float = velocity.x * velocity.x + velocity.z * velocity.z

	if current_speed_sqr < 0.01:
		_step_timer = 0.0
		return

	_step_timer += delta
	var current_interval: float = _get_current_interval(sqrt(current_speed_sqr))

	if _step_timer >= current_interval:
		_play_walk_audio()
		_step_timer = 0.0

func _get_current_interval(current_speed: float) -> float:
	if player_movement != null:
		if current_speed <= player_movement.crouch_speed + 0.2:
			return crouch_interval
			
		if current_speed >= player_movement.sprint_speed - 0.5:
			return sprint_interval

	return walk_interval

func _get_surface_clips() -> Dictionary:
	var space_state = player_body.get_world_3d().direct_space_state
	
	var origin: Vector3 = player_body.global_position + Vector3.UP * 0.5
	var end: Vector3 = origin + Vector3.DOWN * 2.0

	var query = PhysicsRayQueryParameters3D.create(origin, end, ground_mask)
	var result = space_state.intersect_ray(query)

	if not result.is_empty():
		var hit_collider = result["collider"]

		if hit_collider != null:
			for data in grouped_audio_data:
				if data.has("group_name") and data.has("walk_clip"):
					var group_name: String = data["group_name"]
					
					if not group_name.is_empty() and hit_collider.is_in_group(group_name):
						var walk_clip = data.get("walk_clip", null)
						var jump_clip = data.get("jump_clip", null)
						var land_clip = data.get("land_clip", null)
						return {"walk": walk_clip, "jump": jump_clip, "land": land_clip}

	return {"walk": default_walk_clip, "jump": default_jump_clip, "land": default_land_clip}

func _play_walk_audio() -> void:
	var clips: Dictionary = _get_surface_clips()

	if clips["walk"] != null:
		_play_clip_with_pitch(clips["walk"])

func _play_jump_audio() -> void:
	var clips: Dictionary = _get_surface_clips()

	if clips["jump"] != null:
		_play_clip_with_pitch(clips["jump"])

func _play_land_audio() -> void:
	var clips: Dictionary = _get_surface_clips()

	if clips["land"] != null:
		_play_clip_with_pitch(clips["land"])

func _play_clip_with_pitch(clip: AudioStream) -> void:
	if audio_source == null:
		return

	audio_source.pitch_scale = _rng.randf_range(min_pitch, max_pitch)
	audio_source.stream = clip
	audio_source.play()
