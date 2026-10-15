extends SceneTree
## Windowed, serial real-SDK performance record. No production code is changed.
## Cold scene/theme creation and warm-up are excluded; every measured sample is
## retained. Main-thread work and wall-clock rendered-frame throughput have
## separate gates. Default matches normal Boot (64, 60 Hz animation); --uncapped records capacity
## separately with max_fps=0 and vsync disabled. Neither mode changes a gate.
const Session = preload("res://gameplay/session/level_session.gd")
const View = preload("res://presentation/render/world_view.gd")
const FRAME_LIMIT_US: int = 4000
const UNDO_LIMIT_US: int = 100000
const REQUIRED_FPS: float = 60.0
const WARMUP_FRAMES: int = 30
const MEASURED_FRAMES: int = 120
const WATCHDOG_SECONDS: float = 45.0
const THEMES: Array[String] = ["art:theme.dungeon", "art:theme.ruins", "art:theme.cave", "art:theme.forest", "art:theme.sky", "art:theme.cosmos"]
const OUTPUT: String = "res://reports/performance.json"
# The ctypes structure follows this machine's macOS SDK sys/resource.h,
# rusage_info_v4. proc_pid_rusage queries the Godot PID, not the Python helper.
# ri_lifetime_max_phys_footprint is an OS-maintained lifetime high-water mark:
# this is not a peak inferred from periodically sampled resident memory.
const MEMORY_PROBE: String = """import ctypes,json,sys
names = 'ri_user_time ri_system_time ri_pkg_idle_wkups ri_interrupt_wkups ri_pageins ri_wired_size ri_resident_size ri_phys_footprint ri_proc_start_abstime ri_proc_exit_abstime ri_child_user_time ri_child_system_time ri_child_pkg_idle_wkups ri_child_interrupt_wkups ri_child_pageins ri_child_elapsed_abstime ri_diskio_bytesread ri_diskio_byteswritten ri_cpu_time_qos_default ri_cpu_time_qos_maintenance ri_cpu_time_qos_background ri_cpu_time_qos_utility ri_cpu_time_qos_legacy ri_cpu_time_qos_user_initiated ri_cpu_time_qos_user_interactive ri_billed_system_time ri_serviced_system_time ri_logical_writes ri_lifetime_max_phys_footprint ri_instructions ri_cycles ri_billed_energy ri_serviced_energy ri_interval_max_phys_footprint ri_runnable_time'.split()
class Usage(ctypes.Structure):
    _fields_ = [('ri_uuid',ctypes.c_ubyte*16)]+[(name,ctypes.c_uint64) for name in names]
lib=ctypes.CDLL('/usr/lib/libproc.dylib',use_errno=True)
lib.proc_pid_rusage.argtypes=[ctypes.c_int,ctypes.c_int,ctypes.c_void_p]
lib.proc_pid_rusage.restype=ctypes.c_int
info=Usage()
pid=int(sys.argv[1])
if lib.proc_pid_rusage(pid,4,ctypes.byref(info)) != 0:
    raise OSError(ctypes.get_errno(),'proc_pid_rusage')
print(json.dumps({'available':True,'pid':pid,'source':'macOS proc_pid_rusage RUSAGE_INFO_V4','current_resident_bytes':int(info.ri_resident_size),'current_physical_footprint_bytes':int(info.ri_phys_footprint),'peak_process_physical_footprint_bytes':int(info.ri_lifetime_max_phys_footprint),'scope':'Godot process lifetime, including cold loads and warm-up; helper process excluded'}))
"""

