extends RefCounted

const CardCatalog = preload("res://systems/card_catalog.gd")

const ARC_DURATION := 0.24
const SURGE_DURATION := 0.36
const BOMB_DURATION := 0.34
const WARP_DURATION := 0.36
const DASH_MIN_DURATION := 0.22
const DASH_MAX_DURATION := 0.52
const DASH_BASE_DURATION := 0.11
const DASH_PER_CELL_DURATION := 0.055
const DASH_SNAP_PORTION := 0.22
const LOOP_DURATION := 0.52
const CELL_SIZE := 38.0

const C_CORE := Color(0.92, 0.99, 1.0, 0.98)
const C_GLOW := Color(0.28, 0.88, 1.0, 0.62)

var active := false
var kind := ""
var time := 0.0
var cells: Array[Vector2i] = []
var secondary_cells: Array[Vector2i] = []
var distances: Dictionary = {}
var max_distance := 0
var origin := Vector2i.ZERO
var target := Vector2i.ZERO

func reset() -> void:
    active = false
    kind = ""
    time = 0.0
    cells.clear()
    secondary_cells.clear()
    distances.clear()
    max_distance = 0
    origin = Vector2i.ZERO
    target = Vector2i.ZERO

func _duration() -> float:
    match kind:
        CardCatalog.ARC:
            return ARC_DURATION
        CardCatalog.BOMB:
            return BOMB_DURATION
        CardCatalog.WARP:
            return WARP_DURATION
        CardCatalog.DASH:
            # ラインダッシュは経路長に応じて少しだけ長くする。
            # ただし長距離でもテンポを落としすぎず、1マスごとの「ビシッ」を見せる。
            return clampf(DASH_BASE_DURATION + float(maxi(1, cells.size())) * DASH_PER_CELL_DURATION, DASH_MIN_DURATION, DASH_MAX_DURATION)
        CardCatalog.LOOP:
            return LOOP_DURATION
        _:
            return SURGE_DURATION

func process(delta: float) -> bool:
    if not active:
        return false
    time += delta
    if time < _duration():
        return false
    reset()
    return true

func start_arc(path: Array[Vector2i], start_origin: Vector2i) -> void:
    reset()
    active = true
    kind = CardCatalog.ARC
    origin = start_origin
    cells = path.duplicate()
    max_distance = maxi(0, path.size())

func start_surge(region: Dictionary, start_origin: Vector2i) -> void:
    reset()
    active = true
    kind = CardCatalog.SURGE
    origin = start_origin
    if region.is_empty():
        return
    var open: Array[Vector2i] = [start_origin]
    distances[start_origin] = 0
    var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
    while not open.is_empty():
        var current: Vector2i = open.pop_front()
        var dist: int = int(distances[current])
        cells.append(current)
        max_distance = maxi(max_distance, dist)
        for d in dirs:
            var next: Vector2i = current + d
            if region.has(next) and not distances.has(next):
                distances[next] = dist + 1
                open.append(next)

func start_bomb(blast: Array[Vector2i], start_origin: Vector2i) -> void:
    reset()
    active = true
    kind = CardCatalog.BOMB
    origin = start_origin
    cells = blast.duplicate()

func start_warp(start_origin: Vector2i, end_target: Vector2i) -> void:
    reset()
    active = true
    kind = CardCatalog.WARP
    origin = start_origin
    target = end_target

func start_dash(start_origin: Vector2i, path: Array[Vector2i], end_target: Vector2i) -> void:
    reset()
    active = true
    kind = CardCatalog.DASH
    origin = start_origin
    target = end_target
    cells = path.duplicate()
    max_distance = path.size()

func start_loop(boundary: Array[Vector2i], inside: Array[Vector2i], start_origin: Vector2i) -> void:
    reset()
    active = true
    kind = CardCatalog.LOOP
    origin = start_origin
    cells = boundary.duplicate()
    secondary_cells = inside.duplicate()
    max_distance = boundary.size()

