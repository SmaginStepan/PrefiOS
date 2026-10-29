# Android-engine parity harness

Seasons only work if iOS and Android deal and play identically. This runs Android's
real engine (copied verbatim from `PrefAndroid`, nothing edited) on the JVM, with
all three seats played by the bots, and prints one line per deal (contract, tricks,
visters, dealer, bot RNG state...).

```
tools/parity/run_parity.sh <seed> <pools> [../PrefAndroid] > kotlin.txt
```

The Swift side is `SeasonTests.testDumpSeasonBotRun` (set `PREF_PARITY_SEED`, `PREF_PARITY_POOLS`,
`PREF_PARITY_DUMP`); the two files must be identical. `SeasonParityFixtures.swift` holds
golden transcripts produced this way, so the normal test run guards the bots' behaviour
without needing a JVM. Re-run after any Android engine change and before each new
season if the AI changed.
