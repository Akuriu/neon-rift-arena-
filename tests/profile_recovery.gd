extends SceneTree

const SAVE := "pilot_profile.json"
const BACKUP := "pilot_profile.json.bak"
const V5 := "pilot_profile.v5.json"
const CORRUPT := "{\"version\":{"

var failed := 0
var directory: String
var prefs

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	prefs = root.get_node("Prefs")
	directory = prefs.test_profile_dir
	if directory.is_empty():
		printerr("Ce test exige un profil isolé.")
		quit(2)
		return
	check(prefs.profile_notice.is_empty(), "Un profil neuf n’affiche aucun avertissement")
	write(SAVE, '{"version":{},"settings":{"layout":1},"progression":{"name":"Pilote QA"}}')
	var primary := directory.path_join(SAVE)
	var stamp := FileAccess.get_sha256(primary)
	prefs.load_disk()
	check(prefs.values.layout == 1 and prefs.keys.forward == KEY_W and InputMap.has_action("fire"),
		"Un en-tête invalide ne désactive pas les entrées")
	check(prefs.profile.data.name == "Pilote QA" and not prefs.profile_notice.is_empty(),
		"Un en-tête invalide conserve les champs compatibles et affiche un avis")
	check(FileAccess.get_sha256(primary) == stamp, "La lecture ne modifie pas le profil endommagé")
	check(prefs.save_disk(), "Un profil récupéré peut être sauvegardé")
	check(FileAccess.get_sha256(directory.path_join("pilot_profile.corrupt-%s.json" % stamp)) == stamp,
		"Le profil endommagé est conservé octet pour octet")

	write(SAVE, CORRUPT)
	stamp = FileAccess.get_sha256(primary)
	write(BACKUP, '{"version":5,"settings":{"layout":1},"progression":{"name":"Secours QA","coins":37}}')
	var backup := directory.path_join(BACKUP)
	var backup_stamp := FileAccess.get_sha256(backup)
	prefs.load_disk()
	check(prefs.profile.data.name == "Secours QA" and prefs.profile.data.coins == 37 \
		and "copie de secours" in prefs.profile_notice, "La copie saine restaure la progression")
	check(FileAccess.get_sha256(primary) == stamp and FileAccess.get_sha256(backup) == backup_stamp,
		"La récupération ne réécrit aucun fichier au chargement")
	check(prefs.save_disk() and FileAccess.get_sha256(backup) == backup_stamp \
		and FileAccess.get_sha256(directory.path_join(V5)) == backup_stamp,
		"La récupération préserve la copie de secours et archive le schéma 5")

	write(SAVE, CORRUPT)
	write(BACKUP, CORRUPT)
	prefs.load_disk()
	check("illisible" in prefs.profile_notice and InputMap.has_action("forward"),
		"Deux copies illisibles ouvrent une session de secours jouable")
	prefs.load_disk()
	check(FileAccess.get_sha256(primary) == stamp, "Relire un profil illisible laisse l’original intact")
	quit(1 if failed else 0)

func write(filename: String, contents: String) -> void:
	var file := FileAccess.open(directory.path_join(filename), FileAccess.WRITE)
	file.store_string(contents)

func check(condition: bool, message: String) -> void:
	print(("PASS " if condition else "FAIL ") + message)
	if not condition:
		failed += 1
