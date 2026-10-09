extends RefCounted

# VOLT PATH board renderer.
# Draws floor, telegraphs, aiming overlays, enemies and player onto the main Node2D.
# Owns no Node and runs no _process(); it is called only from main.gd::_draw().

var h = null

func setup(host) -> void:
    h = host

func draw_board() -> void:
    if h.current_floor == h.TOTAL_FLOORS and not h.run_clear:
        _draw_boss_body()

    for y in range(h.GRID_H):
        for x in range(h.GRID_W):
            var p := Vector2i(x, y)
            var r: Rect2 = h._cell_rect(p)
            if h.walls.has(p):
                h.draw_rect(r, h.C_WALL)
                h.draw_rect(r, h.C_WALL_EDGE, false, 1.0)
            else:
                h.draw_rect(r, h.C_FLOOR)
                h.draw_rect(r, h.C_FLOOR_EDGE, false, 1.0)
                if h.charged.has(p):
                    var inner: Rect2 = r.grow(-5.0)
                    if h.full_charge_hazard_active:
                        # 全面帯電中は盤面全体を同位相で赤/青へ交互点滅させる。
                        # 常駐Nodeは増やさず、既存の20FPS再描画だけで表現する。
                        h.draw_rect(inner, h._full_charge_flash_fill_color())
                        h.draw_rect(inner, h._full_charge_flash_edge_color(), false, 3.0)
                    else:
                        h.draw_rect(inner, h.C_CHARGED)
                        h.draw_rect(inner, h.C_CHARGED_INNER, false, 2.0)

func draw_telegraphs() -> void:
    # 敵の次の攻撃位置。次の敵ターンで発動するものは赤白の枠点滅で強調する。
    for e in h.enemies:
        if not bool(e["telegraph_active"]):
            continue
        var enemy_type: String = str(e.get("type", "chaser"))
        var imminent: bool = h._enemy_telegraph_is_imminent(e)
        var flash_edge: Color = h._telegraph_flash_edge_color() if imminent else h.C_TELEGRAPH_EDGE
        var border_width: float = 4.0 if imminent else 2.0
        if enemy_type == "boss_leg":
            var boss_target: Vector2i = Vector2i(e.get("telegraph_target", e["pos"]))
            for p in h._boss_leg_cells(boss_target):
                var bsr: Rect2 = h._cell_rect(p).grow(-3.0)
                h.draw_rect(bsr, h.C_TELEGRAPH)
                h.draw_rect(bsr, flash_edge, false, border_width)
        elif enemy_type == "tank":
            var tank_pos: Vector2i = e["pos"]
            var tank_dir: Vector2i = Vector2i(e.get("tank_dir", Vector2i.DOWN))
            for p in h._tank_beam_cells(tank_pos, tank_dir):
                var tbr: Rect2 = h._cell_rect(p).grow(-3.0)
                h.draw_rect(tbr, h.C_TELEGRAPH)
                h.draw_rect(tbr, flash_edge if imminent else h.C_TELEGRAPH_EDGE, false, border_width)
        elif enemy_type == "cross_discharge":
            var cross_center: Vector2i = e["pos"]
            var cross_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
            for cross_dir in cross_dirs:
                for p in h._cross_ray_cells(cross_center, cross_dir):
                    var xr: Rect2 = h._cell_rect(p).grow(-3.0)
                    h.draw_rect(xr, h.C_TELEGRAPH)
                    h.draw_rect(xr, flash_edge if imminent else h.C_TELEGRAPH_EDGE, false, border_width)
        elif enemy_type == "artillery":
            var artillery_pos: Vector2i = e["pos"]
            var artillery_dirs: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT]
            for artillery_dir in artillery_dirs:
                for p in h._artillery_ray_cells(artillery_pos, artillery_dir):
                    var ar: Rect2 = h._cell_rect(p).grow(-3.0)
                    h.draw_rect(ar, h.C_TELEGRAPH)
                    h.draw_rect(ar, flash_edge if imminent else h.C_TELEGRAPH_EDGE, false, border_width)
        elif enemy_type == "turret":
            var turret_pos: Vector2i = e["pos"]
            var turret_dir: Vector2i = e["turret_dir"]
            for p in h._turret_ray_cells(turret_pos, turret_dir):
                var br: Rect2 = h._cell_rect(p).grow(-3.0)
                h.draw_rect(br, h.C_TELEGRAPH)
                h.draw_rect(br, flash_edge if imminent else h.C_TELEGRAPH_EDGE, false, border_width)
        elif enemy_type == "charger" and e.get("charge_dir", Vector2i.ZERO) != Vector2i.ZERO:
            var charger_pos: Vector2i = e["pos"]
            var charger_dir: Vector2i = e["charge_dir"]
            for p in h._charger_preview_cells(charger_pos, charger_dir):
                var cr: Rect2 = h._cell_rect(p).grow(-4.0)
                h.draw_rect(cr, h.C_TELEGRAPH)
                h.draw_rect(cr, flash_edge if imminent else h.C_TELEGRAPH_EDGE, false, border_width)
        else:
            var telegraph_target: Vector2i = e["telegraph_target"]
            if h._is_floor(telegraph_target):
                var tr: Rect2 = h._cell_rect(telegraph_target).grow(-3.0)
                h.draw_rect(tr, h.C_TELEGRAPH)
                h.draw_rect(tr, flash_edge, false, border_width)
                h.draw_string(ThemeDB.fallback_font, h._cell_center(telegraph_target) + Vector2(-5, 6), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, flash_edge)

