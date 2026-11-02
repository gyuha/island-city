extends Node
signal player_health_changed(current: int, maximum: int)
signal stamina_changed(current: float, maximum: float)
signal player_state_changed(state: String)
signal player_underwater_changed(underwater: bool)
signal player_damaged(amount: int)
signal player_died
signal attack_performed
signal enemy_defeated(enemy_id: String)
signal item_added(item_id: String, amount: int)
signal inventory_changed(items: Dictionary)
signal quest_started(quest_id: String)
signal quest_progress(quest_id: String, current: int, target: int)
signal quest_completed(quest_id: String)
signal dialogue_started(dialogue_id: String)
signal dialogue_line(speaker: String, text: String)
signal dialogue_ended
signal interact_prompt_changed(text: String, visible: bool)
signal footstep(surface: String)
