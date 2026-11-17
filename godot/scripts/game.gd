extends Node3D
## WonderWorld 3D demo: a native Godot game with offline practice and WebSocket rooms.
## Everything in the demo world is made from simple colored meshes; no paid assets.

const AvatarScript = preload("res://scripts/avatar.gd")
const NetworkScript = preload("res://scripts/network.gd")
const JoystickScript = preload("res://scripts/virtual_joystick.gd")
const CityWorldScript = preload("res://scripts/wonder_city.gd")
const MiniMapScript = preload("res://scripts/city_minimap.gd")
const WorldActivitiesScript = preload("res://scripts/world_activities.gd")
const ShopScript = preload("res://scripts/wonder_shop.gd")
const ALIASES: Array[String] = ["Sunny", "Rocket", "Pixel", "Comet", "Star", "Sprout", "Bubbles", "Nova"]
const COIN_POSITIONS: Array[Vector3] = [
	Vector3(0, 1.15, 6), Vector3(5, 1.15, 1), Vector3(-5, 1.15, 1),
	Vector3(10, 1.15, 10), Vector3(-10, 1.15, 10),
	Vector3(0, 1.15, -14), Vector3(0, 1.15, -24), Vector3(0, 1.15, -30),
	Vector3(-28, 1.15, 20), Vector3(-34, 1.15, 25),
	Vector3(-34, 1.15, -30), Vector3(-40, 1.15, -29),
	Vector3(20, 1.15, 17), Vector3(40, 1.15, 17),
	Vector3(40, 1.15, 35), Vector3(20, 1.15, 35),
	Vector3(17, 1.5, -29), Vector3(22, 1.65, -25),
	Vector3(27, 2.8, -26), Vector3(37, 3.85, -27)
]

var network
var camera: Camera3D
var menu_overlay: ColorRect
var hud: Control
var hud_score: Label
var hud_status: Label
var hud_room: Label
var hud_rankings: Label
var friends_panel: PanelContainer
var room_copy_button: Button
var menu_status: Label
var join_input: LineEdit
var alias_selector: OptionButton
var joystick
var music_player: AudioStreamPlayer
var local_player
var players: Dictionary = {}    # server id -> remote avatar
var scores: Dictionary = {}     # server id -> {n, score}
var coins: Dictionary = {}      # coin id -> {area, mesh, timer}
var pending_coins: Dictionary = {}
var pending_room: String = ""
var active_room: String = ""
var active_alias: String = "Sunny"
var active_color: int = 0
var playing: bool = false
var multiplayer_mode: bool = false
var current_score: int = 0
var jump_requested: bool = false
var move_timer: float = 0.0
var offline_seconds: float = 0.0
var orbit_time: float = 0.0
# Adventure City v0.2 systems. Multiplayer still uses the original server protocol.
var city_world: Node3D
var pet_companion: Node3D
var ride_shell: Node3D
var pet_enabled: bool = false
var car_enabled: bool = false
var pet_button: Button
var car_button: Button
var quest_label: Label
var city_map
var action_button: Button
var race_running: bool = false
var race_time: float = 0.0
var race_gate: int = 0
var last_zone_name: String = ""
var slide_reuse_timer: float = 0.0
var slide_count: int = 0
const RACE_GATES = [Vector2(20,17), Vector2(44,17), Vector2(44,35), Vector2(20,35), Vector2(20,17)]
var district_label: Label
var world_activities: Node3D
var shop: CanvasLayer
var battle_button: Button
var district_timer: float = 0.0
var districts_seen: Dictionary = {}
var travel_index: int = 0
var travel_pending: bool = false
var pending_travel_stop: int = -1
const TRAVEL_STOPS: Array[Vector3] = [
	Vector3(0, 1.55, 12.0),
	Vector3(0, 1.55, -25.0),
	Vector3(-34, 1.55, 21.0),
	Vector3(-32, 1.55, -31.0),
	Vector3(25, 1.55, 17.5),
	Vector3(24, 1.55, -25.0)
]
const TRAVEL_NAMES: Array[String] = [
	"Central Plaza", "Adventure Castle", "Pet Garden",
	"Splash Water Park", "Racing Challenge", "Rainbow Obby"
]
const DISTRICTS = [
    {"name":"Adventure Castle", "point": Vector2(0, -35), "radius": 12.0},
    {"name":"Pet Garden", "point": Vector2(-34, 22), "radius": 12.0},
    {"name":"Splash Water Park", "point": Vector2(-32, -31), "radius": 13.5},
    {"name":"Racing Challenge", "point": Vector2(32, 26), "radius": 14.5},
    {"name":"Rainbow Obby", "point": Vector2(31, -29), "radius": 14.5}
]


func _ready() -> void:
	randomize()
	network = NetworkScript.new()
	add_child(network)
	network.event_received.connect(_network_message)
	network.connection_changed.connect(_network_status)
	network.connection_lost.connect(_network_lost)
	_build_world()
	_build_interface()
	_start_music()

