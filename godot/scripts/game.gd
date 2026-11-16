extends Node3D
## WonderWorld 3D demo: a native Godot game with offline practice and WebSocket rooms.
## Everything in the demo world is made from simple colored meshes; no paid assets.

const AvatarScript = preload("res://scripts/avatar.gd")
const NetworkScript = preload("res://scripts/network.gd")
const JoystickScript = preload("res://scripts/virtual_joystick.gd")
const ALIASES: Array[String] = ["Sunny", "Rocket", "Pixel", "Comet", "Star", "Sprout", "Bubbles", "Nova"]
const COIN_POSITIONS: Array[Vector3] = [
	Vector3(0, 1.15, -5), Vector3(5, 1.15, 1), Vector3(-5, 1.15, 2),
	Vector3(9, 1.15, 8), Vector3(13, 1.15, 5), Vector3(-9, 1.15, 9),
	Vector3(-13, 1.15, -7), Vector3(3, 1.15, 12), Vector3(-5, 1.15, -13),
	Vector3(14, 1.15, -13), Vector3(-14, 1.15, 13),
	Vector3(7, 2.0, -7), Vector3(10.1, 2.65, -7), Vector3(13.2, 3.3, -7),
	Vector3(16.3, 3.95, -7), Vector3(19.4, 4.65, -7),
	Vector3(4, 1.15, -15), Vector3(-16, 1.15, -1)
]

var network
var camera: Camera3D
var menu_overlay: ColorRect
var hud: Control
var hud_score: Label
var hud_status: Label
var hud_room: Label
var hud_rankings: Label
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
	local_player.control_move(axis, is_jump, delta)
	if multiplayer_mode and network.connected:
		move_timer += delta
		if move_timer >= network.SEND_INTERVAL:
			move_timer = 0.0
			network.send_position(local_player.global_position, local_player.rotation.y)

