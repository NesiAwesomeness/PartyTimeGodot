extends Control
class_name Card

@export var card_vis : Control
@export var selection : Button
@export var count_label : Label

@export var number : Control
@export var number_panel : Control

@export var card_body : Control
@export var card_holder : Control

var rank = ""
var is_power_card : bool = false
var count : int = 1

var animate : bool = true

func _ready():
	add_to_group("HandListener")
	selection.disabled = true
	
	number.hide()
	card_vis.hide()
	
	card_body.self_modulate = Color("252826ff")

var position_tween : Tween

func update_count(_count : int):
	if _count == 0:
		if GoFish.booked_cards.has(rank):
			print("insert booked card animated exit here ", rank)
		queue_free()
		return
	
	if _count == count: return
	
	count_label.text = str(_count) if is_power_card else str(_count, " of ", GoFish.CARDS[rank].tier)
	number.visible = _count > 1
	
	if _count > count:
		var duration = 0.06
		
		if animate:
			if position_tween: position_tween.kill()
			position_tween = create_tween()
			position_tween.tween_property(card_body, "position:y", -32.0, duration * 2.0).set_delay(duration * 4.0)
			position_tween.chain().tween_property(card_body, "position:y", 0.0, duration * 3.0)
	count = _count

#this can only be called by cards for "ME"
func set_up(card : Dictionary):
	is_power_card = not GoFish.CARDS.has(card.rank)
	
	selection.pressed.connect(on_selection)
	selection.disabled = false
	
	rank = card.rank
	card_vis.show()
	
	var card_name : String = GoFish.PASSIVES.merged(GoFish.POWERS)[rank] if is_power_card else GoFish.CARDS[rank].name
	if not is_power_card:
		match card.suite:
			"R": card_body.self_modulate = Color("db3f39ff")
			"B": card_body.self_modulate = Color("4665d3ff")
			"G": card_body.self_modulate = Color("46943fff")
			"Y": card_body.self_modulate = Color("d49936ff")
	else:
		if GoFish.PASSIVES.has(rank):
			add_to_group("PassiveCard")
		
		#should always be able to select them.
		card_body.self_modulate = Color("626c60ff")
	
	for label : RichTextLabel in card_vis.get_children():
		label.text = str("[wave]",card_name,"[/wave]") if is_power_card else card_name
	
	#slide in
	var pop_duration = 0.2
	position.y = -200.0
	
	var tween = create_tween().set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(card_body, "position:y", 0.0, 0.5).set_delay(pop_duration)
	
	#pop in
	var scale_tween = create_tween().set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_IN_OUT)
	scale_tween.tween_property(card_body, "scale", Vector2.ONE, pop_duration).from(Vector2.ZERO)
	
	selection.disabled = true
	await tween.finished
	
	selection.disabled = false

func on_player_deselected():
	if not is_power_card: selection.disabled = true

func on_passive_update(passive : String):
	if passive == rank:
		card_body.position.y = -32.0
	else:
		card_body.position.y = 0.0

func hand_updated(is_me : bool):
	var center_index : float = (get_parent().get_child_count() - 1) / 2.0
	var center_offset: float = get_index() - center_index
	var target_rotation : float = center_offset * 2.0 * float(is_me)
	
	var spacing = 72.0 if is_me else 32.0
	var target_x: float = center_offset * spacing
	var target_y: float = center_offset * center_offset * 2.0 * float(is_me)
	
	var duration : float = 0.3
	# Animate the card to its new position and rotation smoothly
	var tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUINT).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(self, "position",  Vector2(target_x, target_y), duration)
	tween.tween_property(self, "rotation_degrees", target_rotation, duration).set_delay(0.25)
	
	if not is_me: return
	if not GoFish.CARDS.has(rank): return
	
	await tween.finished
	
	if count == GoFish.CARDS[rank].tier and is_inside_tree():
		get_tree().call_group("CardListener", "on_book", rank)

func on_selection():
	if is_power_card:
		#if it's a power card.
		get_tree().call_group("CardListener", "on_power_selected", rank)
		
	else:
		get_tree().call_group("CardListener", "on_card_selected", rank)
