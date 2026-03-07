extends Node2D

# Scéna pre PC 
@export var pc_scene = preload("res://scenes/pc.tscn")
# Scéna pre server
var server_scene = preload("res://scenes/server.tscn")
# Zoznam všetkých možných kancelárií (layoutov)
var office_scenes = [
	preload("res://scenes/offices/office_01.tscn"),
	preload("res://scenes/offices/office_02.tscn"),
	preload("res://scenes/offices/office_03.tscn"),
	preload("res://scenes/offices/office_04.tscn")
]
# Timer, ktorý riadi spawnovanie PC a kancelárií
@onready var spawn_timer: Timer = $SpawnTimer

# Zoznam všetkých spawnutých kancelárií
var offices = []
# Posledná (aktuálna) kancelária, do ktorej sa spawnujú PC
var latest_office = null
# Aktuálny server (posledný spawnutý)
var current_server = null
# Zoznam všetkých farieb, ktoré sú už dostupné v hre
var available_colors = []
# Slovník: kancelária -> použité spawn pointy
var office_used_points = {}   
# Zoznam obsadených pozícií kancelárií (aby sa neprekrývali)
var occupied_positions = []
# Veľkosť jednej kancelárie (grid systém)
const ROOM_SIZE = 160

# Smery, do ktorých sa môže spawnúť nová kancelária
var DIRECTIONS = [
	Vector2(1, 0),
	Vector2(-1, 0),
	Vector2(0, 1),
	Vector2(0, -1)
]

# -------------------------
# READY (spustenie scény)
# -------------------------
func _ready() -> void:
	spawn_first_office() 	# vytvorí prvú kanceláriu
	spawn_timer.start() 	# spustí spawn loop

# -------------------------
# PRVÁ KANCELÁRIA (musí mať server)
# -------------------------
func spawn_first_office():
	# Zoznam všetkých vhodných kancelárií (iba tie, ktoré majú server)
	var valid = []
	
	# Prejdeme všetky dostupné office scény
	# Cieľ: vybrať iba tie, ktoré obsahujú server
	for scene in office_scenes:
		# Dočasne vytvoríme inštanciu, aby sme vedeli skontrolovať vlastnosť has_server
		var temp = scene.instantiate()
		# Ak kancelária obsahuje server, pridáme ju do zoznamu kandidátov
		if temp.has_server:
			valid.append(scene)
		# Dočasnú inštanciu odstránime
		temp.queue_free()
	
	# Náhodne vyberieme jednu vhodnú kanceláriu
	var scene = valid.pick_random()
	# Vytvoríme reálnu inštanciu kancelárie
	var office = scene.instantiate()
	# Nastavíme jej pozíciu na začiatok mapy (0,0)
	office.global_position = Vector2(0, 0)
	# Pridáme kanceláriu do scény (zobrazí sa v hre)
	add_child(office)
	
	# Uloženie kancelárie do zoznamu všetkých kancelárií
	# Potrebné pre ďalšie rozširovanie mapy
	offices.append(office)
	# Nastavenie tejto kancelárie ako aktuálnej (aktívnej)
	# Prvé PC sa budú spawnovať práve sem
	latest_office = office
	# Označenie pozície ako obsadenej
	# Zabraňuje spawnnutiu ďalšej kancelárie na rovnaké miesto
	occupied_positions.append(office.global_position)
	# Inicializácia zoznamu použitých spawn pointov
	# Zatiaľ je miestnosť prázdna (žiadne PC)
	office_used_points[office] = []
	
	# Spawn servera v tejto kancelárii
	# Server definuje prvú farbu 
	spawn_server_for_office(office)
	
# -------------------------
# SPAWN NOVEJ KANCELÁRIE
# -------------------------
func spawn_new_office():
	# Debug výpis pre kontrolu
	print("SPAWNING NEW OFFICE")
	
	# Zoznam všetkých možných pozícií, kam sa môže nová kancelária spawnnúť
	var possible_spots = []
	# Prechádzame všetky existujúce kancelárie
	# Nové miestnosti sa môžu pripojiť ku KTORÉMUKOĽVEK existujúcemu uzlu
	for office in offices:
		# Pre každú kanceláriu skúšame všetky 4 smery
		for dir in DIRECTIONS:
			# Vypočítame potenciálnu pozíciu:
			# aktuálna pozícia kancelárie + smer * veľkosť miestnosti
			# Zabezpečuje, že miestnosti na seba nadväzujú
			var pos = office.global_position + dir * ROOM_SIZE
			
			# Skontrolujeme, či už na tejto pozícii NIE JE iná kancelária
			# Zabraňuje prekrývaniu miestností
			if pos not in occupied_positions:
				# Ak je pozícia voľná, pridáme ju do zoznamu kandidátov
				possible_spots.append(pos)
	# Ak neexistuje žiadna voľná pozícia, funkcia končí
	# Mapa sa už nemôže ďalej rozširovať
	if possible_spots.is_empty():
		return
	# Náhodne vyberieme jednu z dostupných pozícií
	# Zabezpečuje variabilitu mapy pri každom hraní
	var chosen_pos = possible_spots.pick_random()
	# Náhodne vyberieme layout kancelárie
	var scene = office_scenes.pick_random()
	# Vytvoríme novú inštanciu kancelárie zo scény
	var new_office = scene.instantiate()
	# Nastavíme jej pozíciu na vybranú pozíciu v mape
	new_office.global_position = chosen_pos
	# Pridáme ju do scény (tým sa zobrazí v hre)
	add_child(new_office)
	# Pridáme novú kanceláriu do zoznamu všetkých kancelárií
	# Dôležité pre ďalšie rozširovanie mapy
	offices.append(new_office)
	# Nastavíme ju ako aktuálnu kanceláriu
	# Ďalšie PC sa budú spawnovať práve sem
	latest_office = new_office
	# Označíme túto pozíciu ako obsadenú
	# Aby sa tam už ďalšia kancelária nevytvorila
	occupied_positions.append(chosen_pos)
	# Inicializujeme zoznam použitých spawn pointov pre túto kanceláriu
	# Sledujeme, ktoré miesta sú už obsadené PC
	office_used_points[new_office] = []
	# Ak kancelária obsahuje server → spawnne ho
	if new_office.has_server:
		spawn_server_for_office(new_office)
	
