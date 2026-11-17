extends Node
## WebSocket client for Cloudflare Durable Object room server.
## After deploying server, replace SERVER_URL with your own workers.dev URL.

signal event_received(message: Dictionary)
signal connection_changed(message: String)
signal connection_lost(message: String)

const SERVER_URL: String = "wss://REPLACE-WITH-YOUR-WORKER.workers.dev"
const SEND_INTERVAL: float = 0.16 # about 6 updates/second, lower free-tier usage
var socket: WebSocketPeer = WebSocketPeer.new()
var connected: bool = false
var connecting: bool = false
var local_id: String = ""
var room_code: String = ""
var elapsed: float = 0.0
var ping_timer: float = 0.0
var last_state: int = -1

func configured() -> bool:
	return not SERVER_URL.contains("REPLACE-WITH")

func connect_room(code: String, alias: String, avatar: int) -> bool:
	if not configured():
		connection_changed.emit("Server not configured yet. Use Practice Offline or set the Worker URL.")
		return false
	disconnect_room()
	room_code = code
	local_id = ""
	var endpoint := SERVER_URL.rstrip("/") + "/room/" + code + "?alias=" + alias.uri_encode() + "&avatar=" + str(avatar)
	socket = WebSocketPeer.new()
	var err := socket.connect_to_url(endpoint)
	if err != OK:
		connection_changed.emit("Could not connect to server (code %d)." % err)
		return false
	connected = false
	connecting = true
	last_state = -1
	connection_changed.emit("Connecting to private room " + code + " …")
	return true

func disconnect_room() -> void:
	if socket.get_ready_state() == WebSocketPeer.STATE_OPEN:
		socket.close(1000, "Leaving room")
	connected = false
	connecting = false
	room_code = ""
	local_id = ""

func _process(delta: float) -> void:
	if not connecting and not connected:
		return
	socket.poll()
	var state := socket.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not connected:
			connected = true
			connecting = false
			connection_changed.emit("Connected — waiting for world snapshot …")
		while socket.get_available_packet_count() > 0:
			var text_message := socket.get_packet().get_string_from_utf8()
			var parsed: Variant = JSON.parse_string(text_message)
			if typeof(parsed) == TYPE_DICTIONARY:
				event_received.emit(parsed)
		ping_timer += delta
		if ping_timer >= 9.0:
			ping_timer = 0.0
			send_message({"t":"ping"})
	elif state == WebSocketPeer.STATE_CLOSED:
		connected = false
		connecting = false
		connection_lost.emit("Connection closed (%d): %s" % [socket.get_close_code(), socket.get_close_reason()])

func send_message(payload: Dictionary) -> void:
	if connected:
		socket.send_text(JSON.stringify(payload))

func send_position(pos: Vector3, rot: float) -> void:
	send_message({
		"t": "move",
		"x": snappedf(pos.x, 0.01),
		"y": snappedf(pos.y, 0.01),
		"z": snappedf(pos.z, 0.01),
		"r": snappedf(rot, 0.01)
	})

func collect_coin(index: int) -> void:
	send_message({"t":"collect", "coin":index})

func request_travel(stop: int) -> void:
	# Request server-approved movement to a registered city destination.
	send_message({"t": "travel", "stop": stop})
