extends PanelContainer

signal use_power(player, power)
signal ask(player, rank)

var ask_mode := false

@export var request_label : RichTextLabel
@export var send_control : Control
@export var send_button : Button

@export_category("Player Select")
@export var player_name_label : Label
@export var player_select_button_scene : PackedScene
@export var player_list : VBoxContainer
@export var player_select_menu : Control
@export var player_select : Control
@export var player_select_menu_button : Button
@export var select_panel : PanelContainer

var selected_player_name = ""
var single_option = ''
var selected_rank = ''

func _ready():
	add_to_group("CardListener")
	
	send_button.pressed.connect( on_send_pressed )
	player_select_menu_button.pressed.connect( open_player_select_menu )
	
	var members = GameManager.chat_data.members
	
	for member in members:
		if member == GameManager.my_uid: continue
		if members.size() == 2:
			single_option = GameManager.chat_data.members[member]
			player_name_label.custom_minimum_size.x = 0.0
			select_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
			reset()
			return
		
		var _player_select : Button = player_select_button_scene.instantiate()
		var player_name = GameManager.chat_data.members[member]
		_player_select.text = player_name
		
		player_list.add_child(_player_select)
		_player_select.pressed.connect( func(): on_player_selected( player_name ) )
	
	reset()

func get_player_id(player_name):
	return GameManager.chat_data.members.find_key(player_name)

func _input(event):
	#if the player clicks outside that rect the close it.
	if event is InputEventMouse: if event.is_pressed():
		if not player_select.visible: return
		if not player_select_menu.get_global_rect().has_point(event.position):
			player_select.hide()
			player_name_label.text = selected_player_name if selected_player_name else "Select Player"
			
			player_select_menu_button.show()
			send_control.visible = selected_player_name != ''

func open_player_select_menu():
	if single_option != '': return
	
	#print("opening...")
	show()
	
	player_name_label.text = "Select Player"
	
	player_select.show()
	player_select_menu_button.hide()

func on_player_selected(player_name):
	#var player_id = get_player_id(player_name)
	
	#if GoFish.target_player_id == player_id and GoFish.quick_time_on_going: 
		#print("can't select them yet...")
		#return
	
	show()
	
	selected_player_name = player_name
	player_name_label.text = player_name
	
	player_select.hide()
	
	player_select_menu_button.show()
	send_control.show()

func on_card_selected(rank):
	if rank == '':
		reset()
		return
	if single_option != '': send_control.show()
	
	if GoFish.PASSIVES.has(rank):
		request_label.text = "[wave] Drag and Drop over any card. [/wave]"
		self_modulate = Color("647843ff")
		show()
		
		return
	
	var power_card = not GoFish.CARDS.has(rank)
	ask_mode = not power_card
	
	selected_rank = rank
	
	reset_player()
	set_up_panel( power_card )

func set_up_panel( is_power : bool ):
	show()
	
	self_modulate = Color("db3f39ff") if is_power else Color("252525ff") 
	request_label.text = (
		str("Using [shake]", GoFish.POWERS[selected_rank], "[/shake] on") if 
		is_power else str("I need [wave]", GoFish.CARDS[selected_rank].name, "[/wave] from")
	)

func on_send_pressed():
	#var target_id : String = get_player_id(selected_player_name)
	
	if ask_mode:
		if not GoFish.is_my_turn:
			print("not your turn")
			return
		
		if single_option != '':
			selected_player_name = single_option
			
		ask.emit(selected_player_name, selected_rank)
	else:
		if GoFish.is_my_turn:
			return
		
		#if GoFish.quick_time_on_going and target_id == GoFish.target_player_id:
			#print("I can't use powers on ", selected_player_name, " right now")
			#return
		
		use_power.emit(selected_player_name, selected_rank)
		#print("I'm using powers on ", selected_player_name)
	
	reset()

func reset():
	hide()
	self_modulate = Color("252525ff")
	
	selected_rank = ""
	request_label.text = ""
	
	reset_player()

func reset_player():
	#print(single_option, " one option")
	
	selected_player_name = "" if single_option == '' else single_option
	player_select_menu_button.visible = single_option == ''
	send_control.visible = single_option != ''
	
	player_select.hide()
	player_name_label.text = "Select Player" if single_option == '' else single_option
