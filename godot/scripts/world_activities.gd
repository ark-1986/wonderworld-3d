extends Node3D
## WonderWorld interactive attractions. Offline motion is intentionally local-only.
## All visual geometry is original and contains no third-party licensed material.

signal activity_finished(activity: String)
signal battle_finished(hits: int)

const HOME_X: Array[float] = [-15.0, 0.0, 15.0]
const HOME_COLORS: Array[Color] = [Color("eead9c"), Color("a8d3e8"), Color("e9c2ee")]
const HOUSE_Z: float = 41.0
const SLIDE_START: Vector3 = Vector3(-40, 4.8, -36)
const ARENA_CENTER: Vector3 = Vector3(43, 0, -6)

var houses: Array[Dictionary] = []
var swings: Array[Dictionary] = []
var targets: Array[Node3D] = []
var animation_time: float = 0.0
var rider: CharacterBody3D
var ride_kind: String = ""
var ride_time: float = 0.0
var active_swing: int = -1
var last_slide_time: float = -30.0
var battle_active: bool = false
var battle_time: float = 0.0
var battle_hits: int = 0
var last_shot: float = -2.0
var materials: Dictionary = {}

func _ready() -> void:
	for i in HOME_X.size():
		_build_home(i)
	_build_swing(Vector3(-41, 0, 15), Color("f2a965"))
	_build_swing(Vector3(-33, 0, 13), Color("69cfc3"))
	_build_arena()

