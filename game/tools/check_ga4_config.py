from pathlib import Path
import sys

MEASUREMENT_ID = "G-EFN2NDBE53"
preset = Path(__file__).resolve().parents[1] / "export_presets.cfg"
text = preset.read_text(encoding="utf-8")
required = [
    f"https://www.googletagmanager.com/gtag/js?id={MEASUREMENT_ID}",
    f'window.__voltPathGa4Id = \\"{MEASUREMENT_ID}\\"',
    'window.gtag = gtag',
    'gtag(\\"config\\", window.__voltPathGa4Id)',
    'window.voltPathTrack = function(eventName, paramsJson)',
    'window.gtag(\\"event\\", String(eventName), params)',
]
missing = [item for item in required if item not in text]
if missing:
    print("GA4 Head Include check FAILED:")
    for item in missing:
        print(" - missing:", item)
    sys.exit(1)
print(f"GA4 Head Include + custom event bridge OK: {MEASUREMENT_ID}")