var _session: RefCounted
var _viewport: SubViewport
var _view: Node2D
var _tick: int = 0
var _failures: Array[String] = []
var _themes: Array[Dictionary] = []
var _levels: Array[Dictionary] = []
var _peak_frame_us: int = 0
var _peak_view_us: int = 0
var _peak_undo_us: int = 0
var _peak_video_memory_bytes: int = 0
var _finished: bool = false
var _timed_out: bool = false
var _current_case: Dictionary = {}
var _uncapped: bool = false
var _output: String = OUTPUT
var _last_draw_us: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_uncapped = OS.get_cmdline_user_args().has("--uncapped")
	_output = "res://reports/performance-capacity.json" if _uncapped else OUTPUT
	if DisplayServer.get_name() == "headless":
		_failures.append("A real rendering driver is required; headless FPS is not a rendering measurement")
		_finish({"available": false, "reason": "headless rejected"})
		return
	var app_script: Script = load("res://app/boot.gd")
	Engine.max_fps = 0 if _uncapped else int(app_script.get_script_constant_map()["FRAME_CAP"])
	if _uncapped:
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	var watchdog: SceneTreeTimer = create_timer(WATCHDOG_SECONDS, true, false, true)
	watchdog.timeout.connect(_on_watchdog)
	var registry: Node = root.get_node("Registry")
	# One live SDK world serves the six visual skins, then is disposed before
	# any author-route world is created. SDK/world worker configuration is one.
	if _open_scene(registry.level_spec("level:M01")):
		for uid: String in THEMES:
			_current_case = {"kind": "theme", "theme": uid, "phase": "warm_up"}
			_view.set_theme_uid(uid)
			await _warm_up()
			if _finished:
				return
			var refresh_samples: Array[int] = []
			var wall_intervals: Array[int] = []
			# Last warm-up draw is t0. The 120 measured draws append t1..t120:
			# 121 actual post-draw timestamps delimit exactly 120 intervals.
			var draw_timestamps: Array[int] = [_last_draw_us]
			var stages: Dictionary = {}
			_current_case = {"kind": "theme", "theme": uid, "phase": "measuring", "refresh_samples_us": refresh_samples, "draw_timestamps_us": draw_timestamps, "drawn_frame_intervals_us": wall_intervals, "peak_render_stage_us": stages}
			var previous_draw: int = _last_draw_us
			for _frame: int in range(MEASURED_FRAMES):
				_tick += 1
				_view.fixed_tick = _tick
				var refresh_start: int = Time.get_ticks_usec()
				_view.refresh()
				var elapsed: int = Time.get_ticks_usec() - refresh_start
				refresh_samples.append(elapsed)
				_peak_frame_us = maxi(_peak_frame_us, elapsed)
				_peak_view_us = maxi(_peak_view_us, int(_view.last_refresh_us))
				_merge_stage_peaks(stages, _view.last_refresh_stages)
				await _draw_frame()
				if _finished:
					return
				var now: int = _last_draw_us
				draw_timestamps.append(now)
				wall_intervals.append(now - previous_draw)
				previous_draw = now
			var wall_us: int = draw_timestamps.back() - draw_timestamps[0]
			var fps: float = float(MEASURED_FRAMES) * 1000000.0 / maxi(1, wall_us)
			var peak: int = _max_sample(refresh_samples)
			var passed: bool = peak <= FRAME_LIMIT_US and fps >= REQUIRED_FPS
			if not passed:
				_failures.append("%s: refresh peak %dus (limit %d), wall FPS %.6f (minimum %.1f)" % [uid, peak, FRAME_LIMIT_US, fps, REQUIRED_FPS])
			_themes.append({"theme": uid, "sdk_fixture": "level:M01", "environment": "full", "warmup_frames": WARMUP_FRAMES, "measured_frames": MEASURED_FRAMES, "first_tick": _tick - MEASURED_FRAMES + 1, "last_tick": _tick, "refresh_samples_us": refresh_samples, "peak_refresh_us": peak, "peak_render_stage_us": stages, "wall_elapsed_us": wall_us, "draw_timestamps_us": draw_timestamps, "drawn_frame_intervals_us": wall_intervals, "wall_fps": fps, "passed": passed})
			print("PERF_THEME %s peak_us=%d fps=%.3f passed=%s" % [uid, peak, fps, passed])
			_current_case = {}
		await _close_scene()
		if _finished:
			return
	for number: int in range(1, 8):
		var uid: String = "level:" + ("M%02d" % number)
		_current_case = {"kind": "level", "level": uid, "phase": "cold_setup"}
		var spec: Dictionary = registry.level_spec(uid)
		if not _open_scene(spec):
			_levels.append({"level": uid, "passed": false, "error": "SDK scene setup failed"})
			continue
		_current_case.phase = "warm_up"
		await _warm_up()
		if _finished:
			return
		var actions: Array[Dictionary] = []
		var undos: Array[Dictionary] = []
		var route: Array = spec.get("solution", [])
		_current_case = {"kind": "level", "level": uid, "phase": "author_route", "actions": actions, "undos": undos, "expected_author_actions": route.size()}
		var route_ok: bool = not route.is_empty()
		var peak_begin_us: int = 0
		var peak_advance_us: int = 0
		var peak_view_us: int = 0
		var peak_undo_us: int = 0
		for raw_action: Variant in route:
			var action: String = str(raw_action)
			_tick += 1
			_view.fixed_tick = _tick
			var begin_started: int = Time.get_ticks_usec()
			var begin: Dictionary = _session.begin_action(action, true)
			var begin_us: int = Time.get_ticks_usec() - begin_started
			_view.pose = {"walk": "walk", "step": "walk", "push": "push", "dig": "dig", "pour": "pour", "climb": "climb"}.get(begin.get("kind", ""), "idle")
			_view.refresh()
			var begin_frame_us: int = Time.get_ticks_usec() - begin_started
			peak_begin_us = maxi(peak_begin_us, begin_frame_us)
			peak_view_us = maxi(peak_view_us, int(_view.last_refresh_us))
			_peak_frame_us = maxi(_peak_frame_us, begin_frame_us)
			_peak_view_us = maxi(_peak_view_us, int(_view.last_refresh_us))
			var action_result: Dictionary = {"action": action, "accepted": bool(begin.get("accepted", false)), "begin_action_us": begin_us, "begin_plus_refresh_us": begin_frame_us, "commit_profile": _session.last_commit_profile.duplicate(true), "advance_samples_us": [], "advance_sdk_samples_us": [], "advance_render_samples_us": [], "peak_render_stage_us": {}, "error": str(begin.get("error", ""))}
			_current_case.current_action = action_result
			_merge_stage_peaks(action_result.peak_render_stage_us, _view.last_refresh_stages)
			if begin_frame_us > FRAME_LIMIT_US:
				_failures.append("%s %s begin+refresh %dus exceeds %d" % [uid, action, begin_frame_us, FRAME_LIMIT_US])
			await _draw_frame()
			if _finished:
				return
			if not bool(begin.get("accepted", false)):
				route_ok = false
				actions.append(action_result)
				_failures.append("%s author action %s rejected: %s" % [uid, action, begin])
				break
			while _session.busy:
				_tick += 1
				_view.fixed_tick = _tick
				var frame_started: int = Time.get_ticks_usec()
				var step: Dictionary = _session.advance_settle(4)
				var sdk_us: int = Time.get_ticks_usec() - frame_started
				if not _session.last_commit_profile.is_empty(): action_result.commit_profile = _session.last_commit_profile.duplicate(true)
				_view.refresh()
				var combined_us: int = Time.get_ticks_usec() - frame_started
				action_result.advance_samples_us.append(combined_us)
				action_result.advance_sdk_samples_us.append(sdk_us)
				action_result.advance_render_samples_us.append(int(_view.last_refresh_us))
				_merge_stage_peaks(action_result.peak_render_stage_us, _view.last_refresh_stages)
				peak_advance_us = maxi(peak_advance_us, combined_us)
				peak_view_us = maxi(peak_view_us, int(_view.last_refresh_us))
				_peak_frame_us = maxi(_peak_frame_us, combined_us)
				_peak_view_us = maxi(_peak_view_us, int(_view.last_refresh_us))
				if combined_us > FRAME_LIMIT_US:
					_failures.append("%s %s advance(4)+refresh sample %d: %dus exceeds %d" % [uid, action, action_result.advance_samples_us.size(), combined_us, FRAME_LIMIT_US])
				if not str(step.get("error", "")).is_empty() or not bool(step.get("accepted", true)):
					action_result.error = str(step.get("error", "settlement rejected"))
					route_ok = false
				await _draw_frame()
				if _finished:
					return
				if not route_ok:
					break
			actions.append(action_result)
			if not route_ok:
				_failures.append("%s author route settlement failed: %s" % [uid, action_result.error])
				break
		var won: bool = bool(_session.state().get("won", false))
		if not won or actions.size() != route.size():
			route_ok = false
			_failures.append("%s author route incomplete or not won (%d/%d actions)" % [uid, actions.size(), route.size()])
		# Restore every completed action in reverse order. This measures actual
		# snapshots and their renderer refresh, never a replay approximation.
		_current_case.phase = "undo"
		_current_case.erase("current_action")
		for reverse_index: int in range(actions.size()):
			if not bool(actions[actions.size() - 1 - reverse_index].accepted) or _session.busy:
				break
			_tick += 1
			_view.fixed_tick = _tick
			_view.pose = "idle"
			var undo_started: int = Time.get_ticks_usec()
			var restored: bool = _session.undo()
			var undo_us: int = Time.get_ticks_usec() - undo_started
			_view.refresh()
			var undo_frame_us: int = Time.get_ticks_usec() - undo_started
			peak_undo_us = maxi(peak_undo_us, undo_frame_us)
			_peak_undo_us = maxi(_peak_undo_us, undo_frame_us)
			undos.append({"reverse_index": reverse_index, "restored": restored, "undo_us": undo_us, "undo_plus_refresh_us": undo_frame_us})
			if not restored or undo_frame_us > UNDO_LIMIT_US:
				route_ok = false
				_failures.append("%s undo %d: restored=%s, %dus (limit %d)" % [uid, reverse_index, restored, undo_frame_us, UNDO_LIMIT_US])
			await _draw_frame()
			if _finished:
				return
		var passed: bool = route_ok and peak_begin_us <= FRAME_LIMIT_US and peak_advance_us <= FRAME_LIMIT_US and peak_undo_us <= UNDO_LIMIT_US and undos.size() == route.size()
		_levels.append({"level": uid, "environment": "full", "warmup_frames": WARMUP_FRAMES, "expected_author_actions": route.size(), "completed_author_actions": actions.size(), "won_before_undo": won, "actions": actions, "undos": undos, "peak_begin_plus_refresh_us": peak_begin_us, "peak_advance_plus_refresh_us": peak_advance_us, "peak_world_view_us": peak_view_us, "peak_undo_plus_refresh_us": peak_undo_us, "passed": passed})
		print("PERF_LEVEL %s begin_us=%d advance_us=%d undo_us=%d passed=%s" % [uid, peak_begin_us, peak_advance_us, peak_undo_us, passed])
		_current_case = {}
		await _close_scene()
		if _finished:
			return
	var memory: Dictionary = _memory_peak()
	if not bool(memory.get("available", false)):
		_failures.append("OS process memory high-water mark unavailable: " + str(memory))
	_finish(memory)

