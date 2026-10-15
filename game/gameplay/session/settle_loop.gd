class_name GameplaySettleLoop
extends RefCounted
## One state machine serves animated play and synchronous headless replays.

const SdkSettle = preload("res://sim/settle.gd")
const Classifier = preload("res://gameplay/grid/classify.gd")
const MAX_TICKS: int = 1200
const MAX_ROUNDS: int = 16

var _context: WeakRef
var _sdk
var _round_hashes: int = 0
var _round_ticks: int = 0
var _ticks: int = 0
var _rounds: int = 0
var _hashes: Array[String] = []
var _max_step_us: int = 0
var _max_advance_us: int = 0
var _classification_pending: bool = false
var finished: bool = true
var result: Dictionary = {}

func begin(context) -> void:
	_context = weakref(context)
	_ticks = 0
	_rounds = 0
	_hashes.clear()
	_max_step_us = 0
	_max_advance_us = 0
	finished = false
	result = {}
	_classification_pending = false
	_start_round()

func advance(max_ticks: int = 4) -> Dictionary:
	if finished:
		return result
	var started_us: int = Time.get_ticks_usec()
	var context = _context.get_ref()
	if _classification_pending:
		_classification_pending = false
		if not Classifier.new().update(context.world, context.grid):
			return _finish(false, "Cannot read all SDK material ids")
		var changed: bool = context.take_tick_changes()
		context.settle_step_changed = changed
		for mechanic in context.settle_mechanics:
			var mechanism_changed: bool = mechanic.on_settle_step()
			changed = mechanism_changed or changed
			context.settle_step_changed = changed
			if not context.last_error.is_empty():
				return _finish(false, str(context.last_error))
		if changed:
			_start_round()
		else:
			_max_advance_us = maxi(_max_advance_us, Time.get_ticks_usec() - started_us)
			return _finish(true, "")
		_max_advance_us = maxi(_max_advance_us, Time.get_ticks_usec() - started_us)
		return _current(false, true, "")
	var before: int = _round_ticks
	var physics: Dictionary = _sdk.advance(maxi(1, max_ticks))
	var delta: int = int(physics.ticks) - before
	_round_ticks = int(physics.ticks)
	_ticks += delta
	var new_hashes: Array = physics.hashes.slice(_round_hashes)
	_hashes.append_array(new_hashes)
	_round_hashes = physics.hashes.size()
	_max_step_us = maxi(_max_step_us, int(physics.max_step_us))
	if bool(physics.finished):
		if not bool(physics.ok):
			return _finish(false, str(physics.error))
		# Classification and SDK writes from game rules get a separate frame.
		# No physics tick is added or skipped by this scheduling boundary.
		_classification_pending = true
	_max_advance_us = maxi(_max_advance_us, Time.get_ticks_usec() - started_us)
	return _current(false, true, "")

func _start_round() -> void:
	_rounds += 1
	if _rounds > MAX_ROUNDS:
		_finish(false, "Settlement exceeded 16 rounds")
		return
	if _ticks >= MAX_TICKS:
		_finish(false, "Settlement exceeded 1200 total ticks")
		return
	_sdk = SdkSettle.new()
	_sdk.begin(_context.get_ref().world, MAX_TICKS - _ticks)
	_round_hashes = 0
	_round_ticks = 0

func _finish(ok: bool, error: String) -> Dictionary:
	finished = true
	result = _current(true, ok, error)
	return result

func _current(done: bool, ok: bool, error: String) -> Dictionary:
	return {"finished": done, "ok": ok, "ticks": _ticks, "rounds": _rounds, "hashes": _hashes.duplicate(), "max_step_us": _max_step_us, "max_advance_us": _max_advance_us, "error": error, "phase": "classification" if _classification_pending else "physics"}