func _physics_process(delta: float) -> void:
	if not playing or local_player == null:
		return
	var key_axis := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var pad_axis: Vector2 = joystick.axis
	var axis := pad_axis if pad_axis.length() > 0.08 else key_axis
	var is_jump := jump_requested or Input.is_action_just_pressed("jump")
	jump_requested = false
	# Do not send old location while the server is confirming fast travel.
	if travel_pending or (world_activities != null and world_activities.is_riding()):
		return
	local_player.control_move(axis, is_jump, delta)
	if multiplayer_mode and network.connected:
		move_timer += delta
		if move_timer >= network.SEND_INTERVAL:
			move_timer = 0.0
			network.send_position(local_player.global_position, local_player.rotation.y)

func _process(delta: float) -> void:
	if playing and local_player != null:
		var desired: Vector3 = local_player.global_position + Vector3(0, 5.75, 9.6)
		camera.global_position = camera.global_position.lerp(desired, minf(1.0, delta * 5.0))
		camera.look_at(local_player.global_position + Vector3(0, 1.45, 0))
		if city_map != null:
			city_map.set_world_position(local_player.global_position)
		if race_running:
			race_time += delta
			if race_time >= 90.0:
				race_running = false
				hud_status.text = "Race expired! Return to the Raceway and try again."
			else:
				_check_race()
		if pet_enabled and is_instance_valid(pet_companion):
			var follow: Vector3 = local_player.global_position + Vector3(-1.7, -0.40, 1.5)
			pet_companion.global_position = pet_companion.global_position.lerp(follow, minf(1.0, delta * 5.0))
			pet_companion.rotation.y = local_player.rotation.y
		district_timer += delta
		if district_timer >= 0.45:
			district_timer = 0.0
			_update_districts()
	else:
		orbit_time += delta
		camera.global_position = Vector3(13.5 * sin(orbit_time * 0.06), 10.0, 17.5)
		camera.look_at(Vector3(0, 0.9, 0))
	for id in coins.keys():
		var info: Dictionary = coins[id]
		var mesh: Node3D = info["mesh"]
		if mesh.visible:
			mesh.rotation.y += delta * 2.5
			mesh.position.y = 0.17 * sin(Time.get_ticks_msec() * 0.003 + int(id))
		if not multiplayer_mode and float(info["timer"]) > 0.0:
			info["timer"] = float(info["timer"]) - delta
			coins[id] = info
			if float(info["timer"]) <= 0.0:
				_show_coin(int(id))

