extends RefCounted

## 音效播放工具：assets/audio 的 wav 统一加载/播放/自清理。
## 用法：SFX.play_2d(SFX.gunshot_for("pm"), self)；SFX.play_3d(stream, node3d, pos)。
## 全部为单次播放 player（finished→queue_free）；loop_2d 返回常驻 player 由调用方停。

const DIR := "res://assets/audio/"

static var _cache: Dictionary = {}


static func stream(file: String) -> AudioStream:
	if not _cache.has(file):
		_cache[file] = load(DIR + file + ".wav")
	return _cache[file]


static func gunshot_for(weapon_id: String) -> AudioStream:
	match weapon_id:
		"ak74":
			return stream("sfx_shot_ak")
		"mp133":
			return stream("sfx_shot_sg")
		_:
			return stream("sfx_shot_pm")


## 2D（UI/玩家本地音）。parent 须在场景树内。
static func play_2d(s: AudioStream, parent: Node, volume_db: float = 0.0) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## 3D 定位音（枪声/开门/倒地）。parent 须为场景树内 Node3D。
static func play_3d(s: AudioStream, parent: Node3D, at: Vector3, volume_db: float = 0.0,
		max_dist: float = 30.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = volume_db
	p.max_distance = max_dist
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.position = at
	parent.add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
	return p


## 常驻循环播放器（环境底噪/搜索沙沙）：调用方持有引用，stop+queue_free 释放。
static func loop_2d(s: AudioStream, parent: Node, volume_db: float = 0.0) -> AudioStreamPlayer:
	if s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
	var p := AudioStreamPlayer.new()
	p.stream = s
	p.volume_db = volume_db
	parent.add_child(p)
	p.play()
	return p