# -------------------------
# SPAWN SERVERA
# -------------------------
func spawn_server_for_office(office):
	# Získanie referencie na Marker (pozícia), kde sa má server spawnnúť
	# Každý office má presne definované miesto pre server
	var server_spawn = office.get_node("ServerSpawn")
	
	# Vytvorenie novej inštancie servera zo scény
	var server = server_scene.instantiate()
	# Nastavenie pozície servera na pozíciu markeru v kancelárii
	# Zabezpečuje, že server sa zobrazí presne na správnom mieste
	server.global_position = server_spawn.global_position
	# Pridanie servera do hlavnej scény (aktivuje ho v hre)
	add_child(server)
	
	# Náhodná farba servera
	var color = ["red", "blue", "green", "purple"].pick_random()
	
	# Nastavenie farby servera
	server.set_color(color)
	
	# Pridanie farby do globálneho zoznamu (ak tam ešte nie je)
	if color not in available_colors:
		available_colors.append(color)
	
	# Zamapätanie aktuálneho servera
	current_server = server

# -------------------------
# KONTROLA, ČI SA DÁ SPAWNÚŤ PC
# -------------------------
func can_spawn_pc():
	# Bezpečnostná kontrola – ak ešte neexistuje žiadna kancelária, nie je kam spawnovať PC
	if latest_office == null:
		return false
	
	# Získanie všetkých spawn pointov v aktuálnej kancelárii
	# Tieto body reprezentujú maximálnu kapacitu miestnosti
	var points = latest_office.get_node("SpawnPoints").get_children()
	# Získanie už použitých spawn pointov pre túto kanceláriu
	# Sledujeme, ktoré miesta sú už obsadené PC
	var used = office_used_points[latest_office]
	
	# Porovnanie:
	# - points.size() = celkový počet možných miest
	# - used.size() = počet už obsadených miest
	# Ak je obsadených menej než existuje miest = ešte môžeme spawnovať
	# Ak sú rovnaké = miestnosť je plná
	return used.size() < points.size()

# -------------------------
# SPAWN PC
# -------------------------
func spawn_pc():
	# Bezpečnostná kontrola – ak neexistuje aktuálna kancelária, nie je kam spawnovať PC
	if latest_office == null:
		return
	
	# Získanie všetkých spawn pointov v aktuálnej kancelárii
	# Reprezentujú všetky možné pozície pre PC
	var points = latest_office.get_node("SpawnPoints").get_children()
	# Získanie už obsadených spawn pointov
	# Sledujeme, ktoré miesta sú už obsadené
	var used = office_used_points[latest_office]
	# Zoznam voľných (neobsadených) spawn pointov
	var available = []
	
	# Prejdeme všetky spawn pointy a vyberieme len tie, ktoré ešte neboli použité
	for p in points:
		if p not in used:
			available.append(p)
		
	# Ak neexistuje žiadne voľné miesto, funkcia končí, miestnosť je plná (ochrana pred chybou)
	if available.is_empty():
		return
	
	# Náhodný výber jedného voľného spawn pointu
	# Zabezpečuje variabilitu rozloženia 
	var chosen = available.pick_random()
	# Označenie tohto spawn pointu ako obsadeného
	# Zabraňuje spawnnutiu viacerých PC na rovnaké miesto
	used.append(chosen)
	
	# Vytvorenie novej inštancie PC
	var pc = pc_scene.instantiate()
	# Nastavenie pozície PC podľa vybraného spawn pointu
	pc.global_position = chosen.global_position
	# Pridanie PC do scény (aktivácia v hre)
	add_child(pc)
	
	# Výber náhodnej farby zo všetkých doteraz dostupných farieb
	# Čím viac serverov vznikne, tým viac farieb môže PC dostať
	# Zvyšuje sa komplexita a tlak na hráča
	var random_color = available_colors.pick_random()
	# Nastavenie stavu PC:
	# - farba (typ pripojenia)
	# - smer (vizuál + logika)
	# - false = zatiaľ nepripojený (OFF stav)
	pc.set_state(random_color, chosen.facing, false)
	
	# Debug výpis pre kontrolu
	if available_colors.is_empty():
		print("NO COLORS AVAILABLE")
		return

# -------------------------
# TIMER LOOP
# -------------------------
func _on_spawn_timer_timeout():
	if latest_office == null:
		return
	
	if can_spawn_pc():
		spawn_pc()
	else:
		print("ROOM FULL -> spawning new office")
		spawn_new_office()
	
	# Náhodný interval spawnovania
	spawn_timer.wait_time = randf_range(1.0, 2.0)
	spawn_timer.start()