func _material(color: Color, glowing: bool = false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.76
	if glowing:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 0.16
	return m

func _block(where: Vector3, dims: Vector3, color: Color, physical: bool = true) -> Node3D:
	var parent: Node3D = StaticBody3D.new() if physical else Node3D.new()
	parent.position = where
	add_child(parent)
	var visual := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = dims
	visual.mesh = box
	visual.material_override = _material(color)
	parent.add_child(visual)
	if physical:
		var collider := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = dims
		collider.shape = shape
		parent.add_child(collider)
	return parent

func _cylinder(where: Vector3, top_r: float, bottom_r: float, height: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var geo := CylinderMesh.new()
	geo.top_radius = top_r
	geo.bottom_radius = bottom_r
	geo.height = height
	node.mesh = geo
	node.material_override = _material(color)
	node.position = where
	add_child(node)
	return node

func _sphere(where: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var geo := SphereMesh.new()
	geo.radius = radius
	geo.height = radius * 2.0
	geo.radial_segments = 12
	geo.rings = 6
	node.mesh = geo
	node.material_override = _material(color)
	node.position = where
	add_child(node)
	return node

func _tree(x: float, z: float, scale_factor: float, pink: bool = false) -> void:
	_cylinder(Vector3(x, 0.95 * scale_factor, z), 0.20 * scale_factor, 0.32 * scale_factor, 1.9 * scale_factor, Color("a8754e"))
	var foliage := Color("ff98b7") if pink else Color("4dcc8c")
	_sphere(Vector3(x, 2.45 * scale_factor, z), 1.1 * scale_factor, foliage)
	_sphere(Vector3(x + 0.48 * scale_factor, 2.24 * scale_factor, z), 0.79 * scale_factor, foliage.lightened(0.17))
	_sphere(Vector3(x - 0.48 * scale_factor, 2.24 * scale_factor, z), 0.77 * scale_factor, foliage.darkened(0.1))

func _flower(x: float, z: float, color: Color) -> void:
	_cylinder(Vector3(x, 0.18, z), 0.025, 0.035, 0.37, Color("39a777"))
	_sphere(Vector3(x, 0.37, z), 0.13, color)

func _build_world() -> void:
	# Proper art-direction: contrast first, warm evening sunlight, saturated ground,
	# stone streets and hand-textured shop roofs. The old overexposed white island
	# is replaced entirely by a walkable city with five activity districts.
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("3d91bd")
	sky_mat.sky_horizon_color = Color("a0cce3")
	sky_mat.ground_bottom_color = Color("74a0ac")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.42
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.adjustment_enabled = true
	env.adjustment_brightness = 0.81
	env.adjustment_contrast = 1.14
	env.adjustment_saturation = 1.14
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-54, -28, -2)
	sun.light_color = Color("ffe4bb")
	sun.light_energy = 0.82
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 60.0
	camera.position = Vector3(0, 8, 18)
	camera.current = true
	add_child(camera)
	city_world = CityWorldScript.new()
	city_world.name = "WonderCity"
	add_child(city_world)
	for id in COIN_POSITIONS.size():
		_add_coin(id, COIN_POSITIONS[id])
	world_activities = WorldActivitiesScript.new()
	world_activities.name = "WonderWorldActivities"
	add_child(world_activities)
	world_activities.activity_finished.connect(_on_activity_finished)
	world_activities.battle_finished.connect(_on_battle_finished)

func _add_coin(id: int, pos: Vector3) -> void:
	var area := Area3D.new()
	area.position = pos
	area.collision_layer = 0
	area.collision_mask = 1
	area.monitoring = true
	add_child(area)
	var hit := CollisionShape3D.new()
	var shape := SphereShape3D.new()
	shape.radius = 0.95
	hit.shape = shape
	area.add_child(hit)
	var spin := Node3D.new()
	area.add_child(spin)
	var jewel := MeshInstance3D.new()
	var geo := SphereMesh.new()
	geo.radius = 0.42
	geo.height = 0.78
	geo.radial_segments = 8
	geo.rings = 4
	jewel.mesh = geo
	jewel.scale = Vector3(0.78, 1.0, 0.43)
	jewel.material_override = _material(Color("ffe36a"), true)
	spin.add_child(jewel)
	var halo := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.48
	ring.outer_radius = 0.55
	ring.rings = 9
	ring.ring_segments = 16
	halo.mesh = ring
	halo.rotation.x = PI * 0.50
	halo.material_override = _material(Color("ffffff"), true)
	spin.add_child(halo)
	coins[id] = {"area": area, "mesh": spin, "timer": 0.0}
	area.body_entered.connect(func(body: Node3D): _touch_coin(body, id))

func _touch_coin(body: Node3D, id: int) -> void:
	if not playing or body != local_player or pending_coins.has(id):
		return
	if not coins.has(id) or not (coins[id]["mesh"] as Node3D).visible:
		return
	if multiplayer_mode and network.connected:
		pending_coins[id] = true
		network.collect_coin(id)
	elif not multiplayer_mode:
		_mark_coin_taken(id)
		current_score += 10
		coins[id]["timer"] = 24.0
		_update_hud()
		_play_coin_sound()

func _mark_coin_taken(id: int) -> void:
	if not coins.has(id):
		return
	var area: Area3D = coins[id]["area"]
	area.visible = false
	area.set_deferred("monitoring", false)

func _show_coin(id: int) -> void:
	if not coins.has(id):
		return
	var area: Area3D = coins[id]["area"]
	area.visible = true
	area.set_deferred("monitoring", true)
	var data: Dictionary = coins[id]
	data["timer"] = 0.0
	coins[id] = data
	pending_coins.erase(id)

func _build_interface() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)
	# Start menu over a live view of the 3D scene.
	menu_overlay = ColorRect.new()
	menu_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu_overlay.color = Color(0.016, 0.036, 0.087, 0.62)
	menu_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	root.add_child(menu_overlay)
	var menu_panel := PanelContainer.new()
	menu_panel.anchor_left = 0.5
	menu_panel.anchor_right = 0.5
	menu_panel.anchor_top = 0.5
	menu_panel.anchor_bottom = 0.5
	menu_panel.offset_left = -283
	menu_panel.offset_right = 283
	menu_panel.offset_top = -298
	menu_panel.offset_bottom = 298
	menu_panel.add_theme_stylebox_override("panel", _style(Color("20384f"), 24, Color("e5bd72"), 3))
	menu_overlay.add_child(menu_panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_top", 26)
	margin.add_theme_constant_override("margin_bottom", 23)
	margin.add_theme_constant_override("margin_left", 32)
	margin.add_theme_constant_override("margin_right", 32)
	menu_panel.add_child(margin)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 10)
	margin.add_child(stack)
	var title := _label("WONDERWORLD", 49, Color("ffdf8e"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var subtitle := _label("ADVENTURE CITY  •  PETS  •  RACES  •  SPLASH", 16, Color("d6efff"))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(subtitle)
	stack.add_child(_gap(5))
	var alias_heading := _label("CHOOSE YOUR ADVENTURER", 17, Color("c9e9f6"))
	stack.add_child(alias_heading)
	alias_selector = OptionButton.new()
	alias_selector.custom_minimum_size.y = 47
	for alias in ALIASES:
		alias_selector.add_item(alias)
	alias_selector.select(0)
	stack.add_child(alias_selector)
	var create_button := _button("CREATE PRIVATE ROOM", Color("30bba3"))
	create_button.pressed.connect(_create_room)
	stack.add_child(create_button)
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", 8)
	join_input = LineEdit.new()
	join_input.placeholder_text = "8-character room code"
	join_input.max_length = 8
	join_input.custom_minimum_size.y = 48
	join_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(join_input)
	var join_button := _button("JOIN", Color("5b88f0"))
	join_button.custom_minimum_size.x = 110
	join_button.pressed.connect(_join_room)
	join_row.add_child(join_button)
	stack.add_child(join_row)
	var practice := _button("PRACTICE OFFLINE", Color("e7a449"))
	practice.pressed.connect(_practice)
	stack.add_child(practice)
	stack.add_child(_gap(4))
	menu_status = _label("Explore 5 adventure zones offline. Friends rooms need a configured free server.", 15, Color("bce2ec"))
	menu_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(menu_status)
	var note := _label("Private codes • No open chat • No real-money purchases", 13, Color("88aac3"))
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(note)
	
	# In-game HUD.
	hud = Control.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hud)
	hud.visible = false
	var score_panel := PanelContainer.new()
	score_panel.position = Vector2(22, 22)
	score_panel.custom_minimum_size = Vector2(365, 78)
	score_panel.add_theme_stylebox_override("panel", _style(Color("1d3c56"), 17, Color("7ec7bc"), 2))
	hud.add_child(score_panel)
	var score_wrap := VBoxContainer.new()
	score_wrap.add_theme_constant_override("separation", 3)
	score_panel.add_child(score_wrap)
	hud_score = _label("✦ 0 POINTS", 26, Color("ffdf84"))
	score_wrap.add_child(hud_score)
	hud_status = _label("Explore, collect gems and unlock every district!", 14, Color("e2f3ff"))
	score_wrap.add_child(hud_status)
	friends_panel = PanelContainer.new()
	friends_panel.anchor_left = 1.0
	friends_panel.anchor_right = 1.0
	friends_panel.offset_left = -230
	friends_panel.offset_right = -18
	friends_panel.offset_top = 22
	friends_panel.offset_bottom = 190
	friends_panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.16, 0.28, 0.78), 16, Color(0.4, 0.85, 0.95, 0.45), 1))
	hud.add_child(friends_panel)
	hud_rankings = _label("FRIENDS\n\nYou • 0", 18, Color("eaf6ff"))
	hud_rankings.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	friends_panel.add_child(hud_rankings)
	var city_map_panel := PanelContainer.new()
	city_map_panel.anchor_left = 1.0
	city_map_panel.anchor_right = 1.0
	city_map_panel.offset_left = -254
	city_map_panel.offset_right = -18
	city_map_panel.offset_top = 207
	city_map_panel.offset_bottom = 383
	city_map_panel.add_theme_stylebox_override("panel", _style(Color("173046"), 13, Color("3b9caa"), 1))
	hud.add_child(city_map_panel)
	city_map = MiniMapScript.new()
	city_map.mouse_filter = Control.MOUSE_FILTER_IGNORE
	city_map_panel.add_child(city_map)
	var room_panel := PanelContainer.new()
	room_panel.anchor_left = 0.5
	room_panel.anchor_right = 0.5
	room_panel.offset_left = -185
	room_panel.offset_right = 185
	room_panel.offset_top = 20
	room_panel.offset_bottom = 66
	room_panel.add_theme_stylebox_override("panel", _style(Color("22415d"), 15))
	hud.add_child(room_panel)
	var room_box := HBoxContainer.new()
	room_box.alignment = BoxContainer.ALIGNMENT_CENTER
	room_panel.add_child(room_box)
	hud_room = _label("PRACTICE", 18, Color("f8faff"))
	room_box.add_child(hud_room)
	room_copy_button = _button("COPY", Color("348ead"))
	room_copy_button.custom_minimum_size = Vector2(83, 36)
	room_copy_button.pressed.connect(_copy_room)
	room_box.add_child(room_copy_button)
	var home_button := _button("HOME", Color("ce6b88"))
	home_button.position = Vector2(22, 215)
	home_button.custom_minimum_size = Vector2(112, 46)
	home_button.pressed.connect(_back_to_menu)
	hud.add_child(home_button)
	var explore_button := _button("EXPLORE ▶", Color("348e91"))
	explore_button.position = Vector2(22, 275)
	explore_button.custom_minimum_size = Vector2(156, 47)
	explore_button.pressed.connect(_quick_travel)
	hud.add_child(explore_button)
	joystick = JoystickScript.new()
	joystick.anchor_left = 0.0
	joystick.anchor_right = 0.0
	joystick.anchor_top = 1.0
	joystick.anchor_bottom = 1.0
	joystick.offset_left = 34
	joystick.offset_right = 211
	joystick.offset_top = -212
	joystick.offset_bottom = -35
	hud.add_child(joystick)
	var jump_button := _button("JUMP", Color("ef866d"))
	jump_button.anchor_left = 1.0
	jump_button.anchor_right = 1.0
	jump_button.anchor_top = 1.0
	jump_button.anchor_bottom = 1.0
	jump_button.offset_left = -187
	jump_button.offset_right = -38
	jump_button.offset_top = -174
	jump_button.offset_bottom = -45
	jump_button.add_theme_font_size_override("font_size", 28)
	jump_button.pressed.connect(func(): jump_requested = true)
	hud.add_child(jump_button)
	# Live quest tracker is visible during both offline and online play.
	var district_panel := PanelContainer.new()
	district_panel.position = Vector2(22, 111)
	district_panel.custom_minimum_size = Vector2(365, 89)
	district_panel.add_theme_stylebox_override("panel", _style(Color("294b60"), 14, Color("48af97"), 2))
	hud.add_child(district_panel)
	var district_stack := VBoxContainer.new()
	district_stack.add_theme_constant_override("separation", 3)
	district_panel.add_child(district_stack)
	district_label = _label("WELCOME TO ADVENTURE CITY", 17, Color("fff2c4"))
	district_stack.add_child(district_label)
	quest_label = _label("DISCOVER 5 DISTRICTS  •  0/5", 14, Color("c2f7e9"))
	district_stack.add_child(quest_label)
	pet_button = _button("PET", Color("3eaf93"))
	pet_button.anchor_left = 1.0
	pet_button.anchor_right = 1.0
	pet_button.anchor_top = 1.0
	pet_button.anchor_bottom = 1.0
	pet_button.offset_left = -461
	pet_button.offset_right = -350
	pet_button.offset_top = -136
	pet_button.offset_bottom = -81
	pet_button.pressed.connect(_toggle_pet)
	hud.add_child(pet_button)
	car_button = _button("DRIVE", Color("518bc1"))
	car_button.anchor_left = 1.0
	car_button.anchor_right = 1.0
	car_button.anchor_top = 1.0
	car_button.anchor_bottom = 1.0
	car_button.offset_left = -338
	car_button.offset_right = -202
	car_button.offset_top = -136
	car_button.offset_bottom = -81
	car_button.pressed.connect(_toggle_car)
	hud.add_child(car_button)
	action_button = _button("QUEST", Color("8e75c6"))
	action_button.anchor_left = 1.0
	action_button.anchor_right = 1.0
	action_button.anchor_top = 1.0
	action_button.anchor_bottom = 1.0
	action_button.offset_left = -335
	action_button.offset_right = -205
	action_button.offset_top = -206
	action_button.offset_bottom = -151
	action_button.pressed.connect(_use_zone_action)
	hud.add_child(action_button)
	var shop_button := _button("SHOP", Color("ae77b2"))
	shop_button.position = Vector2(22, 337)
	shop_button.custom_minimum_size = Vector2(150, 46)
	shop_button.pressed.connect(_open_store)
	hud.add_child(shop_button)
	battle_button = _button("BATTLE", Color("e39752"))
	battle_button.position = Vector2(22, 395)
	battle_button.custom_minimum_size = Vector2(150, 46)
	battle_button.pressed.connect(_on_battle_pressed)
	hud.add_child(battle_button)
	shop = ShopScript.new()
	shop.controller = self
	add_child(shop)
	_update_hud()

