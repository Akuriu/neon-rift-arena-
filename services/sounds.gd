extends Node

const IDS := [
	"pulse", "volt", "prism", "nova", "nova_impact", "charge_up", "reload", "charged",
	"low", "switch", "hit", "armor", "shield", "break", "hull", "enemy", "heavy",
	"slash", "tell", "kill", "jump", "land", "slide", "click", "pickup", "upgrade",
	"wave", "phase", "boss", "wave_hit", "win", "loss", "menu", "combat", "reactor",
	"rail", "lance", "ion", "mortar", "boost", "repair",
	"pressure", "wind", "canopy", "concourse",
	"ui_select", "ui_confirm", "ui_cancel",
]
const LOOPS := ["menu", "combat", "reactor", "pressure", "wind", "canopy", "concourse"]
const UI_CUES := ["ui_select", "ui_confirm", "ui_cancel"]
const REGIONS := {"skyline": "wind", "bastion": "wind", "grove": "canopy",
	"station": "concourse", "district": "concourse"}
var bank := {}
var flat: Array[AudioStreamPlayer] = []
var world: Array[AudioStreamPlayer3D] = []
var music: Array[AudioStreamPlayer] = []
var ambience: Array[AudioStreamPlayer] = []
var interface: Array[AudioStreamPlayer] = []
var selected := -1
var selected_region := -1
var music_name := ""
var mixing := [0.0, 0.0]
var room_levels := [0.0, 0.0]
var flat_cursor := 0
var world_cursor := 0
var ui_cursor := 0
var duck := false
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
	for title in ["Musique", "SFX", "Ambiance", "Interface"]:
		if AudioServer.get_bus_index(title) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, title)
	AudioServer.set_bus_send(AudioServer.get_bus_index("Interface"), "SFX")
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
	music_name = requested_track
	selected = _play_loop(music, mixing, music_name, selected, "Musique", 1.0)

func set_region(id: String) -> void:
	if not audible:
		return
	requested_region = REGIONS.get(id, "reactor")
	region_pitch = 0.82 if id == "cryo" else 1.0
	_request_loop(requested_region)
	_start_region()

func _start_region() -> void:
	if not bank.has(requested_region):
		return
	if requested_region == region:
		ambience[selected_region].pitch_scale = region_pitch
		return
	region = requested_region
	selected_region = _play_loop(ambience, room_levels, region, selected_region, "Ambiance", region_pitch)

func _play_loop(channels: Array[AudioStreamPlayer], levels: Array, id: String, previous: int, bus: String, pitch: float) -> int:
	if channels.is_empty():
		for _index in 2:
			channels.append(_audio(bus))
	var sample: AudioStreamWAV = bank[id]
	for index in channels.size():
		if channels[index].playing and channels[index].stream == sample:
			channels[index].pitch_scale = pitch
			return index
	var target := 0 if previous < 0 else 1 - previous
	var channel := channels[target]
	channel.stop()
	channel.pitch_scale = pitch
	channel.volume_db = -70.0
	channel.stream = sample
	levels[target] = 0.0
	channel.play()
	channel.stream_paused = suspended
	return target

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
		if audible:
			_cache(id, sample)
	if audible:
		_start_track()
		_start_region()

func play(id: String, at := Vector3.INF) -> void:
	if not audible or suspended or id not in IDS or id in LOOPS or id in UI_CUES:
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

func play_ui(id: String) -> void:
	if not audible or suspended or not Prefs.values.audio_ui or id not in UI_CUES:
		return
	var sample := get_sample(id)
	if sample == null:
		return
	if interface.is_empty():
		for _index in 2:
			interface.append(_audio("Interface"))
	var speaker := interface[ui_cursor]
	ui_cursor = (ui_cursor + 1) % interface.size()
	speaker.stream = sample
	speaker.pitch_scale = randf_range(0.97, 1.035)
	speaker.volume_db = -11.0
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
	if not audible:
		set_process(not pending_loops.is_empty())
		return
	if suspended:
		return
	_mix(music, mixing, selected, 0.39 if duck else 0.84, delta * 1.6)
	var target := (0.29 if duck else 0.66) if music_name in ["combat", "pressure"] else 0.32
	_mix(ambience, room_levels, selected_region, target, delta * 0.9)

func _mix(channels: Array[AudioStreamPlayer], levels: Array, current: int, target: float, step: float) -> void:
	for index in channels.size():
		var gain := target if index == current else 0.0
		var next := move_toward(float(levels[index]), gain, step)
		if next != levels[index]:
			levels[index] = next
			channels[index].volume_db = linear_to_db(maxf(0.0003, next))
		if index != current and next <= 0.0 and channels[index].playing:
			channels[index].stop()

func stop_all() -> void:
	audible = false
	set_process(not pending_loops.is_empty())
	requested_track = ""
	requested_region = ""
	var channels: Array[Node] = []
	channels.append_array(flat)
	channels.append_array(world)
	channels.append_array(music)
	channels.append_array(ambience)
	channels.append_array(interface)
	AudioServer.lock()
	for source in channels:
		if source.has_stream_playback():
			source.get_stream_playback().stop()
	AudioServer.unlock()
	for source in channels:
		source.stop()
		source.stream = null
	selected = -1
	selected_region = -1
	music_name = ""
	region = ""

func suspend(paused: bool) -> void:
	suspended = paused
	for speaker in music:
		speaker.stream_paused = paused
	for speaker in ambience:
		speaker.stream_paused = paused
	if paused:
		for speaker in flat:
			speaker.stop()
		for speaker in interface:
			speaker.stop()
		stop_world()

func stop_world() -> void:
	for speaker in world:
		speaker.stop()
