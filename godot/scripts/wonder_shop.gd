extends CanvasLayer
## Child-safe cosmetic shop. All items use earned offline points only.
## No real-money payments, no ads, no accounts, no external links.
## Data is stored locally under user://. Online room scores remain server-owned.

const SAVE_PATH: String = "user://wonderworld_player_shop.cfg"
const CATEGORIES: Array[String] = ["HATS", "WINGS", "BACKPACKS", "AURAS", "PETS", "CARS", "TOYS"]
const SHADES: Array[Color] = [
	Color("ec748f"), Color("53a9e9"), Color("65d2b0"), Color("f5cf59"),
	Color("a483e2"), Color("ee9d75"), Color("485e9e"), Color("e5e7ed"),
	Color("e6776d"), Color("90c65c"), Color("86d8e8"), Color("c071b7")
]
const NAMES: Array[String] = [
	"Rose", "Ocean", "Mint", "Sunshine", "Violet", "Peach",
	"Midnight", "Snow", "Coral", "Lime", "Sky", "Berry"
]

var controller: Node
var catalog: Array[Dictionary] = []
var owned: Dictionary = {}
var equipped: Dictionary = {}
var wallet: int = 150
var chosen_category: String = "HATS"
var backdrop: ColorRect
var cards: GridContainer
var balance_label: Label
var notice_label: Label
var aura_node: Node3D
var anim_time: float = 0.0

func _ready() -> void:
	layer = 10
	_make_catalog()
	_load_profile()
	_build_shop()

func _make_catalog() -> void:
	for c in CATEGORIES.size():
		var category: String = CATEGORIES[c]
		for i in SHADES.size():
			catalog.append({
				"id": category.to_lower() + "_" + str(i),
				"category": category,
				"name": NAMES[i] + " " + category.substr(0, category.length() - 1).capitalize(),
				"price": 35 + 15 * c + 10 * (i % 4),
				"color": SHADES[i]
			})

func _load_profile() -> void:
	var config := ConfigFile.new()
	if config.load(SAVE_PATH) != OK:
		return
	wallet = maxi(0, int(config.get_value("player", "wallet", 150)))
	var saved_owned: Variant = config.get_value("player", "owned", [])
	if saved_owned is Array:
		for item_id in saved_owned:
			owned[str(item_id)] = true
	var saved_equipped: Variant = config.get_value("player", "equipped", {})
	if saved_equipped is Dictionary:
		for key in saved_equipped.keys():
			equipped[str(key)] = str(saved_equipped[key])

func _save_profile() -> void:
	var config := ConfigFile.new()
	config.set_value("player", "wallet", wallet)
	config.set_value("player", "owned", owned.keys())
	config.set_value("player", "equipped", equipped)
	var err: Error = config.save(SAVE_PATH)
	if err != OK:
		push_warning("Could not save local WonderWorld store progress: " + str(err))

func get_wallet() -> int:
	return wallet

func persist_wallet(value: int) -> void:
	var new_wallet: int = maxi(value, 0)
	if wallet == new_wallet:
		return
	wallet = new_wallet
	_save_profile()
	_refresh_balance()

func _box_style(color: Color, corner: int = 14) -> StyleBoxFlat:
	var st := StyleBoxFlat.new()
	st.bg_color = color
	st.set_corner_radius_all(corner)
	st.content_margin_left = 12
	st.content_margin_right = 12
	st.content_margin_top = 8
	st.content_margin_bottom = 8
	return st