func draw(host, cell_center: Callable, cell_rect: Callable, player_color: Callable, player_facing: Vector2i) -> void:
    if not active:
        return
    if kind == CardCatalog.ARC:
        var progress: float = clamp(time / ARC_DURATION, 0.0, 1.0)
        var total_points: int = cells.size() + 1
        var visible_segments: int = clampi(int(ceil(progress * float(maxi(1, total_points - 1)))), 0, maxi(0, total_points - 1))
        var prev: Vector2 = cell_center.call(origin)
        for i in range(visible_segments):
            if i >= cells.size():
                break
            var cell: Vector2i = cells[i]
            var next_center: Vector2 = cell_center.call(cell)
            host.draw_line(prev, next_center, C_GLOW, 9.0, true)
            host.draw_line(prev, next_center, C_CORE, 3.0, true)
            prev = next_center
        if visible_segments > 0 and not cells.is_empty():
            var head_index: int = mini(visible_segments - 1, cells.size() - 1)
            var head: Vector2 = cell_center.call(cells[head_index])
            host.draw_circle(head, 8.0, C_GLOW)
            host.draw_circle(head, 4.0, C_CORE)
        else:
            host.draw_circle(cell_center.call(origin), 8.0, C_GLOW)
            host.draw_circle(cell_center.call(origin), 4.0, C_CORE)
    elif kind == CardCatalog.SURGE:
        var progress: float = clamp(time / SURGE_DURATION, 0.0, 1.0)
        var wave: float = progress * float(max_distance + 1)
        for cell in cells:
            var dist: int = int(distances.get(cell, 0))
            var delta: float = wave - float(dist)
            if delta < 0.0 or delta > 2.2:
                continue
            var strength: float = 1.0 - clamp(abs(delta - 0.7) / 1.5, 0.0, 1.0)
            var r: Rect2 = cell_rect.call(cell).grow(-3.0)
            var glow: Color = C_GLOW
            glow.a *= 0.28 + 0.55 * strength
            host.draw_rect(r, glow)
            host.draw_rect(r, C_CORE, false, 2.0 + 2.0 * strength)
            host.draw_circle(cell_center.call(cell), 3.0 + 3.0 * strength, C_CORE)
    elif kind == CardCatalog.BOMB:
        var progress: float = clamp(time / BOMB_DURATION, 0.0, 1.0)
        var origin_center: Vector2 = cell_center.call(origin)

        # 1) 爆心を短く白くフラッシュ。
        if progress < 0.24:
            var flash_t: float = 1.0 - progress / 0.24
            var flash_color: Color = C_CORE
            flash_color.a = 0.35 + 0.60 * flash_t
            host.draw_circle(origin_center, 8.0 + 18.0 * (1.0 - flash_t), flash_color)

        # 2) 白青の衝撃波を3x3へ広げる。
        var ring_progress: float = clamp(progress / 0.68, 0.0, 1.0)
        if ring_progress < 1.0:
            var ring_radius: float = lerpf(7.0, CELL_SIZE * 1.60, ring_progress)
            var ring_glow: Color = C_GLOW
            ring_glow.a *= 1.0 - ring_progress * 0.72
            var ring_core: Color = C_CORE
            ring_core.a *= 1.0 - ring_progress * 0.55
            host.draw_arc(origin_center, ring_radius, 0.0, TAU, 48, ring_glow, 8.0, true)
            host.draw_arc(origin_center, ring_radius, 0.0, TAU, 48, ring_core, 2.5, true)

        # 3) 爆発範囲の床を青白く一瞬強調し、帯電したことを見せる。
        if progress >= 0.28:
            var tile_t: float = clamp((progress - 0.28) / 0.72, 0.0, 1.0)
            var tile_alpha: float = sin(tile_t * PI)
            for cell in cells:
                var r: Rect2 = cell_rect.call(cell).grow(-3.0)
                var tile_glow: Color = C_GLOW
                tile_glow.a = 0.18 + 0.50 * tile_alpha
                host.draw_rect(r, tile_glow)
                var edge: Color = C_CORE
                edge.a = 0.45 + 0.50 * tile_alpha
                host.draw_rect(r, edge, false, 2.0 + 2.0 * tile_alpha)

    elif kind == CardCatalog.WARP:
        var progress: float = clamp(time / WARP_DURATION, 0.0, 1.0)
        var origin_center: Vector2 = cell_center.call(origin)
        var target_center: Vector2 = cell_center.call(target)

        # 1) 元位置へ青白い光を収束させて主人公が消える。
        if progress < 0.46:
            var vanish_t: float = clamp(progress / 0.46, 0.0, 1.0)
            var vanish_radius: float = lerpf(18.0, 2.0, vanish_t)
            var vanish_glow: Color = C_GLOW
            vanish_glow.a *= 1.0 - vanish_t * 0.35
            host.draw_circle(origin_center, vanish_radius + 7.0, vanish_glow)
            host.draw_arc(origin_center, vanish_radius + 4.0, 0.0, TAU, 32, C_CORE, 2.5, true)
            var pinch_height: float = lerpf(28.0, 5.0, vanish_t)
            host.draw_line(origin_center - Vector2(0, pinch_height), origin_center + Vector2(0, pinch_height), C_CORE, 3.0, true)

        # 2) 着地点に短い光柱を立てて位置変化を明示する。
        if progress >= 0.28 and progress < 0.88:
            var beam_t: float = clamp((progress - 0.28) / 0.60, 0.0, 1.0)
            var beam_strength: float = sin(beam_t * PI)
            var beam_glow: Color = C_GLOW
            beam_glow.a *= 0.45 + 0.45 * beam_strength
            var beam_core: Color = C_CORE
            beam_core.a *= 0.60 + 0.40 * beam_strength
            host.draw_line(target_center - Vector2(0, 34.0), target_center + Vector2(0, 34.0), beam_glow, 10.0, true)
            host.draw_line(target_center - Vector2(0, 30.0), target_center + Vector2(0, 30.0), beam_core, 3.0, true)
            host.draw_arc(target_center, 8.0 + 11.0 * beam_t, 0.0, TAU, 32, beam_core, 2.0, true)

        # 3) 終盤で主人公が小さく出現し、通常表示へ自然につなぐ。
        if progress >= 0.56:
            var appear_t: float = clamp((progress - 0.56) / 0.44, 0.0, 1.0)
            var appear_radius: float = lerpf(3.0, 13.0, appear_t)
            var body_color: Color = player_color.call()
            body_color.a = 0.45 + 0.55 * appear_t
            host.draw_circle(target_center, appear_radius, body_color)
            var outline: Color = Color.WHITE
            outline.a = 0.55 + 0.45 * appear_t
            host.draw_arc(target_center, appear_radius, 0.0, TAU, 32, outline, 2.0, true)
            if player_facing != Vector2i.ZERO and appear_t > 0.70:
                var player_dir := Vector2(player_facing.x, player_facing.y)
                var dir_alpha: float = clamp((appear_t - 0.70) / 0.30, 0.0, 1.0)
                var dir_color: Color = Color.WHITE
                dir_color.a = dir_alpha
                host.draw_line(target_center + player_dir * 2.0, target_center + player_dir * 16.0, dir_color, 4.0, true)

    elif kind == CardCatalog.DASH:
        var duration: float = _duration()
        var progress: float = clamp(time / duration, 0.0, 1.0)
        var points: Array[Vector2i] = []
        points.append(origin)
        for cell in cells:
            points.append(cell)
        if points.size() >= 2:
            var step_count: int = points.size() - 1
            # 連続的に滑らせず、各セルの冒頭だけ高速移動して残りは「止める」。
            # これで ビシッ → 静止 → ビシッ → 静止 のグリッドらしいダッシュ感を出す。
            var step_f: float = progress * float(step_count)
            var seg: int = mini(int(floor(step_f)), step_count - 1)
            var local_t: float = clamp(step_f - float(seg), 0.0, 1.0)
            if progress >= 1.0:
                seg = step_count - 1
                local_t = 1.0

            var a: Vector2 = cell_center.call(points[seg])
            var b: Vector2 = cell_center.call(points[seg + 1])
            var snap_t: float = 1.0
            if local_t < DASH_SNAP_PORTION:
                var raw_snap: float = clamp(local_t / DASH_SNAP_PORTION, 0.0, 1.0)
                # ease-out cubic。ほぼ瞬間移動だが1〜2フレームだけ方向が読める。
                snap_t = 1.0 - pow(1.0 - raw_snap, 3.0)
            var current: Vector2 = a.lerp(b, snap_t)

            # すでに通過した区間だけ軌跡を残す。未来の経路は光らせない。
            var traveled_segments: int = seg + (1 if local_t >= DASH_SNAP_PORTION else 0)
            for i in range(traveled_segments):
                var ta: Vector2 = cell_center.call(points[i])
                var tb: Vector2 = cell_center.call(points[i + 1])
                var age: int = traveled_segments - 1 - i
                var fade: float = clamp(1.0 - float(age) * 0.17, 0.20, 1.0)
                var glow: Color = C_GLOW
                glow.a *= 0.58 * fade
                var core: Color = C_CORE
                core.a *= 0.82 * fade
                host.draw_line(ta, tb, glow, 7.0, true)
                host.draw_line(ta, tb, core, 2.2, true)

            # 直近2セルに離散的な残像。滑らかな追従ではなく「位置が飛んだ」印象を強める。
            var arrived_index: int = seg + (1 if local_t >= DASH_SNAP_PORTION else 0)
            for ghost_index in range(1, 3):
                var point_index: int = arrived_index - ghost_index
                if point_index < 0 or point_index >= points.size():
                    continue
                var ghost_pos: Vector2 = cell_center.call(points[point_index])
                var ghost_color: Color = player_color.call()
                ghost_color.a = 0.18 / float(ghost_index)
                host.draw_circle(ghost_pos, 10.5 - float(ghost_index), ghost_color)

            # 各セルへ飛び込んだ瞬間だけ白い「ビシッ」を出す。
            if local_t < 0.34:
                var impact_t: float = 1.0 - clamp(local_t / 0.34, 0.0, 1.0)
                var dash_dir: Vector2 = (b - a).normalized()
                var slash_color: Color = C_CORE
                slash_color.a = 0.35 + 0.62 * impact_t
                var slash_glow: Color = C_GLOW
                slash_glow.a = 0.18 + 0.44 * impact_t
                host.draw_line(b - dash_dir * (17.0 + 8.0 * impact_t), b + dash_dir * 8.0, slash_glow, 9.0, true)
                host.draw_line(b - dash_dir * (15.0 + 6.0 * impact_t), b + dash_dir * 7.0, slash_color, 2.8, true)
                host.draw_arc(b, 8.0 + 5.0 * impact_t, 0.0, TAU, 24, slash_color, 1.5 + 1.5 * impact_t, true)

            var dash_body: Color = player_color.call()
            dash_body.a = 0.98
            host.draw_circle(current, 13.0, dash_body)
            host.draw_arc(current, 13.0, 0.0, TAU, 32, Color.WHITE, 2.2, true)

    elif kind == CardCatalog.LOOP:
        var progress: float = clamp(time / LOOP_DURATION, 0.0, 1.0)

        # 1) 閉じたPATHの周囲を、上側から時計回りに光が一周する。
        if progress < 0.62 and not cells.is_empty():
            var sweep: float = clamp(progress / 0.62, 0.0, 1.0)
            var center_sum := Vector2.ZERO
            for cell in cells:
                center_sum += cell_center.call(cell)
            var center: Vector2 = center_sum / float(cells.size())
            for cell in cells:
                var pos: Vector2 = cell_center.call(cell)
                var rel: Vector2 = pos - center
                var angle: float = atan2(rel.y, rel.x) + PI * 0.5
                while angle < 0.0:
                    angle += TAU
                while angle >= TAU:
                    angle -= TAU
                var phase: float = angle / TAU
                var delta: float = sweep - phase
                if delta < 0.0:
                    continue
                var tail: float = clamp(1.0 - delta / 0.22, 0.0, 1.0)
                var glow: Color = C_GLOW
                glow.a = 0.18 + 0.58 * tail
                var edge: Color = C_CORE
                edge.a = 0.35 + 0.62 * tail
                var r: Rect2 = cell_rect.call(cell).grow(-3.0)
                host.draw_rect(r, glow)
                host.draw_rect(r, edge, false, 2.0 + 2.0 * tail)
                if tail > 0.65:
                    host.draw_circle(pos, 4.0 + 3.0 * tail, edge)

        # 2) 一周し切った瞬間、内側全体を強く白青に放電させる。
        if progress >= 0.54:
            var burst_t: float = clamp((progress - 0.54) / 0.46, 0.0, 1.0)
            var burst_strength: float = sin(clamp(burst_t * 1.35, 0.0, 1.0) * PI)
            for cell in secondary_cells:
                var r: Rect2 = cell_rect.call(cell).grow(-2.0)
                var fill: Color = C_GLOW
                fill.a = 0.18 + 0.62 * burst_strength
                host.draw_rect(r, fill)
                var edge: Color = C_CORE
                edge.a = 0.40 + 0.58 * burst_strength
                host.draw_rect(r, edge, false, 2.0 + 2.5 * burst_strength)

        # 3) 最後に輪郭全体を一瞬だけ同時発光させ、閉回路の完成を強調する。
        if progress >= 0.74:
            var finish_t: float = clamp((progress - 0.74) / 0.26, 0.0, 1.0)
            var finish_alpha: float = 1.0 - finish_t
            for cell in cells:
                var edge: Color = C_CORE
                edge.a = 0.75 * finish_alpha
                host.draw_rect(cell_rect.call(cell).grow(-2.0), edge, false, 3.0)

