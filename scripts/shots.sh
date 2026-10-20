#!/usr/bin/env bash
# Draw every image the docs and the landing page show, into docs/images: the gallery with `undertone render`, then the
# app's own images (the settings window, the laptops, the brand mark) with UNDERTONE_SHOTS. Every picture comes from a
# fixed recipe, so a run on any Mac draws the same images; nothing is read from the screen or the settings.
#
#   mise run shots      (builds build/Undertone.app first)
set -euo pipefail
root="$(cd "$(dirname "$0")/.." && pwd)"
cd "$root"
app="${BUILD_DIR:-$root/build}/Undertone.app"
render="$app/Contents/Helpers/undertone render"
shots="docs/images/shots"
rm -rf "$shots"
mkdir -p "$shots"/{styles,tonalities,spaces,grain}

# Each style in the tonality it is shown in, dark and light.
seed=11
for pair in mesh:ember flow:dusk waves:tide orbs:aurora rings:citrus dunes:dusk contour:glacier silk:ember \
  aurora:aurora bauhaus:moss blobs:dusk; do
  style="${pair%%:*}" tonality="${pair##*:}"
  for appearance in dark light; do
    $render --style "$style" --tonality "$tonality" --appearance "$appearance" --seed "$seed" \
      --size 960x624 --scale 1 -o "$shots/styles/$style-$appearance.jpg"
  done
  seed=$((seed + 1))
done

# Shuffles for the landing page's tiles to cycle through: each style locked, the tonality and seed picked anew, as a
# shuffle with a locked style does. shuffles.json names each one's tonality for the captions.
tonalities=($("$app/Contents/Helpers/undertone" tonalities))
mkdir -p "$shots/styles/shuffles"
json="{"
index=0
for style in $("$app/Contents/Helpers/undertone" styles | awk '{print $1}'); do
  names=""
  for n in 1 2 3 4; do
    tonality="${tonalities[$(((index * 3 + n * 2 + 1) % ${#tonalities[@]}))]}"
    for appearance in dark light; do
      $render --style "$style" --tonality "$tonality" --appearance "$appearance" --seed $((1000 + index * 10 + n)) \
        --size 640x416 --scale 1 --grain 0.02 -o "$shots/styles/shuffles/$style-$appearance-$n.jpg"
    done
    names="$names${names:+,}\"$tonality\""
  done
  [ "$index" -eq 0 ] || json="$json,"
  json="$json\"$style\":[$names]"
  index=$((index + 1))
done
echo "$json}" >"$shots/styles/shuffles/shuffles.json"

# Every effect on the same four pictures, dark and light, for the landing page's effect tiles and the docs.
mkdir -p "$shots/effects"
for effect in $("$app/Contents/Helpers/undertone" effects | awk '$1 != "none" {print $1}'); do
  # Dithering leaves 64 colours, which a PNG holds in less than a JPEG does.
  extension=jpg
  [ "$effect" = dither ] && extension=png
  n=1
  for recipe in aurora:aurora:19 waves:tide:100 rings:citrus:4 orbs:aurora:14; do
    IFS=: read -r style tonality seed <<<"$recipe"
    for appearance in dark light; do
      $render --style "$style" --tonality "$tonality" --appearance "$appearance" --seed "$seed" --effect "$effect" \
        --size 800x520 --scale 1.25 --grain 0.02 -o "$shots/effects/$effect-$appearance-$n.$extension"
    done
    n=$((n + 1))
  done
done

# Every tonality in one style, so only the colours change.
for tonality in $("$app/Contents/Helpers/undertone" tonalities); do
  for appearance in dark light; do
    $render --style waves --tonality "$tonality" --appearance "$appearance" --seed 30 \
      --size 640x416 --scale 1 -o "$shots/tonalities/$tonality-$appearance.jpg"
  done
done

# A picture per space: one style and tonality, a seed each.
for space in 1 2 3; do
  $render --style dunes --tonality tide --appearance dark --seed $((200 + space)) \
    --size 800x520 --scale 1 -o "$shots/spaces/space-$space.jpg"
done

# Grain, close up: a Retina-sized corner of the same picture without and with it.
for grain in 0 0.06; do
  $render --style flow --tonality dusk --appearance dark --seed 12 --grain "$grain" \
    --size 900x560 --scale 2 -o "$shots/grain/grain-$grain.jpg"
done

# The picture social sites show for a link.
$render --style aurora --tonality aurora --appearance dark --seed 19 --grain 0.04 --size 1280x640 --scale 1 \
  --title Undertone --subtitle "Hide the notch. Keep the colour." -o docs/images/social.jpg

UNDERTONE_SHOTS="$root/docs/images" "$app/Contents/MacOS/Undertone"
du -sh docs/images | sed 's/^/shots: /'
