extends RefCounted

# VOLT PATH shared enemy geometry / line-of-sight authority.
# Used by enemy AI, card hit tests and rendering through thin wrappers in main.gd.
# Owns no Node and has no _process().

var h = null

func setup(host) -> void:
    h = host

func _next_shape_step(start: Vector2i, occupied: Dictionary, can_occupy: Callable, distance_to_player: Callable) -> Vector2i:
    # 大型敵の基準座標をノードとしてBFSする。
    # 一旦プレイヤーから遠ざかる必要がある迂回路も探索できる。
    var open: Array[Vector2i] = [start]
    var seen: Dictionary = {start: true}
    var came_from: Dictionary = {}
    var read_index := 0
    var best: Vector2i = start
    var best_score: int = int(distance_to_player.call(start))
    var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

    while read_index < open.size():
        var cur: Vector2i = open[read_index]
        read_index += 1
        var score: int = int(distance_to_player.call(cur))
        if score < best_score:
            best_score = score
            best = cur
        for d in dirs:
            var next: Vector2i = cur + d
            if seen.has(next):
                continue
            if not bool(can_occupy.call(next, occupied)):
                continue
            seen[next] = true
            came_from[next] = cur
            open.append(next)

    if best == start:
        return start
    var step: Vector2i = best
    while came_from.has(step) and Vector2i(came_from[step]) != start:
        step = Vector2i(came_from[step])
    if came_from.has(step) and Vector2i(came_from[step]) == start:
        return step
    return start

func heavy_cells(top_left: Vector2i) -> Array[Vector2i]:
    return [
        top_left,
        top_left + Vector2i.RIGHT,
        top_left + Vector2i.DOWN,
        top_left + Vector2i(1, 1)
    ]

func heavy_can_occupy(top_left: Vector2i, occupied: Dictionary) -> bool:
    for cell in heavy_cells(top_left):
        if not h._is_floor(cell) or cell == h.player_pos or occupied.has(cell):
            return false
    return true

func heavy_distance_to_player(top_left: Vector2i) -> int:
    var best: int = 999999
    for cell in heavy_cells(top_left):
        best = min(best, h._manhattan(cell, h.player_pos))
    return best

func heavy_next_step(top_left: Vector2i, occupied: Dictionary) -> Vector2i:
    return _next_shape_step(top_left, occupied, Callable(self, "heavy_can_occupy"), Callable(self, "heavy_distance_to_player"))

func tank_cells(top_left: Vector2i) -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    for oy in range(3):
        for ox in range(3):
            out.append(top_left + Vector2i(ox, oy))
    return out

func tank_can_occupy(top_left: Vector2i, occupied: Dictionary) -> bool:
    for cell in tank_cells(top_left):
        if not h._is_floor(cell) or cell == h.player_pos or occupied.has(cell):
            return false
    return true

func tank_distance_to_player(top_left: Vector2i) -> int:
    var best: int = 999999
    for cell in tank_cells(top_left):
        best = min(best, h._manhattan(cell, h.player_pos))
    return best

func tank_next_step(top_left: Vector2i, occupied: Dictionary) -> Vector2i:
    return _next_shape_step(top_left, occupied, Callable(self, "tank_can_occupy"), Callable(self, "tank_distance_to_player"))

func tank_aim_dir(top_left: Vector2i, target: Vector2i) -> Vector2i:
    var d := Vector2i.ZERO
    var lane_start := Vector2i.ZERO
    if target.y < top_left.y and target.x >= top_left.x and target.x <= top_left.x + 2:
        d = Vector2i.UP
        lane_start = Vector2i(target.x, top_left.y - 1)
    elif target.y > top_left.y + 2 and target.x >= top_left.x and target.x <= top_left.x + 2:
        d = Vector2i.DOWN
        lane_start = Vector2i(target.x, top_left.y + 3)
    elif target.x < top_left.x and target.y >= top_left.y and target.y <= top_left.y + 2:
        d = Vector2i.LEFT
        lane_start = Vector2i(top_left.x - 1, target.y)
    elif target.x > top_left.x + 2 and target.y >= top_left.y and target.y <= top_left.y + 2:
        d = Vector2i.RIGHT
        lane_start = Vector2i(top_left.x + 3, target.y)
    else:
        return Vector2i.ZERO

    var p: Vector2i = lane_start
    while p != target:
        if not h._in_bounds(p) or h.walls.has(p):
            return Vector2i.ZERO
        p += d
    if h.walls.has(target):
        return Vector2i.ZERO
    return d