func draw_last_attack_cells() -> void:
    for p in h.last_attack_cells:
        if h._is_floor(p):
            h.draw_rect(h._cell_rect(p).grow(-2.0), h.C_ATTACK)

func draw_aim_overlay() -> void:
    if h.aim_mode == h.CARD_ARC:
        # 直線伝導は隣接1マスだけでなく、実際に電流が届く帯電PATH全体を予告する。
        _draw_direction_indicator_from_cell(h.player_pos, h.aim_dir, Color("#ffe95c"), false)
        for p in h._arc_path(h.aim_dir):
            h.draw_rect(h._cell_rect(p).grow(-3.0), h.C_ARC)
            h.draw_rect(h._cell_rect(p).grow(-1.0), Color("#ffe95c"), false, 2.0)
    elif h.aim_mode == h.CARD_SURGE:
        var surge_region: Dictionary = h._connected_charged_region(h.player_pos)
        for key in surge_region.keys():
            var surge_cell: Vector2i = Vector2i(key)
            h.draw_rect(h._cell_rect(surge_cell).grow(-4.0), h.C_ARC)
    elif h.aim_mode == h.CARD_LOOP:
        var loop_inside: Array[Vector2i] = h._selected_loop_inside_cells()
        var loop_boundary: Array[Vector2i] = h._selected_loop_boundary_cells()
        for loop_cell in loop_inside:
            h.draw_rect(h._cell_rect(loop_cell).grow(-3.0), h.C_AIM)
        for boundary_cell in loop_boundary:
            h.draw_rect(h._cell_rect(boundary_cell).grow(-2.0), h.C_ARC)
            h.draw_rect(h._cell_rect(boundary_cell).grow(-1.0), Color("#ffe95c"), false, 2.0)
    elif h.aim_mode == h.CARD_DASH:
        if not h.dash_route_customized and h.dash_branch_options.is_empty():
            _draw_direction_indicator(h.aim_dir)
        for p in h.dash_path_preview:
            h.draw_rect(h._cell_rect(p).grow(-3.0), h.C_ARC)
        if not h.dash_branch_options.is_empty():
            for d in h.dash_branch_options:
                var branch_cell: Vector2i = h.dash_branch_origin + d
                if h._in_bounds(branch_cell):
                    h.draw_rect(h._cell_rect(branch_cell).grow(-1.0), Color("#ffe95c"), false, 3.0)
            _draw_direction_indicator_from_cell(h.dash_branch_origin, h.dash_branch_options[0], Color("#ffe95c"), false)
    elif h.aim_mode == h.CARD_BOMB:
        # 爆弾は接続や距離に関係なく、盤面上の任意の帯電マスを爆心にできる。
        for key in h.charged.keys():
            var charged_cell: Vector2i = Vector2i(key)
            if h._is_floor(charged_cell):
                h.draw_rect(h._cell_rect(charged_cell).grow(-5.0), h.C_ARC, false, 1.5)
        var bomb_ok: bool = h._is_floor(h.bomb_cursor) and h.charged.has(h.bomb_cursor)
        if bomb_ok:
            for oy in range(-1, 2):
                for ox in range(-1, 2):
                    var p: Vector2i = h.bomb_cursor + Vector2i(ox, oy)
                    if h._is_floor(p):
                        h.draw_rect(h._cell_rect(p).grow(-3.0), h.C_AIM)
        var bomb_color: Color = Color("#ffe95c") if bomb_ok else h.C_ENEMY
        h.draw_rect(h._cell_rect(h.bomb_cursor).grow(-1.0), bomb_color, false, 3.0)
    elif h.aim_mode == h.CARD_WARP:
        # ワープも接続状態を問わず、盤面上の全帯電マスを候補として表示する。
        for key in h.charged.keys():
            var p: Vector2i = Vector2i(key)
            if h._is_floor(p):
                h.draw_rect(h._cell_rect(p).grow(-5.0), h.C_ARC, false, 2.0)
        var warp_ok: bool = h._is_floor(h.warp_cursor) and h.charged.has(h.warp_cursor) and h._enemy_index_at(h.warp_cursor) == -1 and h.warp_cursor != h.player_pos
        var warp_color: Color = Color("#ffe95c") if warp_ok else h.C_ENEMY
        h.draw_rect(h._cell_rect(h.warp_cursor).grow(-1.0), warp_color, false, 3.0)

