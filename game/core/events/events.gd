class_name GameEventBus
extends RefCounted
## All public event names and argument types are declared only here.

signal action_done(action: Variant)
signal settle_done(result: Dictionary)
signal level_won(level_uid: String, moves: int)
signal delivery_done(cargo_uid: String, recipient_uid: String, rating: int)
signal coins_changed(delta: int, reason: String)
signal item_bought(item_uid: String)
signal dialogue_requested(dialogue_uid: String)
signal quest_started(quest_uid: String)
signal settings_changed(key: String, value: Variant)

const ARGUMENTS: Dictionary = {
	"action_done": ["action"], "settle_done": ["result"], "level_won": ["level_uid", "moves"],
	"delivery_done": ["cargo_uid", "recipient_uid", "rating"], "coins_changed": ["delta", "reason"],
	"item_bought": ["item_uid"], "dialogue_requested": ["dialogue_uid"], "quest_started": ["quest_uid"],
	"settings_changed": ["key", "value"]
}
