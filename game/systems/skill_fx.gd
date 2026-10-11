extends RefCounted

const CardCatalog = preload("res://systems/card_catalog.gd")

const ARC_DURATION := 0.22
const SURGE_DURATION := 0.34
const BOMB_DURATION := 0.36
const WARP_DURATION := 0.30
const DASH_MIN_DURATION := 0.22
const DASH_MAX_DURATION := 0.52
const DASH_BASE_DURATION := 0.11
const DASH_PER_CELL_DURATION := 0.055
const DASH_PLAYER_BLINK_TRAIL_DURATION := 0.085
const DASH_ELECTRIC_DELAY := 0.045
const DASH_CATCH_FLASH_DURATION := 0.075
const DASH_TRAIL_DURATION := 0.16
const LOOP_DURATION := 0.52
const CELL_SIZE := 38.0

const C_CORE := Color(0.92, 0.99, 1.0, 0.98)
const C_GLOW := Color(0.28, 0.88, 1.0, 0.62)
const C_TRAIL := Color(0.18, 0.52, 1.0, 0.48)

var active := false
var kind := ""
var time := 0.0
var cells: Array[Vector2i] = []
var secondary_cells: Array[Vector2i] = []
var distances: Dictionary = {}
var parents: Dictionary = {}
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
    parents.clear()
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

# Hit-reaction timing helpers. These use the exact same phase thresholds as draw(),
# so enemy feedback can start on the frame where the visible attack reaches it.
# They are called once when a skill is committed; there is no per-frame search.
func arc_hit_delay(path: Array[Vector2i], impacted_cells: Array[Vector2i]) -> float:
    if path.is_empty() or impacted_cells.is_empty():
        return 0.0
    var first_index := path.size()
    for cell in impacted_cells:
        var index := path.find(cell)
        if index >= 0:
            first_index = mini(first_index, index)
    if first_index >= path.size():
        return 0.0
    return ARC_DURATION * 0.70 * float(first_index + 1) / float(path.size())

func surge_hit_delay(impacted_cells: Array[Vector2i]) -> float:
    if impacted_cells.is_empty() or distances.is_empty():
        return 0.0
    var travel_start := 0.08
    var travel_span := 0.58
    var earliest := INF
    for cell in impacted_cells:
        if not distances.has(cell):
            continue
        var distance: int = int(distances[cell])
        var distance_ratio: float = float(distance) / float(maxi(1, max_distance))
        var progress_delay: float = travel_start + travel_span * distance_ratio
        earliest = minf(earliest, SURGE_DURATION * progress_delay)
    return 0.0 if is_inf(earliest) else earliest

func _bomb_arrival_progress(cell: Vector2i, bomb_origin: Vector2i) -> float:
    # 中心を起点に、上下左右、その少し後に斜めへ電流が届く。
    # 3x3の端が床外で欠けても、位置関係だけで同じタイミングを返せる。
    var offset: Vector2i = cell - bomb_origin
    var manhattan: int = absi(offset.x) + absi(offset.y)
    if manhattan <= 0:
        return 0.12
    if manhattan == 1:
        return 0.22
    return 0.29

func bomb_hit_delay(blast: Array[Vector2i], impacted_cells: Array[Vector2i], bomb_origin: Vector2i) -> float:
    if blast.is_empty() or impacted_cells.is_empty():
        return 0.0
    var earliest := INF
    for cell in impacted_cells:
        if not blast.has(cell):
            continue
        earliest = minf(earliest, BOMB_DURATION * _bomb_arrival_progress(cell, bomb_origin))
    return 0.0 if is_inf(earliest) else earliest

func loop_hit_delay() -> float:
    # Phase 3 (the full-area break) begins at normalized progress 0.56.
    return LOOP_DURATION * 0.56

func screen_shake_offset() -> Vector2:
    if not active or kind != CardCatalog.BOMB or BOMB_DURATION <= 0.0:
        return Vector2.ZERO
    var progress: float = clamp(time / BOMB_DURATION, 0.0, 1.0)
    # 各セル枠そのものが震えるのが主役。盤面全体は最後の一斉ブレイクだけ軽く揺らす。
    if progress < 0.56 or progress > 0.72:
        return Vector2.ZERO
    var local_t: float = clamp((progress - 0.56) / 0.16, 0.0, 1.0)
    var envelope: float = sin(local_t * PI)
    var amplitude: float = 1.45 * envelope
    var phase: float = local_t * 46.0
    return Vector2(sin(phase) * amplitude, cos(phase * 1.31) * amplitude * 0.72)

func start_arc(path: Array[Vector2i], start_origin: Vector2i) -> void:
    reset()
    active = true
    kind = CardCatalog.ARC
    origin = start_origin
    cells = path.duplicate()
    max_distance = maxi(0, path.size())