func tank_beam_cells(top_left: Vector2i, d: Vector2i) -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    var starts: Array[Vector2i] = []
    if d == Vector2i.UP:
        starts = [top_left + Vector2i(0, -1), top_left + Vector2i(1, -1), top_left + Vector2i(2, -1)]
    elif d == Vector2i.DOWN:
        starts = [top_left + Vector2i(0, 3), top_left + Vector2i(1, 3), top_left + Vector2i(2, 3)]
    elif d == Vector2i.LEFT:
        starts = [top_left + Vector2i(-1, 0), top_left + Vector2i(-1, 1), top_left + Vector2i(-1, 2)]
    elif d == Vector2i.RIGHT:
        starts = [top_left + Vector2i(3, 0), top_left + Vector2i(3, 1), top_left + Vector2i(3, 2)]
    else:
        return out

    for start in starts:
        var p: Vector2i = start
        while h._in_bounds(p) and not h.walls.has(p):
            if not out.has(p):
                out.append(p)
            p += d
    return out

func cross_cells(center: Vector2i) -> Array[Vector2i]:
    return [
        center,
        center + Vector2i.UP,
        center + Vector2i.DOWN,
        center + Vector2i.LEFT,
        center + Vector2i.RIGHT
    ]

func cross_can_occupy(center: Vector2i, occupied: Dictionary) -> bool:
    for cell in cross_cells(center):
        if not h._is_floor(cell) or cell == h.player_pos or occupied.has(cell):
            return false
    return true

func cross_distance_to_player(center: Vector2i) -> int:
    return h._manhattan(center, h.player_pos)

func cross_next_step(center: Vector2i, occupied: Dictionary) -> Vector2i:
    return _next_shape_step(center, occupied, Callable(self, "cross_can_occupy"), Callable(self, "cross_distance_to_player"))

func cross_ray_cells(center: Vector2i, d: Vector2i) -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    if d != Vector2i.UP and d != Vector2i.DOWN and d != Vector2i.LEFT and d != Vector2i.RIGHT:
        return out
    var p: Vector2i = center + d * 2
    while h._in_bounds(p) and not h.walls.has(p):
        out.append(p)
        p += d
    return out

func artillery_cells(left_cell: Vector2i) -> Array[Vector2i]:
    return [
        left_cell,
        left_cell + Vector2i.RIGHT,
        left_cell + Vector2i(2, 0)
    ]

func artillery_can_occupy(left_cell: Vector2i, occupied: Dictionary) -> bool:
    for cell in artillery_cells(left_cell):
        if not h._is_floor(cell) or cell == h.player_pos or occupied.has(cell):
            return false
    return true

func artillery_has_horizontal_target(left_cell: Vector2i, target: Vector2i) -> bool:
    var cells: Array[Vector2i] = artillery_cells(left_cell)
    var left_edge: Vector2i = cells[0]
    var right_edge: Vector2i = cells[2]
    if target.y != left_cell.y:
        return false

    if target.x < left_edge.x:
        var p: Vector2i = left_edge + Vector2i.LEFT
        while p != target:
            if not h._in_bounds(p) or h.walls.has(p):
                return false
            p += Vector2i.LEFT
        return not h.walls.has(target)

    if target.x > right_edge.x:
        var p: Vector2i = right_edge + Vector2i.RIGHT
        while p != target:
            if not h._in_bounds(p) or h.walls.has(p):
                return false
            p += Vector2i.RIGHT
        return not h.walls.has(target)

    return false

func artillery_ray_cells(left_cell: Vector2i, d: Vector2i) -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    if d != Vector2i.LEFT and d != Vector2i.RIGHT:
        return out
    var start: Vector2i = left_cell - Vector2i.RIGHT if d == Vector2i.LEFT else left_cell + Vector2i(3, 0)
    var p: Vector2i = start
    while h._in_bounds(p) and not h.walls.has(p):
        out.append(p)
        p += d
    return out

func charger_axis_dir(start: Vector2i, target: Vector2i) -> Vector2i:
    var distance: int = h._manhattan(start, target)
    if distance < 2 or distance > 4:
        return Vector2i.ZERO

    var d := Vector2i.ZERO
    if start.x == target.x:
        d = Vector2i.DOWN if target.y > start.y else Vector2i.UP
    elif start.y == target.y:
        d = Vector2i.RIGHT if target.x > start.x else Vector2i.LEFT
    else:
        return Vector2i.ZERO

    var p: Vector2i = start + d
    while p != target:
        if not h._is_floor(p):
            return Vector2i.ZERO
        if enemy_index_at(p) != -1:
            return Vector2i.ZERO
        p += d
    return d

