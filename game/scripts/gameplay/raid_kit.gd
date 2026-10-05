extends RefCounted

## Raid-loop helpers: extraction loot merge and death loot loss.
## Kept scene-free so they are unit-testable headless.


## Move everything the backpack holds into the stash. Items that don't fit
## are dropped (lost). Returns {moved: int, dropped: int}.
static func merge_into_stash(backpack: RefCounted, stash: RefCounted) -> Dictionary:
	var moved := 0
	var dropped := 0
	var entries = backpack.entries()
	for entry in entries:
		var taken = backpack.take_at(entry["pos"], -1)
		if taken.is_empty():
			continue
		var leftover = stash.add_item(String(taken["id"]), int(taken["count"]))
		moved += int(taken["count"]) - leftover
		dropped += leftover
	return {"moved": moved, "dropped": dropped}


## Raid death: the backpack's contents are lost.
static func clear_backpack(backpack: RefCounted) -> int:
	var lost := 0
	for entry in backpack.entries():
		var taken = backpack.take_at(entry["pos"], -1)
		lost += int(taken.get("count", 0))
	return lost


## Stacks in-hand when a loot view closed (GAME_STATE.raid_pending) ride
## out with the extraction like backpack contents: merged into the stash,
## dropped if it can't fit. The pending array is emptied either way.
static func merge_pending_into_stash(pending: Array, stash: RefCounted) -> Dictionary:
	var moved := 0
	var dropped := 0
	for stack in pending:
		var leftover = stash.add_item(String(stack["id"]), int(stack["count"]), Vector2i(-1, -1), bool(stack.get("rotated", false)))
		moved += int(stack["count"]) - leftover
		dropped += leftover
	pending.clear()
	return {"moved": moved, "dropped": dropped}
