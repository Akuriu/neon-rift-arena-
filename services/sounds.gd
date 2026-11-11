extends Node

const IDS := [
	"pulse", "volt", "prism", "nova", "nova_impact", "charge_up", "reload", "charged",
	"low", "switch", "hit", "armor", "shield", "break", "hull", "enemy", "heavy",
	"slash", "tell", "kill", "jump", "land", "slide", "click", "pickup", "upgrade",
	"wave", "phase", "boss", "wave_hit", "win", "loss", "menu", "combat", "reactor",
	"rail", "lance", "ion", "mortar", "boost", "repair",
	"pressure", "wind", "canopy", "concourse",
]
const LOOPS := ["menu", "combat", "reactor", "pressure", "wind", "canopy", "concourse"]
var bank := {}
var flat: Array[AudioStreamPlayer] = []
var world: Array[AudioStreamPlayer3D] = []
var music: Array[AudioStreamPlayer] = []
var ambience: AudioStreamPlayer
var selected := -1
var music_name := ""
var mixing := [0.0, 0.0]
var flat_cursor := 0
var world_cursor := 0
var duck := false
var ambient_gain := 0.0
var audible := false
var region := ""
var suspended := false
var requested_track := ""
var requested_region := ""
var region_pitch := 1.0
var pending_loops := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if "--server" in OS.get_cmdline_user_args():
		set_process(false)
		return
	audible = DisplayServer.get_name() != "headless"
	for title in ["Musique", "SFX", "Ambiance"]:
		if AudioServer.get_bus_index(title) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, title)
	Prefs.apply_audio()
	set_process(audible)

func _flat_pool() -> void:
	for _i in 11:
		flat.append(_audio("SFX"))

func _world_pool() -> void:
	for _i in 14:
		var source := AudioStreamPlayer3D.new()
		source.bus = "SFX"
		source.max_distance = 38.0
		source.unit_size = 7.0
		source.volume_db = -6.0
		add_child(source)
		world.append(source)

func _audio(bus: String) -> AudioStreamPlayer:
	var channel := AudioStreamPlayer.new()
	channel.bus = bus
	add_child(channel)
	return channel

func set_track(id: String) -> void:
	if not audible or id not in LOOPS:
		return
	if id == "pressure" and not Prefs.values.audio_dynamic:
		id = "combat"
	requested_track = id
	_request_loop(id)
	_start_track()

func _start_track() -> void:
	if music_name == requested_track or not bank.has(requested_track):
		return
	if music.is_empty():
		for _i in 2:
			music.append(_audio("Musique"))
	music_name = requested_track
	selected = 0 if selected < 0 else 1 - selected
	var channel := music[selected]
	mixing[selected] = 0.0
	channel.volume_db = -70.0
	channel.stream = bank[music_name]
	channel.play()
	channel.stream_paused = suspended

func set_region(id: String) -> void:
	if not audible:
		return
	requested_region = {"skyline": "wind", "bastion": "wind", "grove": "canopy",
		"station": "concourse", "district": "concourse"}.get(id, "reactor")
	region_pitch = 0.82 if id == "cryo" else 1.0
	_request_loop(requested_region)
	_start_region()

func _start_region() -> void:
	if not bank.has(requested_region):
		return
	if not is_instance_valid(ambience):
		ambience = _audio("Ambiance")
	ambience.pitch_scale = region_pitch
	if requested_region == region:
		return
	region = requested_region
	ambient_gain = 0.0
	ambience.volume_db = -60.0
	ambience.stream = bank[region]
	ambience.play()
	ambience.stream_paused = suspended

func _request_loop(id: String) -> void:
	if bank.has(id) or pending_loops.has(id):
		return
	var path := "res://assets/audio/%s.wav" % id
	if ResourceLoader.load_threaded_request(path, "AudioStreamWAV") == OK:
		pending_loops[id] = path
	else:
		push_error("Échantillon manquant  /  " + id)