func _material(color: Color) -> StandardMaterial3D:
	var key: String = color.to_html()
	if materials.has(key):
		return materials[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.73
	materials[key] = m
	return m

func _box(parent: Node3D, position: Vector3, size: Vector3, color: Color, solid: bool = false) -> Node3D:
	var node: Node3D = StaticBody3D.new() if solid else Node3D.new()
	node.position = position
	parent.add_child(node)
	var mesh := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = size
	mesh.mesh = shape
	mesh.material_override = _material(color)
	node.add_child(mesh)
	if solid:
		var collider := CollisionShape3D.new()
		var collision := BoxShape3D.new()
		collision.size = size
		collider.shape = collision
		node.add_child(collider)
	return node

func _ball(parent: Node3D, position: Vector3, radius: float, color: Color) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	m.mesh = mesh
	m.position = position
	m.material_override = _material(color)
	parent.add_child(m)
	return m

func _post(parent: Node3D, position: Vector3, height: float, color: Color, radius: float = 0.13) -> void:
	var mesh := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = radius
	cyl.bottom_radius = radius
	cyl.height = height
	cyl.radial_segments = 10
	mesh.mesh = cyl
	mesh.material_override = _material(color)
	mesh.position = position
	parent.add_child(mesh)

func _sign(parent: Node3D, label: String, position: Vector3, color: Color) -> Label3D:
	var sign := Label3D.new()
	sign.text = label
	sign.font_size = 52
	sign.pixel_size = 0.007
	sign.outline_size = 12
	sign.modulate = color
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	sign.position = position
	parent.add_child(sign)
	return sign

func _build_home(index: int) -> void:
	var x: float = HOME_X[index]
	var root := Node3D.new()
	root.name = "PlayableHome%d" % index
	root.position = Vector3(x, 0, HOUSE_Z)
	add_child(root)
	var wall: Color = HOME_COLORS[index]
	var trim: Color = Color("fff2c8")
	var roof_color: Color = [Color("c95777"), Color("397ea4"), Color("9f69ae")][index]
	_box(root, Vector3(0, 0.17, 0), Vector3(8.0, 0.28, 7.5), Color("bc916d"), true)
	_box(root, Vector3(0, 2.25, 3.67), Vector3(8, 4.5, 0.35), wall, true)
	_box(root, Vector3(-3.9, 2.25, 0), Vector3(0.35, 4.5, 7.6), wall, true)
	_box(root, Vector3(3.9, 2.25, 0), Vector3(0.35, 4.5, 7.6), wall, true)
	# Front wall has a genuine walkable 2.2 m doorway; unlike the earlier solid cottages.
	_box(root, Vector3(-2.50, 2.25, -3.7), Vector3(2.98, 4.5, 0.35), wall, true)
	_box(root, Vector3(2.50, 2.25, -3.7), Vector3(2.98, 4.5, 0.35), wall, true)
	_box(root, Vector3(0, 3.62, -3.7), Vector3(2.1, 1.25, 0.35), wall, true)
	for offset in [-2.0, 2.0]:
		_box(root, Vector3(offset, 2.35, 3.9), Vector3(1.2, 1.45, 0.13), Color("7bc9e0"))
		_box(root, Vector3(offset, 2.35, 3.98), Vector3(0.11, 1.57, 0.15), trim)
		_box(root, Vector3(offset, 2.35, 4.0), Vector3(1.32, 0.11, 0.15), trim)
	var roof := Node3D.new()
	root.add_child(roof)
	_box(roof, Vector3(0, 4.78, 0), Vector3(8.8, 0.32, 8.2), roof_color)
	_box(roof, Vector3(0, 5.1, 0), Vector3(8.0, 0.32, 7.4), roof_color.lightened(0.19))
	# Hinged door pivots around its left edge, with collision while closed.
	var hinge := Node3D.new()
	hinge.position = Vector3(-1.05, 0, -3.91)
	root.add_child(hinge)
	var door := _box(hinge, Vector3(1.0, 1.32, 0), Vector3(1.99, 2.65, 0.16), Color("715571"), true) as StaticBody3D
	_ball(hinge, Vector3(1.83, 1.23, -0.17), 0.095, Color("f4d27c"))
	_box(root, Vector3(0, 0.06, -5.05), Vector3(2.75, 0.10, 2.2), trim)
	# Furniture actually placed inside the hollow, accessible room.
	_box(root, Vector3(-2.45, 0.69, 1.8), Vector3(2.0, 0.72, 0.95), Color("e8a3ac"))
	_box(root, Vector3(-2.45, 1.15, 2.23), Vector3(2.0, 0.93, 0.20), Color("e8a3ac"))
	_box(root, Vector3(1.7, 0.67, 1.6), Vector3(2.2, 0.38, 1.45), Color("e6c398"))
	_box(root, Vector3(1.7, 0.28, 1.6), Vector3(1.5, 0.10, 0.95), Color("f4eff2"))
	_box(root, Vector3(1.0, 0.26, -0.3), Vector3(3.1, 0.12, 2.0), Color("86bbb7"))
	_box(root, Vector3(-2.5, 0.89, -0.5), Vector3(1.0, 1.5, 0.75), Color("8e6ea6"))
	_ball(root, Vector3(-2.45, 1.75, -0.5), 0.34, Color("ffe0a5"))
	var title: String = ["PINK FAMILY HOME", "BLUE HOUSE", "RAINBOW HOUSE"][index]
	_sign(root, title, Vector3(0, 5.6, -4.1), Color("fff2c1"))
	var door_label := _sign(root, "OPEN", Vector3(0, 2.45, -4.2), Color("fef9ce"))
	houses.append({"root":root, "x":x, "hinge":hinge, "door":door, "roof":roof, "open":false, "label":door_label})

func _build_swing(where: Vector3, color: Color) -> void:
	var root := Node3D.new()
	root.position = where
	root.name = "PlaygroundSwing"
	add_child(root)
	for side in [-1.45, 1.45]:
		_post(root, Vector3(side, 2.25, 0), 4.55, Color("687aa2"), 0.15)
		_ball(root, Vector3(side, 4.55, 0), 0.2, color)
	_box(root, Vector3(0, 4.5, 0), Vector3(3.3, 0.24, 0.23), color)
	var pivot := Node3D.new()
	pivot.position = Vector3(0, 4.38, 0)
	root.add_child(pivot)
	for side in [-0.76, 0.76]:
		_post(pivot, Vector3(side, -1.30, 0), 2.6, Color("f1e4bf"), 0.035)
	_box(pivot, Vector3(0, -2.66, 0), Vector3(1.85, 0.20, 0.88), color)
	_sign(root, "SWING • RIDE", Vector3(0, 5.5, 0), Color("fff7c2"))
	swings.append({"root":root, "pivot":pivot, "where":where})

func _build_arena() -> void:
	var root := Node3D.new()
	root.name = "FoamTagArena"
	root.position = ARENA_CENTER
	add_child(root)
	_box(root, Vector3(0, 0.12, 0), Vector3(17, 0.17, 13), Color("68b3a2"))
	for side in [-1.0, 1.0]:
		for z in [-5.5, 5.5]:
			_post(root, Vector3(side * 8.0, 1.5, z), 3.0, Color("f4c36b"))
		_box(root, Vector3(side * 8.0, 2.65, 0), Vector3(0.21, 0.2, 11.0), Color("ec8ba6"))
	_box(root, Vector3(0, 2.8, -6.1), Vector3(8.5, 0.75, 0.28), Color("9a7acf"))
	_sign(root, "FOAM-TAG • NO DAMAGE", Vector3(0, 3.0, -6.6), Color("fff8cf"))
	for i in 4:
		var dummy := Node3D.new()
		dummy.name = "FriendlyTarget%d" % i
		dummy.position = ARENA_CENTER + Vector3(-4.8 + float(i) * 3.2, 0, -2.8)
		add_child(dummy)
		_ball(dummy, Vector3(0, 2.25, 0), 0.58, [Color("f8bf75"), Color("8ac7e7"), Color("e8a4d5"), Color("b9d388")][i])
		_box(dummy, Vector3(0, 1.1, 0), Vector3(0.85, 1.3, 0.55), Color("e8e6d7"))
		_ball(dummy, Vector3(-0.18, 2.3, -0.45), 0.08, Color("253d5a"))
		_ball(dummy, Vector3(0.18, 2.3, -0.45), 0.08, Color("253d5a"))
		_sign(dummy, "TARGET", Vector3(0, 3.1, 0), Color("fff4b7"))
		targets.append(dummy)

func reset_player() -> void:
	ride_kind = ""
	rider = null
	active_swing = -1
	battle_active = false
	battle_time = 0.0
	battle_hits = 0

func is_riding() -> bool:
	return ride_kind != ""

func prompt_at(pos: Vector3) -> String:
	if is_riding():
		return "EXIT RIDE"
	for h in houses:
		var here: Vector3 = Vector3(float(h["x"]), 0, HOUSE_Z - 3.7)
		if Vector2(pos.x, pos.z).distance_to(Vector2(here.x, here.z)) < 3.4:
			return "CLOSE HOME" if bool(h["open"]) else "OPEN HOME"
	for swing in swings:
		var origin: Vector3 = swing["where"]
		if Vector2(pos.x, pos.z).distance_to(Vector2(origin.x, origin.z)) < 4.0:
			return "SWING"
	if Vector2(pos.x, pos.z).distance_to(Vector2(-35, -34)) < 14.0:
		return "WATER SLIDE"
	if Vector2(pos.x, pos.z).distance_to(Vector2(ARENA_CENTER.x, ARENA_CENTER.z)) < 9.0:
		return "FOAM TAG"
	return ""

func use_nearby(player: CharacterBody3D) -> String:
	if is_riding():
		ride_kind = ""
		active_swing = -1
		rider = null
		player.velocity = Vector3.ZERO
		return "Ride stopped."
	for i in houses.size():
		var h: Dictionary = houses[i]
		var here: Vector3 = Vector3(float(h["x"]), 0, HOUSE_Z - 3.7)
		if Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(here.x, here.z)) < 3.4:
			var opened: bool = not bool(h["open"])
			h["open"] = opened
			houses[i] = h
			var door: StaticBody3D = h["door"]
			door.collision_layer = 0 if opened else 1
			door.collision_mask = 0 if opened else 1
			(h["label"] as Label3D).text = "WELCOME INSIDE" if opened else "OPEN"
			return "Home door opened! Walk inside and look around." if opened else "Home door closed."
	for i in swings.size():
		var origin: Vector3 = swings[i]["where"]
		if Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(origin.x, origin.z)) < 4.0:
			rider = player
			ride_kind = "swing"
			ride_time = 0.0
			active_swing = i
			player.velocity = Vector3.ZERO
			return "Swing ride started! Tap EXIT RIDE to stop."
	if Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(-35, -34)) < 14.0:
		return begin_slide(player)
	return ""

