extends SceneTree
## Godot headless integration test: actually starts offline play and uses new features.
## Run: godot --headless --path godot --script res://tests/feature_smoke.gd

func _initialize() -> void:
	call_deferred("_run_tests")

func _fail(message: String) -> void:
	push_error("TEST FAILURE: " + message)
	quit(2)

func _run_tests() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		_fail("Main scene could not load")
		return
	var game: Variant = scene.instantiate()
	root.add_child(game)
	await process_frame
	game._practice()
	await process_frame
	if not game.playing or game.local_player == null:
		_fail("Offline practice did not spawn a character")
		return
	var shop: Variant = game.shop
	var first_wallet: int = int(game.current_score)
	shop.open_shop()
	if not shop.backdrop.visible:
		_fail("Store did not open")
		return
	shop._buy_or_equip("hats_0")
	if not shop.owned.has("hats_0") or game.current_score != first_wallet - 35:
		_fail("Virtual-point purchase did not debit currency and unlock the item")
		return
	if game.local_player.get_node_or_null("WardrobeCosmetics") == null:
		_fail("Purchased hat did not appear in the avatar wardrobe")
		return
	shop.hide_shop()
	if shop.backdrop.visible:
		_fail("Store did not close")
		return
	var activities: Variant = game.world_activities
	var player: Variant = game.local_player
	player.global_position = Vector3(-15, 1.55, 37.3)
	if activities.prompt_at(player.global_position) != "OPEN HOME":
		_fail("Cannot find a playable house door")
		return
	activities.use_nearby(player)
	if not bool(activities.houses[0]["open"]):
		_fail("House door did not open")
		return
	player.global_position = Vector3(-15, 1.55, 41)
	await process_frame
	if (activities.houses[0]["roof"] as Node3D).visible:
		_fail("House roof did not hide for a player inside")
		return
	player.global_position = Vector3(-35, 1.55, -34)
	var slide_result: String = activities.begin_slide(player)
	if not slide_result.begins_with("WATER SLIDE!") or not activities.is_riding():
		_fail("Water-slide animation did not start")
		return
	activities._process(3.9)
	if activities.is_riding() or player.global_position.y > 2.0:
		_fail("Water slide did not reach pool exit")
		return
	player.global_position = Vector3(-41, 1.55, 15)
	activities.use_nearby(player)
	if not activities.is_riding() or activities.ride_kind != "swing":
		_fail("Playground swing did not start")
		return
	activities._process(8.1)
	if activities.is_riding():
		_fail("Swing ride did not release player")
		return
	var battle_message: String = activities.start_or_tag(player)
	if not battle_message.begins_with("FOAM TAG!") or not activities.battle_active:
		_fail("Foam-tag arena did not start")
		return
	var hit_message: String = activities.start_or_tag(player)
	if not hit_message.begins_with("HIT!"):
		_fail("Foam projectile did not hit a nearby practice target")
		return
	activities._process(35.2)
	if activities.battle_active:
		_fail("Foam-tag timer did not complete")
		return
	# Allow the foam-ball tween to finish before releasing the scene.
	await create_timer(0.40).timeout
	activities.reset_player()
	shop.hide_shop()
	game.queue_free()
	shop = null
	player = null
	activities = null
	game = null
	scene = null
	await process_frame
	await process_frame
	print("PASS INTEGRATION: offline spawn, 84-style catalog, purchase/equip, house door/interior, moving water slide, swing ride, foam-tag hits and timeout.")
	quit(0)
