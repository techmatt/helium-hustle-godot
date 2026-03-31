class_name DemandSystem
extends RefCounted

var _demand_cfg: Dictionary = {}
var _rivals: Array = []
var _resources_data: Array = []
var debug_pure_noise: bool = false  # when true, demand = raw fractal noise only (no modifiers)


func init(demand_cfg: Dictionary, rivals: Array, resources_data: Array) -> void:
	_demand_cfg = demand_cfg
	_rivals = rivals
	_resources_data = resources_data


func get_config(key: String) -> float:
	return float(_demand_cfg.get(key, 0.0))


# Returns the speculator suppression component for a resource this tick.
# Formula: max_suppression * (count / (count + half_point)).
# Returns 0.0 if this resource is not the current speculator target.
# Useful for tests that want to assert the suppression value directly
# without reconstructing it from a demand delta.
func get_suppression(state: GameState, resource: String) -> float:
	if state.speculator_target != resource or state.speculator_count <= 0.0:
		return 0.0
	var max_sup: float = _dcfg("speculator_max_suppression")
	var half_pt: float = _dcfg("speculator_half_point")
	return max_sup * (state.speculator_count / (state.speculator_count + half_pt))


# Initializes per-resource demand state (seeds, accumulators, history) and
# fires an initial tick_demand to populate state.demand at day 0.
# Note: perlin seeds are randomized via randf() here. For deterministic tests,
# override state.demand_perlin_seeds and demand_perlin_freq after calling, or
# use TestFixtures.fresh_state_demand_isolated() which sets fixed seeds.
func initialize_demand(state: GameState) -> void:
	var freq_min: float = _dcfg("perlin_freq_min")
	var freq_max: float = _dcfg("perlin_freq_max")
	for res: String in GameState.TRADEABLE_RESOURCES:
		state.demand_perlin_seeds[res] = randf() * 100.0
		state.demand_perlin_freq[res]  = randf_range(freq_min, freq_max)
		state.demand_promote[res]  = 0.0
		state.demand_rival[res]    = 0.0
		state.demand_launch[res]   = 0.0
		state.demand_history[res]  = []
	for rival in _rivals:
		var rid: String = rival.get("id", "")
		if rid:
			state.rival_next_dump_tick[rid] = randi_range(150, 250)
	var burst_min: int = int(_dcfg("speculator_burst_interval_min"))
	var burst_max: int = int(_dcfg("speculator_burst_interval_max"))
	state.speculator_next_burst_tick = randi_range(burst_min, burst_max)
	_reset_target_scores(state)
	# Compute initial demand values at day 0
	tick_demand(state)


