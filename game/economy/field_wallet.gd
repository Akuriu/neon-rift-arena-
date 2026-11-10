extends RefCounted

const MAX_CREDITS := 999999
const OFFERS := [
	{"id": "heal", "name": "Trousse de terrain", "detail": "+40 intégrité", "price": 65, "limit": 1},
	{"id": "cells", "name": "Réserve énergétique", "detail": "Recharge et réserve complètes", "price": 55, "limit": 1},
	{"id": "barrier", "name": "Cellule de bouclier", "detail": "Bouclier au maximum et +6 de capacité", "price": 75, "limit": 3},
	{"id": "power", "name": "Amplificateur", "detail": "+7 % de dégâts de base", "price": 120, "limit": 4},
	{"id": "cool", "name": "Régulateur", "detail": "+10 % de vitesse de recharge", "price": 105, "limit": 4},
	{"id": "rack", "name": "Extension de chargeur", "detail": "+1 charge par arme", "price": 100, "limit": 3},
	{"id": "mobility", "name": "Servomoteur", "detail": "+4 % de vitesse", "price": 95, "limit": 3},
]

var balance := 0
var earned := 0
var spent := 0
var levels := {}
var receipts := {}
var receipt_wave := 0

func grant(amount: int) -> int:
	var accepted := clampi(amount, 0, MAX_CREDITS - balance)
	balance += accepted
	earned += accepted
	return accepted

func offer(id: String) -> Dictionary:
	for item in OFFERS:
		if item.id == id:
			return item
	return {}

func price(item: Dictionary) -> int:
	return int(item.price) + int(levels.get(item.id, 0)) * 22 if int(item.limit) > 1 else int(item.price)

func bought(item: Dictionary, wave: int) -> int:
	var key: String = item.id if int(item.limit) > 1 else "%s:%d" % [item.id, wave]
	return levels.get(key, 0)

func buy(id: String, wave: int, token: int, apply: Callable) -> Dictionary:
	var item := offer(id)
	if item.is_empty() or wave < receipt_wave or token < 0:
		return {"ok": false, "message": "Offre invalide."}
	if wave != receipt_wave:
		receipts.clear()
		receipt_wave = wave
	if receipts.has(token) or receipts.size() >= 12:
		return {"ok": false, "message": "Achat déjà traité."}
	var key: String = id if int(item.limit) > 1 else "%s:%d" % [id, wave]
	if bought(item, wave) >= int(item.limit):
		return {"ok": false, "message": "Limite atteinte."}
	var cost := price(item)
	if balance < cost:
		return {"ok": false, "message": "Crédits insuffisants."}
	balance -= cost
	if not bool(apply.call(id)):
		balance += cost
		return {"ok": false, "message": "Le pilote n’a pas besoin de cet article."}
	spent += cost
	levels[key] = int(levels.get(key, 0)) + 1
	receipts[token] = true
	# Consumables have per-wave stock. Keep only this wave's entries.
	for type in ["heal", "cells"]:
		levels.erase("%s:%d" % [type, wave - 1])
	return {"ok": true, "message": "%s installé · −%d CR" % [item.name, cost]}