func _process(delta: float) -> void:
	if playing and local_player != null:
		var desired := local_player.global_position + Vector3(0, 6.2, 10.8)
		camera.global_position = camera.global_position.lerp(desired, minf(1.0, delta * 5.0))
		camera.look_at(local_player.global_position + Vector3(0, 0.9, 0))
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
		m.emission_energy_multiplier = 0.45
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
	var environment := WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color("47a5f5")
	sky_mat.sky_horizon_color = Color("b5edff")
	sky_mat.ground_bottom_color = Color("70c5e5")
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	environment.environment = env
	add_child(environment)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -26, 0)
	sun.light_color = Color("fff4dc")
	sun.light_energy = 1.45
	sun.shadow_enabled = true
	add_child(sun)
	camera = Camera3D.new()
	camera.fov = 66
	camera.position = Vector3(0, 8, 17)
	camera.current = true
	add_child(camera)
	# Ocean and main lush island; walkable blocks have real Godot physics.
	_block(Vector3(0, -2.6, 0), Vector3(160, 0.35, 160), Color("63c9ef"), false)
	_block(Vector3(0, -1.55, 0), Vector3(46, 2.3, 46), Color("efcb94"))
	_block(Vector3(0, -0.57, 0), Vector3(42, 1.14, 42), Color("7bdb99"))
	# Pastel footpaths and central plaza.
	_block(Vector3(0, 0.05, 0), Vector3(7.4, 0.08, 7.4), Color("ffeacb"), false)
	_block(Vector3(0, 0.055, 9.1), Vector3(2.35, 0.07, 16), Color("ffedcb"), false)
	_block(Vector3(0, 0.058, -9.1), Vector3(2.35, 0.07, 16), Color("ffedcb"), false)
	_block(Vector3(9.1, 0.062, 0), Vector3(16, 0.07, 2.3), Color("ffedcb"), false)
	_block(Vector3(-9.1, 0.062, 0), Vector3(16, 0.07, 2.3), Color("ffedcb"), false)
	# Central rainbow landmark.
	_cylinder(Vector3(0, 0.42, 0), 1.55, 1.8, 0.85, Color("ffffff"))
	_cylinder(Vector3(0, 0.83, 0), 1.3, 1.5, 0.18, Color("5ac9de"))
	_cylinder(Vector3(0, 1.65, 0), 0.15, 0.20, 1.55, Color("ffaf62"))
	_sphere(Vector3(0, 2.62, 0), 0.64, Color("ffe576"))
	for i in 8:
		var angle := i * TAU / 8.0
		_sphere(Vector3(cos(angle) * 2.35, 0.4, sin(angle) * 2.35), 0.22, Color("ff9ab4"))
	# Little houses at the edge of the world.
	for hut in [Vector3(-11, 0, -14), Vector3(14, 0, 13)]:
		_block(hut + Vector3(0, 1.55, 0), Vector3(4.1, 3.1, 3.7), Color("fff0cb"), false)
		_block(hut + Vector3(0, 3.3, 0), Vector3(4.7, 0.66, 4.3), Color("ff8bac"), false)
		_block(hut + Vector3(0, 1.0, -1.89), Vector3(0.95, 2, 0.12), Color("9c83ef"), false)
		_block(hut + Vector3(-1.35, 2.0, -1.89), Vector3(0.55, 0.78, 0.12), Color("9fe0ff"), false)
	# Jumping challenge with gradually rising, collidable platforms.
	for i in 5:
		var xx := 7.0 + i * 3.1
		var h := 0.72 + i * 0.65
		_block(Vector3(xx, h * 0.5, -7), Vector3(2.5, h, 2.8), Color("b491fc") if i % 2 == 0 else Color("ffab88"))
		_block(Vector3(xx, h + 0.06, -7), Vector3(2.65, 0.12, 2.95), Color("f0e7ff") if i % 2 == 0 else Color("fff0cd"), false)
	_block(Vector3(20.3, 4.42, -7), Vector3(0.2, 3.1, 0.2), Color("fefefe"), false)
	_block(Vector3(21.2, 5.53, -7), Vector3(1.9, 0.75, 0.1), Color("ffde75"), false)
	# Decorative foliage and blossoms.
	for entry in [
		[-18.0, -18.0, 1.0, false], [-16.0, 7.0, 0.95, true],
		[-17.0, 18.0, 1.1, false], [-3.0, 18.0, 1.1, true],
		[17.0, 17.0, 1.0, false], [18.0, 2.0, 0.85, true],
		[15.0, -17.0, 1.08, false], [-1.0, -18.0, 1.0, true],
		[-18.0, -1.0, 0.9, false], [17.0, -19.0, 1.0, true]
	]:
		_tree(float(entry[0]), float(entry[1]), float(entry[2]), bool(entry[3]))
	for i in 50:
		var a := i * 2.39996
		var rad := 9.0 + (i % 6) * 1.82
		var x := cos(a) * rad
		var z := sin(a) * rad
		if absf(x) < 4.2 or absf(z) < 4.2 or (x > 4 and z < -4 and z > -11):
			continue
		_flower(x, z, Color("fff6b4") if i % 3 == 0 else Color("ff90ac") if i % 3 == 1 else Color("bd94ff"))
	# Tiny distant decorative islands and fluffy cloud clusters.
	for x in [-42.0, 43.0]:
		_block(Vector3(x, -1.3, -14), Vector3(12, 1.0, 10), Color("f4ca94"), false)
		_block(Vector3(x, -0.82, -14), Vector3(11, 0.3, 9), Color("75d59e"), false)
	for cloud_x in [-23.0, -10.0, 6.0, 26.0]:
		var cloud_y := 15.0 + fmod(absf(cloud_x), 5.0)
		_sphere(Vector3(cloud_x, cloud_y, -40), 2.6, Color("f8fcff"))
		_sphere(Vector3(cloud_x + 2.4, cloud_y - 0.25, -40), 2.0, Color("f8fcff"))
		_sphere(Vector3(cloud_x - 2.1, cloud_y - 0.3, -40), 1.7, Color("f8fcff"))
	for id in COIN_POSITIONS.size():
		_add_coin(id, COIN_POSITIONS[id])

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
	menu_overlay.color = Color(0.015, 0.045, 0.12, 0.48)
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
	menu_panel.add_theme_stylebox_override("panel", _style(Color("173354"), 24, Color("5ab9da"), 3))
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
	var title := _label("WONDERWORLD", 44, Color("ffde72"))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(title)
	var subtitle := _label("3D ADVENTURE  •  FRIENDS  •  FUN", 17, Color("d6efff"))
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
	menu_status = _label("Offline practice works now. Online rooms need your free server URL.", 15, Color("bce2ec"))
	menu_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	menu_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stack.add_child(menu_status)
	var note := _label("Private codes • No open chat • No purchases", 13, Color("88aac3"))
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
	score_panel.custom_minimum_size = Vector2(350, 82)
	score_panel.add_theme_stylebox_override("panel", _style(Color(0.07, 0.15, 0.25, 0.82), 17, Color(0.4, 0.85, 0.95, 0.55), 2))
	hud.add_child(score_panel)
	var score_wrap := VBoxContainer.new()
	score_wrap.add_theme_constant_override("separation", 3)
	score_panel.add_child(score_wrap)
	hud_score = _label("✦ 0 POINTS", 24, Color("ffe779"))
	score_wrap.add_child(hud_score)
	hud_status = _label("Explore the island and collect gems!", 14, Color("e2f3ff"))
	score_wrap.add_child(hud_status)
	var scoreboard := PanelContainer.new()
	scoreboard.anchor_left = 1.0
	scoreboard.anchor_right = 1.0
	scoreboard.offset_left = -255
	scoreboard.offset_right = -18
	scoreboard.offset_top = 22
	scoreboard.offset_bottom = 240
	scoreboard.add_theme_stylebox_override("panel", _style(Color(0.08, 0.16, 0.28, 0.82), 16, Color(0.4, 0.85, 0.95, 0.55), 2))
	hud.add_child(scoreboard)
	hud_rankings = _label("FRIENDS\n\nYou • 0", 18, Color("eaf6ff"))
	hud_rankings.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	scoreboard.add_child(hud_rankings)
	var room_panel := PanelContainer.new()
	room_panel.anchor_left = 0.5
	room_panel.anchor_right = 0.5
	room_panel.offset_left = -185
	room_panel.offset_right = 185
	room_panel.offset_top = 20
	room_panel.offset_bottom = 66
	room_panel.add_theme_stylebox_override("panel", _style(Color(0.08, 0.16, 0.28, 0.83), 15))
	hud.add_child(room_panel)
	var room_box := HBoxContainer.new()
	room_box.alignment = BoxContainer.ALIGNMENT_CENTER
	room_panel.add_child(room_box)
	hud_room = _label("PRACTICE", 18, Color("f8faff"))
	room_box.add_child(hud_room)
	var copy_button := _button("COPY", Color("348ead"))
	copy_button.custom_minimum_size = Vector2(83, 36)
	copy_button.pressed.connect(_copy_room)
	room_box.add_child(copy_button)
	var home_button := _button("HOME", Color("ce6b88"))
	home_button.position = Vector2(22, 116)
	home_button.custom_minimum_size = Vector2(112, 46)
	home_button.pressed.connect(_back_to_menu)
	hud.add_child(home_button)
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
	current_score = 0
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
	local_player.position = Vector3(0, 1.55, 5)
	add_child(local_player)
	move_timer = 0.0
	menu_overlay.visible = false
	hud.visible = true
	_update_hud()

func _back_to_menu() -> void:
	network.disconnect_room()
	playing = false
	multiplayer_mode = false
	active_room = ""
	pending_coins.clear()
	if local_player != null:
		local_player.queue_free()
		local_player = null
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
	hud_score.text = "✦ %d POINTS" % current_score
	hud_room.text = ("ROOM " + active_room) if multiplayer_mode else "PRACTICE"
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
