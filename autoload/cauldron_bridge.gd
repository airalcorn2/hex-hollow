extends Node

# Talks to the real Halloween cauldron prop over the LAN, so collecting
# ingredients and finishing the spell in-game triggers real witch voices,
# a real splash, and real LED ring color on the physical prop sitting next
# to whoever's playing -- see cauldron/game_bridge.py on the Pi, which
# receives these calls. Edit BASE_URL to the Pi's current LAN address
# before playing; left empty (the default), every call below is a silent
# no-op, so the game plays fine with no cauldron connected.
const BASE_URL := ""
const REQUEST_TIMEOUT_SEC := 3.0

var _request: HTTPRequest
var _timeout_timer: Timer


func _ready() -> void:
	_request = HTTPRequest.new()
	add_child(_request)
	_timeout_timer = Timer.new()
	_timeout_timer.one_shot = true
	_timeout_timer.wait_time = REQUEST_TIMEOUT_SEC
	_timeout_timer.timeout.connect(_on_timeout)
	add_child(_timeout_timer)


func notify_deposit(ingredient_id: String) -> void:
	_post("/deposit", {"ingredient": ingredient_id})


func notify_victory() -> void:
	_post("/victory", {})


# Fire-and-forget: nothing here waits on or reads the response, so a slow
# or unreachable cauldron never stalls the game itself.
func _post(path: String, payload: Dictionary) -> void:
	if BASE_URL.is_empty():
		return
	var headers := PackedStringArray(["Content-Type: application/json"])
	var error := _request.request(
		BASE_URL + path, headers, HTTPClient.METHOD_POST, JSON.stringify(payload)
	)
	if error == OK:
		_timeout_timer.start()
	else:
		push_warning("CauldronBridge: couldn't reach the cauldron (error %d)." % error)


func _on_timeout() -> void:
	_request.cancel_request()