func draw_enemies() -> void:
    var base_offset: Vector2 = h._damage_feedback_shake_offset() + h._boss_shake_offset() + h._enemy_impact_shake_offset()
    for e in h.enemies:
        h.draw_set_transform(base_offset + h._enemy_hit_reaction_offset(e))
        var ep: Vector2i = e["pos"]
        var c: Vector2 = h._cell_center(ep)
        var enemy_type: String = str(e.get("type", "chaser"))
        var facing: Vector2i = e["facing"]

        if enemy_type == "boss_leg":
            var boss_destroyed: bool = bool(e.get("destroyed", false))
            var boss_lifted: bool = bool(e.get("telegraph_active", false)) and not boss_destroyed
            var lift_offset := Vector2(0.0, -h.BOSS_LEG_LIFT_PIXELS if boss_lifted else 0.0)
            var boss_cells: Array[Vector2i] = h._boss_leg_cells(ep)
            for bc in boss_cells:
                var base_rect: Rect2 = h._cell_rect(bc).grow(-4.0)
                if boss_lifted:
                    h.draw_rect(base_rect.grow(-3.0), Color(0.0, 0.0, 0.0, 0.36))
                var bcr: Rect2 = Rect2(base_rect.position + lift_offset, base_rect.size)
                h.draw_rect(bcr, h.C_BOSS_LEG_BROKEN if boss_destroyed else h.C_BOSS_LEG)
                h.draw_rect(bcr, h.C_BOSS_LEG_BROKEN_EDGE if boss_destroyed else (Color.WHITE if boss_lifted else h.C_BOSS_LEG_EDGE), false, 2.0 if not boss_lifted else 3.0)
                if boss_destroyed:
                    h.draw_line(bcr.position + Vector2(5, 5), bcr.end - Vector2(5, 5), h.C_BOSS_LEG_BROKEN_EDGE, 2.0)
                    h.draw_line(Vector2(bcr.end.x - 5, bcr.position.y + 5), Vector2(bcr.position.x + 5, bcr.end.y - 5), h.C_BOSS_LEG_BROKEN_EDGE, 2.0)
                    # 壊れた脚は死体として残すが、下の帯電床を視覚的に隠さない。
                    # 帯電セルだけ死体の上へ半透明の発光を重ね、床資源が生きていることを示す。
                    if h.charged.has(bc):
                        var corpse_charge_fill: Color
                        var corpse_charge_edge: Color
                        if h.full_charge_hazard_active:
                            corpse_charge_fill = h._full_charge_flash_fill_color()
                            corpse_charge_fill.a = 0.34
                            corpse_charge_edge = h._full_charge_flash_edge_color()
                        else:
                            corpse_charge_fill = h.C_CHARGED_INNER
                            corpse_charge_fill.a = 0.22
                            corpse_charge_edge = h.C_CHARGED_INNER
                            corpse_charge_edge.a = 0.92
                        h.draw_rect(bcr.grow(-3.0), corpse_charge_fill)
                        h.draw_rect(bcr.grow(-2.0), corpse_charge_edge, false, 3.0)
                        h.draw_circle(bcr.get_center(), 3.5, corpse_charge_edge)
            var boss_center: Vector2 = h._cell_center(ep + Vector2i(1, 1)) + lift_offset
            if not boss_destroyed:
                h.draw_circle(boss_center, 10.0, h.C_BOSS_LEG_CORE)
                h.draw_arc(boss_center, 10.0, 0.0, TAU, 24, Color.WHITE if boss_lifted else h.C_TEXT, 2.0, true)
        elif enemy_type == "tank":
            # 3x3重戦車: 9マスの装甲塊＋中央コア。正面3マス幅の砲撃方向を砲身で示す。
            var tank_cells_draw: Array[Vector2i] = h._tank_cells(ep)
            var tank_center: Vector2 = h._cell_center(ep + Vector2i(1, 1))
            for tc in tank_cells_draw:
                var tcr: Rect2 = h._cell_rect(tc).grow(-4.0)
                h.draw_rect(tcr, h.C_TANK)
                h.draw_rect(tcr, h.C_TANK_BEAM_EDGE if bool(e["telegraph_active"]) else h.C_TANK_EDGE, false, 2.0)
            h.draw_circle(tank_center, 10.0, h.C_TANK_CORE)
            h.draw_arc(tank_center, 10.0, 0.0, TAU, 24, h.C_TANK_BEAM_EDGE if bool(e["telegraph_active"]) else h.C_TEXT, 2.0, true)
            var tank_facing: Vector2i = facing
            if bool(e["telegraph_active"]):
                tank_facing = Vector2i(e.get("tank_dir", facing))
            if tank_facing != Vector2i.ZERO:
                var tv := Vector2(tank_facing.x, tank_facing.y)
                var side := Vector2(-tv.y, tv.x)
                for lane_index in range(-1, 2):
                    var lane: float = float(lane_index)
                    var base: Vector2 = tank_center + side * lane * h.CELL
                    h.draw_line(base + tv * 18.0, base + tv * 35.0, h.C_TANK_CORE, 5.0)
            if bool(e["telegraph_active"]):
                var turns_left: int = int(e.get("telegraph_turns", 0))
                var turn_text: String = str(turns_left)
                var turn_font: Font = ThemeDB.fallback_font
                var turn_font_size := 18
                var turn_size: Vector2 = turn_font.get_string_size(turn_text, HORIZONTAL_ALIGNMENT_LEFT, -1, turn_font_size)
                var turn_plate := Rect2(
                    tank_center + Vector2(-turn_size.x * 0.5 - 5.0, -27.0),
                    Vector2(turn_size.x + 10.0, 23.0)
                )
                # 予告残りターンも裸の数字にせず、盤面情報用の濃いプレートで独立させる。
                h.draw_rect(turn_plate, Color(0.008, 0.012, 0.024, 0.96))
                h.draw_rect(turn_plate, Color(1.0, 1.0, 1.0, 0.88), false, 1.0, true)
                var turn_baseline := Vector2(turn_plate.get_center().x - turn_size.x * 0.5, turn_plate.position.y + 17.0)
                _draw_outlined_text(turn_font, turn_baseline, turn_text, turn_font_size, Color.WHITE, 2.0)
        elif enemy_type == "cross_discharge":
            # 十字放電機: 中央＋上下左右の5マス。形そのものが4方向放電を示す。
            var cross_cells_draw: Array[Vector2i] = h._cross_cells(ep)
            for xc in cross_cells_draw:
                var xcr: Rect2 = h._cell_rect(xc).grow(-5.0)
                h.draw_rect(xcr, h.C_CROSS)
                h.draw_rect(xcr, h.C_CROSS_BEAM_EDGE if bool(e["telegraph_active"]) else h.C_CROSS_EDGE, false, 2.0)
            h.draw_circle(c, 8.0, h.C_CROSS_CORE)
            h.draw_arc(c, 8.0, 0.0, TAU, 24, h.C_CROSS_BEAM_EDGE if bool(e["telegraph_active"]) else h.C_TEXT, 2.0, true)
            # 腕の中央に短い発光線を描き、上下左右へ撃つ敵だと分かりやすくする。
            var arm_dirs: Array[Vector2i] = [Vector2i.UP, Vector2i.DOWN, Vector2i.LEFT, Vector2i.RIGHT]
            for ad in arm_dirs:
                var av := Vector2(ad.x, ad.y)
                h.draw_line(c + av * 10.0, c + av * 26.0, h.C_CROSS_CORE, 4.0)
        elif enemy_type == "artillery":
            # 3マス砲撃機: 横3マスの砲身をそのままシルエットにする。
            var artillery_cells: Array[Vector2i] = h._artillery_cells(ep)
            var artillery_center: Vector2 = h._cell_center(artillery_cells[1])
            for ac in artillery_cells:
                var abr: Rect2 = h._cell_rect(ac).grow(-5.0)
                h.draw_rect(abr, h.C_ARTILLERY)
                h.draw_rect(abr, h.C_ARTILLERY_BEAM_EDGE if bool(e["telegraph_active"]) else h.C_ARTILLERY_EDGE, false, 2.0)
            h.draw_circle(artillery_center, 7.0, h.C_ARTILLERY_CORE)
            h.draw_arc(artillery_center, 7.0, 0.0, TAU, 24, h.C_ARTILLERY_BEAM_EDGE if bool(e["telegraph_active"]) else h.C_TEXT, 2.0, true)
            var left_center: Vector2 = h._cell_center(artillery_cells[0])
            var right_center: Vector2 = h._cell_center(artillery_cells[2])
            h.draw_line(left_center + Vector2(-6, 0), left_center + Vector2(-19, 0), h.C_ARTILLERY_CORE, 5.0)
            h.draw_line(right_center + Vector2(6, 0), right_center + Vector2(19, 0), h.C_ARTILLERY_CORE, 5.0)
        elif enemy_type == "long_serpent":
            # 5マス長蛇: 頭1マス＋胴体4マス。身体の連なり自体が移動障害になる。
            var raw_segments: Array = e.get("segments", [])
            var long_segments: Array[Vector2i] = []
            for item in raw_segments:
                long_segments.append(Vector2i(item))
            for si in range(long_segments.size() - 1, 0, -1):
                var body_pos: Vector2i = long_segments[si]
                var body_center: Vector2 = h._cell_center(body_pos)
                var prev_center: Vector2 = h._cell_center(long_segments[si - 1])
                h.draw_line(body_center, prev_center, h.C_LONG_SERPENT_EDGE, 8.0)
                h.draw_circle(body_center, 10.0, h.C_LONG_SERPENT)
                h.draw_circle(body_center, 4.0, h.C_LONG_SERPENT_CORE)
                h.draw_arc(body_center, 10.0, 0.0, TAU, 24, h.C_LONG_SERPENT_EDGE, 2.0, true)
            var long_head_shape := PackedVector2Array([
                c + Vector2(0, -15),
                c + Vector2(14, -8),
                c + Vector2(14, 8),
                c + Vector2(0, 15),
                c + Vector2(-14, 8),
                c + Vector2(-14, -8)
            ])
            h.draw_colored_polygon(long_head_shape, h.C_LONG_SERPENT)
            h.draw_polyline(PackedVector2Array([long_head_shape[0], long_head_shape[1], long_head_shape[2], long_head_shape[3], long_head_shape[4], long_head_shape[5], long_head_shape[0]]), h.C_LONG_SERPENT_EDGE if bool(e["telegraph_active"]) else h.C_TEXT, 2.0)
            h.draw_circle(c, 5.0, h.C_LONG_SERPENT_CORE)
            if facing != Vector2i.ZERO:
                var lfd := Vector2(facing.x, facing.y)
                h.draw_line(c + lfd * 8.0, c + lfd * 20.0, h.C_LONG_SERPENT_EDGE, 4.0)
        elif enemy_type == "serpent":
            # 二連蛇: 頭と胴体を線でつなぎ、2マス占有を一目で分かるようにする。
            var tail_pos: Vector2i = e["tail"]
            var tail_center: Vector2 = h._cell_center(tail_pos)
            h.draw_line(tail_center, c, h.C_SERPENT_EDGE, 8.0)
            h.draw_circle(tail_center, 11.0, h.C_SERPENT)
            h.draw_circle(tail_center, 5.0, h.C_SERPENT_CORE)
            h.draw_arc(tail_center, 11.0, 0.0, TAU, 24, h.C_SERPENT_EDGE, 2.0, true)

            var head_shape := PackedVector2Array([
                c + Vector2(0, -14),
                c + Vector2(13, -7),
                c + Vector2(13, 7),
                c + Vector2(0, 14),
                c + Vector2(-13, 7),
                c + Vector2(-13, -7)
            ])
            h.draw_colored_polygon(head_shape, h.C_SERPENT)
            h.draw_polyline(PackedVector2Array([head_shape[0], head_shape[1], head_shape[2], head_shape[3], head_shape[4], head_shape[5], head_shape[0]]), h.C_SERPENT_EDGE if bool(e["telegraph_active"]) else h.C_TEXT, 2.0)
            h.draw_circle(c, 5.0, h.C_SERPENT_CORE)
            if facing != Vector2i.ZERO:
                var sfd := Vector2(facing.x, facing.y)
                h.draw_line(c + sfd * 8.0, c + sfd * 19.0, h.C_SERPENT_EDGE, 4.0)
        elif enemy_type == "heavy":
            # 2x2重装機: 4つの装甲ブロックを一体として描く。
            var heavy_cells: Array[Vector2i] = h._heavy_cells(ep)
            var center: Vector2 = (h._cell_center(heavy_cells[0]) + h._cell_center(heavy_cells[3])) * 0.5
            for hc in heavy_cells:
                var hr: Rect2 = h._cell_rect(hc).grow(-5.0)
                h.draw_rect(hr, h.C_HEAVY)
                h.draw_rect(hr, h.C_HEAVY_EDGE, false, 2.0)
            h.draw_circle(center, 8.0, h.C_HEAVY_CORE)
            h.draw_arc(center, 8.0, 0.0, TAU, 24, h.C_TEXT if not bool(e["telegraph_active"]) else h.C_TELEGRAPH_EDGE, 2.0, true)
            if facing != Vector2i.ZERO:
                var hfd := Vector2(facing.x, facing.y)
                h.draw_line(center + hfd * 10.0, center + hfd * 24.0, h.C_HEAVY_CORE, 5.0)
        elif enemy_type == "turret":
            # 固定砲台: 四角い本体 + 赤いレンズ + 砲身。追跡敵と形だけでも区別できる。
            var body := Rect2(c - Vector2(13, 13), Vector2(26, 26))
            h.draw_rect(body, h.C_TURRET)
            h.draw_rect(body, h.C_TEXT if not bool(e["telegraph_active"]) else h.C_TURRET_BEAM_EDGE, false, 2.0)
            h.draw_circle(c, 6.0, h.C_TURRET_LENS if not bool(e["telegraph_active"]) else h.C_TURRET_BEAM_EDGE)
            if facing != Vector2i.ZERO:
                var tfd := Vector2(facing.x, facing.y)
                h.draw_line(c + tfd * 9.0, c + tfd * 20.0, h.C_TURRET_BEAM_EDGE, 5.0)
        elif enemy_type == "charger":
            # 突進機: 菱形 + 明るいコア + 前方矢印。固定砲台・丸い追跡敵と形で区別する。
            var diamond := PackedVector2Array([
                c + Vector2(0, -15),
                c + Vector2(15, 0),
                c + Vector2(0, 15),
                c + Vector2(-15, 0)
            ])
            h.draw_colored_polygon(diamond, h.C_CHARGER)
            h.draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), h.C_CHARGER_EDGE if bool(e["telegraph_active"]) else h.C_TEXT, 2.0)
            h.draw_circle(c, 5.0, h.C_CHARGER_CORE)
            if facing != Vector2i.ZERO:
                var cfd := Vector2(facing.x, facing.y)
                h.draw_line(c + cfd * 7.0, c + cfd * 20.0, h.C_CHARGER_EDGE, 4.0)
        elif enemy_type == "runner":
            # 逃走機: 緑の矢じり型。攻撃敵ではなく「逃げる敵」だと形と色で区別する。
            var rfd := Vector2(facing.x, facing.y)
            if rfd == Vector2.ZERO:
                rfd = Vector2.DOWN
            var side := Vector2(-rfd.y, rfd.x)
            var tip: Vector2 = c + rfd * 16.0
            var back: Vector2 = c - rfd * 12.0
            var tri := PackedVector2Array([tip, back + side * 11.0, back - side * 11.0])
            h.draw_colored_polygon(tri, h.C_RUNNER)
            h.draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), h.C_RUNNER_EDGE, 2.0)
            h.draw_circle(c, 4.0, h.C_RUNNER_CORE)
            h.draw_line(back - rfd * 2.0, back - rfd * 9.0, h.C_RUNNER_EDGE, 3.0)
        else:
            h.draw_circle(c, 12.0, h.C_ENEMY)
            if facing != Vector2i.ZERO:
                var fd := Vector2(facing.x, facing.y)
                h.draw_line(c + fd * 10.0, c + fd * 17.0, h.C_TELEGRAPH_EDGE if bool(e["telegraph_active"]) else h.C_TEXT, 3.0)

    # 敵ごとの局所揺れで変更した描画原点を、画面全体の基準へ戻す。
    h.draw_set_transform(base_offset)

