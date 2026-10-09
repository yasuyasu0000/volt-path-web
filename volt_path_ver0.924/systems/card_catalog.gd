extends RefCounted

# VOLT PATH card definitions.
# Keep card identity, display text, cost, and hand-summary text in one place.

const ARC := "arc"
const SURGE := "surge"
const BOMB := "bomb"
const WARP := "warp"
const DASH := "dash"
const LOOP := "loop"

const POOL: Array[String] = [
    ARC,
    SURGE,
    BOMB,
    WARP,
    DASH,
    LOOP,
]

static func display_name(card_id: String) -> String:
    match card_id:
        ARC:
            return "直線伝導"
        SURGE:
            return "一斉放電"
        BOMB:
            return "爆弾"
        WARP:
            return "ワープ"
        DASH:
            return "ラインダッシュ"
        LOOP:
            return "ループ"
    return "不明"

static func cost(card_id: String) -> int:
    match card_id:
        ARC:
            return 2
        SURGE:
            return 4
        BOMB:
            return 7
        WARP:
            return 3
        DASH:
            return 2
        LOOP:
            return 4
    return 99

static func short_info(card_id: String) -> String:
    match card_id:
        ARC:
            return "直線PATH  2DMG"
        SURGE:
            return "接続PATH全体  1DMG/マス"
        BOMB:
            return "任意の帯電マス  3×3攻撃"
        WARP:
            return "任意の帯電マスへ移動"
        DASH:
            return "PATH走破  1DMG/マス"
        LOOP:
            return "ループ内+輪  3DMG/マス"
    return ""