func _style(color: Color, radius: int, border_color: Color = Color.TRANSPARENT, border: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_border_width_all(border)
	s.border_color = border_color
	s.content_margin_left = 17
	s.content_margin_right = 17
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0.02, 0.06, 0.12, 0.30)
	s.shadow_size = 3
	s.shadow_offset = Vector2(0, 2)
	return s

func _label(value: String, font_size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = value
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", color)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _button(value: String, color: Color) -> Button:
	var btn := Button.new()
	btn.text = value
	btn.custom_minimum_size.y = 49
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_color_override("font_color", Color.WHITE)
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", Color.WHITE)
	btn.add_theme_stylebox_override("normal", _style(color.darkened(0.1), 14))
	btn.add_theme_stylebox_override("hover", _style(color.lightened(0.17), 14))
	btn.add_theme_stylebox_override("pressed", _style(color.darkened(0.25), 14))
	return btn

func _gap(height: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = height
	return c

func _read_alias() -> void:
	active_color = maxi(0, alias_selector.selected) % 8
	active_alias = ALIASES[active_color]

func _random_code() -> String:
	const CHARS := "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
	var code := ""
	for i in 8:
		code += CHARS[randi_range(0, CHARS.length() - 1)]
	return code

func _create_room() -> void:
	_read_alias()
	if not network.configured():
		menu_status.text = "Online server not configured. Edit scripts/network.gd and add your Cloudflare URL."
		return
	pending_room = _random_code()
	if network.connect_room(pending_room, active_alias, active_color):
		_start_play(true, pending_room)

func _join_room() -> void:
	_read_alias()
	var code := join_input.text.strip_edges().to_upper()
	if code.length() != 8:
		menu_status.text = "Please enter the friend's 8-character room code."
		return
	for i in code.length():
		if not "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".contains(code[i]):
			menu_status.text = "Room codes use A–Z and 2–9 only."
			return
	if not network.configured():
		menu_status.text = "Online server not configured. Set the free Cloudflare Worker URL first."
		return
	pending_room = code
	if network.connect_room(code, active_alias, active_color):
		_start_play(true, code)

func _practice() -> void:
	_read_alias()
	network.disconnect_room()
	_start_play(false, "")

func _start_play(is_multi: bool, code: String) -> void:
	playing = true
	multiplayer_mode = is_multi
	active_room = code
	travel_index = 0
	travel_pending = false
	pending_travel_stop = -1
	friends_panel.visible = is_multi
	room_copy_button.visible = is_multi
	current_score = shop.get_wallet() if not is_multi else 0
	districts_seen.clear()
	pet_enabled = false
	car_enabled = false
	race_running = false
	race_gate = 0
	race_time = 0.0
	slide_count = 0
	slide_reuse_timer = 0.0
	last_zone_name = ""
	world_activities.reset_player()
	if battle_button != null:
		battle_button.text = "BATTLE"
	shop.hide_shop()
	pending_coins.clear()
	scores.clear()
	for peer in players.values():
		(peer as Node).queue_free()
	players.clear()
	for id in coins.keys():
		_show_coin(int(id))
	if local_player != null:
		local_player.queue_free()
	local_player = AvatarScript.new()
	local_player.configure(active_alias, active_color, true)
	local_player.position = Vector3(0, 1.55, 9.7)
	add_child(local_player)
	if is_instance_valid(pet_companion):
		pet_companion.queue_free()
	pet_companion = _make_pet_companion()
	pet_companion.visible = false
	pet_companion.global_position = Vector3(-1.7, 1.05, 11.4)
	if is_instance_valid(ride_shell):
		ride_shell.queue_free()
	ride_shell = _make_ride_shell()
	ride_shell.visible = false
	world_activities.watch_player = local_player
	shop.apply_equipment()
	pet_button.text = "PET"
	car_button.text = "DRIVE"
	move_timer = 0.0
	menu_overlay.visible = false
	hud.visible = true
	_update_hud()

func _complete_travel(stop: int) -> void:
	if local_player == null or stop < 0 or stop >= TRAVEL_STOPS.size():
		return
	travel_index = stop
	local_player.global_position = TRAVEL_STOPS[stop]
	local_player.velocity = Vector3.ZERO
	hud_status.text = "Now visiting: " + TRAVEL_NAMES[stop]
	_update_districts()

func _request_travel_to(stop: int) -> void:
	if not playing or local_player == null:
		return
	if multiplayer_mode:
		if not network.connected:
			hud_status.text = "Connecting to your private room…"
			return
		if travel_pending:
			hud_status.text = "Confirming previous travel…"
			return
		travel_pending = true
		pending_travel_stop = stop
		network.request_travel(stop)
		hud_status.text = "Traveling to: " + TRAVEL_NAMES[stop]
		return
	_complete_travel(stop)

func _quick_travel() -> void:
	# Online travel must be acknowledged by the server to avoid desync.
	if not playing or local_player == null:
		return
	_request_travel_to((travel_index + 1) % TRAVEL_STOPS.size())

func _back_to_menu() -> void:
	network.disconnect_room()
	playing = false
	multiplayer_mode = false
	shop.hide_shop()
	world_activities.reset_player()
	world_activities.watch_player = null
	active_room = ""
	travel_pending = false
	pending_travel_stop = -1
	pending_coins.clear()
	if local_player != null:
		local_player.queue_free()
		local_player = null
	if is_instance_valid(pet_companion):
		pet_companion.queue_free()
		pet_companion = null
	ride_shell = null
	pet_enabled = false
	car_enabled = false
	for peer in players.values():
		(peer as Node).queue_free()
	players.clear()
	scores.clear()
	menu_overlay.visible = true
	hud.visible = false
	menu_status.text = "Play offline or invite friends using the same private room code."

func _copy_room() -> void:
	if active_room != "":
		DisplayServer.clipboard_set(active_room)
		hud_status.text = "Copied room code! Share it with a friend."
	else:
		hud_status.text = "Offline practice: no room code needed."

func _network_status(message: String) -> void:
	if playing:
		hud_status.text = message
	else:
		menu_status.text = message

func _network_lost(message: String) -> void:
	if playing and multiplayer_mode:
		multiplayer_mode = false
		travel_pending = false
		pending_travel_stop = -1
		for peer in players.values():
			(peer as Node).queue_free()
		players.clear()
		scores.clear()
		hud_status.text = "Connection lost. Continue exploring offline."
		_update_hud()
	else:
		menu_status.text = message

func _spawn_remote(info: Dictionary) -> void:
	var id := str(info.get("id", ""))
	if id == "" or id == network.local_id:
		return
	if players.has(id):
		return
	var p = AvatarScript.new()
	p.configure(str(info.get("n", "Friend")), int(info.get("c", 0)), false)
	p.position = Vector3(float(info.get("x", 0)), float(info.get("y", 1.5)), float(info.get("z", 0)))
	add_child(p)
	players[id] = p
	scores[id] = {"n": str(info.get("n", "Friend")), "score": int(info.get("score", 0))}

func _network_message(data: Dictionary) -> void:
	if not playing or not multiplayer_mode:
		return
	var t: String = str(data.get("t", ""))
	match t:
		"travel_ok":
			var stop: int = int(data.get("stop", -1))
			if travel_pending and stop == pending_travel_stop:
				_complete_travel(stop)
			travel_pending = false
			pending_travel_stop = -1
		"travel_reject":
			travel_pending = false
			pending_travel_stop = -1
			hud_status.text = str(data.get("reason", "Travel not available yet"))
		"welcome":
			network.local_id = str(data.get("id", ""))
			current_score = int(data.get("score", 0))
			scores[network.local_id] = {"n": active_alias, "score": current_score}
			for p in data.get("players", []):
				if typeof(p) == TYPE_DICTIONARY:
					_spawn_remote(p)
			for id in coins.keys():
				_show_coin(int(id))
			for taken in data.get("taken", []):
				_mark_coin_taken(int(taken))
			hud_status.text = "Connected! Find gems, climb platforms, explore with friends."
			_update_hud()
		"join":
			if typeof(data.get("player")) == TYPE_DICTIONARY:
				_spawn_remote(data["player"])
			_update_hud()
		"move":
			var id := str(data.get("id", ""))
			if players.has(id):
				players[id].set_remote_state(
					Vector3(float(data.get("x", 0)), float(data.get("y", 1)), float(data.get("z", 0))),
					float(data.get("r", 0)))
		"leave":
			var id := str(data.get("id", ""))
			if players.has(id):
				(players[id] as Node).queue_free()
				players.erase(id)
				scores.erase(id)
				_update_hud()
		"score":
			var id := str(data.get("id", ""))
			var score := int(data.get("score", 0))
			if scores.has(id):
				var sc: Dictionary = scores[id]
				sc["score"] = score
				scores[id] = sc
			if id == network.local_id:
				current_score = score
				_play_coin_sound()
			if data.has("coin"):
				_mark_coin_taken(int(data["coin"]))
				pending_coins.erase(int(data["coin"]))
			_update_hud()
		"reset":
			for id in data.get("coins", []):
				_show_coin(int(id))
		"reject":
			pending_coins.erase(int(data.get("coin", -1)))
		"error":
			hud_status.text = str(data.get("reason", "Server error"))

func _update_hud() -> void:
	if hud_score == null:
		return
	if playing and not multiplayer_mode and shop != null:
		shop.persist_wallet(current_score)
	hud_score.text = "✦ %d POINTS" % current_score
	if quest_label != null:
		quest_label.text = "DISCOVER THE CITY  •  %d/5 ZONES" % districts_seen.size()
	hud_room.text = ("ROOM " + active_room) if multiplayer_mode else "ADVENTURE CITY"
	var text := "FRIENDS\n\n"
	if not multiplayer_mode:
		text += "%s  •  %d" % [active_alias, current_score]
	else:
		var ranking: Array = scores.values()
		ranking.sort_custom(func(a: Dictionary, b: Dictionary): return int(a["score"]) > int(b["score"]))
		for s in ranking.slice(0, 8):
			text += "%s  •  %d\n" % [str(s["n"]), int(s["score"])]
		if ranking.is_empty():
			text += "Connecting …"
	hud_rankings.text = text

func _update_districts() -> void:
	if not playing or local_player == null:
		return
	var player_pos: Vector2 = Vector2(local_player.global_position.x, local_player.global_position.z)
	var nearby: String = "CENTRAL TOWN"
	for zone in DISTRICTS:
		var zone_name: String = str(zone["name"])
		var center: Vector2 = zone["point"]
		var radius: float = float(zone["radius"])
		if player_pos.distance_to(center) < radius:
			nearby = zone_name.to_upper()
			if not districts_seen.has(zone_name):
				districts_seen[zone_name] = true
				if not multiplayer_mode:
					current_score += 25
					_play_coin_sound()
				hud_status.text = "NEW DISTRICT! %s • +25 explore points" % zone_name if not multiplayer_mode else "Discovered %s!" % zone_name
				_update_hud()
			break
	if district_label != null:
		district_label.text = "EXPLORE  •  " + nearby
	if action_button != null:
		match nearby:
			"SPLASH WATER PARK":
				action_button.text = "SLIDE"
			"RACING CHALLENGE":
				action_button.text = "RACE" if not race_running else "RACING"
			"RAINBOW OBBY":
				action_button.text = "OBBY"
			_:
				action_button.text = "QUEST"
	if world_activities != null and action_button != null:
		var nearby_action: String = world_activities.prompt_at(local_player.global_position)
		if nearby_action != "":
			action_button.text = nearby_action
	last_zone_name = nearby

func _check_race() -> void:
	if not race_running or local_player == null:
		return
	var at: Vector2 = Vector2(local_player.global_position.x, local_player.global_position.z)
	if at.distance_to(RACE_GATES[race_gate]) < 4.5:
		race_gate += 1
		if race_gate >= RACE_GATES.size():
			race_running = false
			hud_status.text = "RACE FINISHED! %0.1f seconds" % race_time
			if not multiplayer_mode:
				current_score += 100
				_play_coin_sound()
				_update_hud()
		else:
			hud_status.text = "RACE  •  Checkpoint %d/%d" % [race_gate, RACE_GATES.size()]

func _use_zone_action() -> void:
	if not playing or local_player == null:
		return
	var near: String = world_activities.prompt_at(local_player.global_position)
	if near == "OPEN STORE":
		_open_store()
		return
	if near == "FOAM TAG":
		_on_battle_pressed()
		return
	if near != "":
		if multiplayer_mode:
			hud_status.text = "Interactive attractions currently work in offline practice."
			return
		var result: String = world_activities.use_nearby(local_player)
		if result != "":
			hud_status.text = result
			return
	match last_zone_name:
		"SPLASH WATER PARK":
			if multiplayer_mode:
				hud_status.text = "The water slide is currently offline-only."
				return
			hud_status.text = world_activities.begin_slide(local_player)
		"RACING CHALLENGE":
			if not car_enabled:
				_toggle_car()
			race_running = true
			race_time = 0.0
			race_gate = 0
			_request_travel_to(4)
			hud_status.text = "GO! Follow the five race checkpoints within 90 seconds."
		"RAINBOW OBBY":
			_request_travel_to(5)
			hud_status.text = "Rainbow Obby: jump across all the platforms to the gold flag!"
		_:
			hud_status.text = "QUEST: Find 5 districts, collect gems, adopt your pet and race!"

func _pet_piece(parent: Node3D, where: Vector3, radius: float, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	mi.mesh = mesh
	mi.position = where
	mi.material_override = _material(color)
	parent.add_child(mi)

func _make_pet_companion() -> Node3D:
	var pet := Node3D.new()
	pet.name = "PetCompanion"
	add_child(pet)
	_pet_piece(pet, Vector3(0, 0.12, 0), 0.48, Color("ffc98c"))
	_pet_piece(pet, Vector3(0, 0.44, -0.25), 0.42, Color("ffe0ab"))
	_pet_piece(pet, Vector3(-0.34, 0.78, -0.24), 0.22, Color("cc8359"))
	_pet_piece(pet, Vector3(0.34, 0.78, -0.24), 0.22, Color("cc8359"))
	_pet_piece(pet, Vector3(-0.15, 0.47, -0.59), 0.075, Color("243454"))
	_pet_piece(pet, Vector3(0.15, 0.47, -0.59), 0.075, Color("243454"))
	_pet_piece(pet, Vector3(0, 0.31, -0.63), 0.12, Color("a85763"))
	_pet_piece(pet, Vector3(0.1, 0.17, 0.51), 0.23, Color("f4b66d"))
	return pet

func _ride_piece(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = _material(color)
	parent.add_child(mi)

func _make_ride_shell() -> Node3D:
	var shell := Node3D.new()
	shell.name = "CarRide"
	local_player.add_child(shell)
	shell.position = Vector3(0, -0.45, 0.0)
	_ride_piece(shell, Vector3(0, -0.26, 0), Vector3(2.4, 0.45, 1.5), Color("ed6b70"))
	_ride_piece(shell, Vector3(0, -0.01, -0.1), Vector3(1.2, 0.55, 1.17), Color("f6ad70"))
	_ride_piece(shell, Vector3(0, 0.12, -0.72), Vector3(0.90, 0.28, 0.12), Color("416f98"))
	for x in [-0.78, 0.78]:
		for z in [-0.61, 0.61]:
			_pet_piece(shell, Vector3(x, -0.43, z), 0.34, Color("283447"))
	return shell

func _toggle_pet() -> void:
	if not playing or local_player == null:
		return
	pet_enabled = not pet_enabled
	pet_companion.visible = pet_enabled
	pet_button.text = "PET ON" if pet_enabled else "PET"
	hud_status.text = "Your friendly pet is following you!" if pet_enabled else "Pet returned to its garden."

func _toggle_car() -> void:
	if not playing or local_player == null:
		return
	car_enabled = not car_enabled
	ride_shell.visible = car_enabled
	local_player.speed_multiplier = 1.65 if car_enabled else 1.0
	car_button.text = "PARK" if car_enabled else "DRIVE"
	hud_status.text = "Driving! Explore the raceway at the eastern side." if car_enabled else "Back on foot."

func _open_store() -> void:
	if shop != null:
		shop.open_shop()

func _on_battle_pressed() -> void:
	if not playing or local_player == null:
		return
	if multiplayer_mode:
		hud_status.text = "Foam-tag practice is offline-only until anti-cheat is ready."
		return
	var message: String = world_activities.start_or_tag(local_player)
	hud_status.text = message
	if message.begins_with("HIT!"):
		current_score += 8
		_play_coin_sound()
		_update_hud()
	battle_button.text = "TAG!" if world_activities.battle_active else "BATTLE"

func _on_activity_finished(activity: String) -> void:
	if not playing or multiplayer_mode:
		return
	if activity == "slide":
		slide_count += 1
		current_score += 20
		hud_status.text = "SPLASH! Finished the water slide • +20 points"
	elif activity == "swing":
		current_score += 8
		hud_status.text = "Swing ride finished! +8 points"
	_play_coin_sound()
	_update_hud()

func _on_battle_finished(hits: int) -> void:
	if not playing or multiplayer_mode:
		return
	battle_button.text = "BATTLE"
	if hits >= 6:
		current_score += 60
		hud_status.text = "FOAM TAG CHAMPION! %d hits • +60 bonus" % hits
	elif hits > 0:
		current_score += 10
		hud_status.text = "Foam-tag round complete! %d hits • +10 bonus" % hits
	else:
		hud_status.text = "Foam-tag round over. Try getting closer to the targets!"
	_update_hud()

func _start_music() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.volume_db = -14.0
	var song: AudioStreamWAV = load("res://assets/happy_loop.wav")
	if song != null:
		song.loop_mode = AudioStreamWAV.LOOP_FORWARD
		music_player.stream = song
		add_child(music_player)
		music_player.play()

func _play_coin_sound() -> void:
	var player := AudioStreamPlayer.new()
	player.volume_db = -11.0
	player.stream = load("res://assets/coin.wav")
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()
