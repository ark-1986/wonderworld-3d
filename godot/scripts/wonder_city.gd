extends Node3D
## WonderWorld Adventure City: deterministic procedural stylized environment.
## No paid assets; reusable meshes/materials, designed for mobile GL Compatibility.
## ALL positions are world coordinates; game controller owns network/player logic.

const ROSE := Color("d94f66")
const TEAL := Color("24a69b")
const GOLD := Color("f6b84d")
const NAVY := Color("315b7e")
const CREAM := Color("f6d9a9")
const GRASS := Color("65aa64")
var mats: Dictionary = {}
var decorative_anim: Array[Node3D] = []
var animated_time: float = 0.0

func _ready() -> void:
	_make_land()
	_make_castle()
	_make_village()
	_make_pet_garden()
	_make_water_park()
	_make_raceway()
	_make_obby()
	_make_scenery()
	_make_professional_props()


# Professionally staged hero scenery, authored as original low-poly glTF meshes.
# Each .glb is a single colored mesh to control mobile draw calls.
func _spawn_model(asset_name: String, where: Vector3, size_factor: float = 1.0, facing: float = 0.0, hitbox: Vector3 = Vector3.ZERO) -> Node3D:
	var source: Resource = load("res://assets/models/" + asset_name + ".glb")
	if not (source is PackedScene):
		push_warning("Optional WonderWorld scenery failed to import: " + asset_name)
		return null
	var packed_scene: PackedScene = source as PackedScene
	var actor: Node3D = packed_scene.instantiate() as Node3D
	if actor == null:
		return null
	actor.name = asset_name
	actor.position = where
	actor.rotation_degrees.y = facing
	actor.scale = Vector3.ONE * size_factor
	add_child(actor)
	if hitbox.length_squared() > 0.001:
		var body := StaticBody3D.new()
		body.position = Vector3(0, hitbox.y * 0.5, 0)
		actor.add_child(body)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = hitbox
		shape.shape = box
		body.add_child(shape)
	return actor

func _make_professional_props() -> void:
	# Main entrance, thematic zones, high-quality hero props, focal landmarks.
	_spawn_model("festival_gate", Vector3(0, 0.24, 13.5), 1.05)
	_spawn_model("candy_kiosk", Vector3(-8, 0.11, -22.0), 0.9, 15.0, Vector3(4.7, 4.5, 3.6))
	_spawn_model("candy_kiosk", Vector3(8, 0.11, 22.0), 0.8, 180.0, Vector3(4.7, 4.5, 3.6))
	_spawn_model("ferris_wheel", Vector3(-44.0, 0.22, -35), 1.0, 20.0)
	_spawn_model("pet_house", Vector3(-38, 0.24, 28), 1.1, -28, Vector3(2.9, 2.2, 2.6))
	_spawn_model("pet_house", Vector3(-29, 0.24, 29), 0.85, 30, Vector3(2.9, 2.2, 2.6))
	_spawn_model("trophy_portal", Vector3(20, 0.55, 16.5), 0.88)
	_spawn_model("trophy_portal", Vector3(20, 0.24, -34), 1.0, 18)
	_spawn_model("balloon_cart", Vector3(-9, 0.18, 7.5), 0.86, 30, Vector3(2.25, 2, 1.45))
	_spawn_model("balloon_cart", Vector3(9, 0.18, -6.5), 0.95, -24, Vector3(2.25, 2, 1.45))
	for pos in [Vector3(-6.3,0.20,8), Vector3(6.3,0.20,8), Vector3(-6.3,0.20,-8), Vector3(6.3,0.20,-8)]:
		_spawn_model("park_bench", pos, 0.90, 90.0, Vector3(2.75, 2.1, 1.4))
	for pos in [Vector3(-6.5,0.22,-23),Vector3(6.5,0.22,-23),Vector3(-6.5,0.22,21),Vector3(6.5,0.22,21), Vector3(-25,0.22,-2),Vector3(25,0.22,2)]:
		_spawn_model("lantern_post", pos, 0.83)
	for pos in [Vector3(-7.9,0.22,4.4),Vector3(7.9,0.22,4.4),Vector3(-7.9,0.22,-4.4),Vector3(7.9,0.22,-4.4),Vector3(-21,0.22,17),Vector3(22,0.22,-19),Vector3(-35,0.22,17),Vector3(-35,0.22,27)]:
		_spawn_model("flower_bed", pos, 0.7)
	for pos in [Vector3(-45,0.22,-23),Vector3(-23,0.22,-43),Vector3(-20,0.22,-24),Vector3(-42,0.22,-44)]:
		_spawn_model("palm_tree",pos,0.92)
	for pos in [Vector3(-11.3,0.22,-37),Vector3(11.3,0.22,-37)]:
		_spawn_model("magic_tower",pos,1.07,0,Vector3(3.5,8,3.5))