func _label(value: String, size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = value
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	return label

func _button(value: String, color: Color) -> Button:
	var button := Button.new()
	button.text = value
	button.custom_minimum_size = Vector2(95, 43)
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_stylebox_override("normal", _box_style(color, 11))
	button.add_theme_stylebox_override("hover", _box_style(color.lightened(0.12), 11))
	button.add_theme_stylebox_override("pressed", _box_style(color.darkened(0.16), 11))
	button.add_theme_color_override("font_color", Color.WHITE)
	return button

func _build_shop() -> void:
	backdrop = ColorRect.new()
	backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.09, 0.92)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)
	var panel := PanelContainer.new()
	panel.anchor_left = 0.12
	panel.anchor_right = 0.88
	panel.anchor_top = 0.06
	panel.anchor_bottom = 0.94
	panel.add_theme_stylebox_override("panel", _box_style(Color("182f47"), 18))
	backdrop.add_child(panel)
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 15)
	margin.add_theme_constant_override("margin_bottom", 15)
	panel.add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 9)
	margin.add_child(layout)
	var title_row := HBoxContainer.new()
	layout.add_child(title_row)
	title_row.add_child(_label("WONDER STORE • 84 STYLES", 25, Color("ffe0a1")))
	var filler := Control.new()
	filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(filler)
	balance_label = _label("", 20, Color("b0f7dd"))
	title_row.add_child(balance_label)
	var close_button := _button("CLOSE ✕", Color("b65d74"))
	close_button.pressed.connect(hide_shop)
	title_row.add_child(close_button)
	var description := _label("Earn points by exploring and playing. All purchases are virtual — no real money.", 14, Color("bbd8e9"))
	layout.add_child(description)
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 6)
	layout.add_child(tabs)
	for category in CATEGORIES:
		var category_button := _button(category, Color("3f6983"))
		category_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		category_button.pressed.connect(_choose_category.bind(category))
		tabs.add_child(category_button)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	cards = GridContainer.new()
	cards.columns = 3
	cards.add_theme_constant_override("h_separation", 10)
	cards.add_theme_constant_override("v_separation", 10)
	cards.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(cards)
	notice_label = _label("Select a style to buy or equip.", 16, Color("fff1cb"))
	layout.add_child(notice_label)
	_refresh_cards()
	_refresh_balance()
	backdrop.visible = false

func _refresh_balance() -> void:
	if balance_label == null:
		return
	balance_label.text = "✦ %d POINTS  " % wallet

func _choose_category(category: String) -> void:
	chosen_category = category
	_refresh_cards()

func _refresh_cards() -> void:
	if cards == null:
		return
	for child in cards.get_children():
		cards.remove_child(child)
		child.queue_free()
	for item in catalog:
		if str(item["category"]) != chosen_category:
			continue
		var card := PanelContainer.new()
		card.custom_minimum_size = Vector2(225, 108)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card.add_theme_stylebox_override("panel", _box_style(Color("264661"), 11))
		cards.add_child(card)
		var container := VBoxContainer.new()
		container.add_theme_constant_override("separation", 5)
		card.add_child(container)
		var caption := _label(str(item["name"]), 18, item["color"])
		container.add_child(caption)
		var item_id: String = str(item["id"])
		var category: String = str(item["category"])
		var action: String = "BUY • %d POINTS" % int(item["price"])
		if owned.has(item_id):
			action = "EQUIPPED ✓" if str(equipped.get(category, "")) == item_id else "EQUIP"
		var button := _button(action, Color("358f8e") if owned.has(item_id) else Color("8669b4"))
		button.pressed.connect(_buy_or_equip.bind(item_id))
		container.add_child(button)

func _get_item(id: String) -> Dictionary:
	for item in catalog:
		if str(item["id"]) == id:
			return item
	return {}

func _buy_or_equip(id: String) -> void:
	if controller == null or not bool(controller.get("playing")):
		return
	var item: Dictionary = _get_item(id)
	if item.is_empty():
		return
	var category: String = str(item["category"])
	if not owned.has(id):
		# Public multiplayer score is server-authoritative; local purchases do not debit it.
		if bool(controller.get("multiplayer_mode")):
			notice_label.text = "Shop purchases currently work in OFFLINE practice only."
			return
		var price: int = int(item["price"])
		var available: int = int(controller.get("current_score"))
		if available < price:
			notice_label.text = "Not enough points! Explore, race or play foam tag."
			return
		owned[id] = true
		controller.set("current_score", available - price)
		controller.call("_update_hud")
		notice_label.text = "Purchased " + str(item["name"]) + "!"
	else:
		notice_label.text = "Equipped " + str(item["name"]) + "."
	equipped[category] = id
	_save_profile()
	apply_equipment()
	_refresh_cards()
	_refresh_balance()

func open_shop() -> void:
	if controller == null or not bool(controller.get("playing")):
		return
	_refresh_balance()
	_refresh_cards()
	backdrop.visible = true

func hide_shop() -> void:
	backdrop.visible = false

func _mesh_box(parent: Node3D, pos: Vector3, size: Vector3, color: Color) -> Node3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.5
	mi.material_override = material
	parent.add_child(mi)
	return mi