func draw_enemy_hit_flashes() -> void:
    # 実際に攻撃が触れた占有マスだけを白くし、そのセル自体を短く小刻みに震わせる。
    # 大型敵の「どこへ当たったか」を一目で読めるよう、敵全体の白化は行わない。
    for flash in h.enemy_hit_flashes:
        var time_left: float = float(flash.get("time", 0.0))
        if time_left <= 0.0:
            continue
        var duration: float = maxf(0.001, float(flash.get("duration", h.ENEMY_HIT_REACTION_DURATION)))
        var envelope: float = clampf(time_left / duration, 0.0, 1.0)
        var progress: float = 1.0 - envelope
        var tier: int = int(flash.get("tier", 1))
        var sequence: float = float(int(flash.get("sequence", 0)))
        var alpha_fill: float = (0.70 if tier == 1 else (0.82 if tier == 2 else 0.94)) * (0.55 + 0.45 * envelope)
        var alpha_edge: float = (0.88 if tier == 1 else 1.0) * envelope
        var edge_width: float = 2.0 if tier == 1 else (3.0 if tier == 2 else 4.0)
        var shake_pixels: float = (2.2 if tier == 1 else (3.2 if tier == 2 else 4.2)) * envelope
        var raw_cells: Array = flash.get("cells", [])
        var cell_index := 0
        for item in raw_cells:
            var p: Vector2i = Vector2i(item)
            if not h._in_bounds(p):
                cell_index += 1
                continue
            var phase: float = progress * TAU * 5.5 + sequence * 1.71 + float(p.x * 7 + p.y * 11 + cell_index * 5) * 0.37
            var jitter := Vector2(sin(phase), cos(phase * 1.23)) * shake_pixels
            var r: Rect2 = h._cell_rect(p).grow(-3.0)
            r.position += jitter
            h.draw_rect(r, Color(1.0, 1.0, 1.0, alpha_fill))
            h.draw_rect(r, Color(1.0, 1.0, 1.0, alpha_edge), false, edge_width, true)
            cell_index += 1

    _draw_enemy_destroy_fx()
    _draw_enemy_damage_numbers()