func _open_scene(spec: Dictionary) -> bool:
	if _session != null or _viewport != null:
		_failures.append("Performance harness refused overlapping SDK worlds")
		return false
	_session = Session.new()
	if not _session.setup(spec):
		_failures.append("SDK setup failed for %s: %s" % [spec.get("id", "unknown"), _session.last_error])
		_session.dispose()
		_session = null
		return false
	if int(_session.world.node.get("threads")) != 1:
		_failures.append("Performance harness requires exactly one SDK worker")
		_session.dispose()
		_session = null
		return false
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(320, 180)
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	root.add_child(_viewport)
	_view = View.new()
	_view.environment_mode = "full"
	_view.fixed_tick = 0
	_view.set_session(_session)
	_viewport.add_child(_view)
	# The test explicitly drives one refresh and one increasing tick per drawn
	# frame, so WorldView's automatic _process does not add a second cached call.
	_view.set_process(false)
	_tick = 0
	return true

func _close_scene() -> void:
	if _view != null and is_instance_valid(_view):
		_view.set_process(false)
	if _viewport != null:
		_viewport.queue_free()
		await process_frame
		if _finished:
			return
	_view = null
	_viewport = null
	if _session != null:
		_session.dispose()
		_session = null

func _warm_up() -> void:
	for _frame: int in range(WARMUP_FRAMES):
		if _finished:
			return
		_tick += 1
		_view.fixed_tick = _tick
		_view.refresh()
		await _draw_frame()

