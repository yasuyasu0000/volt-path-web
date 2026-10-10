extends RefCounted

# Web-only GA4 event bridge.
# GA4 itself and window.voltPathTrack() are initialized in the Web export
# preset via html/head_include.
const GAME_VERSION := "0.946"

var enabled := false
var measurement_id := ""
var _window = null

func setup() -> void:
    if not OS.has_feature("web"):
        return

    _window = JavaScriptBridge.get_interface("window")
    if _window == null:
        push_warning("JavaScript window interface is unavailable; analytics events are disabled.")
        return

    measurement_id = String(_window.__voltPathGa4Id).strip_edges()
    if measurement_id == "" or not measurement_id.begins_with("G-"):
        push_warning("GA4 Head Include was not initialized; analytics events are disabled.")
        return

    enabled = true

func track(event_name: String, params: Dictionary = {}) -> void:
    if not enabled or event_name == "" or _window == null:
        return

    var payload := params.duplicate(true)
    payload["game_version"] = GAME_VERSION

    # Only base String values cross the JavaScriptBridge boundary here.
    # The Head Include helper parses the JSON and calls gtag().
    var sent = _window.voltPathTrack(event_name, JSON.stringify(payload))
    if sent != true:
        push_warning("GA4 event was not sent: %s" % event_name)