# Recomputes state.demand for all tradeable resources and decays the promote,
# rival, and launch saturation accumulators by one step. Called once per tick
# (before programs) and directly by tests to advance demand in isolation.
func tick_demand(state: GameState) -> void:
	var amplitude: float = _dcfg("perlin_amplitude")
	if debug_pure_noise:
		for res: String in GameState.TRADEABLE_RESOURCES:
			var t: float = float(state.current_day) * state.demand_perlin_freq.get(res, 0.01) + state.demand_perlin_seeds.get(res, 0.0)
			var perlin_val: float = (
				_perlin_1d(t)                    * 0.53
				+ _perlin_1d(t * 2.7 + 37.3)    * 0.27
				+ _perlin_1d(t * 7.1 + 71.9)    * 0.13
				+ _perlin_1d(t * 17.3 + 131.7)  * 0.07
			)
			state.demand[res] = 0.5 + perlin_val * amplitude
			var hist: Array = state.demand_history.get(res, [])
			hist.append(state.demand[res])
			if hist.size() > 200:
				hist.pop_front()
			state.demand_history[res] = hist
		return

	var spec_count: float = state.speculator_count
	var spec_target: String = state.speculator_target
	var max_sup: float = _dcfg("speculator_max_suppression")
	var half_pt: float = _dcfg("speculator_half_point")
	var promote_decay: float = _dcfg("promote_decay_rate")
	var rival_decay: float = _dcfg("rival_demand_decay_rate")
	var launch_decay: float = _dcfg("launch_saturation_decay_rate")
	var min_d: float = _dcfg("min_demand")
	var max_d: float = _dcfg("max_demand")
	var coupling: float = _dcfg("coupling_fraction")

	# Speculator suppression on the target resource
	var spec_sup_on_target: float = 0.0
	if spec_target != "" and spec_count > 0.0:
		spec_sup_on_target = max_sup * (spec_count / (spec_count + half_pt))

	for res: String in GameState.TRADEABLE_RESOURCES:
		# Decay accumulators each tick
		state.demand_promote[res] = maxf(0.0, state.demand_promote.get(res, 0.0) - promote_decay)
		state.demand_rival[res]   = maxf(0.0, state.demand_rival.get(res, 0.0)   - rival_decay)
		state.demand_launch[res]  = maxf(0.0, state.demand_launch.get(res, 0.0)  - launch_decay)

		# Fractal gradient noise: 4 octaves at irrational frequency multiples so no
		# visible period emerges. Weights (4/9, 2.4/9, 1.6/9, 1/9) ≈ sum to 1.0,
		# keeping output in [-1, 1] and preserving the amplitude bound.
		var t: float = float(state.current_day) * state.demand_perlin_freq.get(res, 0.01) + state.demand_perlin_seeds.get(res, 0.0)
		var perlin_val: float = (
			_perlin_1d(t)                    * 0.53
			+ _perlin_1d(t * 2.7 + 37.3)    * 0.27
			+ _perlin_1d(t * 7.1 + 71.9)    * 0.13
			+ _perlin_1d(t * 17.3 + 131.7)  * 0.07
		)
		var base_demand: float = 0.5 + perlin_val * amplitude

		# Speculator suppression on this resource
		var spec_sup: float = spec_sup_on_target if spec_target == res else 0.0

		# Coupling bonus: other resources get a small lift when one is suppressed
		var coupling_bonus: float = 0.0
		if spec_target != "" and spec_target != res:
			coupling_bonus = spec_sup_on_target * coupling / 3.0

		# Nationalist ideology bonus — multiplies final demand
		var nationalist_mult: float = state.get_ideology_bonus("nationalist", 1.0, 1.05)

		var raw: float = (base_demand
			- spec_sup
			- state.demand_rival.get(res, 0.0)
			- state.demand_launch.get(res, 0.0)
			+ state.demand_promote.get(res, 0.0)
			+ coupling_bonus)
		state.demand[res] = clampf(raw * nationalist_mult, min_d, max_d)

		# Record history for sparklines
		var hist: Array = state.demand_history.get(res, [])
		hist.append(state.demand[res])
		if hist.size() > 200:
			hist.pop_front()
		state.demand_history[res] = hist


# Decays speculator count (proportional rate + arbitrage engine bonus) and
# fires a speculator burst if current_day >= speculator_next_burst_tick.
# Called once per tick after shipments. Test with defer_random_events() to
# prevent burst side effects.
func tick_speculators(state: GameState) -> void:
	# Decay speculators — proportional base rate (boosted by Nationalist ideology + Arbitrage Engines)
	var active_arb: int = state.buildings_active.get("arbitrage_engine", state.buildings_owned.get("arbitrage_engine", 0))
	var nationalist_decay_mult: float = state.get_ideology_bonus("nationalist", 1.0, 1.05)
	var proportional_decay: float = state.speculator_count * _dcfg("speculator_proportional_decay") * nationalist_decay_mult
	var arbitrage_decay: float = float(active_arb) * _dcfg("arbitrage_decay_bonus_per_building")
	state.speculator_count = maxf(0.0, state.speculator_count - proportional_decay - arbitrage_decay)
	# Check for burst arrival
	if state.current_day >= state.speculator_next_burst_tick:
		_fire_speculator_burst(state)


# Checks each rival's dump schedule and applies demand_hit to the target
# resource when due. Returns an Array of notification dicts for any dumps
# that fired this tick. Called once per tick after shipments.
func tick_rivals(state: GameState) -> Array:
	var notifications: Array = []
	for rival in _rivals:
		var rid: String = rival.get("id", "")
		if rid.is_empty():
			continue
		if state.current_day >= state.rival_next_dump_tick.get(rid, 0):
			var target_res: String = rival.get("target_resource", "")
			var hit: float = float(rival.get("demand_hit", 0.3))
			state.demand_rival[target_res] = state.demand_rival.get(target_res, 0.0) + hit
			var imin: int = int(rival.get("dump_interval_min", 150))
			var imax: int = int(rival.get("dump_interval_max", 250))
			state.rival_next_dump_tick[rid] = state.current_day + randi_range(imin, imax)
			# Push to launch history as a notification entry
			var res_display: String = _get_resource_display_name(target_res)
			var msg: String = "%s flooded the %s market" % [rival.get("name", rid), res_display]
			var note := GameState.LaunchRecord.new()
			note.tick = state.current_day
			note.notification_message = msg
			note.source_type = "rival"
			state.launch_history.push_front(note)
			if state.launch_history.size() > 5:
				state.launch_history.pop_back()
			notifications.append({
				"tick": state.current_day,
				"rival_name": rival.get("name", rid),
				"resource": target_res,
				"message": msg,
			})
	return notifications


