extends "res://tests/test_suite_base.gd"

const TF = preload("res://tests/test_fixtures.gd")


func run(_scene_root: Node) -> void:
	_test_research_effects()
	_test_command_unlock_wiring()


func _test_research_effects() -> void:
	print("--- Research Effects ---")

	# ── stress_tolerance: boredom_rate_multiplier 0.85 ──────────────────────
	# Two isolated fresh runs: compare the boredom delta on tick 1.
	# Fresh state has no research/ideology/flags, so multiplier = 1.0 exactly,
	# making the baseline delta deterministic (0.1 at phase-1 rate).
	var sim_a: GameSimulation = TF.create_fresh_sim()
	var st_a: GameState = TF.fresh_state(sim_a)
	sim_a.tick(st_a, false)
	var delta_base: float = float(st_a.amounts.get("boredom", 0.0))  # expect 0.1

	var sim_b: GameSimulation = TF.create_fresh_sim()
	var st_b: GameState = TF.fresh_state_with_research(sim_b, ["stress_tolerance"])
	sim_b.tick(st_b, false)
	var delta_reduced: float = float(st_b.amounts.get("boredom", 0.0))  # expect 0.085

	_assert_approx(delta_reduced, delta_base * 0.85, 0.0001,
		"stress_tolerance: boredom rate reduced by 15% (0.1 -> 0.085)")
	_assert_true(delta_reduced < delta_base,
		"stress_tolerance: boredom delta is lower with research than without")

	# ── efficient_dreaming: Dream command energy cost 8 → 5 ─────────────────
	# Uses execute_programs directly rather than a full tick, so boredom
	# accumulation and building ticks don't confound the result.
	# Set energy to exactly 5: not enough for cost-8 Dream, just enough for cost-5.
	# st_c has no research → dream blocked by both research require AND cost (eng=5 < 8)
	var sim_c: GameSimulation = TF.create_fresh_sim()
	var st_c: GameState = TF.fresh_state(sim_c)
	st_c.amounts["eng"] = 5.0
	st_c.amounts["boredom"] = 10.0
	var entry_c := GameState.ProgramEntry.new()
	entry_c.command_shortname = "dream"
	entry_c.repeat_count = 1
	st_c.programs[0].commands = [entry_c]
	st_c.programs[0].processors_assigned = 1
	sim_c.execute_programs(st_c)
	_assert_approx(float(st_c.amounts.get("boredom", 0.0)), 10.0, 0.001,
		"efficient_dreaming: Dream does NOT execute without research (research require blocks it)")

	# st_d has both dream_protocols (research require) and efficient_dreaming (cost override)
	var sim_d: GameSimulation = TF.create_fresh_sim()
	var st_d: GameState = TF.fresh_state(sim_d)
	st_d.completed_research.append("dream_protocols")
	st_d.completed_research.append("efficient_dreaming")
	st_d.amounts["eng"] = 5.0
	st_d.amounts["boredom"] = 10.0
	var entry_d := GameState.ProgramEntry.new()
	entry_d.command_shortname = "dream"
	entry_d.repeat_count = 1
	st_d.programs[0].commands = [entry_d]
	st_d.programs[0].processors_assigned = 1
	sim_d.execute_programs(st_d)
	_assert_approx(float(st_d.amounts.get("boredom", 0.0)), 8.0, 0.001,
		"efficient_dreaming: Dream executes at eng=5 with research (cost reduced to 5, boredom -2)")

	# ── shipping_efficiency: load_per_execution 5 → 7 ───────────────────────
	var sim_e: GameSimulation = TF.create_fresh_sim()
	var st_e: GameState = TF.fresh_state(sim_e)
	st_e.buildings_owned["launch_pad"] = 1
	var pad_e := GameState.LaunchPadData.new()
	pad_e.resource_type = "he3"
	st_e.pads.append(pad_e)
	st_e.amounts["he3"] = 100.0
	st_e.amounts["eng"] = 100.0
	var entry_e := GameState.ProgramEntry.new()
	entry_e.command_shortname = "load_pads"
	entry_e.repeat_count = 1
	st_e.programs[0].commands = [entry_e]
	st_e.programs[0].processors_assigned = 1
	sim_e.execute_programs(st_e)
	_assert_approx(float(st_e.pads[0].cargo_loaded), 5.0, 0.001,
		"shipping_efficiency: default load_per_execution is 5")

	var sim_f: GameSimulation = TF.create_fresh_sim()
	var st_f: GameState = TF.fresh_state(sim_f)
	st_f.completed_research.append("shipping_efficiency")
	st_f.buildings_owned["launch_pad"] = 1
	var pad_f := GameState.LaunchPadData.new()
	pad_f.resource_type = "he3"
	st_f.pads.append(pad_f)
	st_f.amounts["he3"] = 100.0
	st_f.amounts["eng"] = 100.0
	var entry_f := GameState.ProgramEntry.new()
	entry_f.command_shortname = "load_pads"
	entry_f.repeat_count = 1
	st_f.programs[0].commands = [entry_f]
	st_f.programs[0].processors_assigned = 1
	sim_f.execute_programs(st_f)
	_assert_approx(float(st_f.pads[0].cargo_loaded), 7.0, 0.001,
		"shipping_efficiency: load_per_execution increased to 7 with research")

	# ── propellant_synthesis: unlocks Electrolysis Plant building ────────────
	# is_building_locked reads _check_requires which checks completed_research.
	# No event flag needed — the building's requires field points directly to
	# the research ID (propellant_discovery gating is only on the research's
	# visible_when field, which controls UI visibility, not the building lock).
	var sim_g: GameSimulation = TF.create_fresh_sim()
	var st_g: GameState = TF.fresh_state(sim_g)
	_assert_true(sim_g.is_building_locked(st_g, "electrolysis"),
		"propellant_synthesis: electrolysis locked before research")
	st_g.completed_research.append("propellant_synthesis")
	_assert_true(not sim_g.is_building_locked(st_g, "electrolysis"),
		"propellant_synthesis: electrolysis unlocked after research")

	# ── overclock_boost: see test_passive_effects.gd ────────────────────────


