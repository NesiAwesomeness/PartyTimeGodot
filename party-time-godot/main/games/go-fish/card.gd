extends Control
class_name Card

@export var card_vis : Control
@export var selection : Button
@export var count_label : Label
@export var number : Control
@export var card_body : PanelContainer

var rank = ""
var is_my_card : bool = false
var count : int = 1

var rotation_tween
var position_tween

var animate = false

func _ready():
	add_to_group("HandListener")
	
	selection.disabled = true
	number.hide()
	
	selection.pressed.connect(on_selection)

func add_to_count():
	count += 1
	
	number.show()
	count_label.text = str(count, " of ", GoFish.CARDS[rank].tier)
	wiggle()


func wiggle():
	if not animate: return
	var wiggle_amount = deg_to_rad(5.0) # 5 degrees wiggle
	var duration = 0.06
	
	if not rotation_tween: rotation_tween = create_tween().set_loops(2) # Repeat the wiggle twice
	else: rotation_tween.chain()
	
	#wiggle
	rotation_tween.tween_property(card_body, "rotation", rotation + wiggle_amount, duration)
	rotation_tween.tween_property(card_body, "rotation", rotation - wiggle_amount, duration)
	rotation_tween.chain().tween_property(card_body, "rotation", rotation, duration)
	
	if not position_tween: position_tween = create_tween()
	else: position_tween.chain()
	
	#rise and fall
	position_tween.tween_property(card_body, "position:y", -32.0, duration * 2.0).set_delay(duration * 3.0)
	position_tween.chain().tween_property(card_body, "position:y", 0.0, duration * 2.0)

func set_up(card : Dictionary, is_me):
	wiggle()
	
	rank = card.rank
	is_my_card = is_me
	
	if is_me:
		card_vis.show()
		match card.suite:
			"R": card_body.self_modulate = Color("db3f39ff")
			"B": card_body.self_modulate = Color("4665d3ff")
			"G": card_body.self_modulate = Color("46943fff")
			"Y": card_body.self_modulate = Color("d49936ff")
		for label : Label in card_vis.get_children():
			label.text = GoFish.CARDS[rank].name
	else:
		card_vis.hide()
		card_body.self_modulate = Color("252826ff")

func on_player_selected(_p):
	if is_my_card: selection.disabled = false

func on_player_deselected():
	selection.disabled = true

func on_selection():
	get_tree().call_group("CardListener", "on_card_selected", rank)