func _process(delta: float) -> void:
	animated_time += delta
	for obj in decorative_anim:
		if is_instance_valid(obj):
			obj.rotate_y(delta * 0.4)

func _mat(hex: Color, texture: String = "") -> StandardMaterial3D:
	var key: String = hex.to_html() + texture
	if mats.has(key):
		return mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = hex
	m.roughness = 0.87
	if texture != "":
		var asset: Resource = load("res://assets/textures/" + texture + ".png")
		if asset is Texture2D:
			m.albedo_texture = asset as Texture2D
			m.uv1_scale = Vector3(2.0, 2.0, 2.0)
	mats[key] = m
	return m

func _box(pos: Vector3, sz: Vector3, shade: Color, solid: bool = false, texture: String = "") -> Node3D:
	var root: Node3D
	if solid:
		root = StaticBody3D.new()
	else:
		root = Node3D.new()
	root.position = pos
	add_child(root)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	mi.mesh = bm
	mi.material_override = _mat(shade, texture)
	root.add_child(mi)
	if solid:
		var col := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = sz
		col.shape = bs
		root.add_child(col)
	return root

func _ball(pos: Vector3, radius: float, color: Color, height_scale: float = 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0 * height_scale
	sm.radial_segments = 12
	sm.rings = 8
	mi.mesh = sm
	mi.position = pos
	mi.material_override = _mat(color)
	add_child(mi)
	return mi

func _cyl(pos: Vector3, top_r: float, bot_r: float, height: float, color: Color, rotate: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = top_r
	cm.bottom_radius = bot_r
	cm.height = height
	cm.radial_segments = 14
	mi.mesh = cm
	mi.position = pos
	mi.rotation_degrees = rotate
	mi.material_override = _mat(color)
	add_child(mi)
	return mi

func _ring(pos: Vector3, inner: float, outer: float, color: Color, rotate: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = inner
	tm.outer_radius = outer
	tm.rings = 8
	tm.ring_segments = 18
	mi.mesh = tm
	mi.position = pos
	mi.rotation_degrees = rotate
	mi.material_override = _mat(color)
	add_child(mi)
	return mi

func _text(pos: Vector3, title: String, color: Color = Color.WHITE, scale_value: float = 1.0) -> void:
	var l := Label3D.new()
	l.text = title
	l.font_size = 48
	l.pixel_size = 0.009 * scale_value
	l.position = pos
	l.modulate = color
	l.outline_size = 14
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(l)

func _roof(pos: Vector3, width: float, depth: float, color: Color) -> void:
	var slope: float = sqrt((width * 0.53) * (width * 0.53) + 1.15 * 1.15)
	var left := _box(pos + Vector3(-width * 0.25, 0.57, 0), Vector3(slope + 0.25, 0.19, depth + 0.5), color, false, "roof")
	left.rotation_degrees.z = 28.0
	var right := _box(pos + Vector3(width * 0.25, 0.57, 0), Vector3(slope + 0.25, 0.19, depth + 0.5), color, false, "roof")
	right.rotation_degrees.z = -28.0
	_box(pos + Vector3(0, 1.20, 0), Vector3(0.22, 0.23, depth + 0.5), color.darkened(0.2))

func _house(x: float, z: float, w: float, d: float, h: float, wall: Color, roof: Color, sign_name: String, facing: float = 0.0) -> void:
	# Detailed cottage facade. All geometry is intentionally low-poly but saturated and layered.
	var y := h / 2.0
	_box(Vector3(x, y, z), Vector3(w, h, d), wall, true, "plaster")
	_box(Vector3(x, 0.15, z), Vector3(w + 0.35, 0.25, d + 0.35), wall.darkened(0.21))
	_roof(Vector3(x, h, z), w + 0.35, d + 0.35, roof)
	_box(Vector3(x, 1.13, z - d / 2.0 - 0.09), Vector3(1.05, 2.18, 0.14), Color("7b4d55"))
	_box(Vector3(x + 0.27, 1.08, z - d / 2.0 - 0.21), Vector3(0.09, 0.09, 0.09), GOLD)
	for side in [-1.0, 1.0]:
		var wx: float = x + side * w * 0.31
		_box(Vector3(wx, h * 0.60, z - d / 2.0 - 0.07), Vector3(0.92, 1.0, 0.10), Color("f8f1d5"))
		_box(Vector3(wx, h * 0.60, z - d / 2.0 - 0.15), Vector3(0.69, 0.75, 0.09), Color("589dc1"))
		_box(Vector3(wx, h * 0.60, z - d / 2.0 - 0.22), Vector3(0.08, 0.8, 0.07), Color("fff1be"))
		_box(Vector3(wx, h * 0.60, z - d / 2.0 - 0.23), Vector3(0.78, 0.07, 0.07), Color("fff1be"))
		_box(Vector3(wx, h * 0.60 - 0.62, z - d / 2.0 - 0.20), Vector3(1.17, 0.17, 0.30), wall.darkened(0.29))
	_box(Vector3(x, h + 1.6, z - d / 2.0 + 0.20), Vector3(minf(3.6, w), 0.56, 0.17), NAVY)
	_text(Vector3(x, h + 1.66, z - d / 2.0 - 0.09), sign_name, Color("fff1bd"), 0.65)
	if facing != 0.0:
		# Facade orientation is retained as lightweight street-only variation.
		pass

func _pine(x: float, z: float, scale_factor: float, pink: bool = false) -> void:
	var green: Color = Color("c76fa0") if pink else Color("268f69")
	_cyl(Vector3(x, 1.0 * scale_factor, z), 0.17 * scale_factor, 0.25 * scale_factor, 2.0 * scale_factor, Color("866047"))
	for i in 3:
		var level: float = float(i)
		_cyl(Vector3(x, (2.0 + level * 0.63) * scale_factor, z), 0.0, (1.3 - level * 0.26) * scale_factor, 1.55 * scale_factor, green.lightened(float(i) * 0.08))

func _round_tree(x: float, z: float, scale_factor: float, pink: bool = false) -> void:
	var col: Color = Color("e58db3") if pink else Color("269a61")
	_cyl(Vector3(x, 1.05 * scale_factor, z), 0.18 * scale_factor, 0.3 * scale_factor, 2.10 * scale_factor, Color("936247"))
	_ball(Vector3(x, 2.57 * scale_factor, z), 1.2 * scale_factor, col)
	_ball(Vector3(x + 0.63 * scale_factor, 2.3 * scale_factor, z), 0.82 * scale_factor, col.lightened(0.13))
	_ball(Vector3(x - 0.49 * scale_factor, 2.4 * scale_factor, z), 0.91 * scale_factor, col.darkened(0.09))

func _make_land() -> void:
	# The sea/beach is below the large walking grass terrain.
	_box(Vector3(0, -2.65, 0), Vector3(220, 0.18, 220), Color("3aafd9"), false, "water")
	_box(Vector3(0, -1.25, 0), Vector3(116, 2.30, 116), Color("d6ba7d"), true)
	_box(Vector3(0, -0.22, 0), Vector3(108, 0.42, 108), GRASS, true, "grass")
	# Central sandstone city plaza and stone-lined avenues.
	_box(Vector3(0, 0.044, 0), Vector3(18, 0.08, 18), Color("d6ae80"), false, "cobble")
	_box(Vector3(0, 0.08, -20), Vector3(7, 0.10, 40), Color("d5b68a"), false, "cobble")
	_box(Vector3(0, 0.09, 20), Vector3(7, 0.10, 33), Color("d5b68a"), false, "cobble")
	_box(Vector3(-21, 0.09, 0), Vector3(36, 0.10, 7), Color("d5b68a"), false, "cobble")
	_box(Vector3(21, 0.09, 0), Vector3(36, 0.10, 7), Color("d5b68a"), false, "cobble")
	# Waterfront walk and planters.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 49, 0.09, 0), Vector3(2.4, 0.10, 82), CREAM, false)
		_box(Vector3(0, 0.09, side * 49), Vector3(82, 0.10, 2.4), CREAM, false)
	# Plaza centerpiece: vibrant decorative fountain.
	_cyl(Vector3(0, 0.42, 0), 3.1, 3.35, 0.76, Color("c8b0a0"))
	_cyl(Vector3(0, 0.89, 0), 2.65, 2.85, 0.20, Color("ffffff"))
	_cyl(Vector3(0, 0.99, 0), 2.48, 2.48, 0.08, Color("47b7d4"))
	_cyl(Vector3(0, 1.5, 0), 0.38, 0.48, 1.08, GOLD)
	_cyl(Vector3(0, 2.07, 0), 1.08, 0.72, 0.22, Color("fff5cc"))
	_ball(Vector3(0, 2.67, 0), 0.45, Color("eebd58"))
	for j in 12:
		var a: float = float(j) * TAU / 12.0
		_ball(Vector3(cos(a) * 2.23, 1.28, sin(a) * 2.23), 0.16, Color("b9eeff"))
	_text(Vector3(0, 3.7, 0), "WONDERWORLD", Color("fff2bc"), 1.2)

func _make_castle() -> void:
	# Signature landmark visible from the central plaza, inspired by classic cartoon theme parks.
	var z: float = -36.0
	_box(Vector3(0, 4.0, z), Vector3(16, 8, 9), Color("f0b8a4"), true, "plaster")
	_box(Vector3(0, 8.4, z), Vector3(16.5, 0.8, 9.5), Color("f0d7ac"), false)
	_box(Vector3(0, 10.5, z), Vector3(5, 4.2, 5), Color("f1c9a8"))
	_cyl(Vector3(0, 14.6, z), 0, 3.15, 4.2, ROSE)
	# Towers in the four corners with ruby roofs.
	for corner in [Vector2(-8, -4.2), Vector2(8, -4.2), Vector2(-8, 4.2), Vector2(8, 4.2)]:
		var tx: float = corner.x
		var tz: float = z + corner.y
		_cyl(Vector3(tx, 6.0, tz), 2.2, 2.2, 12.0, Color("edc8aa"))
		_cyl(Vector3(tx, 12.75, tz), 0, 2.95, 4.5, Color("c83e58"))
		_cyl(Vector3(tx, 15.8, tz), 0.05, 0.05, 2.3, Color("f5d063"))
		_box(Vector3(tx + 0.5, 16.6, tz), Vector3(1.0, 0.55, 0.08), Color("ffdf79"))
		for k in 4:
			var yy: float = 3.0 + float(k) * 2.0
			_box(Vector3(tx, yy, tz - 2.22), Vector3(0.65, 0.9, 0.13), NAVY)
	# Castle arch, balcony, stained window and striped entry.
	_box(Vector3(0, 2.35, z + 4.59), Vector3(3.0, 4.7, 0.18), Color("543c60"))
	_ball(Vector3(0, 4.60, z + 4.64), 1.47, Color("543c60"), 0.5)
	for x in [-4.25, 4.25]:
		_box(Vector3(x, 5.5, z + 4.63), Vector3(1.25, 2.05, 0.12), NAVY)
		_box(Vector3(x, 6.75, z + 4.67), Vector3(1.5, 0.18, 0.21), GOLD)
	for i in 6:
		_box(Vector3(-5.5 + float(i) * 2.2, 8.95, z + 4.4), Vector3(1.1, 1.2, 1.0), Color("f4dbac"))
	_text(Vector3(0, 10.0, z + 4.91), "ADVENTURE CASTLE", Color("fff6c0"), 0.72)

func _make_village() -> void:
	# Two continuous colorful streets, each cottage has distinct layered roof and facade.
	_house(-12, -16, 6.0, 5.3, 4.8, Color("f1b18e"), Color("c94352"), "SWEET SHOP")
	_house(12, -16, 6.4, 5.4, 5.6, Color("f4d5ac"), Color("d34d66"), "TOY STORE")
	_house(-14, 13, 6.5, 5.0, 4.8, Color("ffd2b2"), Color("e16560"), "BAKERY")
	_house(13, 13, 6.2, 5.5, 5.2, Color("b6d5ef"), Color("dc626c"), "COSTUMES")
	_house(-23, -12, 5.0, 5.5, 4.8, Color("e9b8db"), Color("cc5481"), "CANDY")
	_house(23, -13, 5.4, 5.2, 4.7, Color("e4caae"), Color("ba4c65"), "GIFTS")
	_house(-23, 13, 5.5, 4.9, 4.6, Color("a6cfc2"), Color("d76963"), "FLOWERS")
	_house(24, 13, 5.7, 5.5, 4.9, Color("edd2b1"), Color("ca6a45"), "ARCADE")
	# Bunting flags over plaza.
	for j in 11:
		var x: float = -8.0 + float(j) * 1.6
		_box(Vector3(x, 5.6, -8.7), Vector3(0.65, 0.47, 0.055), [ROSE, GOLD, TEAL, Color("7d75d6")][j % 4])
	_box(Vector3(0, 5.95, -8.7), Vector3(20, 0.04, 0.04), Color("f3eed0"))

func _make_pet_garden() -> void:
	var x: float = -34.0
	var z: float = 22.0
	_box(Vector3(x, 0.17, z), Vector3(22.0, 0.27, 22.0), Color("70bc72"), false, "grass")
	_ring(Vector3(x, 0.36, z), 4.2, 4.6, Color("ead9ae"))
	_box(Vector3(x, 0.27, z), Vector3(3.7, 0.12, 19), Color("debb85"), false, "cobble")
	_box(Vector3(x, 0.27, z), Vector3(19, 0.12, 3.7), Color("debb85"), false, "cobble")
	for k in 12:
		var a: float = float(k) * TAU / 12.0
		var px: float = x + cos(a) * 9.3
		var pz: float = z + sin(a) * 9.3
		_box(Vector3(px, 0.74, pz), Vector3(0.2, 1.18, 0.22), Color("f7e4c0"))
	_box(Vector3(x, 0.45, z - 10), Vector3(14, 0.25, 0.25), Color("e5bd84"))
	_house(x + 4.8, z - 6.5, 3.9, 3.7, 3.25, Color("c2d9a6"), Color("dc7865"), "ADOPT A PET")
	for i in 7:
		var fx: float = x + sin(float(i) * 1.9) * 7.5
		var fz: float = z + cos(float(i) * 2.35) * 7.0
		_ball(Vector3(fx, 0.37, fz), 0.31, [Color("ef7299"), Color("f6bc51"), Color("9384ed")][i % 3])
	_text(Vector3(x, 5.2, z), "PET GARDEN", Color("fff4b0"), 1.0)

func _make_water_park() -> void:
	var x: float = -32.0
	var z: float = -31.0
	_box(Vector3(x, 0.14, z), Vector3(27.0, 0.28, 27.0), Color("f4ce95"), false)
	_box(Vector3(x, 0.31, z), Vector3(19.0, 0.16, 16.0), Color("fff5d2"), false)
	_box(Vector3(x, 0.41, z), Vector3(18.0, 0.10, 15.0), Color("42aacf"), false, "water")
	for i in 5:
		var a: float = float(i) * TAU / 5.0
		_ring(Vector3(x + cos(a) * 5.5, 0.54, z + sin(a) * 4.7), 0.68, 1.04, [Color("f8e25c"), Color("ea678a"), Color("6be4d2")][i % 3], Vector3(0, 0, 0))
	# Slide tower and downward ramps, supported by posts.
	_box(Vector3(x - 8, 3.9, z - 5), Vector3(5.0, 0.27, 5.0), Color("c19ae9"), true)
	for xx in [-10.0, -6.0]:
		for zz in [-7.0, -3.0]:
			_cyl(Vector3(x + xx + 8, 1.9, z + zz + 5), 0.16, 0.16, 3.9, Color("8b7aca"))
	for i in 6:
		var a: float = float(i) / 5.0
		var q := _box(Vector3(x - 8 + a * 8, 3.7 - a * 2.8, z - 5), Vector3(1.8, 0.18, 3.4), [Color("fa7e83"), Color("fdd65d"), Color("3bb7cc")][i % 3], true)
		q.rotation_degrees.z = -10.0
	_text(Vector3(x, 5.8, z + 10), "SPLASH WATER PARK", Color("fbf4bb"), 0.8)

func _make_raceway() -> void:
	var x: float = 32.0
	var z: float = 26.0
	_box(Vector3(x, 0.18, z), Vector3(37, 0.32, 31), Color("728d60"), false)
	_box(Vector3(x, 0.38, z), Vector3(32, 0.12, 25), Color("525e66"), false, "road")
	_box(Vector3(x, 0.47, z), Vector3(18, 0.12, 13), Color("65ae65"), false, "grass")
	for j in 8:
		var q: float = -14.0 + float(j) * 4
		_box(Vector3(x + q, 0.52, z - 9.6), Vector3(2.25, 0.035, 0.20), Color("fff3b5"), false)
		_box(Vector3(x + q, 0.52, z + 9.6), Vector3(2.25, 0.035, 0.20), Color("fff3b5"), false)
	for j in 5:
		var q: float = -9.0 + float(j) * 4.3
		_box(Vector3(x - 13.2, 0.52, z + q), Vector3(0.2, 0.04, 2.3), Color("fff3b5"), false)
		_box(Vector3(x + 13.2, 0.52, z + q), Vector3(0.2, 0.04, 2.3), Color("fff3b5"), false)
	for gate in [Vector2(20,17), Vector2(44,17), Vector2(44,35), Vector2(20,35)]:
		_cyl(Vector3(gate.x, 1.25, gate.y), 0.17, 0.17, 2.55, Color("f7dd91"))
		_ring(Vector3(gate.x, 2.55, gate.y), 0.65, 0.85, Color("f1c45b"))
	_make_car(Vector3(x - 12, 0.95, z - 9), Color("f07765"))
	_make_car(Vector3(x + 13, 0.95, z + 7), Color("76c9e1"))
	_box(Vector3(x, 4.4, z - 13.4), Vector3(12.0, 1.15, 0.8), ROSE)
	_text(Vector3(x, 4.42, z - 14), "RACING CHALLENGE", Color("fff1b8"), 0.74)

func _make_car(pos: Vector3, color: Color) -> void:
	_box(pos + Vector3(0, 0.0, 0), Vector3(3.0, 0.75, 1.6), color)
	_box(pos + Vector3(-0.1, 0.65, 0), Vector3(1.35, 0.95, 1.3), color.lightened(0.06))
	_box(pos + Vector3(-0.1, 0.82, -0.71), Vector3(1.1, 0.55, 0.12), NAVY)
	for side in [-0.88, 0.88]:
		for forward in [-0.95, 0.95]:
			_cyl(pos + Vector3(forward, -0.34, side), 0.38, 0.38, 0.21, Color("243544"), Vector3(90, 0, 0))

func _make_obby() -> void:
	var x: float = 31.0
	var z: float = -29.0
	_box(Vector3(x, 0.15, z), Vector3(37, 0.28, 30), Color("5caa6d"), false)
	_box(Vector3(x - 14, 0.26, z), Vector3(4.8, 0.18, 5.5), Color("e5b675"), false)
	for i in 8:
		var yy: float = 0.56 + float(i) * 0.45
		var px: float = x - 11 + float(i) * 3.2
		var pz: float = z + sin(float(i) * 1.25) * 4.0
		var shade: Color = [Color("e77f8b"), Color("f4c463"), Color("7e9bd8"), Color("72c6a4")][i % 4]
		_box(Vector3(px, yy / 2.0, pz), Vector3(2.65, yy, 2.55), shade, true)
		_box(Vector3(px, yy + 0.07, pz), Vector3(2.86, 0.15, 2.76), shade.lightened(0.15), false)
	_cyl(Vector3(x + 15.5, 5.5, z - 1), 0.08, 0.08, 4.1, CREAM)
	_box(Vector3(x + 16.4, 6.4, z - 1), Vector3(2.0, 1.1, 0.14), GOLD)
	_text(Vector3(x, 7.1, z - 12), "RAINBOW OBBY", Color("fff3b9"), 0.87)

func _make_scenery() -> void:
	# Forest groups deliberately frame the main street without blocking it.
	for i in 43:
		var a: float = float(i) * 2.399963
		var r: float = 40.0 + float(i % 9) * 1.2
		var x: float = cos(a) * r
		var z: float = sin(a) * r
		if absf(x) > 50.0 or absf(z) > 50.0:
			continue
		if i % 3 == 0:
			_pine(x, z, 0.85 + 0.1 * float(i % 4), i % 13 == 0)
		else:
			_round_tree(x, z, 0.8 + 0.1 * float(i % 4), i % 11 == 0)
	for i in 44:
		var a: float = float(i) * 2.3999
		var r: float = 11.0 + float(i % 7) * 3.3
		var x: float = cos(a) * r
		var z: float = sin(a) * r
		if absf(x) < 5.5 or absf(z) < 5.5:
			continue
		_ball(Vector3(x, 0.21, z), 0.17, [Color("ef7992"), Color("f4c765"), Color("a2a0d9")][i % 3])
	for cx in [-22.0, -6.0, 15.0, 31.0]:
		_ball(Vector3(cx, 17.0, -65.0), 3.1, Color("f2f5ef"), 0.5)
		_ball(Vector3(cx + 2.7, 16.5, -65.0), 2.5, Color("f2f5ef"), 0.5)
	# Small protective boundary prevents accidentally walking into endless sea.
	for side in [-1.0, 1.0]:
		_box(Vector3(side * 53.5, 0.5, 0), Vector3(0.5, 1.2, 107), Color("d3be8a"), true)
		_box(Vector3(0, 0.5, side * 53.5), Vector3(107, 1.2, 0.5), Color("d3be8a"), true)
