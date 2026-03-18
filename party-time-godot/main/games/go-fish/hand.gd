extends Control
class_name CardHand

@export var card_scene : PackedScene
@export var is_me : bool = false
var hand_name = "Jeff"
var hand : Array

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

func update_hand(new_hand : Array, on_set_up : bool = false):
	score_tag.show()
	
	if is_me:
		var cards_to_remove : Array = hand.filter(func(card): return not new_hand.has(card))
		hand = new_hand
		
		#my hand.
		for card in new_hand:
			var card_node : Card = hand_container.get_node_or_null(card.rank)
			if card_node:
				card_node.animate = not on_set_up
				card_node.update_count( new_hand.filter(func(c): return c.rank == card.rank).size() )
				continue
			
			card_node = card_scene.instantiate()
			card_node.name = card.rank
			
			hand_container.add_child(card_node)
			card_node.tree_exited.connect(arrange_cards)
			card_node.set_up(card)
		
		for card in cards_to_remove:
			var card_node : Card = hand_container.get_node_or_null(card.rank)
			if card_node: card_node.update_count( 0 )
		
	else:
		#not my hand
		var s = new_hand.filter(func(card): return GoFish.CARDS.has(card.rank)).size()
		summary.visible = s > 4
		summary_label.text = str("+", s-4)
		
		var card_count = hand_container.get_child_count()
		var difference = card_count - min( s, 4 )
		
		if difference != 0: for i in abs(difference):
			if difference < 0:
				hand_container.add_child(card_scene.instantiate())
			elif hand_container.get_child_count() != 0:
				hand_container.get_child(0).queue_free()
		
	arrange_cards()

func shake_card( _rank ):
	var card_node : Card = hand_container.get_node_or_null( _rank )
	
	if card_node: 
		var jiggle_tween : Tween = card_node.card_body.create_tween().set_loops()
		
		var shake_dist: float = 2.0
		var speed: float = 0.1
		
		jiggle_tween.tween_property(card_node.card_body, "position:x", 
		shake_dist, speed).as_relative().set_trans(Tween.TRANS_SINE)
		
		jiggle_tween.tween_property(card_node.card_body, "position:x", 
		-(shake_dist * 2.0), speed * 2.0).as_relative().set_trans(Tween.TRANS_SINE)
		
		jiggle_tween.tween_property(card_node.card_body, "position:x", 
		shake_dist, speed).as_relative().set_trans(Tween.TRANS_SINE)
		
		var tween_kill = func(): if jiggle_tween: jiggle_tween.kill()
		
		get_tree().create_timer(GoFish.REQUEST_TIME).timeout.connect( tween_kill )
		tree_exiting.connect( tween_kill )

func arrange_cards():
	for card_node : Card in hand_container.get_children():
		card_node.hand_updated(is_me)

func on_button_pressed():
	if not is_me: get_tree().call_group("HandListener", "on_player_selected", hand_name)
