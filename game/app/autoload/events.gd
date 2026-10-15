class_name EventsService
extends Node

const BUS = preload("res://core/events/events.gd")
var _bus = BUS.new()

var action_done: Signal:
	get: return _bus.action_done
var settle_done: Signal:
	get: return _bus.settle_done
var level_won: Signal:
	get: return _bus.level_won
var delivery_done: Signal:
	get: return _bus.delivery_done
var coins_changed: Signal:
	get: return _bus.coins_changed
var item_bought: Signal:
	get: return _bus.item_bought
var dialogue_requested: Signal:
	get: return _bus.dialogue_requested
var quest_started: Signal:
	get: return _bus.quest_started
var settings_changed: Signal:
	get: return _bus.settings_changed
