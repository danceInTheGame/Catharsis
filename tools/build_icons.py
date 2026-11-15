#!/usr/bin/env python3
"""Génère les icônes de l'application (cachet rouge 汉) pour Android."""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

GaussianBlur = ImageFilter.GaussianBlur

ROOT = Path(__file__).resolve().parent.parent
RES = ROOT / "hskhelp" / "android" / "app" / "src" / "main" / "res"

SEAL = (183, 45, 38, 255)  # rouge sceau
SEAL_DEEP = (120, 24, 20, 255)
WHITE = (255, 255, 255, 255)

# dossiers mipmap : densité -> taille en px (icône complète 108dp)
DENSITIES = {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}

# l'icône adaptative Android utilise une toile de 108dp dont le quart central
# (66dp) est la zone sûre.
ADAPTIVE_SIZES = {
    "mipmap-mdpi": 108,
    "mipmap-hdpi": 162,
    "mipmap-xhdpi": 216,
    "mipmap-xxhdpi": 324,
    "mipmap-xxxhdpi": 432,
}


def _font(size: int) -> ImageFont.FreeTypeFont:
    candidates = [
        Path("/home/sah/HskHelp/hskhelp/assets/fonts/HskHelp-Bold.ttf"),
        Path("/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"),
    ]
    for path in candidates:
        if path.exists():
            try:
                return ImageFont.truetype(str(path), size)
            except OSError:
                continue
    sys.exit("aucune police CJK disponible pour l'icône")


def _rounded_mask(size: int, radius: int, ss: int = 4) -> Image.Image:
    mask = Image.new("L", (size * ss, size * ss), 0)
    ImageDraw.Draw(mask).rounded_rectangle(
        [0, 0, size * ss - 1, size * ss - 1], radius=radius * ss, fill=255
    )
    return mask.resize((size, size), Image.LANCZOS)


def _seal_icon(size: int, glyph_scale: float = 0.56) -> Image.Image:
    """Cachet rouge arrondi avec un 汉 blanc gravé."""
    ss = 4
    big = size * ss
    img = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    radius = int(big * 0.22)
    # dégradé vertical très léger pour donner du relief
    top = (196, 56, 46, 255)
    bottom = (148, 28, 23, 255)
    for y in range(big):
        t = y / max(big - 1, 1)
        draw.line(
            [(0, y), (big, y)],
            fill=tuple(int(a + (b - a) * t) for a, b in zip(top, bottom)),
        )
    # biseau intérieur
    draw.rounded_rectangle(
        [0, 0, big - 1, big - 1],
        radius=radius,
        outline=(255, 255, 255, 60),
        width=max(int(big * 0.012), 2),
    )
    inner = int(big * 0.045)
    draw.rounded_rectangle(
        [inner, inner, big - inner, big - inner],
        radius=radius - inner,
        outline=(255, 255, 255, 70),
        width=max(int(big * 0.016), 2),
    )

    # glyphe 汉
    glyph = "汉"
    target = int(big * glyph_scale)
    font = _font(target)
    bbox = draw.textbbox((0, 0), glyph, font=font)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (big - w) / 2 - bbox[0]
    y = (big - h) / 2 - bbox[1]

    # ombre portée douce
    shadow = Image.new("RGBA", (big, big), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text(
        (x + big * 0.012, y + big * 0.014), glyph, font=font, fill=(0, 0, 0, 90)
    )
    shadow = shadow.filter(GaussianBlur(big * 0.012))
    img.alpha_composite(shadow)

    draw.text((x, y), glyph, font=font, fill=(255, 255, 255, 255))

    out = img.resize((size, size), Image.LANCZOS)
    mask = _rounded_mask(size, radius=int(size * 0.22))
    final = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    final.paste(out, (0, 0), mask)
    return final


def _adaptive_foreground(size: int) -> Image.Image:
    """Glyphe seul, dans la zone sûre centrale d'une toile de 108dp."""
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    glyph = "汉"
    # zone sûre = 66/108 de la toile
    target = int(size * 0.66 * 0.72)
    font = _font(target)
    bbox = draw.textbbox((0, 0), glyph, font=font)
    w, h = bbox[2] - bbox[0], bbox[3] - bbox[1]
    x = (size - w) / 2 - bbox[0]
    y = (size - h) / 2 - bbox[1] + size * 0.01

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    ImageDraw.Draw(shadow).text(
        (x + size * 0.012, y + size * 0.014), glyph, font=font, fill=(0, 0, 0, 70)
    )
    shadow = shadow.filter(GaussianBlur(size * 0.014))
    img.alpha_composite(shadow)
    draw.text((x, y), glyph, font=font, fill=WHITE)
    return img


def main():
    if not RES.exists():
        sys.exit(f"dossier res introuvable : {RES}")

    for folder, size in DENSITIES.items():
        dest = RES / folder / "ic_launcher.png"
        dest.parent.mkdir(parents=True, exist_ok=True)
        icon = _seal_icon(size)
        icon.save(dest, "PNG")
        round_icon = RES / folder / "ic_launcher_round.png"
        _circular(icon).save(round_icon, "PNG")
        print(f"{dest.relative_to(ROOT)} ({size}x{size})", file=sys.stderr)

    for folder, size in ADAPTIVE_SIZES.items():
        dest = RES / folder / "ic_launcher_foreground.png"
        dest.parent.mkdir(parents=True, exist_ok=True)
        _adaptive_foreground(size).save(dest, "PNG")
        print(f"{dest.relative_to(ROOT)} ({size}x{size})", file=sys.stderr)

    # fond uni de l'icône adaptative
    drawable = RES / "drawable"
    drawable.mkdir(parents=True, exist_ok=True)
    (drawable / "ic_launcher_background.xml").write_text(
        """<?xml version="1.0" encoding="utf-8"?>
<vector xmlns:android="http://schemas.android.com/apk/res/android"
    android:width="108dp"
    android:height="108dp"
    android:viewportWidth="108"
    android:viewportHeight="108">
    <path android:fillColor="#B72D26" android:pathData="M0,0h108v108h-108z"/>
</vector>
""",
        encoding="utf-8",
    )

    # XML des icônes adaptatives (Android 8+)
    for name in ("ic_launcher", "ic_launcher_round"):
        xml = RES / f"mipmap-anydpi-v26" / f"{name}.xml"
        xml.parent.mkdir(parents=True, exist_ok=True)
        xml.write_text(
            """<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@drawable/ic_launcher_background"/>
    <foreground android:drawable="@mipmap/ic_launcher_foreground"/>
    <monochrome android:drawable="@mipmap/ic_launcher_foreground"/>
</adaptive-icon>
""",
            encoding="utf-8",
        )
        print(f"{xml.relative_to(ROOT)}", file=sys.stderr)


def _circular(img: Image.Image) -> Image.Image:
    size = img.width
    ss = 4
    mask = Image.new("L", (size * ss, size * ss), 0)
    ImageDraw.Draw(mask).ellipse([0, 0, size * ss - 1, size * ss - 1], fill=255)
    mask = mask.resize((size, size), Image.LANCZOS)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    out.paste(img, (0, 0), mask)
    return out


if __name__ == "__main__":
    main()