func begin_slide(player: CharacterBody3D) -> String:
	if is_riding():
		return "Finish your current ride first."
	if animation_time - last_slide_time < 12.0:
		return "Water slide is cooling down. Explore and return!"
	last_slide_time = animation_time
	rider = player
	ride_kind = "slide"
	ride_time = 0.0
	player.velocity = Vector3.ZERO
	player.global_position = SLIDE_START
	return "WATER SLIDE! Moving down the actual slide ramp."

func start_or_tag(player: CharacterBody3D) -> String:
	if is_riding():
		return "Exit your ride before starting foam tag."
	if not battle_active:
		battle_active = true
		battle_time = 35.0
		battle_hits = 0
		last_shot = -2.0
		player.global_position = Vector3(42, 1.55, -1)
		player.velocity = Vector3.ZERO
		return "FOAM TAG! Find friendly targets and tap TAG. 35 seconds!"
	if animation_time - last_shot < 0.40:
		return "Foam blaster reloading..."
	last_shot = animation_time
	var best: Node3D
	var best_distance: float = 10.5
	for dummy in targets:
		var dist: float = Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(dummy.global_position.x, dummy.global_position.z))
		if dist < best_distance:
			best = dummy
			best_distance = dist
	if best == null:
		return "Move closer to a colorful target, then tap TAG."
	battle_hits += 1
	var foam := _ball(self, player.global_position + Vector3(0, 0.8, 0), 0.20, Color("f8e8a6"))
	var anim := get_tree().create_tween()
	anim.tween_property(foam, "global_position", best.global_position + Vector3(0, 2.0, 0), 0.20)
	anim.tween_callback(foam.queue_free)
	var bump := get_tree().create_tween()
	bump.tween_property(best, "scale", Vector3(1.27, 0.76, 1.27), 0.10)
	bump.tween_property(best, "scale", Vector3.ONE, 0.19)
	return "HIT! Foam-tag target %d • %d seconds left" % [battle_hits, int(ceil(battle_time))]

