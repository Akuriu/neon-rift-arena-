extends Node

const IDS := [
	"pulse", "volt", "prism", "nova", "nova_impact", "charge_up", "reload", "charged",
	"low", "switch", "hit", "armor", "shield", "break", "hull", "enemy", "heavy",
	"slash", "tell", "kill", "jump", "land", "slide", "click", "pickup", "upgrade",
	"wave", "phase", "boss", "wave_hit", "win", "loss", "menu", "combat", "reactor",
	"rail", "lance", "ion", "mortar", "boost", "repair",
]
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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	audible = DisplayServer.get_name() != "headless"
	for title in ["Musique", "SFX", "Ambiance"]:
		if AudioServer.get_bus_index(title) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, title)
	for id in IDS:
		var sample := load("res://assets/audio/%s.wav" % id) as AudioStreamWAV
		if sample == null:
			push_error("Échantillon manquant  /  " + id)
			continue
		if id in ["menu", "combat", "reactor"]:
			sample.loop_mode = AudioStreamWAV.LOOP_FORWARD
			sample.loop_begin = 0
			sample.loop_end = roundi(sample.get_length() * sample.mix_rate)
		bank[id] = sample
	for _i in 11:
		flat.append(_audio("SFX"))
	for _i in 14:
		var source := AudioStreamPlayer3D.new()
		source.bus = "SFX"
		source.max_distance = 38.0
		source.unit_size = 7.0
		source.volume_db = -6.0
		add_child(source)
		world.append(source)
	for _i in 2:
		music.append(_audio("Musique"))
	ambience = _audio("Ambiance")
	ambience.stream = bank.get("reactor")
	ambience.volume_db = -60.0
	if audible:
		ambience.play()
	Prefs.apply_audio()

func _audio(bus: String) -> AudioStreamPlayer:
	var channel := AudioStreamPlayer.new()
	channel.bus = bus
	add_child(channel)
	return channel

func set_track(id: String) -> void:
	if music_name == id or not bank.has(id) or not audible:
		return
	music_name = id
	selected = 0 if selected < 0 else 1 - selected
	var channel := music[selected]
	mixing[selected] = 0.0
	channel.volume_db = -70.0
	channel.stream = bank[id]
	channel.play()

func play(id: String, at := Vector3.INF) -> void:
	if not bank.has(id) or not audible:
		return
	if at.is_finite():
		var speaker := world[world_cursor]
		world_cursor = (world_cursor + 1) % world.size()
		speaker.global_position = at
		speaker.stream = bank[id]
		speaker.pitch_scale = randf_range(0.92, 1.07)
		speaker.play()
	else:
		var speaker := flat[flat_cursor]
		flat_cursor = (flat_cursor + 1) % flat.size()
		speaker.stream = bank[id]
		speaker.volume_db = -9.0 if id in ["hit", "click", "jump", "land"] else -3.0
		speaker.pitch_scale = 1.0
		speaker.play()

func _process(delta: float) -> void:
	for i in music.size():
		var gain := (0.39 if duck else 0.84) if i == selected else 0.0
		mixing[i] = move_toward(mixing[i], gain, delta * 1.6)
		music[i].volume_db = linear_to_db(maxf(0.0003, mixing[i]))
		if i != selected and mixing[i] <= 0.0 and music[i].playing:
			music[i].stop()
	var target := (0.29 if duck else 0.73) if music_name == "combat" else 0.32
	ambient_gain = move_toward(ambient_gain, target, delta * 0.85)
	ambience.volume_db = linear_to_db(maxf(0.0002, ambient_gain))

func stop_all() -> void:
	audible = false
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