func _draw_frame() -> void:
	await process_frame
	if _finished:
		return
	await RenderingServer.frame_post_draw
	if _finished:
		return
	_last_draw_us = Time.get_ticks_usec()
	_peak_video_memory_bytes = maxi(_peak_video_memory_bytes, int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))

static func _max_sample(samples: Array[int]) -> int:
	var peak: int = 0
	for sample: int in samples:
		peak = maxi(peak, sample)
	return peak

static func _merge_stage_peaks(target: Dictionary, source: Dictionary) -> void:
	for stage: String in source:
		target[stage] = maxi(int(target.get(stage, 0)), int(source[stage]))

func _memory_peak() -> Dictionary:
	var output: Array = []
	var code: int = OS.execute("/usr/bin/python3", ["-c", MEMORY_PROBE, str(OS.get_process_id())], output, true)
	if code != 0 or output.is_empty():
		return {"available": false, "exit_code": code, "output": "".join(output)}
	var result: Variant = JSON.parse_string("".join(output).strip_edges())
	if not result is Dictionary or int(result.get("peak_process_physical_footprint_bytes", 0)) <= 0:
		return {"available": false, "reason": "invalid proc_pid_rusage result", "output": "".join(output)}
	result.engine_static_peak_bytes = OS.get_static_memory_peak_usage()
	result.engine_static_current_bytes = OS.get_static_memory_usage()
	result.peak_engine_video_memory_bytes = _peak_video_memory_bytes
	return result

