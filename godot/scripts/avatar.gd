extends CharacterBody3D
## Lightweight colorful blocky avatar with basic walk animation.
## For remote players the CharacterBody has no physics layers; position is interpolated.

var display_name: String = "Sunny"
var palette_index: int = 0
var is_local: bool = false
var target_position: Vector3 = Vector3.ZERO
var target_rotation: float = 0.0
var walking: bool = false
var animation_clock: float = 0.0
var left_arm: Node3D
var right_arm: Node3D
var left_leg: Node3D
var right_leg: Node3D
var body_color: Color

const COLORS := [
	Color("ff6e92"), Color("43c6ff"), Color("ffbb35"),
	Color("a88eff"), Color("41d9b1"), Color("ff8660"),
	Color("6da8ff"), Color("e278e8")
]

func configure(n: String, p: int, local_player: bool) -> void:
	display_name = n
	palette_index = clampi(p, 0, COLORS.size() - 1)
	is_local = local_player

func _ready() -> void:
	body_color = COLORS[palette_index]
	collision_layer = 1 if is_local else 0
	collision_mask = 1 if is_local else 0
	var collider := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.39
	capsule.height = 2.05
	collider.shape = capsule
	add_child(collider)
	
	# Head, face, torso, limbs, backpack and tiny crown.
	_piece(Vector3(0, 0.12, 0), Vector3(0.92, 0.93, 0.55), body_color)
	_piece(Vector3(0, 0.91, 0), Vector3(0.72, 0.7, 0.65), Color("ffe0ad"))
	_piece(Vector3(-0.16, 0.97, -0.34), Vector3(0.095, 0.125, 0.035), Color("243553"))
	_piece(Vector3(0.16, 0.97, -0.34), Vector3(0.095, 0.125, 0.035), Color("243553"))
	_piece(Vector3(0, 0.79, -0.355), Vector3(0.24, 0.055, 0.03), Color("e88789"))
	_piece(Vector3(0, 0.46, 0.37), Vector3(0.68, 0.73, 0.2), Color("3e5478"))
	_piece(Vector3(0, 1.37, 0), Vector3(0.84, 0.18, 0.75), body_color.darkened(0.13))
	_piece(Vector3(0, 1.52, 0.02), Vector3(0.37, 0.19, 0.3), Color("ffdf68"))
	left_arm = Node3D.new()
	right_arm = Node3D.new()
	left_leg = Node3D.new()
	right_leg = Node3D.new()
	for joint in [left_arm, right_arm, left_leg, right_leg]:
		add_child(joint)
	left_arm.position = Vector3(-0.58, 0.42, 0)
	right_arm.position = Vector3(0.58, 0.42, 0)
	left_leg.position = Vector3(-0.22, -0.3, 0)
	right_leg.position = Vector3(0.22, -0.3, 0)
	_piece(Vector3(0, -0.27, 0), Vector3(0.28, 0.62, 0.28), Color("ffe0ad"), left_arm)
	_piece(Vector3(0, -0.27, 0), Vector3(0.28, 0.62, 0.28), Color("ffe0ad"), right_arm)
	_piece(Vector3(0, -0.31, 0), Vector3(0.35, 0.66, 0.37), Color("293b69"), left_leg)
	_piece(Vector3(0, -0.31, 0), Vector3(0.35, 0.66, 0.37), Color("293b69"), right_leg)
	_piece(Vector3(0, -0.61, -0.13), Vector3(0.38, 0.21, 0.64), Color("f9faff"), left_leg)
	_piece(Vector3(0, -0.61, -0.13), Vector3(0.38, 0.21, 0.64), Color("f9faff"), right_leg)
	
	var tag := Label3D.new()
	tag.text = display_name
	tag.position = Vector3(0, 2.08, 0)
	tag.font_size = 40
	tag.pixel_size = 0.005
	tag.outline_size = 8
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.modulate = Color.WHITE
	add_child(tag)
	target_position = global_position

func _piece(pos: Vector3, size: Vector3, color: Color, parent: Node3D = null) -> MeshInstance3D:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.position = pos
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.63
	mesh.material_override = mat
	if parent == null:
		add_child(mesh)
	else:
		parent.add_child(mesh)
	return mesh

func _process(delta: float) -> void:
	if not is_local:
		var distance_to_target := global_position.distance_to(target_position)
		if distance_to_target > 6.0:
			global_position = target_position
		else:
			global_position = global_position.lerp(target_position, minf(1.0, delta * 12.0))
		rotation.y = lerp_angle(rotation.y, target_rotation, minf(1.0, delta * 12.0))
	animation_clock += delta * (11.0 if walking else 3.0)
	var amplitude := 0.44 if walking else 0.045
	left_leg.rotation.x = sin(animation_clock) * amplitude
	right_leg.rotation.x = -sin(animation_clock) * amplitude
	left_arm.rotation.x = -sin(animation_clock) * amplitude
	right_arm.rotation.x = sin(animation_clock) * amplitude

func control_move(axis: Vector2, jump_pressed: bool, delta: float) -> void:
	if not is_local:
		return
	var motion := Vector3(axis.x, 0.0, axis.y)
	if motion.length() > 1.0:
		motion = motion.normalized()
	walking = motion.length() > 0.12
	velocity.x = motion.x * 6.8
	velocity.z = motion.z * 6.8
	if is_on_floor():
		if jump_pressed:
			velocity.y = 8.3
		else:
			velocity.y = -0.1
	else:
		velocity.y -= 19.6 * delta
	move_and_slide()
	if walking:
		rotation.y = lerp_angle(rotation.y, atan2(-motion.x, -motion.z), minf(1.0, delta * 11.0))
	if global_position.y < -7.0 or absf(global_position.x) > 80.0 or absf(global_position.z) > 80.0:
		global_position = Vector3(0, 2.0, 0)
		velocity = Vector3.ZERO

func set_remote_state(pos: Vector3, rot_y: float) -> void:
	walking = pos.distance_to(target_position) > 0.045
	target_position = pos
	target_rotation = rot_y
