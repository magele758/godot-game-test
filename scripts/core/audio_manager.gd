class_name AudioManager
extends Node

## 全局音频管理 (Autoload)
## 提供 BGM 播放和 SFX 播放接口

var bgm_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_index: int = 0
const SFX_POOL_SIZE: int = 8

var sfx_cache: Dictionary = {}

const AUDIO_DIR: String = "res://assets/audio/"


func _ready() -> void:
	# BGM 播放器
	bgm_player = AudioStreamPlayer.new()
	bgm_player.bus = "Master"
	bgm_player.volume_db = -8.0
	add_child(bgm_player)

	# SFX 播放器池
	for i in range(SFX_POOL_SIZE):
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		p.volume_db = -2.0
		add_child(p)
		sfx_players.append(p)


func play_bgm(file_name: String = "bgm_loop.wav") -> void:
	var stream: AudioStream = _load_audio(file_name)
	if stream == null:
		return
	bgm_player.stream = stream
	bgm_player.play()


func stop_bgm() -> void:
	bgm_player.stop()


func play_sfx(file_name: String) -> void:
	var stream: AudioStream = _load_audio(file_name)
	if stream == null:
		return
	var player: AudioStreamPlayer = sfx_players[sfx_index]
	player.stream = stream
	player.play()
	sfx_index = (sfx_index + 1) % SFX_POOL_SIZE


func _load_audio(file_name: String) -> AudioStream:
	if sfx_cache.has(file_name):
		return sfx_cache[file_name] as AudioStream
	var path: String = AUDIO_DIR + file_name
	if not ResourceLoader.exists(path):
		push_warning("AudioManager: file not found: " + path)
		return null
	var stream: AudioStream = load(path) as AudioStream
	sfx_cache[file_name] = stream
	return stream
