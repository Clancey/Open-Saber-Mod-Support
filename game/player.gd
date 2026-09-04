extends XROrigin3D

const LOW_FPS_THRESHOLD: float = 5.0
const LOW_FPS_DURATION: float = 2.0
const SONG_START_GRACE_PERIOD: float = 3.0

@onready var beep_saber: BeepSaber_Game = $".."
@onready var song_player: AudioStreamPlayer = $"../SongPlayer"

var _was_song_playing: bool = false
var _song_playing_duration: float = 0.0
var _low_fps_duration: float = 0.0

func _process(delta: float) -> void:
	var is_song_playing: bool = song_player.playing

	if is_song_playing and not _was_song_playing:
		_song_playing_duration = 0.0
		_low_fps_duration = 0.0
	elif not is_song_playing:
		_song_playing_duration = 0.0
		_low_fps_duration = 0.0

	_was_song_playing = is_song_playing

	if not is_song_playing:
		return

	_song_playing_duration += delta

	if (
		not vr.inVR
		or beep_saber.gamestate != beep_saber.gamestate_playing
		or _song_playing_duration < SONG_START_GRACE_PERIOD
	):
		_low_fps_duration = 0.0
		return

	var fps: float = Engine.get_frames_per_second()
	if fps > LOW_FPS_THRESHOLD:
		_low_fps_duration = 0.0
		return

	_low_fps_duration += delta
	if _low_fps_duration >= LOW_FPS_DURATION:
		_low_fps_duration = 0.0
		beep_saber._transition_game_state(beep_saber.gamestate_paused)
