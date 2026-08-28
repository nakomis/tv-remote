#!/usr/bin/env python3
"""Turn one 1024x1024 artwork into the app icons both platforms need.

    python3 scripts/make-icons.py <artwork.png>

The two platforms want opposite things from the same picture:

  iOS    a full-bleed square, no transparency, no rounded corners. iOS applies
         its own mask, so rounding the source just gets rounded twice and
         leaves pale fringes at the corners.
  macOS  a rounded "squircle" with transparent margins, drawn to Apple's icon
         grid: an 824x824 rounded square centred on a 1024x1024 canvas. macOS
         does *not* mask, so the shape has to be in the image.

Generated artwork usually arrives as a rounded shape on a white page, which is
wrong for both. This crops away that page, then builds each platform's form.
"""
import json
import pathlib
import sys

from PIL import Image, ImageDraw

# Apple's macOS icon grid.
CANVAS = 1024
PLATE = 824
PLATE_RADIUS = 185
# macOS's icon slots, as (point size, scale) -> pixels needed. These are the
# only combinations the asset catalogue accepts; deriving them arithmetically
# invents 64x64@1x and 64x64@2x, which do not exist and are silently dropped
# with an "unassigned children" warning.
MAC_SLOTS = [
    (16, "1x", 16), (16, "2x", 32),
    (32, "1x", 32), (32, "2x", 64),
    (128, "1x", 128), (128, "2x", 256),
    (256, "1x", 256), (256, "2x", 512),
    (512, "1x", 512), (512, "2x", 1024),
]


def crop_to_artwork(image: Image.Image) -> Image.Image:
    """Discard the white page around the artwork.

    Works on the inverse of the image: `getbbox()` finds non-zero pixels, so
    inverting makes 'not white' the thing it measures.
    """
    grey = image.convert("L")
    inverted = grey.point(lambda p: 255 - p)
    box = inverted.getbbox()
    if box is None:
        return image

    # Square the crop off around its own centre, so nothing is stretched.
    left, top, right, bottom = box
    cx, cy = (left + right) // 2, (top + bottom) // 2
    half = max(right - left, bottom - top) // 2
    half = min(half, cx, cy, image.width - cx, image.height - cy)
    return image.crop((cx - half, cy - half, cx + half, cy + half))


def page_corner_radius(image: Image.Image) -> int:
    """The corner radius of the rounded shape the artwork was drawn as.

    Generated artwork is typically a rounded square on a white page. Along the
    very top row, that shape spans from x = radius to width - radius, so the
    first non-white pixel on row 0 gives the radius directly.
    """
    grey = image.convert("L")
    width = image.width
    for x in range(width // 2):
        if grey.getpixel((x, 0)) < 240:
            return x
    return 0


def flatten_page(image: Image.Image) -> Image.Image:
    """Replace the white page outside the artwork's rounded corners.

    Both platforms need this gone: iOS because a pale fringe survives its own
    masking, macOS because the plate is re-cut at a different radius and would
    otherwise show white slivers.
    """
    radius = page_corner_radius(image)
    backing = Image.new("RGB", image.size, (10, 10, 10))  # Theme.background
    if radius == 0:
        backing.paste(image.convert("RGB"), (0, 0))
        return backing
    mask = rounded_mask(image.width, radius)
    backing.paste(image.convert("RGB"), (0, 0), mask)
    print(f"stripped the white page (corner radius {radius}px)")
    return backing


def rounded_mask(size: int, radius: int) -> Image.Image:
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, size - 1, size - 1), radius, fill=255)
    return mask


def build_ios(art: Image.Image) -> Image.Image:
    """Full-bleed square, no alpha. iOS rounds it itself."""
    return art.convert("RGB").resize((CANVAS, CANVAS), Image.LANCZOS)


def build_mac(art: Image.Image) -> Image.Image:
    """An 824x824 rounded plate centred on a transparent 1024 canvas."""
    plate = art.convert("RGB").resize((PLATE, PLATE), Image.LANCZOS)
    plate.putalpha(rounded_mask(PLATE, PLATE_RADIUS))
    canvas = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    canvas.paste(plate, ((CANVAS - PLATE) // 2, (CANVAS - PLATE) // 2), plate)
    return canvas


def main() -> int:
    if len(sys.argv) != 2:
        print(__doc__)
        return 2

    source = pathlib.Path(sys.argv[1])
    if not source.exists():
        print(f"No such file: {source}")
        return 1

    root = pathlib.Path(__file__).resolve().parent.parent
    iconset = root / "TVRemote/Resources/Assets.xcassets/AppIcon.appiconset"
    iconset.mkdir(parents=True, exist_ok=True)
    for stale in iconset.glob("*.png"):
        stale.unlink()

    art = crop_to_artwork(Image.open(source).convert("RGBA"))
    print(f"cropped artwork to {art.width}x{art.height}")
    art = flatten_page(art)

    images = []

    build_ios(art).save(iconset / "icon-ios-1024.png")
    images.append({
        "filename": "icon-ios-1024.png",
        "idiom": "universal",
        "platform": "ios",
        "size": "1024x1024",
    })
    print("wrote icon-ios-1024.png (full-bleed, no alpha)")

    mac = build_mac(art)
    for pixels in sorted({p for _, _, p in MAC_SLOTS}):
        mac.resize((pixels, pixels), Image.LANCZOS).save(iconset / f"icon-mac-{pixels}.png")
        print(f"wrote icon-mac-{pixels}.png")

    for points, scale, pixels in MAC_SLOTS:
        images.append({
            "filename": f"icon-mac-{pixels}.png",
            "idiom": "mac",
            "scale": scale,
            "size": f"{points}x{points}",
        })

    (iconset / "Contents.json").write_text(
        json.dumps({"images": images, "info": {"author": "xcode", "version": 1}}, indent=2) + "\n"
    )
    print(f"\nwrote Contents.json with {len(images)} entries")
    return 0


if __name__ == "__main__":
    sys.exit(main())