func _process(delta: float) -> void:
	animation_time += delta
	for i in houses.size():
		var h: Dictionary = houses[i]
		var hinge: Node3D = h["hinge"]
		var target_angle: float = -1.67 if bool(h["open"]) else 0.0
		hinge.rotation.y = lerp_angle(hinge.rotation.y, target_angle, minf(1.0, delta * 5.0))
		var roof: Node3D = h["roof"]
		if rider != null:
			var p: Vector3 = rider.global_position
			roof.visible = not (absf(p.x - float(h["x"])) < 3.7 and absf(p.z - HOUSE_Z) < 3.7)
		else:
			roof.visible = true
	for i in swings.size():
		var pivot: Node3D = swings[i]["pivot"]
		var strength: float = 0.51 if ride_kind == "swing" and active_swing == i else 0.16
		pivot.rotation.x = sin(animation_time * 2.10 + float(i) * 1.5) * strength
	for i in targets.size():
		if is_instance_valid(targets[i]):
			targets[i].position.y = 0.15 * sin(animation_time * 2.3 + float(i))
	if rider != null and ride_kind == "slide":
		ride_time += delta
		var t: float = clampf(ride_time / 3.6, 0.0, 1.0)
		var smooth_t: float = t * t * (3.0 - 2.0 * t)
		rider.global_position = Vector3(-40.0 + 9.4 * smooth_t, 4.8 - 3.28 * smooth_t + 0.05 * sin(t * TAU * 3.0), -36.0 + sin(t * PI) * 0.4)
		rider.velocity = Vector3.ZERO
		if t >= 1.0:
			ride_kind = ""
			rider = null
			activity_finished.emit("slide")
	elif rider != null and ride_kind == "swing":
		ride_time += delta
		var pivot: Node3D = swings[active_swing]["pivot"]
		rider.global_position = pivot.to_global(Vector3(0, -2.66, 0)) + Vector3(0, 1.02, 0)
		rider.velocity = Vector3.ZERO
		if ride_time >= 8.0:
			ride_kind = ""
			active_swing = -1
			rider = null
			activity_finished.emit("swing")
	if battle_active:
		battle_time -= delta
		if battle_time <= 0.0:
			battle_active = false
			battle_finished.emit(battle_hits)