func charger_preview_cells(start: Vector2i, d: Vector2i) -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    if d == Vector2i.ZERO:
        return out
    var p: Vector2i = start
    for _step in range(4):
        p += d
        if not h._is_floor(p):
            break
        out.append(p)
    return out

func turret_axis_dir(start: Vector2i, target: Vector2i) -> Vector2i:
    var d: Vector2i = Vector2i.ZERO
    if start.x == target.x:
        d = Vector2i.DOWN if target.y > start.y else Vector2i.UP
    elif start.y == target.y:
        d = Vector2i.RIGHT if target.x > start.x else Vector2i.LEFT
    else:
        return Vector2i.ZERO

    var p: Vector2i = start + d
    while p != target:
        if not h._in_bounds(p) or h.walls.has(p):
            return Vector2i.ZERO
        p += d
    return d

func turret_ray_cells(start: Vector2i, d: Vector2i) -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    if d == Vector2i.ZERO:
        return out
    var p: Vector2i = start + d
    while h._in_bounds(p) and not h.walls.has(p):
        out.append(p)
        p += d
    return out

func next_step_toward(start: Vector2i, goal: Vector2i, occupied: Dictionary) -> Vector2i:
    var open: Array[Vector2i] = [start]
    var came_from: Dictionary = {}
    var seen: Dictionary = {start: true}
    var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]

    while not open.is_empty():
        var cur: Vector2i = open.pop_front()
        if cur == goal:
            break
        for d in dirs:
            var n: Vector2i = cur + d
            if not h._is_floor(n) or seen.has(n):
                continue
            if occupied.has(n) and n != goal:
                continue
            seen[n] = true
            came_from[n] = cur
            open.push_back(n)

    if not seen.has(goal):
        return start

    var cur: Vector2i = goal
    while came_from.has(cur) and came_from[cur] != start:
        cur = came_from[cur]
    if came_from.has(cur) and came_from[cur] == start:
        return cur
    return start

func enemy_cells(enemy: Dictionary) -> Array[Vector2i]:
    var out: Array[Vector2i] = []
    var head: Vector2i = enemy["pos"]
    out.append(head)
    var enemy_type: String = str(enemy.get("type", "chaser"))
    if enemy_type == "boss_leg":
        out.clear()
        if bool(enemy.get("destroyed", false)):
            return out
        for cell in h._boss_leg_cells(head):
            out.append(cell)
    elif enemy_type == "serpent":
        var tail: Vector2i = enemy["tail"]
        if tail != head:
            out.append(tail)
    elif enemy_type == "long_serpent":
        out.clear()
        var raw_segments: Array = enemy.get("segments", [])
        for item in raw_segments:
            out.append(Vector2i(item))
    elif enemy_type == "heavy":
        out.clear()
        for cell in heavy_cells(head):
            out.append(cell)
    elif enemy_type == "artillery":
        out.clear()
        for cell in artillery_cells(head):
            out.append(cell)
    elif enemy_type == "cross_discharge":
        out.clear()
        for cell in cross_cells(head):
            out.append(cell)
    elif enemy_type == "tank":
        out.clear()
        for cell in tank_cells(head):
            out.append(cell)
    return out

func enemy_intersects_cells(enemy: Dictionary, cells: Array[Vector2i]) -> bool:
    for enemy_cell in enemy_cells(enemy):
        if enemy_cell in cells:
            return true
    return false

func enemy_intersects_region(enemy: Dictionary, region: Dictionary) -> bool:
    for enemy_cell in enemy_cells(enemy):
        if region.has(enemy_cell):
            return true
    return false

func enemy_index_at(p: Vector2i) -> int:
    for i in range(h.enemies.size()):
        for enemy_cell in enemy_cells(h.enemies[i]):
            if enemy_cell == p:
                return i
    return -1

func enemy_bounds_rect(enemy: Dictionary) -> Rect2:
    var cells: Array[Vector2i] = enemy_cells(enemy)
    if cells.is_empty():
        return Rect2()
    var min_x: int = cells[0].x
    var max_x: int = cells[0].x
    var min_y: int = cells[0].y
    var max_y: int = cells[0].y
    for cell in cells:
        min_x = mini(min_x, cell.x)
        max_x = maxi(max_x, cell.x)
        min_y = mini(min_y, cell.y)
        max_y = maxi(max_y, cell.y)
    var top_left: Vector2 = h._cell_rect(Vector2i(min_x, min_y)).position
    var bottom_right: Vector2 = h._cell_rect(Vector2i(max_x, max_y)).end
    return Rect2(top_left, bottom_right - top_left)
