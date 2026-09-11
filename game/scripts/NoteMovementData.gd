class_name NoteMovementData
extends RefCounted

# Movement model for beatmap objects: how notes, bombs, chains, arcs and walls
# travel toward the player and arrive on their beat.
#
# Coordinate conventions (Godot): the player faces -Z, +X is the player's right.
# Objects travel from far away (-Z) toward the player and pass the "beat
# position" exactly at their beat time.

# --- global constants ---
const NOTE_LINES_DISTANCE := 0.6
const NOTE_LINES_COUNT := 4
const BASE_LINES_Y := 0.25
const HIGHEST_JUMP_Y := [0.85, 1.4, 1.9] # base / upper / top line layers
const OBSTACLE_VERTICAL_OFFSET := -0.15
const OBSTACLE_MIN_Y := 0.1
const OBSTACLE_TOP_Y := 3.1
const CENTER_Z := 0.65 # distance in front of the head where the beat happens
const NOTE_Z_OFFSET := 0.25 # NoteMovement._zOffset
const MAX_HALF_JUMP_DISTANCE := 18.0
const START_HALF_JUMP_DURATION_IN_BEATS := 4.0
const MIN_HALF_JUMP_DURATION_IN_BEATS := 0.25
const MIN_NOTE_JUMP_MOVEMENT_SPEED := 0.01

# --- movement data ---
const MOVE_DURATION := 0.5
const MOVE_DISTANCE := 100.0

# --- jump phase ---
const MISSED_TIME_OFFSET := 0.15
const Y_AVOIDANCE_UP := 0.45
const Y_AVOIDANCE_DOWN := 0.15
const END_DISTANCE_OFFSET := 500.0
const FULL_SCALE_JUMP_PART := 0.125 # fraction of the jump spent growing to full size
const RANDOM_ROTATION_DEGREES := 20.0
const RANDOM_ROTATIONS: Array[Vector3] = [
	Vector3(-0.9543871, -0.1183784, 0.2741019),
	Vector3(0.7680854, -0.08805521, 0.6342642),
	Vector3(-0.6780157, 0.306681, -0.6680131),
	Vector3(0.1255014, 0.9398643, 0.3176546),
	Vector3(0.365105, -0.3664974, -0.8557909),
	Vector3(-0.8790653, -0.06244748, -0.4725934),
	Vector3(0.01886305, -0.8065798, 0.5908241),
	Vector3(-0.1455435, 0.8901445, 0.4318099),
	Vector3(0.07651193, 0.9474725, -0.3105508),
	Vector3(0.1306983, -0.2508438, -0.9591639),
]

# --- ObstacleMovement ---
const OBSTACLE_AVOID_MARK_TIME_OFFSET := 0.15

enum Phase { WAITING, MOVING, JUMPING, FINISHED }

# --- runtime state shared by every object on the track ---
static var song_time := 0.0
## Global Z of the player's head. Beat Saber keeps the track relative to the
## head's forward/backward position ("headPseudoLocalZOnlyPos").
static var head_z := 1.0
## Global position of the player's head (notes rotate to face it).
static var head_position := Vector3(0.0, 1.7, 1.0)
## Vertical offset applied to jump heights from the player height
## (PlayerHeightToJumpOffsetYProvider).
static var jump_offset_y := 0.0
static var bpm := 120.0
static var default_njs := 10.0
static var default_start_beat_offset := 0.0

static func setup(map_bpm: float, njs: float, start_beat_offset: float, player_height: float) -> void:
	bpm = maxf(map_bpm, 1.0)
	default_njs = maxf(njs, MIN_NOTE_JUMP_MOVEMENT_SPEED)
	default_start_beat_offset = start_beat_offset
	jump_offset_y = jump_offset_y_for_player_height(player_height)
	song_time = 0.0

static func jump_offset_y_for_player_height(player_height: float) -> float:
	return clampf((player_height - 1.8) * 0.5, -0.2, 0.6)

static func one_beat_duration() -> float:
	return 60.0 / bpm

## CoreMathUtils.CalculateHalfJumpDurationInBeats
static func half_jump_duration_in_beats(njs: float, start_beat_offset: float) -> float:
	var beats := START_HALF_JUMP_DURATION_IN_BEATS
	var distance_per_beat := maxf(njs, MIN_NOTE_JUMP_MOVEMENT_SPEED) * one_beat_duration()
	var half_jump_distance := distance_per_beat * beats
	var max_distance := MAX_HALF_JUMP_DISTANCE - 0.001
	while half_jump_distance > max_distance:
		beats *= 0.5
		half_jump_distance = distance_per_beat * beats
	beats += start_beat_offset
	return maxf(beats, MIN_HALF_JUMP_DURATION_IN_BEATS)