func _draw_enemy_damage_numbers() -> void:
    var font: Font = ThemeDB.fallback_font
    for item in h.enemy_damage_numbers:
        var time_left: float = float(item.get("time", 0.0))
        var duration: float = maxf(0.001, float(item.get("duration", h.ENEMY_DAMAGE_NUMBER_DURATION)))
        if time_left <= 0.0:
            continue
        var remain: float = clampf(time_left / duration, 0.0, 1.0)
        var progress: float = 1.0 - remain
        var tier: int = int(item.get("tier", 1))
        var amount: int = int(item.get("amount", 0))
        # 瞬間情報はHPより明確に大きくする。大型ヒットほどさらに一段大きい。
        var font_size: int = 24 if tier == 1 else (29 if tier == 2 else 35)
        var pop: float = sin(minf(1.0, progress / 0.28) * PI) * (3.0 if tier == 1 else (5.0 if tier == 2 else 7.0))
        var center: Vector2 = Vector2(item.get("center", Vector2.ZERO)) + Vector2(0.0, -14.0 - 20.0 * progress - pop)
        var text: String = str(amount)
        var text_size: Vector2 = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
        var baseline: Vector2 = center + Vector2(-text_size.x * 0.5, text_size.y * 0.36)
        var alpha: float = 1.0 if progress < 0.68 else clampf((1.0 - progress) / 0.32, 0.0, 1.0)
        var white: Color = Color(1.0, 1.0, 1.0, alpha)
        var outline: float = 3.0 if tier == 1 else (4.0 if tier == 2 else 5.0)
        _draw_outlined_text(font, baseline, text, font_size, white, outline, alpha)

