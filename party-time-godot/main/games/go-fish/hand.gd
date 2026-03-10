extends Control
class_name CardHand

@export var card_scene : PackedScene
@export var is_me : bool = false
var hand : Array
var hand_name = "Jeff"

@export var hand_container : Control
@export var name_tag : Label
@export var score_tag : Label

@export var button : Button
@export var summary : Control
@export var summary_label : Label

@export var quick_time : ProgressBar

func _ready():
	name_tag.text = hand_name
	if is_me:
		name_tag.hide()
		button.queue_free()
		return
	button.pressed.connect(on_button_pressed)

func update_score(score):
	score_tag.text = str( int(score) ) 

func update_hand(new_hand : Array, from_set_up = false):
	if not score_tag.visible:
		score_tag.show()
	
	var cards_to_remove : Array = hand.filter(func(card): return not new_hand.has(card))
	var cards_to_add : Array = new_hand.filter(func(card): return not hand.has(card))
	
	if not is_me: 
		cards_to_add = cards_to_add.filter(func(card): return GoFish.CARDS.has(card.rank))
		cards_to_remove = cards_to_remove.filter(func(card): return GoFish.CARDS.has(card.rank))
	
	var s = new_hand.filter(func(card): return GoFish.CARDS.has(card.rank)).size()
	
	for card in cards_to_add:
		if not is_me and hand_container.get_child_count() >= min(4, s): break
		hand.append( card )
		
		var card_name = String(card.rank)
		var card_node : Card = hand_container.get_node_or_null(card_name)
		
		if card_node:
			card_node.animate = not from_set_up and is_me
			var cards_left = new_hand.filter(func(c): return c.rank == card_node.rank).size()
			if is_me: card_node.update_count( cards_left )
			continue
		
		card_node = card_scene.instantiate()
		card_node.animate = not from_set_up and is_me
		if is_me: card_node.name = card_name
		
		hand_container.add_child(card_node)
		card_node.tree_exited.connect(arrange_cards)
		card_node.set_up(card, is_me)
	
	for card in cards_to_remove:
		if not is_me:
			if s > 4: break
			if not GoFish.CARDS.has(card.rank): continue
		
		hand.erase(card)
		if hand_container.get_child_count() < 1: break
		
		var card_name = String(card.rank) if is_me else String(card.suite + card.rank)
		var card_node : Card = hand_container.get_node_or_null(card_name) if is_me else hand_container.get_child(0)
		
		if card_node: 
			var cards_left = new_hand.filter(func(c): return c.rank == card_node.rank).size()
			card_node.update_count( cards_left )
	
	if not is_me:
		summary_label.text = str("+", s-4)
		summary.visible = s > 4
	
	arrange_cards()

func arrange_cards():
	for card_node : Card in hand_container.get_children():
		card_node.hand_updated(is_me)
	
	

func on_button_pressed():
	if not is_me: get_tree().call_group("HandListener", "on_player_selected", hand_name)
