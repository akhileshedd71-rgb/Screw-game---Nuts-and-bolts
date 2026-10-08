#!/usr/bin/env python3
"""Rebuild the bundled open fonts from a checksum-verified upstream revision.

The game uses the already bundled TTFs and has no font download dependency.
For maintainers: python -m pip install fonttools==4.61.1, then run this file.
All requests use normal certificate verification and the environment proxy.
"""
from hashlib import sha256
from io import BytesIO
from pathlib import Path
from urllib.request import urlopen

from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

REVISION = "2eb0b48d5f760f62e286216f0859a8c540dbc1bd"
BASE = f"https://raw.githubusercontent.com/google/fonts/{REVISION}/ofl/"
OUT = Path(__file__).resolve().parent
SOURCES = {
    "lilitaone/LilitaOne-Regular.ttf": "f5b641c45c69d772ee4eda687bc9fda411d5cad6b0b45371491da4580cbc8d59",
    "lilitaone/OFL.txt": "255d5debbb80eb2ea762644311f266a279e8778f00156655a516e2b7781a63e1",
    "nunito/Nunito%5Bwght%5D.ttf": "bb55a5ca5c2042335b3991af27c4d0705d0ef41cac6164ac737fd8f2a1e85207",
    "nunito/OFL.txt": "580df76c95a1ec5ab878ceb25bb3d85c6a076804e9c970c8c6972aea775fdf65",
}


def verified(relative):
    with urlopen(BASE + relative, timeout=45) as response:
        data = response.read()
    if sha256(data).hexdigest() != SOURCES[relative]:
        raise ValueError(f"Checksum mismatch for {relative}; no output written")
    return data


def main():
    lilita = verified("lilitaone/LilitaOne-Regular.ttf")
    lilita_license = verified("lilitaone/OFL.txt")
    nunito = verified("nunito/Nunito%5Bwght%5D.ttf")
    nunito_license = verified("nunito/OFL.txt")
    (OUT / "LilitaOne-Regular.ttf").write_bytes(lilita)
    (OUT / "LICENSE-Lilita-One.txt").write_bytes(lilita_license)
    (OUT / "LICENSE-Nunito.txt").write_bytes(nunito_license)
    for weight, style in ((400, "Regular"), (800, "ExtraBold")):
        font = TTFont(BytesIO(nunito), recalcTimestamp=False)
        instance = instantiateVariableFont(font, {"wght": weight}, updateFontNames=True)
        target = OUT / f"Nunito-{style}.ttf"
        instance.save(target)
        print(target.name, sha256(target.read_bytes()).hexdigest())


if __name__ == "__main__":
    main()