func _sphere(parent: Node3D, pos: Vector3, radius: float, color: Color) -> Node3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 8
	mi.mesh = mesh
	mi.position = pos
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mi.material_override = material
	parent.add_child(mi)
	return mi

func _color_for(category: String) -> Color:
	var id: String = str(equipped.get(category, ""))
	if id == "" or not owned.has(id):
		return Color.TRANSPARENT
	var item: Dictionary = _get_item(id)
	return item.get("color", Color.TRANSPARENT)

func apply_equipment() -> void:
	if controller == null:
		return
	var player: Node3D = controller.get("local_player")
	if player == null or not is_instance_valid(player):
		return
	var old: Node = player.get_node_or_null("WardrobeCosmetics")
	if old != null:
		player.remove_child(old)
		old.queue_free()
	var cosmetic := Node3D.new()
	cosmetic.name = "WardrobeCosmetics"
	player.add_child(cosmetic)
	var shade: Color = _color_for("HATS")
	if shade.a > 0.1:
		_mesh_box(cosmetic, Vector3(0, 1.71, 0), Vector3(0.97, 0.14, 0.91), shade.darkened(0.17))
		_mesh_box(cosmetic, Vector3(0, 1.93, 0.03), Vector3(0.74, 0.44, 0.71), shade)
	shade = _color_for("WINGS")
	if shade.a > 0.1:
		for side in [-1.0, 1.0]:
			var wing: Node3D = _mesh_box(cosmetic, Vector3(side * 0.89, 0.62, 0.37), Vector3(0.66, 1.25, 0.14), shade)
			wing.rotation.z = side * -0.40
			_sphere(cosmetic, Vector3(side * 1.1, 1.15, 0.45), 0.30, shade.lightened(0.20))
	shade = _color_for("BACKPACKS")
	if shade.a > 0.1:
		_mesh_box(cosmetic, Vector3(0, 0.37, 0.56), Vector3(0.77, 0.87, 0.40), shade)
		_mesh_box(cosmetic, Vector3(0, 0.66, 0.78), Vector3(0.60, 0.14, 0.12), shade.darkened(0.25))
	shade = _color_for("TOYS")
	if shade.a > 0.1:
		_mesh_box(cosmetic, Vector3(0.94, 0.30, -0.09), Vector3(0.12, 0.55, 0.12), Color("f3d9ab"))
		_sphere(cosmetic, Vector3(0.94, 0.70, -0.09), 0.32, shade)
	shade = _color_for("AURAS")
	aura_node = null
	if shade.a > 0.1:
		var aura := Node3D.new()
		aura.name = "CosmeticAura"
		player.add_child(aura)
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.95
		mesh.outer_radius = 1.13
		mesh.rings = 12
		mesh.ring_segments = 22
		ring.mesh = mesh
		ring.material_override = StandardMaterial3D.new()
		(ring.material_override as StandardMaterial3D).albedo_color = shade
		aura.add_child(ring)
		aura.position.y = -0.90
		aura_node = aura
	# Equip a colored pet collar and color accents without changing safe movement behavior.
	var pet: Node3D = controller.get("pet_companion")
	if pet != null and is_instance_valid(pet):
		var prior: Node = pet.get_node_or_null("WardrobePet")
		if prior != null:
			pet.remove_child(prior)
			prior.queue_free()
		shade = _color_for("PETS")
		if shade.a > 0.1:
			var collar := Node3D.new()
			collar.name = "WardrobePet"
			pet.add_child(collar)
			_mesh_box(collar, Vector3(0, 0.25, -0.32), Vector3(0.8, 0.13, 0.25), shade)
			_sphere(collar, Vector3(0, 0.20, -0.51), 0.12, shade.lightened(0.15))
	var ride: Node3D = controller.get("ride_shell")
	shade = _color_for("CARS")
	if ride != null and is_instance_valid(ride) and shade.a > 0.1:
		for index in [0, 1]:
			if index < ride.get_child_count() and ride.get_child(index) is MeshInstance3D:
				var part: MeshInstance3D = ride.get_child(index)
				var paint := StandardMaterial3D.new()
				paint.albedo_color = shade
				paint.roughness = 0.32
				part.material_override = paint

func _process(delta: float) -> void:
	anim_time += delta
	if aura_node != null and is_instance_valid(aura_node):
		aura_node.rotation.y += delta * 0.95
		aura_node.scale = Vector3.ONE * (1.0 + 0.08 * sin(anim_time * 3.0))