static func half_jump_duration(njs: float, start_beat_offset: float) -> float:
	return one_beat_duration() * half_jump_duration_in_beats(njs, start_beat_offset)

## Seconds before an object's beat at which it spawns.
static func spawn_ahead_time(njs: float, start_beat_offset: float) -> float:
	return MOVE_DURATION + half_jump_duration(njs, start_beat_offset)

static func line_x(line_index: float) -> float:
	return (-(NOTE_LINES_COUNT - 1) * 0.5 + line_index) * NOTE_LINES_DISTANCE

static func line_y(line_layer: float) -> float:
	return BASE_LINES_Y + NOTE_LINES_DISTANCE * line_layer

static func highest_jump_y(line_layer: int) -> float:
	return HIGHEST_JUMP_Y[clampi(line_layer, 0, 2)]

## Z (global) where notes are at their beat time.
static func note_beat_z() -> float:
	return head_z - CENTER_Z - NOTE_Z_OFFSET

## Z (global) where the front face of an obstacle is at its beat time.
static func obstacle_beat_z() -> float:
	return head_z - CENTER_Z

static func ease_in_out_quad(t: float) -> float:
	if t < 0.5:
		return 2.0 * t * t
	return -1.0 + (4.0 - 2.0 * t) * t

static func ease_out_quad(t: float) -> float:
	return -t * (t - 2.0)

## Notes grow from nothing during the first 12.5% of the jump.
static func jump_scale(progress: float) -> float:
	if progress >= FULL_SCALE_JUMP_PART:
		return 1.0
	return ease_out_quad(clampf(progress / FULL_SCALE_JUMP_PART, 0.0, 1.0))

## Deterministic random rotation offset in degrees.
static func random_rotation_offset(note_time: float, end_x: float, end_y: float) -> Vector3:
	var index := absi(roundi(note_time * 10.0 + end_x * 2.0 + end_y * 2.0) % RANDOM_ROTATIONS.size())
	return RANDOM_ROTATIONS[index] * RANDOM_ROTATION_DEGREES


## Per-object movement state (floor movement + jump), evaluated purely
## from the song time so it never drifts from the audio.
class Jump extends RefCounted:
	var note_time := 0.0
	var njs := 10.0
	var half_jump_duration := 1.0
	var jump_duration := 2.0
	var half_jump_distance := 10.0
	var z_offset := NoteMovementData.NOTE_Z_OFFSET
	var start_xy := Vector2.ZERO # x / lineY at the end of the floor movement
	var end_xy := Vector2.ZERO # x / lineY at the end of the jump
	var gravity_base := 0.0
	var gravity := 0.0
	var flip_y_side := 0.0
	var jump_start_time := 0.0
	var move_start_time := 0.0
	var missed_time := 0.0
	var finish_time := 0.0

	# outputs of update()
	var local_position := Vector3.ZERO
	var progress := 0.0
	var phase := NoteMovementData.Phase.WAITING

	func setup(
		p_note_time: float,
		p_njs: float,
		start_beat_offset: float,
		p_start_xy: Vector2,
		p_end_xy: Vector2,
		highest_y: float,
		before_jump_line_y: float,
		p_flip_y_side: float = 0.0,
		p_z_offset: float = NoteMovementData.NOTE_Z_OFFSET
	) -> void:
		note_time = p_note_time
		njs = maxf(p_njs, NoteMovementData.MIN_NOTE_JUMP_MOVEMENT_SPEED)
		half_jump_duration = NoteMovementData.half_jump_duration(njs, start_beat_offset)
		jump_duration = half_jump_duration * 2.0
		half_jump_distance = njs * half_jump_duration
		z_offset = p_z_offset
		start_xy = p_start_xy
		end_xy = p_end_xy
		gravity_base = highest_y + NoteMovementData.jump_offset_y - before_jump_line_y
		gravity = 2.0 * gravity_base / (half_jump_duration * half_jump_duration)
		flip_y_side = p_flip_y_side
		jump_start_time = note_time - half_jump_duration
		move_start_time = jump_start_time - NoteMovementData.MOVE_DURATION
		missed_time = note_time + NoteMovementData.MISSED_TIME_OFFSET
		finish_time = note_time + half_jump_duration
		update(NoteMovementData.song_time)

	func spawn_time() -> float:
		return move_start_time

	## Z of the beat position for this object.
	func beat_z() -> float:
		return NoteMovementData.head_z - NoteMovementData.CENTER_Z - z_offset

	func move_end_z() -> float:
		return beat_z() - half_jump_distance

	func jump_end_z() -> float:
		return beat_z() + half_jump_distance

	## Signed distance the object still has to travel before reaching the beat
	## position (positive = still in front of the player).
	func distance_to_beat(time: float) -> float:
		return (note_time - time) * njs

	func update(time: float) -> void:
		if time < move_start_time:
			phase = NoteMovementData.Phase.WAITING
			progress = 0.0
			local_position = Vector3(start_xy.x, -1000.0, move_end_z() - NoteMovementData.MOVE_DISTANCE)
			return
		if time < jump_start_time:
			phase = NoteMovementData.Phase.MOVING
			progress = 0.0
			var t := (time - move_start_time) / NoteMovementData.MOVE_DURATION
			var end_z := move_end_z()
			local_position = Vector3(
				start_xy.x,
				start_xy.y,
				lerpf(end_z - NoteMovementData.MOVE_DISTANCE, end_z, t)
			)
			return
		var t := time - jump_start_time
		progress = t / jump_duration
		phase = NoteMovementData.Phase.FINISHED if progress >= 1.0 else NoteMovementData.Phase.JUMPING
		var x := end_xy.x
		if not is_equal_approx(start_xy.x, end_xy.x) and progress < 0.25:
			x = start_xy.x + (end_xy.x - start_xy.x) * NoteMovementData.ease_in_out_quad(progress * 4.0)
		var z := lerpf(move_end_z(), jump_end_z(), progress)
		var y := start_xy.y + gravity * half_jump_duration * t - gravity * t * t * 0.5
		if flip_y_side != 0.0 and progress < 0.25:
			var avoidance := flip_y_side * (NoteMovementData.Y_AVOIDANCE_UP if flip_y_side > 0.0 else NoteMovementData.Y_AVOIDANCE_DOWN)
			y += (0.5 - cos(progress * 8.0 * PI) * 0.5) * avoidance
		if progress >= 0.75:
			var tail := (progress - 0.75) / 0.25
			z += NoteMovementData.END_DISTANCE_OFFSET * tail * tail * tail
		local_position = Vector3(x, y, z)


