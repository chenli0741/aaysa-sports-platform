"""Package the supplied full-bleed artwork as an opaque 1024 px iOS icon."""

from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
MASTER = ROOT / "design/FieldLine-AppIcon-master.png"
OUTPUT = ROOT / "FieldLine/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png"

with Image.open(MASTER) as source:
    if source.width != source.height:
        raise ValueError("The app icon master must be square")
    icon = source.convert("RGB").resize((1024, 1024), Image.Resampling.LANCZOS)
    icon.save(OUTPUT, format="PNG", optimize=True)

print(OUTPUT)