func _finish(memory: Dictionary) -> void:
	if _finished:
		return
	_finished = true
	var passed: bool = _failures.is_empty() and _themes.size() == 6 and _levels.size() == 7
	var report: Dictionary = {"format": "portitor.performance/1", "passed": passed, "measured_at_unix": Time.get_unix_time_from_system(), "gates": {"main_thread_frame_us": FRAME_LIMIT_US, "minimum_wall_fps": REQUIRED_FPS, "undo_plus_refresh_us": UNDO_LIMIT_US}, "scope": {"renderer": "Actual WorldView and real SDK material render textures, 320x180; HUD/UI excluded", "theme_frames": "30 warm-up frames excluded, then all 120 increasing-tick frames retained per theme; actual wall time includes draw waits", "actions": "Every M01-M07 spec.solution action; begin_action+refresh and every advance_settle(4)+refresh measured; no fast-forward", "undo": "Every completed action restored from its real snapshot; separate GD 100ms undo gate", "excluded": "Scene/theme cold setup, warm-up, report serialization, and read-only memory helper are outside frame timing; process lifetime memory peak still includes cold setup", "worker_policy": "One live SDK world, threads=1, worlds disposed serially; no additional simulation workers", "driver": "Explicit tick + exactly one WorldView.refresh per drawn frame; automatic WorldView._process disabled", "engine_max_fps": Engine.max_fps, "vsync_mode": int(DisplayServer.window_get_vsync_mode()), "display_server": DisplayServer.get_name()}, "peak_main_thread_frame_us": _peak_frame_us, "peak_world_view_us": _peak_view_us, "peak_undo_plus_refresh_us": _peak_undo_us, "memory": memory, "themes": _themes, "levels": _levels, "failures": _failures}
	report.watchdog_seconds = WATCHDOG_SECONDS
	report.mode = "capacity" if _uncapped else "normal"
	report.scope.fps_method = "N+1 real post-draw timestamps delimit N=120 intervals; FPS=120e6/(t120-t0); no tolerance"
	report.scope.mode_meaning = "Uncapped rendering capacity: max_fps=0 and vsync disabled; does not establish normal-mode absence of slow frames" if _uncapped else "Normal Boot frame cap 64 (animation clock 60 Hz); vsync unchanged; raw wall-clock FPS retained with strict >=60 gate"
	report.timed_out = _timed_out
	report.in_progress_at_timeout = _current_case if _timed_out else {}
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://reports"))
	var file: FileAccess = FileAccess.open(_output, FileAccess.WRITE)
	if file == null:
		push_error("Cannot write performance report: " + _output)
		print("PORTITOR_PERFORMANCE_COMPLETE passed=false report_write_failed=true")
		quit(1)
		return
	file.store_string(JSON.stringify(report, "  "))
	file.close()
	print("PORTITOR_PERFORMANCE_COMPLETE passed=%s themes=%d levels=%d peak_frame_us=%d peak_view_us=%d peak_undo_us=%d failures=%d mode=%s report=%s" % [passed, _themes.size(), _levels.size(), _peak_frame_us, _peak_view_us, _peak_undo_us, _failures.size(), report.mode, _output])
	quit(0 if passed else 1)

func _on_watchdog() -> void:
	if _finished:
		return
	_timed_out = true
	_failures.append("45-second watchdog expired; completed cases and in-progress samples are partial results")
	if _view != null and is_instance_valid(_view):
		_view.set_process(false)
	if _viewport != null and is_instance_valid(_viewport):
		_viewport.queue_free()
	if _session != null:
		_session.dispose()
		_session = null
	_finish(_memory_peak())
