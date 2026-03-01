extends PanelContainer
class_name Card

@onready var card_vis : Control = $Margin
@onready var selection : Button = $Selectable
@export var count_label : Label
@export var number : Control

var rank = ""
var is_my_card : bool = false
var count : int = 1

func _ready():
	add_to_group("HandListener")
	
	selection.disabled = true
	number.hide()
	selection.pressed.connect(on_selection)

func add_to_count():
	count += 1
	
	number.show()
	count_label.text = str(count, " of ", GoFish.CARDS[rank].tier)

func set_up(card : Dictionary, is_me):
	rank = card.rank
	is_my_card = is_me
	
	if is_me:
		card_vis.show()
		match card.suite:
			"R": self_modulate = Color("db3f39ff")
			"B": self_modulate = Color("4665d3ff")
			"G": self_modulate = Color("46943fff")
			"Y": self_modulate = Color("d49936ff")
		for label : Label in card_vis.get_children():
			label.text = GoFish.CARDS[rank].name
	else:
		card_vis.hide()
		self_modulate = Color("252826ff")

func on_player_selected(_p):
	if is_my_card: selection.disabled = false

func on_player_deselected():
	selection.disabled = true

func on_selection():
	get_tree().call_group("CardListener", "on_card_selected", rank)
