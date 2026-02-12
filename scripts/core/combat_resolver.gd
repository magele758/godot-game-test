class_name CombatResolver
extends RefCounted


static func compute_hit(base_damage: float, attacker_bonus: float, combo_depth: int, is_execution: bool = false) -> Dictionary:
	var combo_multiplier: float = 1.0 + minf(0.35, float(max(0, combo_depth - 1)) * 0.05)
	var execution_multiplier: float = 1.8 if is_execution else 1.0
	var damage: int = int(round(base_damage * attacker_bonus * combo_multiplier * execution_multiplier))
	return {
		"damage": max(1, damage),
		"stagger_frames": 6 + combo_depth,
		"hitstop_seconds": 0.04 + float(combo_depth) * 0.005,
		"execution": is_execution,
	}
