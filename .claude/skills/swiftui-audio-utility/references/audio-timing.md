# Audio timing & tempo maths

Reference for the calculations these apps perform. All durations in
milliseconds unless noted.

## Table of contents

- [Beat and note durations](#beat-and-note-durations)
- [Dotted and triplet feels](#dotted-and-triplet-feels)
- [Milliseconds ↔ Hz ↔ samples](#milliseconds--hz--samples)
- [Time signatures / bars](#time-signatures--bars)
- [Reverb: pre-delay and decay](#reverb-pre-delay-and-decay)
- [Tap tempo](#tap-tempo)
- [Reverse lookup (time → note)](#reverse-lookup-time--note)
- [Reference values at 120 BPM](#reference-values-at-120-bpm)

## Beat and note durations

One quarter note (one beat in 4/4):

```
quarterNoteMs = 60_000 / BPM
```

A note's duration is the quarter-note duration scaled by how many beats it
spans:

| Note        | Beats (quarter = 1) | Formula                |
|-------------|---------------------|------------------------|
| Whole       | 4                   | quarterNoteMs × 4      |
| Half        | 2                   | quarterNoteMs × 2      |
| Quarter     | 1                   | quarterNoteMs          |
| Eighth      | 1/2                 | quarterNoteMs / 2      |
| Sixteenth   | 1/4                 | quarterNoteMs / 4      |
| 32nd        | 1/8                 | quarterNoteMs / 8      |
| 64th        | 1/16                | quarterNoteMs / 16     |
| 128th       | 1/32                | quarterNoteMs / 32     |

Model this as one `enum` case per base with a `beats: Double`, then derive
everything — don't hand-write 21 formulas.

## Dotted and triplet feels

Apply a multiplier to any base note:

| Feel     | Multiplier | Meaning                                   |
|----------|------------|-------------------------------------------|
| Straight | 1          | the note as written                       |
| Dotted   | 1.5        | note + half its value (3 of the next subdivision) |
| Triplet  | 2/3        | three in the space of two                 |

```
noteMs = quarterNoteMs × beats(base) × factor(feel)
```

Dotted eighth (a staple delay setting for "the edge" slap) at 120 BPM:
`500 × 0.5 × 1.5 = 375 ms`.

## Milliseconds ↔ Hz ↔ samples

```
hz       = 1000 / noteMs           // frequency whose period is the note
samples  = noteMs / 1000 × sampleRate
noteMs   = 1000 / hz
noteMs   = samples / sampleRate × 1000
```

Hz output matters for syncing LFOs, tremolo, auto-pan, and filter movement to
tempo. Samples output matters for sample-delay plugins and loudspeaker /
mic time-alignment. Common sample rates: 44100, 48000, 88200, 96000, 192000.

Guard: if `noteMs == 0` (BPM 0 or missing), return 0 for hz/samples rather than
dividing.

## Time signatures / bars

A bar lasts `beatsPerBar × (beatUnit relative to quarter) × quarterNoteMs`.
In X/4 that's simply `X × quarterNoteMs`. In X/8, the eighth is the beat:
`X × (quarterNoteMs / 2)`. Supporting arbitrary `n/d` lets odd-meter users
(5/8, 7/8, 12/8) get bar-length reverb tails. Offer whole/half/quarter bars and
"n bars" as reverb length options.

## Reverb: pre-delay and decay

Producers sync reverb two ways:

**Pre-delay** = the gap before the reverb tail starts. Setting it to a small
note value keeps the dry transient clear and locks the wash to the grid.
Typical: 1/64 to 1/16 note.

```
preDelayMs = quarterNoteMs × beats(preDelayNote)      // e.g. 1/32 → /8
```

**Decay / reverb time** = how long the tail rings. Sync it to a musical length
so the tail resolves with the music (often 1 beat to 2 bars). A common working
rule:

```
decayMs = targetNoteOrBarMs − preDelayMs
```

so the reverb has faded by the next hit. For hall/plate/room presets, seed
sensible defaults (e.g. room ≈ 1 beat, plate ≈ 1 bar, hall ≈ 2 bars) and let
the user save custom sizes.

RT60 (time for the tail to drop 60 dB) is the plugin's own parameter; the
calculator's job is only to suggest a musical value to dial in.

## Tap tempo

```
BPM = 60_000 / averageIntervalMs
```

where `averageIntervalMs` is the mean of the last N inter-tap gaps measured on
a **monotonic** clock. See SKILL.md for the windowing, outlier-rejection and
stale-reset rules. Clamp the result to the app's valid BPM range.

## Reverse lookup (time → note)

Given a delay time the user dialled in by ear, find the closest musical value:

1. For the current BPM, compute `noteMs` for every base × feel.
2. Return the entries with the smallest `abs(noteMs − target)`, sorted.
3. Optionally solve for the BPM that makes the target land exactly on a chosen
   subdivision: `BPM = 60_000 × beats × factor / targetMs`.

No competing app does this well — it's a strong feature.

## Reference values at 120 BPM

Quarter = 500 ms. Use these to sanity-check an implementation:

| Note              | Straight | Dotted  | Triplet |
|-------------------|----------|---------|---------|
| Whole             | 2000     | 3000    | 1333.33 |
| Half              | 1000     | 1500    | 666.67  |
| Quarter           | 500      | 750     | 333.33  |
| Eighth            | 250      | 375     | 166.67  |
| Sixteenth         | 125      | 187.5   | 83.33   |
| 32nd              | 62.5     | 93.75   | 41.67   |
| 64th              | 31.25    | 46.875  | 20.83   |

Quarter note in Hz at 120 BPM: `1000 / 500 = 2.0 Hz`.
Quarter note in samples at 48 kHz: `0.5 × 48000 = 24000`.