func _draw_enemy_destroy_fx() -> void:
    for item in h.enemy_destroy_fx:
        var time_left: float = float(item.get("time", 0.0))
        var duration: float = maxf(0.001, float(item.get("duration", h.ENEMY_DESTROY_FX_DURATION)))
        if time_left <= 0.0:
            continue
        var remain: float = clampf(time_left / duration, 0.0, 1.0)
        var progress: float = 1.0 - remain
        var center: Vector2 = Vector2(item.get("center", Vector2.ZERO))
        var raw_cells: Array = item.get("cells", [])

        # 撃破直後は占有マスが中心へ縮みながら白く抜ける。
        if progress < 0.52:
            var shrink_t: float = clampf(progress / 0.52, 0.0, 1.0)
            var cell_alpha: float = 1.0 - shrink_t
            var half_size: float = lerpf(12.0, 2.0, shrink_t)
            for raw in raw_cells:
                var cell: Vector2i = Vector2i(raw)
                var cc: Vector2 = h._cell_center(cell)
                var rect := Rect2(cc - Vector2(half_size, half_size), Vector2(half_size * 2.0, half_size * 2.0))
                h.draw_rect(rect, Color(1.0, 1.0, 1.0, 0.70 * cell_alpha))
                h.draw_rect(rect, Color(1.0, 1.0, 1.0, 0.95 * cell_alpha), false, 2.0, true)

        # 破片は2〜4個だけ。大量パーティクルを作らず、短い放射で撃破を区別する。
        var sequence: float = float(int(item.get("sequence", 0)))
        var fragment_count: int = clampi(2 + raw_cells.size() / 3, 2, 4)
        for i in range(fragment_count):
            var angle: float = sequence * 0.71 + float(i) * TAU / float(fragment_count)
            var distance: float = 8.0 + 28.0 * minf(1.0, progress / 0.82)
            var pos: Vector2 = center + Vector2(cos(angle), sin(angle)) * distance
            var frag_alpha: float = clampf(1.0 - progress, 0.0, 1.0)
            var size: float = lerpf(5.0, 2.0, progress)
            h.draw_rect(Rect2(pos - Vector2(size, size) * 0.5, Vector2(size, size)), Color(1.0, 1.0, 1.0, frag_alpha))

        # 大きな粒子を増やす代わりに、中心の短いリングで「撃破」を締める。
        if progress < 0.72:
            var ring_t: float = clampf(progress / 0.72, 0.0, 1.0)
            var ring_color := Color(1.0, 1.0, 1.0, (1.0 - ring_t) * 0.86)
            h.draw_arc(center, lerpf(5.0, 24.0, ring_t), 0.0, TAU, 28, ring_color, 2.5, true)