func start_surge(region: Dictionary, hit_cells: Array[Vector2i], start_origin: Vector2i) -> void:
    reset()
    active = true
    kind = CardCatalog.SURGE
    origin = start_origin
    secondary_cells = hit_cells.duplicate()

    # FLOOR LIGHTNINGは主人公を起点に、接続帯電PATHへ電流を流し込む。
    # 発動時に一度だけBFSし、各セルの主人公からの距離と分岐元を保存する。
    # draw中はこの結果を読むだけなので、毎フレーム経路探索は行わない。
    if region.is_empty() or not region.has(start_origin):
        return
    var dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]
    var frontier: Array[Vector2i] = [start_origin]
    distances[start_origin] = 0
    cells.append(start_origin)
    var read_index := 0
    while read_index < frontier.size():
        var current: Vector2i = frontier[read_index]
        read_index += 1
        var current_distance: int = int(distances[current])
        for d in dirs:
            var next: Vector2i = current + d
            if not region.has(next) or distances.has(next):
                continue
            var next_distance := current_distance + 1
            distances[next] = next_distance
            parents[next] = current
            max_distance = maxi(max_distance, next_distance)
            frontier.append(next)
            cells.append(next)

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

    # CIRCUIT BREAKは「外周から内側へ圧縮される」見た目にする。
    # 発動時に内側セルを外周からの距離レイヤーへ一度だけ分類し、
    # draw中はこの結果を読むだけにして毎フレーム探索を行わない。
    var boundary_set: Dictionary = {}
    for p in cells:
        boundary_set[p] = true
    var inside_set: Dictionary = {}
    for p in secondary_cells:
        inside_set[p] = true

    var touch_dirs: Array[Vector2i] = [
        Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
        Vector2i(-1, 0),                     Vector2i(1, 0),
        Vector2i(-1, 1),  Vector2i(0, 1),  Vector2i(1, 1),
    ]
    var spread_dirs: Array[Vector2i] = [
        Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN,
    ]
    var frontier: Array[Vector2i] = []
    for p in secondary_cells:
        for d in touch_dirs:
            if boundary_set.has(p + d):
                distances[p] = 0
                frontier.append(p)
                break

    var read_index := 0
    max_distance = 0
    while read_index < frontier.size():
        var current: Vector2i = frontier[read_index]
        read_index += 1
        var current_distance: int = int(distances[current])
        for d in spread_dirs:
            var next: Vector2i = current + d
            if not inside_set.has(next) or distances.has(next):
                continue
            var next_distance := current_distance + 1
            distances[next] = next_distance
            max_distance = maxi(max_distance, next_distance)
            frontier.append(next)

    # 極端な形状でも演出を欠落させないための保険。
    for p in secondary_cells:
        if not distances.has(p):
            distances[p] = 0

func _draw_arc_lightning_segment(host, a: Vector2, b: Vector2, segment_index: int, intensity: float) -> void:
    if intensity <= 0.0:
        return
    var delta: Vector2 = b - a
    if delta.length_squared() <= 0.001:
        return
    var normal := Vector2(-delta.y, delta.x).normalized()
    var points := PackedVector2Array()
    var subdivisions := 5
    for j in range(subdivisions + 1):
        var t: float = float(j) / float(subdivisions)
        var p: Vector2 = a.lerp(b, t)
        if j > 0 and j < subdivisions:
            # 毎フレーム完全ランダムにはせず、位置とtimeから決まる高速な揺れにする。
            # 低コストのまま「生きた電気」の細かな変化だけを出す。
            var seed: float = float((segment_index + 1) * 19 + j * 37)
            var wobble: float = sin(seed * 0.71 + time * 92.0) * 3.1
            wobble += sin(seed * 1.31 + time * 137.0) * 1.5
            p += normal * wobble * intensity
        points.append(p)

    var glow: Color = C_GLOW.lerp(C_TRAIL, 1.0 - intensity)
    glow.a = 0.18 + 0.48 * intensity
    var core: Color = C_CORE
    core.a = 0.16 + 0.80 * intensity
    host.draw_polyline(points, glow, 7.0, true)
    host.draw_polyline(points, core, 2.1, true)