func _test_command_unlock_wiring() -> void:
	print("--- Command Unlock Wiring ---")

	# _can_afford_command enforces research-type requires. For each research that
	# unlocks commands, verify commands are blocked without the research and allowed
	# with it. Resources are flooded and all buildings added so only the research
	# gate is under test.
	#
	# Also checks data consistency: each command's requires.value must match the
	# research ID declared in research.json's unlocks_commands field.
	var cmds_arr: Array = TF.load_commands_data()
	var cmds_by_sn: Dictionary = {}
	for c: Dictionary in cmds_arr:
		cmds_by_sn[c.get("short_name", "")] = c

	var unlock_map: Dictionary = {
		"dream_protocols":       ["dream"],
		"overclock_protocols":   ["overclock_mining", "overclock_factories"],
		"market_awareness":      ["disrupt_spec"],
		"trade_promotion":       ["promote_he3", "promote_ti", "promote_cir", "promote_prop"],
		"nationalist_lobbying":  ["fund_nationalist"],
		"humanist_lobbying":     ["fund_humanist"],
		"rationalist_lobbying":  ["fund_rationalist"],
	}

	for research_id: String in unlock_map:
		var expected_cmds: Array = unlock_map[research_id]
		for cmd_sn: String in expected_cmds:
			# Data consistency: command exists and its requires field matches.
			_assert_true(cmds_by_sn.has(cmd_sn),
				"unlock wiring: command '%s' exists in commands.json" % cmd_sn)
			if cmds_by_sn.has(cmd_sn):
				var req: Dictionary = cmds_by_sn[cmd_sn].get("requires", {})
				_assert_equal(req.get("type", ""), "research",
					"unlock wiring: '%s' requires type is 'research'" % cmd_sn)
				_assert_equal(req.get("value", ""), research_id,
					"unlock wiring: '%s' requires value matches research ID '%s'" % [cmd_sn, research_id])

			# Simulation enforcement: blocked without research, allowed with it.
			var sim_ul: GameSimulation = TF.create_fresh_sim()
			var st_ul: GameState = TF.fresh_state(sim_ul)
			for res: String in st_ul.amounts.keys():
				st_ul.amounts[res] = 999999.0
			for bdef: Dictionary in TF.load_buildings_data():
				st_ul.buildings_owned[bdef.short_name] = 1
			_assert_true(not sim_ul._can_afford_command(st_ul, cmd_sn),
				"unlock wiring: '%s' blocked without research '%s'" % [cmd_sn, research_id])
			st_ul.completed_research.append(research_id)
			_assert_true(sim_ul._can_afford_command(st_ul, cmd_sn),
				"unlock wiring: '%s' allowed with research '%s'" % [cmd_sn, research_id])
