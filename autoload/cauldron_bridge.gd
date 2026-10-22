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


func notify_deposit(ingredient_id: String) -> void:
	_post("/deposit", {"ingredient": ingredient_id})


func notify_victory() -> void:
	_post("/victory", {})


# Fire-and-forget: nothing here waits on or reads the response, so a slow
# or unreachable cauldron never stalls the game itself. A fresh
# HTTPRequest per call, not one shared node -- the final ingredient's
# deposit and the victory call that follows it fire back-to-back with no
# await in between (see hollow_world.gd's interact()), and a single
# HTTPRequest can only have one request in flight at a time: the second
# call would hit ERR_BUSY while the first is still out on the network and
# silently drop, which is exactly what was happening before this.
func _post(path: String, payload: Dictionary) -> void:
	if BASE_URL.is_empty():
		return
	var request := HTTPRequest.new()
	add_child(request)
	request.request_completed.connect(
		func(_result: int, _code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
			if is_instance_valid(request):
				request.queue_free()
	)
	var headers := PackedStringArray(["Content-Type: application/json"])
	var error := request.request(
		BASE_URL + path, headers, HTTPClient.METHOD_POST, JSON.stringify(payload)
	)
	if error != OK:
		push_warning("CauldronBridge: couldn't reach the cauldron (error %d)." % error)
		request.queue_free()
		return
	var timer := get_tree().create_timer(REQUEST_TIMEOUT_SEC)
	timer.timeout.connect(
		func() -> void:
			if is_instance_valid(request):
				request.cancel_request()
				request.queue_free()
	)
