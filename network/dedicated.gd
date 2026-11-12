extends Node

const Coop := preload("res://network/coop.gd")
const Session := preload("res://scenes/Session.tscn")

var coop: Coop
var session: Node3D

func _ready() -> void:
	var options := {"port": str(Coop.PORT), "map": "reactor", "mode": "survival",
		"difficulty": "standard", "code": ""}
	for argument in OS.get_cmdline_user_args():
		var pair := argument.trim_prefix("--").split("=", true, 1)
		if argument.begins_with("--") and pair.size() == 2 and options.has(pair[0]):
			options[pair[0]] = pair[1]
	coop = Coop.new()
	coop.name = "Coop"
	coop.app = self
	add_child(coop)
	var port := int(options.port)
	if not coop.host(port, 4, options.code, true):
		printerr(coop.status)
		get_tree().quit(2)
		return
	coop.configure(options.map, options.mode, options.difficulty)
	print("COOP dedicated UDP ", port, " · ", coop.room)

func launch_coop() -> void:
	_drop_session()
	session = Session.instantiate()
	session.mode = coop.room.mode
	session.difficulty = coop.room.difficulty
	session.map_id = coop.room.map
	session.run_seed = coop.room.seed
	session.net = coop
	add_child(session)
	coop.attach(session)

func _drop_session() -> void:
	coop.stage = null
	if is_instance_valid(session):
		remove_child(session)
		session.queue_free()
		session = null
