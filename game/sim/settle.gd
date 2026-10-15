class_name SdkSettler
extends RefCounted
## The only physics advancement loop. Statistics never use wall time as logic.

const QUIET_TICKS: int = 4
const MAX_TICKS: int = 1200

var _world
var _budget: int = MAX_TICKS
var _quiet: int = 0
var _ticks: int = 0
var _hashes: Array[String] = []
var _max_step_us: int = 0
var finished: bool = true
var result: Dictionary = {}

func begin(world, budget: int = MAX_TICKS) -> void:
	_world = world
	_budget = budget
	_quiet = 0
	_ticks = 0
	_hashes.clear()
	_max_step_us = 0
	finished = false
	result = {}

func run(world, budget: int = MAX_TICKS) -> Dictionary:
	begin(world, budget)
	while not finished:
		advance(4)
	return result

func advance(max_ticks: int = 4) -> Dictionary:
	if finished:
		return result
	var remaining: int = maxi(1, max_ticks)
	while _ticks < _budget and remaining > 0:
		if _world.step(1) != 0:
			return _finish(false, str(_world.last_error))
		_ticks += 1
		remaining -= 1
		_hashes.append(_world.get_state_hash())
		var stats: Dictionary = _world.get_stats()
		_max_step_us = maxi(_max_step_us, int(stats.get("step_us", 0)))
		if not _world.command_errors.is_empty() or int(stats.get("commands_dropped", 0)) > 0 or int(stats.get("events_dropped", 0)) > 0:
			return _finish(false, "SDK rejected or dropped work: " + str(_world.command_errors))
		var stopped: bool = int(stats.get("active_chunks", -1)) == 0 and int(stats.get("queue_size", -1)) == 0 and int(stats.get("pressure_moves", 0)) == 0 and int(stats.get("electric_heads", 0)) == 0
		_quiet = _quiet + 1 if stopped else 0
		if _quiet >= QUIET_TICKS:
			return _finish(true, "")
	if _ticks >= _budget:
		return _finish(false, "Settlement exceeded 1200 total ticks")
	var pending: Dictionary = _result(true, _ticks, _quiet, _hashes, _max_step_us, "")
	pending.finished = false
	return pending

func _finish(ok: bool, error: String) -> Dictionary:
	finished = true
	result = _result(ok, _ticks, _quiet, _hashes, _max_step_us, error)
	result.finished = true
	return result

func _result(ok: bool, ticks: int, quiet: int, hashes: Array[String], peak: int, error: String) -> Dictionary:
	return {"ok": ok, "ticks": ticks, "quiet": quiet, "hashes": hashes, "max_step_us": peak, "error": error}
