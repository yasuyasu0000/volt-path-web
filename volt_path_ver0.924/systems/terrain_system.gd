extends RefCounted

# VOLT PATH terrain generation authority.
# Owns no Node and no per-frame processing. It only rebuilds the wall map when a stage starts.

var h = null

func setup(host) -> void:
    h = host

func _build_border() -> void:
    for x in range(h.GRID_W):
        h.walls[Vector2i(x, 0)] = true
        h.walls[Vector2i(x, h.GRID_H - 1)] = true
    for y in range(h.GRID_H):
        h.walls[Vector2i(0, y)] = true
        h.walls[Vector2i(h.GRID_W - 1, y)] = true

func generate_open_map() -> void:
    h.walls.clear()
    _build_border()

func generate_map() -> void:
    h.walls.clear()
    _build_border()

    # FLOOR 10 is an open boss arena so every 3x3 leg can move inside its assigned area.
    if h.current_floor == h.TOTAL_FLOORS:
        return

    for y in range(1, h.GRID_H - 1):
        for x in range(1, h.GRID_W - 1):
            var p := Vector2i(x, y)
            if p.distance_to(h.player_pos) <= 2.0:
                continue
            if h.rng.randf() < 0.115:
                h.walls[p] = true

    var reachable: Dictionary = reachable_from(h.player_pos)
    for y in range(1, h.GRID_H - 1):
        for x in range(1, h.GRID_W - 1):
            var p := Vector2i(x, y)
            if not h.walls.has(p) and not reachable.has(p):
                h.walls[p] = true

func reachable_from(start: Vector2i) -> Dictionary:
    var seen: Dictionary = {}
    var open: Array[Vector2i] = [start]
    seen[start] = true
    var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
    while not open.is_empty():
        var cur: Vector2i = open.pop_front()
        for d in dirs:
            var n: Vector2i = cur + d
            if not h._in_bounds(n) or h.walls.has(n) or seen.has(n):
                continue
            seen[n] = true
            open.push_back(n)
    return seen