func draw(host, cell_center: Callable, cell_rect: Callable, player_color: Callable, player_facing: Vector2i) -> void:
    if not active:
        return
    if kind == CardCatalog.ARC:
        var progress: float = clamp(time / ARC_DURATION, 0.0, 1.0)
        var cell_count: int = cells.size()
        var origin_center: Vector2 = cell_center.call(origin)

        # STRAIGHT BOLT: 長さに関係なく全体時間は固定。
        # 前半で電流がPATHを走り、後半でシアン→青の残光だけを短く残す。
        var travel_end := 0.70
        var travel_progress: float = clamp(progress / travel_end, 0.0, 1.0)
        var reached_count: int = clampi(int(ceil(travel_progress * float(maxi(1, cell_count)))), 0, cell_count)

        # 発火点。雷そのものではなく「床へ電流を流し込んだ」ことを見せる。
        if progress < 0.22:
            var origin_t: float = 1.0 - clamp(progress / 0.22, 0.0, 1.0)
            var origin_glow: Color = C_GLOW
            origin_glow.a = 0.24 + 0.46 * origin_t
            var origin_core: Color = C_CORE
            origin_core.a = 0.52 + 0.46 * origin_t
            host.draw_circle(origin_center, 10.0 + 5.0 * origin_t, origin_glow)
            host.draw_circle(origin_center, 4.0 + 2.0 * origin_t, origin_core)

        # 到達済みの帯電マスを白→シアン→青の順に発光させる。
        # 各セルの到達時刻をPATH長から正規化するため、長距離でも演出時間は伸びない。
        for i in range(reached_count):
            var cell: Vector2i = cells[i]
            var reach_progress: float = travel_end * float(i + 1) / float(maxi(1, cell_count))
            var age: float = maxf(0.0, progress - reach_progress)
            var flash_strength: float = 1.0 - clamp(age / 0.12, 0.0, 1.0)
            var trail_strength: float = 1.0 - clamp(age / 0.38, 0.0, 1.0)
            var r: Rect2 = cell_rect.call(cell).grow(-3.0)

            var fill: Color = C_TRAIL
            fill.a = 0.10 + 0.28 * trail_strength
            host.draw_rect(r, fill)

            var edge: Color = C_GLOW
            edge.a = 0.22 + 0.48 * trail_strength
            host.draw_rect(r, edge, false, 2.0 + 1.5 * flash_strength, true)

            if flash_strength > 0.0:
                var white_fill: Color = C_CORE
                white_fill.a = 0.18 + 0.56 * flash_strength
                host.draw_rect(r.grow(-3.0), white_fill)

        # マス間は細い白芯＋シアン発光のギザギザ電撃でつなぐ。
        # 到達直後ほど白く、後ろへ行くほど青い残光になる。
        var prev: Vector2 = origin_center
        for i in range(reached_count):
            var next_center: Vector2 = cell_center.call(cells[i])
            var reach_progress: float = travel_end * float(i + 1) / float(maxi(1, cell_count))
            var age: float = maxf(0.0, progress - reach_progress)
            var intensity: float = 1.0 - clamp(age / 0.34, 0.0, 1.0)
            _draw_arc_lightning_segment(host, prev, next_center, i, intensity)
            prev = next_center

        # 電流の先頭だけ小さく強く光らせる。巨大な円にはせず盤面を隠さない。
        if reached_count > 0:
            var head_index: int = reached_count - 1
            var head: Vector2 = cell_center.call(cells[head_index])
            var head_reach: float = travel_end * float(head_index + 1) / float(maxi(1, cell_count))
            var head_age: float = maxf(0.0, progress - head_reach)
            var head_strength: float = 1.0 - clamp(head_age / 0.13, 0.0, 1.0)
            if head_strength > 0.0:
                var head_glow: Color = C_GLOW
                head_glow.a = 0.35 + 0.45 * head_strength
                var head_core: Color = C_CORE
                head_core.a = 0.62 + 0.36 * head_strength
                host.draw_circle(head, 7.0 + 3.0 * head_strength, head_glow)
                host.draw_circle(head, 3.0 + 2.0 * head_strength, head_core)
    elif kind == CardCatalog.SURGE:
        var progress: float = clamp(time / SURGE_DURATION, 0.0, 1.0)
        var origin_center: Vector2 = cell_center.call(origin)
        var travel_start := 0.08
        var travel_span := 0.58
        var trail_span := 0.34

        # FLOOR LIGHTNING Phase 1: 主人公自身を発火点として一瞬白く発光させる。
        # ストレートボルトのような一方向射出ではなく、ここから電力網全体へ枝分かれする。
        if progress < 0.24:
            var origin_t: float = clamp(progress / 0.24, 0.0, 1.0)
            var origin_strength: float = sin(origin_t * PI)
            var origin_glow: Color = C_GLOW
            origin_glow.a = 0.24 + 0.52 * origin_strength
            var origin_core: Color = C_CORE
            origin_core.a = 0.48 + 0.48 * origin_strength
            host.draw_circle(origin_center, 10.0 + 8.0 * origin_strength, origin_glow)
            host.draw_circle(origin_center, 4.0 + 3.0 * origin_strength, origin_core)
            for i in range(4):
                var dir := Vector2.RIGHT.rotated(float(i) * PI * 0.5)
                var side := Vector2(-dir.y, dir.x)
                var a: Vector2 = origin_center + dir * 6.0
                var b: Vector2 = origin_center + dir * (16.0 + 5.0 * origin_strength) + side * sin(time * 120.0 + float(i) * 1.7) * 2.0
                host.draw_line(a, b, origin_glow, 5.0, true)
                host.draw_line(a, b, origin_core, 1.6, true)

        # Phase 2: BFSで保存した分岐元から子セルへ、主人公から外側へ向かって高速伝播。
        # 到達済みセルは白→シアン→青の残光へ落ち、PATHの流れそのものを見せる。
        for i in range(cells.size()):
            var cell: Vector2i = cells[i]
            if not distances.has(cell):
                continue
            var distance: int = int(distances[cell])
            var distance_ratio: float = float(distance) / float(maxi(1, max_distance))
            var arrival_progress: float = travel_start + travel_span * distance_ratio
            if progress < arrival_progress:
                continue
            var age: float = progress - arrival_progress
            var trail_strength: float = 1.0 - clamp(age / trail_span, 0.0, 1.0)
            if trail_strength <= 0.0:
                continue

            var r: Rect2 = cell_rect.call(cell).grow(-4.0)
            var tile_fill: Color = C_GLOW.lerp(C_TRAIL, 1.0 - trail_strength)
            tile_fill.a = 0.10 + 0.34 * trail_strength
            host.draw_rect(r, tile_fill)
            var tile_edge: Color = C_CORE.lerp(C_TRAIL, 1.0 - trail_strength)
            tile_edge.a = 0.14 + 0.62 * trail_strength
            host.draw_rect(r, tile_edge, false, 1.4 + 1.8 * trail_strength, true)

            if cell != origin and parents.has(cell):
                var parent: Vector2i = Vector2i(parents[cell])
                var parent_center: Vector2 = cell_center.call(parent)
                var current_center: Vector2 = cell_center.call(cell)
                _draw_arc_lightning_segment(host, parent_center, current_center, 700 + i, trail_strength)

        # Phase 3: 電流が敵占有セルへ到達した瞬間、床から上へ青白い放電を噴き上げる。
        # 大型敵が複数セルを踏んでいれば、そのセル数だけ独立した柱が立つ。
        for i in range(secondary_cells.size()):
            var cell: Vector2i = secondary_cells[i]
            if not distances.has(cell):
                continue
            var distance: int = int(distances[cell])
            var distance_ratio: float = float(distance) / float(maxi(1, max_distance))
            var arrival_progress: float = travel_start + travel_span * distance_ratio
            var local_t: float = (progress - arrival_progress) / 0.30
            if local_t < 0.0 or local_t > 1.0:
                continue
            var discharge_strength: float = sin(clamp(local_t, 0.0, 1.0) * PI)
            var center: Vector2 = cell_center.call(cell)
            var r: Rect2 = cell_rect.call(cell).grow(-2.0)

            var hit_fill: Color = C_GLOW
            hit_fill.a = 0.20 + 0.50 * discharge_strength
            host.draw_rect(r, hit_fill)
            var hit_edge: Color = C_CORE
            hit_edge.a = 0.38 + 0.60 * discharge_strength
            host.draw_rect(r, hit_edge, false, 2.2 + 2.0 * discharge_strength, true)

            # 下端を床セル中心付近に固定し、上側へ広がる3本の裂けた電撃で「床から噴く」を強調。
            var root: Vector2 = center + Vector2(0.0, CELL_SIZE * 0.26)
            for branch in range(3):
                var top_offset_x: float = float(branch - 1) * (8.0 + 5.0 * discharge_strength)
                var top: Vector2 = center + Vector2(top_offset_x, -CELL_SIZE * (0.72 + 0.12 * discharge_strength))
                var points := PackedVector2Array()
                var subdivisions := 5
                for j in range(subdivisions + 1):
                    var jt: float = float(j) / float(subdivisions)
                    var p: Vector2 = root.lerp(top, jt)
                    if j > 0 and j < subdivisions:
                        var seed: float = float((i + 1) * 29 + branch * 47 + j * 31)
                        var wobble: float = sin(seed * 0.79 + time * 111.0) * 4.0
                        wobble += sin(seed * 1.41 + time * 157.0) * 1.7
                        p.x += wobble * discharge_strength
                    points.append(p)
                var bolt_glow: Color = C_GLOW
                bolt_glow.a = (0.16 + 0.50 * discharge_strength) * (1.0 if branch == 1 else 0.74)
                var bolt_core: Color = C_CORE
                bolt_core.a = (0.28 + 0.66 * discharge_strength) * (1.0 if branch == 1 else 0.82)
                host.draw_polyline(points, bolt_glow, 7.0 if branch == 1 else 5.0, true)
                host.draw_polyline(points, bolt_core, 2.2 if branch == 1 else 1.5, true)

            # 根元だけ短いリングを出し、空からの落雷ではなく床由来であることを補強する。
            host.draw_arc(root, 5.0 + 8.0 * local_t, 0.0, TAU, 24, hit_edge, 1.6 + 1.5 * discharge_strength, true)
    elif kind == CardCatalog.BOMB:
        var progress: float = clamp(time / BOMB_DURATION, 0.0, 1.0)
        var origin_center: Vector2 = cell_center.call(origin)

        # THUNDER BOMBは「爆発」ではなく、爆心から3x3の各セルへ高電圧を送り込み、
        # 到達セルそのものを大きな電気フレームでロックして震わせる技として見せる。

        # Phase 1: 爆心を短く白く飽和させ、ここが電流の発生源だと先に示す。
        if progress < 0.28:
            var core_t: float = clamp(progress / 0.28, 0.0, 1.0)
            var core_peak: float = sin(core_t * PI)
            var origin_rect: Rect2 = cell_rect.call(origin).grow(-2.0)
            var origin_fill: Color = C_CORE
            origin_fill.a = 0.18 + 0.70 * core_peak
            host.draw_rect(origin_rect, origin_fill)
            var core_glow: Color = C_GLOW
            core_glow.a = 0.24 + 0.56 * core_peak
            host.draw_circle(origin_center, 8.0 + 10.0 * core_peak, core_glow)
            var core_white: Color = C_CORE
            core_white.a = 0.52 + 0.44 * core_peak
            host.draw_circle(origin_center, 3.0 + 5.0 * core_peak, core_white)

        # Phase 2/3: 中心→上下左右→斜めの順で電流が走り、到達したセルに太い枠が出現。
        # 枠は短時間だけ2〜3px細かく震え、マスそのものへ高電圧が掛かった印象を出す。
        for i in range(cells.size()):
            var cell: Vector2i = cells[i]
            var arrival: float = _bomb_arrival_progress(cell, origin)
            if progress < arrival:
                continue

            var target_center: Vector2 = cell_center.call(cell)
            if cell != origin:
                var travel_span: float = 0.11 if absi(cell.x - origin.x) + absi(cell.y - origin.y) == 1 else 0.15
                var travel_t: float = clamp((progress - (arrival - travel_span)) / travel_span, 0.0, 1.0)
                if travel_t < 1.0:
                    var current_end: Vector2 = origin_center.lerp(target_center, travel_t)
                    _draw_arc_lightning_segment(host, origin_center, current_end, 400 + i, 0.50 + 0.50 * sin(travel_t * PI * 0.5))
                else:
                    # 到達後もごく短く電気の線を残し、中心とのつながりを見せる。
                    var wire_age: float = progress - arrival
                    var wire_strength: float = 1.0 - clamp(wire_age / 0.17, 0.0, 1.0)
                    if wire_strength > 0.0:
                        _draw_arc_lightning_segment(host, origin_center, target_center, 400 + i, wire_strength)

            var frame_age: float = progress - arrival
            if frame_age > 0.42:
                continue
            var appear: float = clamp(frame_age / 0.055, 0.0, 1.0)
            var fade: float = 1.0 - clamp((frame_age - 0.28) / 0.14, 0.0, 1.0)
            var frame_strength: float = appear * fade
            if frame_strength <= 0.0:
                continue

            # セルごとに位相を変えた固定波形で振動。乱数NodeやParticleは使わない。
            var shake_env: float = 1.0 - clamp(frame_age / 0.20, 0.0, 1.0)
            var shake_x: float = sin(time * 186.0 + float(i) * 2.31) * 2.8 * shake_env
            var shake_y: float = sin(time * 229.0 + float(i) * 1.47) * 2.0 * shake_env
            var r: Rect2 = cell_rect.call(cell).grow(-1.5)
            r.position += Vector2(shake_x, shake_y)

            var frame_glow: Color = C_GLOW
            frame_glow.a = 0.22 + 0.48 * frame_strength
            host.draw_rect(r.grow(1.5), frame_glow, false, 7.0 * frame_strength, true)
            var frame_core: Color = C_CORE
            frame_core.a = 0.34 + 0.64 * frame_strength
            host.draw_rect(r, frame_core, false, 2.8 + 2.7 * frame_strength, true)

            # 枠の内側も薄く明滅させ、線だけのUI枠ではなくセルそのものが帯電しているようにする。
            var frame_fill: Color = C_GLOW
            frame_fill.a = 0.06 + 0.17 * frame_strength
            host.draw_rect(r.grow(-4.0), frame_fill)

        # Phase 4: 9マスのロックが揃った瞬間、全枠を同時に一度だけ白くブレイクさせる。
        if progress >= 0.56 and progress < 0.74:
            var break_t: float = clamp((progress - 0.56) / 0.18, 0.0, 1.0)
            var break_strength: float = sin(break_t * PI)
            for cell in cells:
                var r: Rect2 = cell_rect.call(cell).grow(-0.5)
                var break_glow: Color = C_GLOW
                break_glow.a = 0.20 + 0.48 * break_strength
                host.draw_rect(r.grow(2.0), break_glow, false, 8.0 * break_strength, true)
                var break_core: Color = C_CORE
                break_core.a = 0.26 + 0.70 * break_strength
                host.draw_rect(r, break_core, false, 2.5 + 3.2 * break_strength, true)

        # Phase 5: 白い枠が消えた後は青い残光だけ残し、3x3が帯電した結果へ自然につなぐ。
        if progress >= 0.68:
            var trail_t: float = clamp((progress - 0.68) / 0.32, 0.0, 1.0)
            var trail_alpha: float = 1.0 - trail_t
            for cell in cells:
                var trail: Color = C_TRAIL
                trail.a = 0.24 * trail_alpha
                host.draw_rect(cell_rect.call(cell).grow(-3.0), trail)

    elif kind == CardCatalog.WARP:
        var progress: float = clamp(time / WARP_DURATION, 0.0, 1.0)
        var origin_center: Vector2 = cell_center.call(origin)
        var target_center: Vector2 = cell_center.call(target)

        # BOLT WARPは地点間を線で結ばない。
        # 「元位置で電気へ分解 -> 一瞬消失 -> 着地点で再構成」の3段階だけを描き、
        # 中間PATHが必要な移動に見えないようにする。

        # Phase 1: 出発地点で主人公を青白い電気へ圧縮して消す。
        if progress < 0.38:
            var vanish_t: float = clamp(progress / 0.38, 0.0, 1.0)
            var vanish_ease: float = 1.0 - pow(1.0 - vanish_t, 2.4)
            var body_radius: float = lerpf(13.0, 1.5, vanish_ease)
            var body_color: Color = player_color.call()
            body_color.a = 1.0 - vanish_t * 0.72
            host.draw_circle(origin_center, body_radius, body_color)

            var outline: Color = C_CORE
            outline.a = 0.44 + 0.52 * (1.0 - vanish_t)
            host.draw_arc(origin_center, body_radius + 0.8, 0.0, TAU, 28, outline, 2.0, true)

            # 8本の短い電気片が外側から中心へ収束する。
            # Node/Particleは増やさず、角度固定の短線だけで分解感を出す。
            var spark_strength: float = sin(vanish_t * PI)
            for i in range(8):
                var angle: float = TAU * float(i) / 8.0 + 0.18 * sin(float(i) * 1.7 + time * 36.0)
                var dir := Vector2(cos(angle), sin(angle))
                var radius: float = lerpf(27.0, 6.0, vanish_ease)
                var spark_pos: Vector2 = origin_center + dir * radius
                var tangent := Vector2(-dir.y, dir.x)
                var wobble: float = sin(float(i) * 2.13 + time * 92.0) * 2.4
                spark_pos += tangent * wobble * spark_strength

                var spark_glow: Color = C_GLOW
                spark_glow.a = 0.12 + 0.54 * spark_strength
                var spark_core: Color = C_CORE
                spark_core.a = 0.18 + 0.72 * spark_strength
                var inward: Vector2 = spark_pos.lerp(origin_center, 0.34 + 0.42 * vanish_t)
                host.draw_line(spark_pos, inward, spark_glow, 6.0, true)
                host.draw_line(spark_pos, inward, spark_core, 1.8, true)

            # 消失直前だけ中心を白く焼き、SEの最初のスナップと合わせる。
            if vanish_t > 0.68:
                var flash_t: float = clamp((vanish_t - 0.68) / 0.32, 0.0, 1.0)
                var flash: Color = C_CORE
                flash.a = 0.30 + 0.64 * sin(flash_t * PI)
                host.draw_circle(origin_center, 3.0 + 7.0 * flash_t, flash)

        # Phase 2: ごく短い消失区間。出発地点には青い残光だけを置く。
        if progress >= 0.30 and progress < 0.52:
            var after_t: float = clamp((progress - 0.30) / 0.22, 0.0, 1.0)
            var after: Color = C_TRAIL
            after.a = 0.28 * (1.0 - after_t)
            host.draw_circle(origin_center, lerpf(10.0, 18.0, after_t), after)

        # Phase 3: 着地点の一点から逆再生のように主人公を再構成する。
        if progress >= 0.50:
            var appear_t: float = clamp((progress - 0.50) / 0.50, 0.0, 1.0)
            var appear_ease: float = 1.0 - pow(1.0 - appear_t, 2.1)

            # 最初に小さな白い種を出し、そこへ周囲の電気片が集まる。
            var seed_strength: float = 1.0 - clamp((appear_t - 0.34) / 0.34, 0.0, 1.0)
            if seed_strength > 0.0:
                var seed_glow: Color = C_GLOW
                seed_glow.a = 0.24 + 0.50 * seed_strength
                var seed_core: Color = C_CORE
                seed_core.a = 0.48 + 0.48 * seed_strength
                host.draw_circle(target_center, 7.0 + 4.0 * seed_strength, seed_glow)
                host.draw_circle(target_center, 2.5 + 2.5 * seed_strength, seed_core)

            var spark_strength: float = sin(appear_t * PI)
            for i in range(8):
                var angle: float = TAU * float(i) / 8.0 + 0.16 * sin(float(i) * 1.43 + time * 41.0)
                var dir := Vector2(cos(angle), sin(angle))
                # 再構成では外側の電気片が中心へ寄り、後半ほど短くなる。
                var outer_radius: float = lerpf(28.0, 11.0, appear_ease)
                var outer: Vector2 = target_center + dir * outer_radius
                var inner: Vector2 = target_center + dir * lerpf(11.0, 5.0, appear_ease)
                var tangent := Vector2(-dir.y, dir.x)
                var wobble: float = sin(float(i) * 2.47 + time * 97.0) * 2.2
                outer += tangent * wobble * spark_strength

                var spark_glow: Color = C_GLOW
                spark_glow.a = 0.10 + 0.48 * spark_strength
                var spark_core: Color = C_CORE
                spark_core.a = 0.18 + 0.66 * spark_strength
                host.draw_line(outer, inner, spark_glow, 6.0, true)
                host.draw_line(outer, inner, spark_core, 1.8, true)

            var appear_radius: float = lerpf(2.5, 13.0, appear_ease)
            var body_color: Color = player_color.call()
            body_color.a = 0.34 + 0.66 * appear_ease
            host.draw_circle(target_center, appear_radius, body_color)
            var outline: Color = Color.WHITE
            outline.a = 0.42 + 0.58 * appear_ease
            host.draw_arc(target_center, appear_radius, 0.0, TAU, 32, outline, 2.0, true)

            # 再構成がほぼ終わったら向き線も復帰させ、通常表示へ自然につなぐ。
            if player_facing != Vector2i.ZERO and appear_t > 0.74:
                var player_dir := Vector2(player_facing.x, player_facing.y)
                var dir_alpha: float = clamp((appear_t - 0.74) / 0.26, 0.0, 1.0)
                var dir_color: Color = Color.WHITE
                dir_color.a = dir_alpha
                host.draw_line(target_center + player_dir * 2.0, target_center + player_dir * 16.0, dir_color, 4.0, true)

    elif kind == CardCatalog.DASH:
        var duration: float = _duration()
        var points: Array[Vector2i] = []
        points.append(origin)
        for cell in cells:
            points.append(cell)
        if points.size() >= 2:
            var step_count: int = points.size() - 1

            # CHAIN DASH: 主人公が先にゴールへ瞬間移動し、その後を電流が追走する。
            # ボルトワープと違い、消失/再構成ではなくPATH上にごく短い残像を残して
            # 「この経路を一瞬で駆け抜けた」ことを示す。
            var target_index: int = points.find(target)
            if target_index < 0:
                target_index = step_count
            var player_step_count: int = maxi(0, target_index)
            var current: Vector2 = cell_center.call(target)

            # 発動直後だけ、通過したPATH上に薄い主人公残像を並べる。
            # 長距離でもNode/Particleは増やさず、最大3個だけ描画する。
            if time < DASH_PLAYER_BLINK_TRAIL_DURATION and player_step_count > 0:
                var blink_t: float = clampf(time / DASH_PLAYER_BLINK_TRAIL_DURATION, 0.0, 1.0)
                var ghost_alpha: float = (1.0 - blink_t) * 0.34
                var ghost_count: int = mini(3, player_step_count)
                for ghost_slot in range(ghost_count):
                    var ratio: float = float(ghost_slot + 1) / float(ghost_count + 1)
                    var path_index: int = clampi(int(round(ratio * float(player_step_count))), 0, player_step_count - 1)
                    var ghost_pos: Vector2 = cell_center.call(points[path_index])
                    var ghost_color: Color = C_TRAIL
                    ghost_color.a = ghost_alpha * (1.0 - float(ghost_slot) * 0.16)
                    host.draw_circle(ghost_pos, 10.0 - float(ghost_slot) * 1.4, ghost_color)
                    var ghost_edge: Color = C_CORE
                    ghost_edge.a = ghost_color.a * 0.72
                    host.draw_arc(ghost_pos, 10.0 - float(ghost_slot) * 1.4, 0.0, TAU, 20, ghost_edge, 1.2, true)

            # 電流は主人公より45ms遅れて発生し、選択した攻撃PATHを最後まで追走する。
            # 生き残った敵のため主人公が手前で止まる場合も、攻撃判定を示す電流はPATH末端まで走る。
            var electric_finish_time: float = maxf(DASH_ELECTRIC_DELAY + 0.10, duration - 0.045)
            var electric_travel_time: float = maxf(0.08, electric_finish_time - DASH_ELECTRIC_DELAY)
            var electric_progress: float = clampf((time - DASH_ELECTRIC_DELAY) / electric_travel_time, 0.0, 1.0) if time >= DASH_ELECTRIC_DELAY else 0.0
            var electric_units: float = electric_progress * float(step_count)

            # 電流が到達したセルは白→シアン→青へ短く残光する。
            for cell_index in range(1, points.size()):
                var arrival_time: float = DASH_ELECTRIC_DELAY + (float(cell_index) / float(step_count)) * electric_travel_time
                if time < arrival_time:
                    continue
                var age: float = time - arrival_time
                if age > DASH_TRAIL_DURATION:
                    continue
                var trail_t: float = clampf(age / DASH_TRAIL_DURATION, 0.0, 1.0)
                var trail_strength: float = 1.0 - trail_t
                var trail_rect: Rect2 = cell_rect.call(points[cell_index]).grow(-4.0)
                var trail_fill: Color = C_GLOW.lerp(C_TRAIL, trail_t)
                trail_fill.a = 0.12 + 0.34 * trail_strength
                var trail_edge: Color = C_CORE.lerp(C_TRAIL, trail_t)
                trail_edge.a = 0.20 + 0.64 * trail_strength
                host.draw_rect(trail_rect, trail_fill)
                host.draw_rect(trail_rect, trail_edge, false, 1.4 + 1.8 * trail_strength, true)

            # 白い細芯＋シアン発光のギザギザ電流を、遅れて進む先頭まで描く。
            if time >= DASH_ELECTRIC_DELAY:
                for i in range(step_count):
                    var segment_reach: float = clampf(electric_units - float(i), 0.0, 1.0)
                    if segment_reach <= 0.0:
                        continue
                    var segment_complete_time: float = DASH_ELECTRIC_DELAY + (float(i + 1) / float(step_count)) * electric_travel_time
                    var segment_age: float = maxf(0.0, time - segment_complete_time)
                    if segment_reach >= 1.0 and segment_age > DASH_TRAIL_DURATION:
                        continue
                    var ta: Vector2 = cell_center.call(points[i])
                    var tb_full: Vector2 = cell_center.call(points[i + 1])
                    var tb: Vector2 = ta.lerp(tb_full, segment_reach)
                    var intensity: float = 1.0
                    if segment_reach >= 1.0:
                        intensity = clampf(1.0 - segment_age / DASH_TRAIL_DURATION, 0.18, 1.0)
                    _draw_arc_lightning_segment(host, ta, tb, 200 + i, intensity)

                # 電流の先頭だけ強い白芯と短い火花を出す。
                var electric_seg: int = mini(int(floor(electric_units)), step_count - 1)
                var electric_local: float = clampf(electric_units - float(electric_seg), 0.0, 1.0)
                if electric_progress >= 1.0:
                    electric_seg = step_count - 1
                    electric_local = 1.0
                var electric_a: Vector2 = cell_center.call(points[electric_seg])
                var electric_b: Vector2 = cell_center.call(points[electric_seg + 1])
                var electric_head: Vector2 = electric_a.lerp(electric_b, electric_local)
                var head_strength: float = 1.0 if electric_progress < 1.0 else clampf((duration - time) / 0.045, 0.0, 1.0)
                if head_strength > 0.0:
                    var head_glow: Color = C_GLOW
                    head_glow.a = 0.30 + 0.44 * head_strength
                    var head_core: Color = C_CORE
                    head_core.a = 0.55 + 0.43 * head_strength
                    host.draw_circle(electric_head, 8.0 + 3.0 * head_strength, head_glow)
                    host.draw_circle(electric_head, 3.0 + 2.0 * head_strength, head_core)
                    for ray in range(4):
                        var angle: float = TAU * float(ray) / 4.0 + time * 23.0
                        var dir := Vector2(cos(angle), sin(angle))
                        host.draw_line(electric_head + dir * 4.0, electric_head + dir * (10.0 + 4.0 * head_strength), head_core, 1.6, true)

            # 電流が主人公の停止セルへ追いついた瞬間だけ、小さな白いキャッチフラッシュを出す。
            # PATH末端が敵でtargetが手前の場合でも、その停止セルで一度だけ追いついた感触を作る。
            if player_step_count > 0:
                var catch_time: float = DASH_ELECTRIC_DELAY + (float(player_step_count) / float(step_count)) * electric_travel_time
                var catch_age: float = time - catch_time
                if catch_age >= 0.0 and catch_age < DASH_CATCH_FLASH_DURATION:
                    var catch_t: float = clampf(catch_age / DASH_CATCH_FLASH_DURATION, 0.0, 1.0)
                    var catch_strength: float = 1.0 - catch_t
                    var catch_glow: Color = C_GLOW
                    catch_glow.a = 0.18 + 0.52 * catch_strength
                    var catch_core: Color = C_CORE
                    catch_core.a = 0.26 + 0.70 * catch_strength
                    host.draw_circle(current, 18.0 + 5.0 * catch_t, catch_glow)
                    host.draw_arc(current, 14.0 + 9.0 * catch_t, 0.0, TAU, 28, catch_core, 2.0 + 1.4 * catch_strength, true)

            # 主人公本体は演出開始時点からゴール側にいる。
            # これにより「電流に引っ張られる」のではなく、主人公が電流より速く駆け抜けた印象にする。
            var dash_body: Color = player_color.call()
            dash_body.a = 0.98
            host.draw_circle(current, 13.0, dash_body)
            host.draw_arc(current, 13.0, 0.0, TAU, 32, Color.WHITE, 2.2, true)
            if player_facing != Vector2i.ZERO:
                var player_dir := Vector2(player_facing.x, player_facing.y)
                host.draw_line(current + player_dir * 2.0, current + player_dir * 16.0, Color.WHITE, 4.0, true)

    elif kind == CardCatalog.LOOP:
        var progress: float = clamp(time / LOOP_DURATION, 0.0, 1.0)

        # CIRCUIT BREAK:
        # 「電流が一周する」見せ方をやめ、閉路そのものがロックされ、
        # 外周から内側へ電場が圧縮されたあと領域全体がブレイクする構成にする。
        # THUNDER BOMBの「中心→外」と逆向きなので、6スキルの中でも役割が被らない。

        # Phase 1: 閉路ロック。輪郭全体を同時に白く立ち上げる。
        # 円周ワイプではなく同時発光なので、不規則な閉路でも形状をそのまま読める。
        var lock_strength := 0.0
        if progress < 0.22:
            var lock_t: float = clamp(progress / 0.22, 0.0, 1.0)
            lock_strength = sin(lock_t * PI)
        var boundary_hold: float = 1.0 - clamp(progress / 0.86, 0.0, 1.0)
        for cell in cells:
            var r: Rect2 = cell_rect.call(cell).grow(-3.0)
            var boundary_fill: Color = C_GLOW
            boundary_fill.a = 0.08 + 0.30 * lock_strength + 0.08 * boundary_hold
            host.draw_rect(r, boundary_fill)
            var boundary_edge: Color = C_CORE.lerp(C_GLOW, 0.36)
            boundary_edge.a = 0.18 + 0.74 * lock_strength + 0.18 * boundary_hold
            host.draw_rect(r, boundary_edge, false, 1.7 + 2.4 * lock_strength, true)

        # Phase 2: 外周に近いセルから中心側へ圧縮波を送る。
        # start_loop()で確定した距離レイヤーを使うため、毎フレーム探索はしない。
        var compress_start := 0.12
        var compress_end := 0.60
        var max_layer: int = maxi(0, max_distance)
        for cell in secondary_cells:
            var layer: int = int(distances.get(cell, 0))
            var layer_ratio := 0.0
            if max_layer > 0:
                layer_ratio = float(layer) / float(max_layer)
            var arrival: float = lerpf(compress_start, compress_end, layer_ratio)
            if progress < arrival:
                continue
            var age: float = progress - arrival
            var flash_strength: float = 1.0 - clamp(age / 0.12, 0.0, 1.0)
            var trail_strength: float = 1.0 - clamp(age / 0.48, 0.0, 1.0)
            var r: Rect2 = cell_rect.call(cell).grow(-3.0)

            var compress_fill: Color = C_TRAIL.lerp(C_GLOW, flash_strength)
            compress_fill.a = 0.10 + 0.34 * trail_strength + 0.20 * flash_strength
            host.draw_rect(r, compress_fill)

            var compress_edge: Color = C_GLOW.lerp(C_CORE, flash_strength)
            compress_edge.a = 0.18 + 0.46 * trail_strength + 0.30 * flash_strength
            host.draw_rect(r, compress_edge, false, 1.4 + 1.8 * flash_strength, true)

            # 圧縮波の先端だけ、セル中央を短く白く飽和させる。
            if flash_strength > 0.0:
                var core: Color = C_CORE
                core.a = 0.10 + 0.52 * flash_strength
                host.draw_rect(r.grow(-4.0), core)

        # Phase 3: 圧縮完了と同時に領域全体を一度だけブレイク。
        # 敵ごとの落雷にはせず、「囲んだ領域そのものが武器」という見え方を優先する。
        if progress >= 0.56 and progress < 0.82:
            var break_t: float = clamp((progress - 0.56) / 0.26, 0.0, 1.0)
            var break_strength: float = sin(break_t * PI)
            for cell in secondary_cells:
                var r: Rect2 = cell_rect.call(cell).grow(-2.0)
                var break_fill: Color = C_GLOW
                break_fill.a = 0.18 + 0.58 * break_strength
                host.draw_rect(r, break_fill)
                var break_core: Color = C_CORE
                break_core.a = 0.10 + 0.58 * break_strength
                host.draw_rect(r.grow(-4.0), break_core)

                # 全セルへ粒子を出さず、規則的に間引いた短い電撃だけ重ねる。
                # 追加Nodeなしで「面が破裂した」質感を出す。
                if break_strength > 0.22 and posmod(cell.x * 17 + cell.y * 29, 3) == 0:
                    var center: Vector2 = cell_center.call(cell)
                    var phase: float = float(cell.x * 11 + cell.y * 7) * 0.37
                    var dir := Vector2(cos(phase), sin(phase))
                    var tangent := Vector2(-dir.y, dir.x)
                    var spark_points := PackedVector2Array([
                        center - dir * 10.0,
                        center + tangent * (3.0 + 2.0 * sin(time * 91.0 + phase)),
                        center + dir * 10.0,
                    ])
                    var spark_glow: Color = C_GLOW
                    spark_glow.a = 0.24 + 0.46 * break_strength
                    var spark_core: Color = C_CORE
                    spark_core.a = 0.38 + 0.58 * break_strength
                    host.draw_polyline(spark_points, spark_glow, 5.0, true)
                    host.draw_polyline(spark_points, spark_core, 1.5, true)

            # ブレイク瞬間だけ輪郭も白く飽和し、内側と外周を一つの回路として見せる。
            for cell in cells:
                var break_edge: Color = C_CORE
                break_edge.a = 0.26 + 0.70 * break_strength
                host.draw_rect(cell_rect.call(cell).grow(-2.0), break_edge, false, 2.4 + 2.2 * break_strength, true)

        # Phase 4: 青い残光だけを薄く残し、すでに帯電済みになった通常床表示へ接続する。
        if progress >= 0.74:
            var residue_t: float = clamp((progress - 0.74) / 0.26, 0.0, 1.0)
            var residue_strength: float = 1.0 - residue_t
            for cell in secondary_cells:
                var residue: Color = C_TRAIL
                residue.a = 0.22 * residue_strength
                host.draw_rect(cell_rect.call(cell).grow(-3.0), residue)
            for cell in cells:
                var residue_edge: Color = C_TRAIL
                residue_edge.a = 0.34 * residue_strength
                host.draw_rect(cell_rect.call(cell).grow(-3.0), residue_edge, false, 2.0, true)

