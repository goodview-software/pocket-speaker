#!/bin/sh
# Publie une version : ./release.sh 0.2.0 "Notes"
# Exporte le zip Linux (avec l'APK à côté, installé automatiquement sur le téléphone) et l'APK.
set -e
V="$1"; NOTES="${2:-Version $1}"
[ -n "$V" ] || { echo "usage: $0 <version> [notes]"; exit 1; }
cd "$(dirname "$0")"
REPO=goodview-software/pocket-speaker
GODOT="flatpak run org.godotengine.Godot"
OUT=build/release; rm -rf "$OUT"; mkdir -p "$OUT" build/linux

sed -i "s/^const VERSION := .*/const VERSION := \"$V\"/" version.gd
sed -i "s/^version\/name=.*/version\/name=\"$V\"/" export_presets.cfg
CODE=$(echo "$V" | awk -F. '{print $1*10000+$2*100+$3}')  # versionCode croissant : sans ça Android/le PC ne réinstallent jamais l'APK
sed -i "s/^version\/code=.*/version\/code=$CODE/" export_presets.cfg
sed -i "s/^const VERSION := [0-9]*.*/const VERSION := $CODE  # versionCode de l'APK/" main.gd
$GODOT --headless --path . --export-debug "Android" "$OUT/PocketSpeaker.apk"
ENGINE="$($GODOT --version | cut -d. -f1-3)"
$GODOT --headless --path . --export-pack "Linux" "$OUT/pocket-speaker-$V.pck"
$GODOT --headless --path . --export-release "Linux" build/linux/PocketSpeaker.x86_64
cp "$OUT/PocketSpeaker.apk" build/linux/pocket-speaker.apk
cp "$OUT/PocketSpeaker.apk" build/pocket-speaker.apk
cp icon.png tools/vosk_stream.py tools/media.sh build/linux/
rm -rf build/PocketSpeaker && cp -r build/linux build/PocketSpeaker
(cd build && zip -qr "release/PocketSpeaker-linux.zip" PocketSpeaker) && rm -rf build/PocketSpeaker
rm -f "$OUT"/*.idsig

SHA="$(sha256sum "$OUT/pocket-speaker-$V.pck" | cut -d' ' -f1)"
cat > "$OUT/version.json" <<J
{"version": "$V", "godot": "$ENGINE", "sha256": "$SHA",
 "pck": "https://github.com/$REPO/releases/download/v$V/pocket-speaker-$V.pck"}
J
git add -A && git commit -qm "Version $V" || true
git tag -f "v$V" && git push -q origin HEAD && git push -qf origin "v$V"
gh release create "v$V" --repo "$REPO" --title "Pocket Speaker $V" --notes "$NOTES" "$OUT"/*
echo "Publié : https://github.com/$REPO/releases/tag/v$V"
