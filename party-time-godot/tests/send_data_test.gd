extends Node

var svelte_callback_ref

#this only works in Web Builds
func _ready():
	svelte_callback_ref = JavaScriptBridge.create_callback(add_name)
	var window = JavaScriptBridge.get_interface("window")
	window.sendToGodot = svelte_callback_ref

func add_name(args):
	var data : JavaScriptObject = args[0]
	prints("Received data from Svelte: ", data.message, data)
	#send the data back.
	
	send_data_to_svelte("successful test run", {
		"value" : data.message,
	})

func send_data_to_svelte(message_name: String, payload : Dictionary):
	var message_data = {"message": message_name, "data": payload }
	var json_string = JSON.stringify(message_data)
	var js_code = "window.parent.postMessage(%s, '*');" % json_string
	JavaScriptBridge.eval(js_code)
