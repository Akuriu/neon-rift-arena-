extends SceneTree

const Career := preload("res://services/career.gd")
const Profile := preload("res://services/profile.gd")
const Track := preload("res://network/snapshot_track.gd")
const Replication := preload("res://network/replication.gd")

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if OS.get_environment("NEON_QA_ISOLATED") != "1":
		quit(2)
		return
	var prefs = root.get_node("Prefs")
	var path: String = prefs.profile_file(prefs.SAVE)
	var old := {"version": 3, "settings": {"fov": 93}, "progression": {"coins": 480,
		"xp": 870, "owned": ["wp_eclipse", "mod_rack"], "slots": ["wp_eclipse", "wp_pulse", "wp_volt", "wp_nova"]},
		"records": {"survival|standard|reactor": [{"score": 7200, "wave": 8}]}}
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(old))
	file.close()
	var checksum := FileAccess.get_sha256(path)
	prefs.load_disk()
	var profile = prefs.profile
	check(profile.data.xp == 870 and profile.data.coins == 480 and prefs.values.fov == 93
		and profile.data.slots[0] == "wp_eclipse" and prefs.leaderboard("survival", "standard", "reactor")[0].score == 7200,
		"V2 préserve XP, pièces, équipement, FOV et records")
	check(prefs.save_disk() and checksum == FileAccess.get_sha256(prefs.profile_file(prefs.V2_BACKUP)),
		"Copie du profil V2 avant migration, identique octet pour octet")
	var first: Dictionary = prefs.profile_action(profile.buy.bind("skin_ash"))
	var second: Dictionary = prefs.profile_action(profile.buy.bind("skin_ash"))
	check(first.ok and not second.ok and profile.data.coins == 395 and profile.data.career.ledger.size() == 1,
		"Achat unique et reçu local avec solde cohérent")
	var loadout: Array = profile.data.slots.duplicate()
	prefs.profile_action(profile.loadout.bind("save"))
	prefs.profile_action(profile.loadout.bind("guard"))
	var owned := true
	for id in profile.data.slots:
		owned = owned and profile.owns(id)
	check(owned and profile.data.coins == 395 and profile.data.module == "mod_rack", "Préréglage utilise les équipements acquis sans débit")
	prefs.load_disk()
	prefs.profile_action(profile.loadout.bind("own"))
	check(profile.data.slots == loadout, "Configuration personnelle rechargeable après redémarrage")
	var report := {"score": 990, "wave": 20, "seconds": 300, "kills": 100,
		"accuracy": 90, "hits": 180, "shots": 200, "victory": true, "bosses": 1, "seed": 321}
	var reward: Dictionary = prefs.complete_run("v3-career-first", "survival", "standard", "reactor", report)
	var repeated: Dictionary = prefs.complete_run("v3-career-first", "survival", "standard", "reactor", report)
	check(reward.ok and not repeated.ok and reward.badges.size() >= 3 and profile.data.career.history.size() == 1,
		"Bilan unique et déblocage automatique de trois succès")
	var weekly: Dictionary = profile.data.career.weekly
	weekly.value = Career.challenge(weekly.period)[2]
	var week_receipt: Dictionary = prefs.profile_action(profile.claim_weekly)
	prefs.load_disk()
	check(week_receipt.ok and not prefs.profile_action(profile.claim_weekly).ok
		and profile.data.career.weekly.claimed, "Défi hebdomadaire encaissable une seule fois et persistant")
	for i in 50:
		profile.settle("local-career-%d" % i, "short", "standard", report)
	check(profile.data.career.history.size() == 32 and profile.data.career.ledger.size() == 48, "Historique et reçus bornés")
	profile.data.career.weekly.period = Career.week() + 1
	profile.data.career.weekly.claimed = true
	profile.refresh_contracts()
	check(profile.data.career.weekly.claimed and profile.data.career.weekly.period > Career.week(),
		"Le recul de calendrier ne renouvelle pas un gain")
	var casual := Profile.rewards({"outcome": "victoire", "kills": 99, "seconds": 10, "participated": true}, "standard")
	check(casual.coins == 0 and casual.xp == 0, "Match artificiellement court sans gain permanent")
	for mode in ["survival", "short", "trial", "classic", "capture"]:
		var pieces := 0
		var xp := 0
		for i in 20:
			var sample := {"wave": 8 + i % 12 if mode == "survival" else (5 + i % 6 if mode == "short" else 0),
				"kills": 7 + i * (5 if mode in ["survival", "short"] else 1), "seconds": 70 + 23 * i,
				"bosses": i / 7, "victory": i % 3 != 0, "participated": true}
			if mode in ["classic", "capture"]:
				sample.outcome = "victoire" if sample.victory else "défaite"
				sample.objectives = 12 + 4 * i if mode == "capture" else 0
			var value := Profile.rewards(sample, ["discovery", "standard", "expert"][i % 3])
			pieces += value.coins
			xp += value.xp
		print("ECONOMIE ", mode, " cas=20 moyenne_pieces=", pieces / 20.0, " moyenne_xp=", xp / 20.0)
		check(pieces > 0 and xp > 0, "Simulation économique bornée · " + mode)
	var track := Track.new()
	track.append(Vector3.ZERO, 3.13, 0.0, 2.0, 1.0)
	track.append(Vector3(2.0, 0, 0), -3.13, 0.3, 5.0, 1.20)
	var pose := track.pose(1.22)
	check(absf(pose.at.x - 1.0) < 0.002 and absf(pose.yaw) > 3.0 and track.pose(4).at.x == 2.0,
		"Interpolation, angles courts et stabilisation après perte de snapshots")
	track.append(Vector3(20.0, 0, 0), 0.0, 0.0, 0.0, 4.0)
	check(track.samples.size() == 1 and track.pose(4).at.x == 20.0, "Déplacement discontinu réinitialise le tampon")
	check(not Replication.valid([0, [], [], [], []]) and not Replication.valid([[0], [], [], [], []]),
		"Enveloppes réseau mal formées rejetées avant lecture")
	var app = load("res://scenes/App.tscn").instantiate()
	root.add_child(app)
	for page in ["history", "stats", "ledger", "badges"]:
		app.show_career(page)
	app.show_profile("contracts")
	app.replay_report({"mode": "classic", "difficulty": "standard", "map": "bastion", "seed": 922, "rules": "4-600-35"})
	check(app.session.run_seed == 922 and app.session.classic.options.target == 35, "Le journal relance exactement les règles solo")
	app.menu()
	await process_frame
	quit(failures)

func check(ok: bool, message: String) -> void:
	print("PASS " if ok else "FAIL ", message)
	if not ok:
		failures += 1
