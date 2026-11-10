extends RefCounted

const MAPS := {
	"cryo": {"name": "Chaufferie", "summary": "Des cuves en acier bordent l’allée centrale. Deux passerelles dominent les voies de service."},
	"reactor": {"name": "Cour industrielle", "summary": "Une cuve de stockage coupe la cour en deux. Les rampes latérales donnent accès aux voies de maintenance."},
	"skyline": {"name": "Dépôt de fret", "summary": "Des conteneurs, un portique et deux voies ouvertes pour les tirs à distance."},
	"bastion": {"name": "Poste radio", "summary": "Une antenne radio surplombe les soutes et les rampes en béton."},
	"district": {"name": "Quartier du marché", "summary": "Des rues étroites, des façades en brique et un carrefour traversé par le tram."},
	"grove": {"name": "Ruines du bois", "summary": "Des murs effondrés et un sentier forestier autour d’une clairière."},
	"station": {"name": "Gare de transit", "summary": "Un hall couvert, deux quais et des balcons reliés par des rampes."},
}

const Weapons := preload("res://game/weapons/catalog.gd")
const WEAPONS := Weapons.WEAPONS

const UNITS := {
	"scout": {"name": "Éclaireur", "health": 62.0, "speed": 5.8, "range": 2.7, "tell": 0.42,
		"rest": 0.86, "damage": 18.0, "radius": 0.49, "points": 100, "tint": Color("#8f805f")},
	"sentinel": {"name": "Fusilier", "health": 93.0, "speed": 4.2, "range": 21.0, "tell": 0.70,
		"rest": 1.15, "damage": 16.0, "radius": 0.57, "points": 160, "tint": Color("#7b7764")},
	"bulwark": {"name": "Blindé", "health": 184.0, "speed": 3.6, "range": 14.0, "tell": 0.92,
		"rest": 1.24, "damage": 19.0, "radius": 0.66, "points": 240, "tint": Color("#777668")},
	"specter": {"name": "Voltigeur", "health": 67.0, "speed": 6.9, "range": 14.0, "tell": 0.49,
		"rest": 0.86, "damage": 17.0, "radius": 0.51, "points": 190, "tint": Color("#80785b")},
	"elite": {"name": "Chef blindé", "health": 390.0, "speed": 3.55, "range": 18.0, "tell": 1.12,
		"rest": 1.24, "damage": 21.0, "radius": 0.73, "points": 620, "tint": Color("#756e58")},
	"warden": {"name": "Commandant", "health": 950.0, "speed": 4.05, "range": 25.0, "tell": 1.10,
		"rest": 1.13, "damage": 23.0, "radius": 0.85, "points": 1800, "tint": Color("#87775b")},

	"skimmer": {"name": "Drone léger", "health": 72.0, "speed": 6.0, "range": 16.0, "tell": 0.61,
		"rest": 1.05, "damage": 15.0, "radius": 0.47, "points": 160, "tint": Color("#808478")},
	"medic": {"name": "Secouriste", "health": 88.0, "speed": 4.4, "range": 13.0, "tell": 0.87,
		"rest": 2.1, "damage": 12.0, "radius": 0.53, "points": 205, "tint": Color("#888a76")},
	"disruptor": {"name": "Opérateur radio", "health": 110.0, "speed": 4.15, "range": 18.0, "tell": 1.06,
		"rest": 2.2, "damage": 13.0, "radius": 0.58, "points": 220, "tint": Color("#7c7866")},
	"artillery": {"name": "Grenadier", "health": 138.0, "speed": 3.2, "range": 27.0, "tell": 1.45,
		"rest": 2.1, "damage": 24.0, "radius": 0.63, "points": 260, "tint": Color("#826d56")},
	"colossus": {"name": "Démineur lourd", "health": 1100.0, "speed": 3.15, "range": 22.0, "tell": 1.18,
		"rest": 1.15, "damage": 25.0, "radius": 0.86, "points": 2200, "tint": Color("#77746a")},
	"architect": {"name": "Tireur d’élite", "health": 1350.0, "speed": 3.9, "range": 27.0, "tell": 1.15,
		"rest": 1.16, "damage": 26.0, "radius": 0.85, "points": 2800, "tint": Color("#84776c")},
}

const BOSSES := ["elite", "warden", "colossus", "architect"]
const DIFFICULTIES := {
	"discovery": {"name": "Découverte", "hp": 0.82, "power": 0.61, "tempo": 1.18, "cap": 5},
	"standard": {"name": "Standard", "hp": 1.0, "power": 1.0, "tempo": 1.0, "cap": 7},
	"expert": {"name": "Expert", "hp": 1.16, "power": 1.24, "tempo": 0.82, "cap": 9},
}

const TRIAL := ["scout", "sentinel", "specter", "scout", "sentinel", "specter", "bulwark",
	"scout", "scout", "specter", "sentinel", "bulwark", "specter", "scout", "elite"]

const UPGRADES := [
	{"name": "Plaques de protection", "kind": "BOUCLIER", "effect": "+16 au bouclier maximum", "cap": 3, "tint": Color("#69ece7")},
	{"name": "Équipement léger", "kind": "MOBILITÉ", "effect": "+8 % de vitesse au sol", "cap": 3, "tint": Color("#b6e6a7")},
	{"name": "Recharge rapide", "kind": "RECHARGE", "effect": "+18 % de vitesse de recharge et de refroidissement", "cap": 3, "tint": Color("#ffba73")},
	{"name": "Trousse de soins", "kind": "SANTÉ", "effect": "+38 points d’intégrité immédiatement", "cap": 0, "tint": Color("#d9e6d4")},
	{"name": "Récupération de munitions", "kind": "MUNITIONS", "effect": "+1 charge à chaque neutralisation", "cap": 3, "tint": Color("#a6a2ff")},
	{"name": "Munitions renforcées", "kind": "IMPACT", "effect": "+12 % de dégâts avec chaque équipement", "cap": 3, "tint": Color("#ff80cb")},
]