## Obstacle movement (ObstacleMovement): floor movement, then a linear pass.
class ObstacleMovement extends RefCounted:
	var obstacle_time := 0.0
	var duration := 0.0
	var njs := 10.0
	var half_jump_duration := 1.0
	var jump_duration := 2.0
	var half_jump_distance := 10.0
	var offset_xy := Vector2.ZERO
	var move_start_time := 0.0
	var jump_start_time := 0.0
	var avoided_time := 0.0
	var finish_time := 0.0
	var length := 1.0

	var local_position := Vector3.ZERO
	var phase := NoteMovementData.Phase.WAITING

	func setup(p_time: float, p_duration: float, p_njs: float, start_beat_offset: float, p_offset_xy: Vector2) -> void:
		obstacle_time = p_time
		duration = maxf(p_duration, 0.0)
		njs = maxf(p_njs, NoteMovementData.MIN_NOTE_JUMP_MOVEMENT_SPEED)
		half_jump_duration = NoteMovementData.half_jump_duration(njs, start_beat_offset)
		jump_duration = half_jump_duration * 2.0
		half_jump_distance = njs * half_jump_duration
		offset_xy = p_offset_xy
		length = njs * duration
		jump_start_time = obstacle_time - half_jump_duration
		move_start_time = jump_start_time - NoteMovementData.MOVE_DURATION
		avoided_time = obstacle_time + duration + NoteMovementData.OBSTACLE_AVOID_MARK_TIME_OFFSET
		finish_time = obstacle_time + half_jump_duration + duration
		update(NoteMovementData.song_time)

	func spawn_time() -> float:
		return move_start_time

	func beat_z() -> float:
		return NoteMovementData.head_z - NoteMovementData.CENTER_Z

	func update(time: float) -> void:
		var mid_z := beat_z() - half_jump_distance
		var end_z := beat_z() + half_jump_distance
		if time < move_start_time:
			phase = NoteMovementData.Phase.WAITING
			local_position = Vector3(offset_xy.x, -1000.0, mid_z - NoteMovementData.MOVE_DISTANCE)
			return
		if time < jump_start_time:
			phase = NoteMovementData.Phase.MOVING
			var t := (time - move_start_time) / NoteMovementData.MOVE_DURATION
			local_position = Vector3(offset_xy.x, offset_xy.y, lerpf(mid_z - NoteMovementData.MOVE_DISTANCE, mid_z, t))
			return
		var t := (time - jump_start_time) / jump_duration
		var z := lerpf(mid_z, end_z, t)
		if time > avoided_time:
			var tail := (time - avoided_time) / maxf(finish_time - avoided_time, 0.001)
			z += NoteMovementData.END_DISTANCE_OFFSET * tail * tail * tail
		phase = NoteMovementData.Phase.FINISHED if time > finish_time else NoteMovementData.Phase.JUMPING
		local_position = Vector3(offset_xy.x, offset_xy.y, z)