func draw_player() -> void:
    var pc: Vector2 = h._cell_center(h.player_pos)
    # ワープ／ラインダッシュ演出中は通常の主人公表示を隠し、専用エフェクト側で描く。
    if not (h.skill_fx != null and bool(h.skill_fx.active) and (str(h.skill_fx.kind) == h.CARD_WARP or str(h.skill_fx.kind) == h.CARD_DASH)):
        # 主人公は青い丸＋白い外周＋白い方向線で、敵や帯電床から即座に識別できるようにする。
        h.draw_circle(pc, 13.0, h._player_pulse_color())
        h.draw_arc(pc, 13.0, 0.0, TAU, 32, Color.WHITE, 2.0, true)
        var player_dir := Vector2(h.player_facing.x, h.player_facing.y)
        if player_dir != Vector2.ZERO:
            h.draw_line(pc + player_dir * 2.0, pc + player_dir * 16.0, Color.WHITE, 4.0, true)

func draw_enemy_hp_labels() -> void:
    # HPは敵の外へ張り出さず、本体の中へ小さな現在値だけを重ねる。
    # 盤面の移動先・帯電状態を隠さないことを優先し、背景プレートも使わない。
    var base_offset: Vector2 = h._damage_feedback_shake_offset() + h._boss_shake_offset() + h._enemy_impact_shake_offset()
    for enemy in h.enemies:
        if maxi(0, int(enemy.get("hp", 0))) <= 0:
            continue
        h.draw_set_transform(base_offset + h._enemy_hit_reaction_offset(enemy))
        _draw_enemy_hp_number_inside(enemy)
    h.draw_set_transform(base_offset)

