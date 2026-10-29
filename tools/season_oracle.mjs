// Independent reference implementation of the season contract (BigInt), written
// from the specification in Android's SeasonRandom.kt — no Swift/Kotlin code is
// reused, so agreement between it and the app is real evidence.
//
//   node tools/season_oracle.mjs <seedHex>   # prints config, deals 0/1/2/7, bot doubles
//
// Cross-check the Swift engine against it for any seed (e.g. the live season):
//   PREF_SEASON_SEED=<hex> PREF_SEASON_DUMP=/tmp/swift.json \
//     swift test --filter testDumpSeasonForSeed   (in PrefEngine/)
//   node tools/season_oracle.mjs <hex> > /tmp/oracle.json   # then compare the two
// Independent reference implementation of the season contract, written from the
// SPEC (SeasonRandom.kt doc comment), using BigInt. No Swift/Kotlin code reused.
import { createHash } from 'node:crypto';
const M = (1n << 64n) - 1n;
class Rng {
  constructor(seed, purpose, index) {
    const d = createHash('sha256').update(`${seed}|${purpose}|${index}`, 'utf8').digest();
    this.s = d.readBigUInt64BE(0);
  }
  next() {
    this.s = (this.s + 0x9E3779B97F4A7C15n) & M;
    let z = this.s;
    z = ((z ^ (z >> 30n)) * 0xBF58476D1CE4E5B9n) & M;
    z = ((z ^ (z >> 27n)) * 0x94D049BB133111EBn) & M;
    return z ^ (z >> 31n);
  }
  nextInt(b) { return Number((this.next() >> 1n) % BigInt(b)); }
  nextDouble() { return Number(this.next() >> 11n) * (1 / 9007199254740992); }
}
const LIMITS = [10, 20, 40, 60];
const TYPES = ['Sochy', 'Leningrad', 'Rostov'];
const PROG = ['NoProgression1', 'Arifm1233', 'Geom1244'];
const EXIT = ['Easy6', 'Med677', 'Hard678'];
const VIST = ['HalfResponsibility', 'FullResponsibility'];
const CONS = ['Gentlemen', 'Zlob'];
function config(seed) {
  const r = new Rng(seed, 'config', 0);
  const limit = LIMITS[r.nextInt(4)];
  const type = TYPES[r.nextInt(3)];
  const prog = PROG[r.nextInt(3)];
  const exit = EXIT[r.nextInt(3)];
  const miserExit = r.nextInt(2) === 1;
  const vist = VIST[r.nextInt(2)];
  const consolation = CONS[r.nextInt(2)];
  const talon = r.nextInt(2) === 1;
  const firstDealer = r.nextInt(3);
  return { limit, type, progression: type === 'Rostov' ? 'NoProgression1' : prog, exit, miserExit, vist, consolation, talon, firstDealer };
}
function deal(seed, index) {
  const r = new Rng(seed, 'deal', index);
  const prikup = [];
  for (let v = 7; v <= 14; v++) for (let c = 0; c < 4; c++) prikup.push(v + c * 100);
  const hands = [];
  for (let h = 0; h < 3; h++) {
    const hand = [];
    for (let k = 0; k < 10; k++) { const pos = r.nextInt(prikup.length); hand.push(prikup[pos]); prikup.splice(pos, 1); }
    hands.push(hand);
  }
  return { hands, prikup };
}
const seed = process.argv[2];
const out = {
  config: config(seed),
  deals: [0, 1, 2, 7].map((i) => ({ index: i, ...deal(seed, i) })),
  botDoubles: (() => { const r = new Rng(seed, 'bots', 7); return [r.nextDouble(), r.nextDouble()]; })(),
};
console.log(JSON.stringify(out));
