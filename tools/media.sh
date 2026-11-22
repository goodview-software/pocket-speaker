#!/bin/sh
# Pilote le lecteur multimédia du PC (MPRIS) : media.sh playpause | back
P=/org/mpris/MediaPlayer2; I=org.mpris.MediaPlayer2.Player
best=""; paused=""
for n in $(busctl --user list --no-legend 2>/dev/null | awk '{print $1}' | grep '^org.mpris.MediaPlayer2\.'); do
  st=$(busctl --user get-property "$n" $P $I PlaybackStatus 2>/dev/null)
  case "$st" in *Playing*) best="$n"; break;; *Paused*) [ -z "$paused" ] && paused="$n";; esac
done
[ -z "$best" ] && best="$paused"
[ -z "$best" ] && exit 1
case "$1" in
  playpause) busctl --user call "$best" $P $I PlayPause >/dev/null ;;
  back) busctl --user call "$best" $P $I Seek x -5000000 >/dev/null ;;
esac
