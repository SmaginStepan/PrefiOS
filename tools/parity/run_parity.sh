#!/usr/bin/env bash
# Runs Android's UNMODIFIED engine (model/ + ai/, minus GlobalScores.kt) on the JVM
# and prints the bot-vs-bot season transcript for a seed, so it can be diffed with
# the Swift engine's (SeasonTests.testDumpSeasonBotRun).
#
#   tools/parity/run_parity.sh <season-seed> <pools> [path-to-PrefAndroid]
#
# Needs: curl, tar, unzip. Downloads JDK 21, kotlinc and kotlinx-serialization
# into ~/.cache/pref-parity on first use.
set -euo pipefail
SEED=${1:?seed}; POOLS=${2:?pools}
ANDROID=${3:-"$(cd "$(dirname "$0")/../../.." && pwd)/PrefAndroid"}
HERE=$(cd "$(dirname "$0")" && pwd)
C=$HOME/.cache/pref-parity; mkdir -p "$C"
SRC=$ANDROID/app/src/main/java/com/an0obIs/pref
[ -d "$SRC/model" ] || { echo "Android sources not found at $ANDROID" >&2; exit 1; }

if [ ! -d "$C/jdk" ]; then
  case "$(uname -m)" in arm64) A=aarch64;; *) A=x64;; esac
  mkdir -p "$C/jdk"
  curl -fsSL "https://api.adoptium.net/v3/binary/latest/21/ga/mac/$A/jdk/hotspot/normal/eclipse" | tar xz -C "$C/jdk" --strip-components=1
fi
export JAVA_HOME=$C/jdk/Contents/Home
if [ ! -d "$C/kotlinc" ]; then
  curl -fsSL -o "$C/kotlin.zip" https://github.com/JetBrains/kotlin/releases/download/v2.2.20/kotlin-compiler-2.2.20.zip
  unzip -q "$C/kotlin.zip" -d "$C" && rm "$C/kotlin.zip"
fi
M=https://repo1.maven.org/maven2/org/jetbrains/kotlinx
[ -f "$C/ser-core.jar" ] || curl -fsSL -o "$C/ser-core.jar" $M/kotlinx-serialization-core-jvm/1.9.0/kotlinx-serialization-core-jvm-1.9.0.jar
[ -f "$C/ser-json.jar" ] || curl -fsSL -o "$C/ser-json.jar" $M/kotlinx-serialization-json-jvm/1.9.0/kotlinx-serialization-json-jvm-1.9.0.jar

# keyed by the Android commit so a changed engine is always recompiled
REV=$(git -C "$ANDROID" rev-parse --short HEAD)-$(cd "$SRC" && cat model/*.kt ai/*.kt | shasum | cut -c1-8)
JAR=$C/engine-$REV.jar
if [ ! -f "$JAR" ]; then
  # the serialization compiler plugin ships inside the kotlinc distribution
  "$C/kotlinc/bin/kotlinc" -nowarn -jvm-target 21 \
    -Xplugin="$C/kotlinc/lib/kotlin-serialization-compiler-plugin.jar" \
    -cp "$C/ser-core.jar:$C/ser-json.jar" \
    $(ls "$SRC"/model/*.kt | grep -v GlobalScores.kt) "$SRC"/ai/*.kt \
    "$HERE"/stubs/*.kt "$HERE/Main.kt" -d "$JAR"
fi
exec "$JAVA_HOME/bin/java" -cp "$JAR:$C/kotlinc/lib/kotlin-stdlib.jar:$C/ser-core.jar:$C/ser-json.jar" MainKt "$SEED" "$POOLS"
