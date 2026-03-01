extends Control
class_name CardHand

@export var card_scene : PackedScene
@export var is_me : bool = false
var hand : Array
var hand_name = "Jeff"

@export var hand_container : HBoxContainer
@export var name_tag : Label
@export var score_tag : Label

@export var button : Button

func _ready():
	name_tag.text = hand_name
	if is_me:
		name_tag.hide()
		button.queue_free()
		return
	button.pressed.connect(on_button_pressed)

func update_score(score):
	score_tag.text = str(int(score))

func update_hand(new_hand : Array):
	if not score_tag.visible:
		score_tag.show()
	
	var cards_to_remove : Array = hand.filter(func(card): return not new_hand.has(card))
	var cards_to_add : Array = new_hand.filter(func(card): return not hand.has(card))
	
	for card in cards_to_add:
		var card_node : Card = card_scene.instantiate()
		card_node.name = StringName(card.suite + card.rank)
		
		hand_container.add_child(card_node)
		card_node.set_up(card, is_me)
		hand.append(card)
	
	for card in cards_to_remove:
		if not hand_container.has_node(card.suite + card.rank): return
		
		var card_node : Card = hand_container.get_node(card.suite + card.rank)
		card_node.queue_free()
		hand.erase(card)

func on_button_pressed():
	if not is_me: get_tree().call_group("HandListener", "on_player_selected", hand_name)
