#!/bin/sh
# Rebuilds chordpad_midi_send and chordpad_bridge_daemon from source and
# deploys them to ~/.chordpad/keyboard_bridge/.
#
# The binaries are NOT run from this repo checkout (under ~/Documents/...)
# because that's a TCC-protected folder (Desktop/Documents/Downloads):
# launched interactively (Terminal, this build script) that's fine since the
# calling process already has standing consent, but launchd (the daemon's
# LaunchAgent) and Karabiner's grabber spawn processes outside that trusted
# context, and dyld hangs indefinitely inside open() during TCC evaluation
# before the process even reaches main(). ~/.chordpad avoids both the TCC
# hang and (unlike ~/Library/Application Support) a space in the path, which
# would otherwise need careful quoting in the Karabiner shell_command rule.
# Re-run this script after editing either .swift file.
set -e
cd "$(dirname "$0")"
DEST="$HOME/.chordpad/keyboard_bridge"
mkdir -p "$DEST"
swiftc -O chordpad_midi_send.swift -o "$DEST/chordpad_midi_send"
swiftc -O chordpad_bridge_daemon.swift -o "$DEST/chordpad_bridge_daemon"
echo "Built $DEST/chordpad_midi_send"
echo "Built $DEST/chordpad_bridge_daemon"
