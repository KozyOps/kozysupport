#!/usr/bin/env bash
# Regenerates every icon in this directory from the KozyOps mark below (the
# brand file is web/src/assets/kozy_branding/BrandColor(BG)-Icon.svg in
# KozyOps/platform). The outputs are committed, so CI needs none of these tools:
# rsvg-convert, ImageMagick 7 and python3. kozy/rebrand.py copies them over
# upstream's icons at build time.
set -euo pipefail
cd "$(dirname "$0")"

# The mark spans x 227-332, y 80-211 in the brand file; centre (279.5, 145.5).
mark() { # $1 = white-part colour, $2 = accent colour
  cat <<SVG
<path d="M318.63 139.868L329.511 151.959C331.037 146.877 331.914 141.588 331.914 136.143C331.914 105.136 308.453 80 279.513 80C250.574 80 227.113 105.136 227.113 136.143C227.113 141.592 227.991 146.885 229.519 151.971L240.398 139.883C240.276 138.639 240.213 137.392 240.213 136.143C240.213 111.505 258.645 93.1 279.513 93.1C300.382 93.1 318.813 111.505 318.813 136.143C318.813 137.387 318.751 138.629 318.63 139.868Z" fill="$1"/>
<rect x="263.133" y="119.303" width="13.1" height="13.1" fill="$2"/>
<rect x="282.781" y="119.303" width="13.1" height="13.1" fill="$2"/>
<rect x="263.133" y="138.953" width="13.1" height="13.1" fill="$2"/>
<rect x="282.781" y="138.953" width="13.1" height="13.1" fill="$2"/>
<path d="M314.473 154.826C310.382 163.928 303.782 172.572 296.333 180.221C290.354 186.36 284.33 191.341 279.786 194.789L279.518 194.992L279.25 194.789C274.706 191.341 268.681 186.36 262.703 180.221C255.256 172.575 248.659 163.935 244.567 154.837L235.145 165.307C249.827 192.443 279.518 210.999 279.518 210.999C279.518 210.999 309.216 192.438 323.897 165.297L314.473 154.826Z" fill="$2"/>
SVG
}
# $1 canvas, $2 tile inset, $3 tile corner radius, $4 mark height, $5 white, $6 accent, $7 tile colour or none
svg() {
  local c=$1 tile=$(( $1 - 2 * $2 )) s; s=$(python3 -c "print(round($4 / 131, 5))")
  echo "<svg xmlns=\"http://www.w3.org/2000/svg\" width=\"$c\" height=\"$c\" viewBox=\"0 0 $c $c\">"
  [ "$7" = none ] || echo "<rect x=\"$2\" y=\"$2\" width=\"$tile\" height=\"$tile\" rx=\"$3\" fill=\"$7\"/>"
  echo "<g transform=\"translate($(( c / 2 )) $(( c / 2 ))) scale($s) translate(-279.5 -145.5)\">"
  mark "$5" "$6"
  echo "</g></svg>"
}

# Windows, Linux and the in-app icon: a full-bleed tile, like upstream's.
svg 1024 0 224 600 white '#CF17BF' '#202033' > icon.svg
# macOS: Apple's grid, an 824 tile on a 1024 canvas with a 185 corner radius.
svg 1024 100 185 480 white '#CF17BF' '#202033' > mac-icon.svg
# macOS menu bar: a template image, so only the alpha channel counts.
svg 60 0 0 54 black black none > mac-tray.svg

png() { rsvg-convert -w "$2" -h "$2" "$1" -o "$3"; }
png icon.svg 1024 icon.png
png mac-icon.svg 1024 mac-icon.png
for s in 32 64 128; do png icon.svg $s ${s}x${s}.png; done
png icon.svg 256 128x128@2x.png
png mac-tray.svg 60 mac-tray-dark-x2.png
cp icon.svg scalable.svg

tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
for s in 16 24 32 48 64 128 256; do png icon.svg $s "$tmp/$s.png"; done
magick "$tmp"/{16,24,32,48,64,128,256}.png icon.ico
magick "$tmp"/{16,24,32}.png tray-icon.ico

# .icns is a header and a list of (type, length, PNG) records.
for s in 16 32 64 128 256 512 1024; do png mac-icon.svg $s "$tmp/m$s.png"; done
python3 - "$tmp" <<'PY'
import struct, sys
d = sys.argv[1]
types = [("icp4", 16), ("icp5", 32), ("ic11", 32), ("ic12", 64), ("ic07", 128),
         ("ic13", 256), ("ic08", 256), ("ic14", 512), ("ic09", 512), ("ic10", 1024)]
body = b"".join(t.encode() + struct.pack(">I", 8 + len(b)) + b
                for t, s in types for b in [open(f"{d}/m{s}.png", "rb").read()])
open("AppIcon.icns", "wb").write(b"icns" + struct.pack(">I", 8 + len(body)) + body)
PY
echo "brand: icons regenerated"
