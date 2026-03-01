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
@export var summary : Control
@export var summary_label : Label

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
		if hand.size() > 3 and not is_me:
			summary.show()
			summary.move_to_front()
			summary_label.text = str("+",new_hand.size()-3)
			continue
		
		hand.append(card)
		summary.hide()
		
		var card_name = String(card.rank) if is_me else String(card.suite + card.rank)
		if hand_container.has_node(card_name): 
			hand_container.get_node(card_name).add_to_count()
			continue
		
		var card_node : Card = card_scene.instantiate()
		card_node.name = card_name
		
		hand_container.add_child(card_node)
		card_node.set_up(card, is_me)
	
	for card in cards_to_remove:
		var card_name = String(card.rank) if is_me else String(card.suite + card.rank)
		if not hand_container.has_node(card_name): break
		
		var card_node : Card = hand_container.get_node(card_name)
		card_node.queue_free()
		hand.erase(card)

func on_button_pressed():
	if not is_me: get_tree().call_group("HandListener", "on_player_selected", hand_name)
