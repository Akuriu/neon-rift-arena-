extends RefCounted

const MAPS := {
	"cryo": {"name": "Cryo Foundry", "summary": "Fonderie de refroidissement. Alternez le couloir central de précision, les rangées de cuves et les deux voies de service surélevées."},
	"reactor": {"name": "Reactor Court", "summary": "Cour énergétique et voies de maintenance. Exploitez les rampes et les couvertures de chaque côté du réacteur."},
	"skyline": {"name": "Skyline Depot", "summary": "Dépôt de fret ouvert à l’aube. Traversez les îlots de conteneurs ou prenez la passerelle pour couvrir les longues lignes."},
	"bastion": {"name": "Bastion Relay", "summary": "Poste de transmissions fictif. Soutes latérales, tour radio et rampes de la voie technique."},
	"district": {"name": "Meridian District", "summary": "Quartier fermé. Enchaînez les passages entre immeubles et traversez la place du tram."},
	"grove": {"name": "Ashgrove Ruins", "summary": "Enceinte forestière. Les ruines et leurs ouvertures entourent une clairière centrale."},
	"station": {"name": "Transit Hall", "summary": "Station intérieure. Alternez hall central, quais et balcons de circulation."},
}

const Weapons := preload("res://game/weapons/catalog.gd")
const WEAPONS := Weapons.WEAPONS

const UNITS := {
	"scout": {"name": "Scout", "health": 62.0, "speed": 5.8, "range": 2.7, "tell": 0.42,
		"rest": 0.86, "damage": 18.0, "radius": 0.49, "points": 100, "tint": Color("#ffd075")},
	"sentinel": {"name": "Sentinel", "health": 93.0, "speed": 4.2, "range": 21.0, "tell": 0.70,
		"rest": 1.15, "damage": 16.0, "radius": 0.57, "points": 160, "tint": Color("#ff79b6")},
	"bulwark": {"name": "Bulwark", "health": 184.0, "speed": 3.6, "range": 14.0, "tell": 0.92,
		"rest": 1.24, "damage": 19.0, "radius": 0.66, "points": 240, "tint": Color("#76caff")},
	"specter": {"name": "Specter", "health": 67.0, "speed": 6.9, "range": 14.0, "tell": 0.49,
		"rest": 0.86, "damage": 17.0, "radius": 0.51, "points": 190, "tint": Color("#9efaac")},
	"elite": {"name": "Bulwark Apex", "health": 390.0, "speed": 3.55, "range": 18.0, "tell": 1.12,
		"rest": 1.24, "damage": 21.0, "radius": 0.73, "points": 620, "tint": Color("#5cc8ff")},
	"warden": {"name": "Reactor Warden", "health": 950.0, "speed": 4.05, "range": 25.0, "tell": 1.10,
		"rest": 1.13, "damage": 23.0, "radius": 0.85, "points": 1800, "tint": Color("#ff986d")},

	"skimmer": {"name": "Skimmer", "health": 72.0, "speed": 6.0, "range": 16.0, "tell": 0.61,
		"rest": 1.05, "damage": 15.0, "radius": 0.47, "points": 160, "tint": Color("#64f4e3")},
	"medic": {"name": "Medic Drone", "health": 88.0, "speed": 4.4, "range": 13.0, "tell": 0.87,
		"rest": 2.1, "damage": 12.0, "radius": 0.53, "points": 205, "tint": Color("#aafa81")},
	"disruptor": {"name": "Disruptor", "health": 110.0, "speed": 4.15, "range": 18.0, "tell": 1.06,
		"rest": 2.2, "damage": 13.0, "radius": 0.58, "points": 220, "tint": Color("#d095ff")},
	"artillery": {"name": "Artillery Node", "health": 138.0, "speed": 3.2, "range": 27.0, "tell": 1.45,
		"rest": 2.1, "damage": 24.0, "radius": 0.63, "points": 260, "tint": Color("#ffad67")},
	"colossus": {"name": "Aegis Colossus", "health": 1100.0, "speed": 3.15, "range": 22.0, "tell": 1.18,
		"rest": 1.15, "damage": 25.0, "radius": 0.86, "points": 2200, "tint": Color("#80ddff")},
	"architect": {"name": "Null Architect", "health": 1350.0, "speed": 3.9, "range": 27.0, "tell": 1.15,
		"rest": 1.16, "damage": 26.0, "radius": 0.85, "points": 2800, "tint": Color("#fa91f7")},
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
	{"name": "Blindage ionique", "kind": "BOUCLIER", "effect": "+16 au bouclier maximum", "cap": 3, "tint": Color("#69ece7")},
	{"name": "Pas vectoriel", "kind": "MOBILITÉ", "effect": "+8 % de vitesse au sol", "cap": 3, "tint": Color("#b6e6a7")},
	{"name": "Cycle express", "kind": "RECHARGE", "effect": "+18 % de vitesse de recharge et de refroidissement", "cap": 3, "tint": Color("#ffba73")},
	{"name": "Kit de réparation", "kind": "INTÉGRITÉ", "effect": "+38 points d’intégrité immédiatement", "cap": 0, "tint": Color("#d9e6d4")},
	{"name": "Recyclage", "kind": "ÉNERGIE", "effect": "+1 charge à chaque neutralisation", "cap": 3, "tint": Color("#a6a2ff")},
	{"name": "Résonance", "kind": "IMPACT", "effect": "+12 % de dégâts avec chaque équipement", "cap": 3, "tint": Color("#ff80cb")},
]