func _fire_speculator_burst(state: GameState) -> void:
	state.speculator_target = _choose_speculator_target(state)
	var size_min: int = int(_dcfg("speculator_burst_size_min"))
	var size_max: int = int(_dcfg("speculator_burst_size_max"))
	var growth: float = _dcfg("speculator_burst_growth")
	var burst: float = float(randi_range(size_min, size_max)) * pow(growth, float(state.speculator_burst_number))
	state.speculator_count += burst
	var int_min: int = int(_dcfg("speculator_burst_interval_min"))
	var int_max: int = int(_dcfg("speculator_burst_interval_max"))
	var interval_mult: float = state.get_modifier("speculator_burst_interval_mult")
	state.speculator_next_burst_tick = state.current_day + int(randi_range(int_min, int_max) * interval_mult)
	state.speculator_burst_number += 1
	# Push speculator burst notification to launch history
	var res_display: String = _get_resource_display_name(state.speculator_target)
	var msg: String = "Speculator surge — %d speculators target %s" % [int(burst), res_display]
	var note := GameState.LaunchRecord.new()
	note.tick = state.current_day
	note.notification_message = msg
	note.source_type = "speculator"
	state.launch_history.push_front(note)
	if state.launch_history.size() > 5:
		state.launch_history.pop_back()
	# Roll fresh random bases for the next cycle
	_reset_target_scores(state)


func _reset_target_scores(state: GameState) -> void:
	for res: String in GameState.TRADEABLE_RESOURCES:
		state.speculator_target_scores[res] = randf_range(0.0, 0.25)


func on_shipment_launched(state: GameState, resource: String, cargo_loaded: float, cargo_capacity: float) -> void:
	var demand: float = state.demand.get(resource, 0.5)
	var increment: float = maxf(0.25, demand) * (cargo_loaded / cargo_capacity)
	state.speculator_target_scores[resource] = state.speculator_target_scores.get(resource, 0.0) + increment


func _choose_speculator_target(state: GameState) -> String:
	var total: float = 0.0
	for res: String in GameState.TRADEABLE_RESOURCES:
		total += state.speculator_target_scores.get(res, 0.0)
	if total <= 0.0:
		return GameState.TRADEABLE_RESOURCES[randi() % GameState.TRADEABLE_RESOURCES.size()] as String
	var roll: float = randf() * total
	var cumulative: float = 0.0
	for res: String in GameState.TRADEABLE_RESOURCES:
		cumulative += state.speculator_target_scores.get(res, 0.0)
		if roll <= cumulative:
			return res
	return GameState.TRADEABLE_RESOURCES[-1] as String


func _get_resource_display_name(short_name: String) -> String:
	for rdef in _resources_data:
		if rdef.short_name == short_name:
			return rdef.get("name", short_name)
	return short_name


func _perlin_1d(t: float) -> float:
	# 1D gradient noise with quintic interpolation
	var xi: int = int(floor(t))
	var xf: float = t - float(xi)
	# Quintic interpolant (zero 1st and 2nd derivative at lattice points)
	var u: float = xf * xf * xf * (xf * (xf * 6.0 - 15.0) + 10.0)
	# Random gradients at lattice points, mapped to [-1, 1]
	var ga: float = _hash_noise(xi) * 2.0 - 1.0
	var gb: float = _hash_noise(xi + 1) * 2.0 - 1.0
	# Dot product of gradient with distance (1D: just multiply)
	return lerpf(ga * xf, gb * (xf - 1.0), u) * 2.0


func _hash_noise(i: int) -> float:
	# lowbias32-style integer hash → [0, 1]
	var x: int = i
	x = ((x >> 16) ^ x) * 0x45d9f3b & 0x7FFFFFFF
	x = ((x >> 16) ^ x) * 0x45d9f3b & 0x7FFFFFFF
	x = (x >> 16) ^ x
	x = x & 0x7FFFFFFF
	return float(x) / float(0x7FFFFFFF)


func _dcfg(key: String) -> float:
	return float(_demand_cfg.get(key, 0.0))