func _enemy_hp_anchor(enemy: Dictionary) -> Vector2:
    var ep: Vector2i = Vector2i(enemy.get("pos", Vector2i.ZERO))
    var enemy_type: String = str(enemy.get("type", "chaser"))
    var anchor: Vector2 = h._cell_center(ep)

    # 大型敵は実際の胴体中央を基準にする。通常敵は基準セル内に収める。
    match enemy_type:
        "boss_leg":
            anchor = h._cell_center(ep + Vector2i(1, 1))
            if bool(enemy.get("telegraph_active", false)) and not bool(enemy.get("destroyed", false)):
                anchor += Vector2(0.0, -h.BOSS_LEG_LIFT_PIXELS)
            anchor += Vector2(0.0, 22.0)
        "tank":
            anchor = h._cell_center(ep + Vector2i(1, 1)) + Vector2(0.0, 22.0)
        "heavy":
            var heavy_cells: Array[Vector2i] = h._heavy_cells(ep)
            if heavy_cells.size() >= 4:
                anchor = (h._cell_center(heavy_cells[0]) + h._cell_center(heavy_cells[3])) * 0.5 + Vector2(0.0, 17.0)
        "artillery":
            var artillery_cells: Array[Vector2i] = h._artillery_cells(ep)
            if artillery_cells.size() >= 2:
                anchor = h._cell_center(artillery_cells[1]) + Vector2(0.0, 9.0)
        "cross_discharge":
            anchor += Vector2(0.0, 10.0)
        "long_serpent", "serpent", "turret", "charger", "runner":
            anchor += Vector2(0.0, 9.0)
        _:
            anchor += Vector2(0.0, 9.0)
    return anchor

func _draw_enemy_hp_number_inside(enemy: Dictionary) -> void:
    var current_hp: int = maxi(0, int(enemy.get("hp", 0)))
    if current_hp <= 0:
        return

    var hp_text: String = str(current_hp)
    var font: Font = ThemeDB.fallback_font
    var font_size: int = 13
    var text_size: Vector2 = font.get_string_size(hp_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
    var center: Vector2 = _enemy_hp_anchor(enemy)
    var baseline := Vector2(center.x - text_size.x * 0.5, center.y + font_size * 0.36)

    # 被弾直後は大きいダメージ数字を先に読ませるため、HPだけ少し薄くする。
    var reacting: bool = float(enemy.get("hit_fx_time", 0.0)) > 0.0
    var alpha: float = 0.58 if reacting else 0.96
    _draw_outlined_text(font, baseline, hp_text, font_size, Color(1.0, 1.0, 1.0, alpha), 1.0, alpha)

func _draw_outlined_text(font: Font, baseline: Vector2, text: String, font_size: int, fill: Color, outline_width: float, alpha_scale: float = 1.0) -> void:
    # 8方向へ暗い縁を置き、床色・敵色・白フラッシュのどの上でも数字の形を保つ。
    var dark := Color(0.0, 0.0, 0.0, 0.98 * alpha_scale)
    var offsets: Array[Vector2] = [
        Vector2(-outline_width, 0.0), Vector2(outline_width, 0.0),
        Vector2(0.0, -outline_width), Vector2(0.0, outline_width),
        Vector2(-outline_width, -outline_width), Vector2(outline_width, -outline_width),
        Vector2(-outline_width, outline_width), Vector2(outline_width, outline_width)
    ]
    for offset in offsets:
        h.draw_string(font, baseline + offset, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, dark)
    h.draw_string(font, baseline, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, fill)

func _draw_boss_body() -> void:
    # 本体は画面上部の外側。下半分だけを見せて、脚の持ち主を示す。
    var center := Vector2(h.GRID_ORIGIN.x + (h.GRID_W * h.CELL) * 0.5, h.GRID_ORIGIN.y - 38.0)
    h.draw_circle(center, 72.0, h.C_BOSS_BODY)
    h.draw_arc(center, 72.0, 0.0, TAU, 48, h.C_BOSS_LEG_EDGE, 3.0, true)
    h.draw_circle(center + Vector2(-22, 48), 5.0, h.C_BOSS_LEG_CORE)
    h.draw_circle(center + Vector2(22, 48), 5.0, h.C_BOSS_LEG_CORE)

func _draw_direction_indicator(d: Vector2i) -> void:
    _draw_direction_indicator_from_cell(h.player_pos, d, Color("#ffe95c"), true)

func _draw_direction_indicator_from_cell(origin_cell: Vector2i, d: Vector2i, color: Color, highlight_target: bool = true) -> void:
    if d == Vector2i.ZERO:
        return
    var c: Vector2 = h._cell_center(origin_cell)
    var dv := Vector2(float(d.x), float(d.y))
    var side := Vector2(-dv.y, dv.x)
    var tip: Vector2 = c + dv * 27.0
    var base: Vector2 = c + dv * 13.0
    h.draw_line(c + dv * 7.0, tip, color, 4.0)
    h.draw_line(tip, base + side * 6.0, color, 4.0)
    h.draw_line(tip, base - side * 6.0, color, 4.0)

    var target: Vector2i = origin_cell + d
    if highlight_target and h._in_bounds(target):
        # 床・壁を問わず「現在この方向を選択中」と示す。
        h.draw_rect(h._cell_rect(target).grow(-1.0), color, false, 3.0)