func _poll_loops() -> void:
	for id in pending_loops.keys():
		var path: String = pending_loops[id]
		var status := ResourceLoader.load_threaded_get_status(path)
		if status == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
			continue
		pending_loops.erase(id)
		var sample := ResourceLoader.load_threaded_get(path) as AudioStreamWAV if status == ResourceLoader.THREAD_LOAD_LOADED else null
		if sample == null:
			push_error("Échantillon manquant  /  " + id)
			continue
		_cache(id, sample)
	_start_track()
	_start_region()

func play(id: String, at := Vector3.INF) -> void:
	if not audible or suspended or id not in IDS or id in LOOPS:
		return
	if (id in ["boss", "tell", "phase", "low"] and not Prefs.values.audio_alerts) or (id in ["hit", "armor"] and not Prefs.values.audio_hits):
		return
	if at.is_finite():
		var listener := get_viewport().get_camera_3d()
		if is_instance_valid(listener) and at.distance_squared_to(listener.global_position) > 1444.0:
			return
		if get_sample(id) == null:
			return
		if world.is_empty():
			_world_pool()
		var speaker := world[world_cursor]
		if is_instance_valid(listener):
			var near := listener.global_position
			for channel in world:
				if not channel.playing:
					speaker = channel
					break
				if channel.global_position.distance_squared_to(near) > speaker.global_position.distance_squared_to(near):
					speaker = channel
			if speaker.playing and speaker.global_position.distance_squared_to(near) + 4.0 < at.distance_squared_to(near):
				return
		world_cursor = (world_cursor + 1) % world.size()
		speaker.global_position = at
		speaker.stream = bank[id]
		speaker.pitch_scale = randf_range(0.92, 1.07)
		speaker.play()
	else:
		if get_sample(id) == null:
			return
		if flat.is_empty():
			_flat_pool()
		var speaker := flat[flat_cursor]
		flat_cursor = (flat_cursor + 1) % flat.size()
		speaker.stream = bank[id]
		speaker.volume_db = -9.0 if id in ["hit", "click", "jump", "land"] else -3.0
		speaker.pitch_scale = 1.0
		speaker.play()

func get_sample(id: String) -> AudioStreamWAV:
	if id not in IDS:
		return null
	if not bank.has(id):
		var sample := load("res://assets/audio/%s.wav" % id) as AudioStreamWAV
		if sample == null:
			push_error("Échantillon manquant  /  " + id)
			return null
		_cache(id, sample)
	return bank[id]

func _cache(id: String, sample: AudioStreamWAV) -> void:
	if id in LOOPS:
		sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sample.loop_begin = 0
		sample.loop_end = roundi(sample.get_length() * sample.mix_rate)
	bank[id] = sample

func _process(delta: float) -> void:
	if not pending_loops.is_empty():
		_poll_loops()
	for i in music.size():
		var gain := (0.39 if duck else 0.84) if i == selected else 0.0
		mixing[i] = move_toward(mixing[i], gain, delta * 1.6)
		music[i].volume_db = linear_to_db(maxf(0.0003, mixing[i]))
		if i != selected and mixing[i] <= 0.0 and music[i].playing:
			music[i].stop()
	if is_instance_valid(ambience):
		var target := (0.29 if duck else 0.73) if music_name in ["combat", "pressure"] else 0.32
		ambient_gain = move_toward(ambient_gain, target, delta * 0.85)
		ambience.volume_db = linear_to_db(maxf(0.0002, ambient_gain))

func stop_all() -> void:
	audible = false
	set_process(false)
	requested_track = ""
	requested_region = ""
	pending_loops.clear()
	var channels: Array[Node] = []
	channels.append_array(flat)
	channels.append_array(world)
	channels.append_array(music)
	if is_instance_valid(ambience):
		channels.append(ambience)
	AudioServer.lock()
	for source in channels:
		if source.has_stream_playback():
			source.get_stream_playback().stop()
	AudioServer.unlock()
	for source in channels:
		source.stop()
		source.stream = null
	selected = -1
	music_name = ""

func suspend(paused: bool) -> void:
	suspended = paused
	for speaker in music:
		speaker.stream_paused = paused
	if is_instance_valid(ambience):
		ambience.stream_paused = paused
	if paused:
		for speaker in flat:
			speaker.stop()
		for speaker in world:
			speaker.stop()
