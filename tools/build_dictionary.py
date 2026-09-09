#!/usr/bin/env python3
"""
Build glozi.sqlite from CC-CEDICT.

Development-time tool. Run this on a Mac, commit the resulting .sqlite,
and ship it inside the app bundle. It never runs on a phone.

    python3 tools/build_dictionary.py

Reads   data/cedict_ts.u8
Writes  data/glozi.sqlite
"""

import re
import sqlite3
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / "data" / "cedict_ts.u8"
OUTPUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "data" / "glozi.sqlite"

# A CC-CEDICT line:  傳統 简体 [pin1 yin1] /gloss/gloss/
LINE = re.compile(r"^(\S+)\s+(\S+)\s+\[([^\]]*)\]\s+/(.*)/\s*$")

# Tone marks, indexed by tone number 1-4. Tone 5 (neutral) gets no mark.
TONE_MARKS = {
    "a": "āáǎà", "e": "ēéěè", "i": "īíǐì",
    "o": "ōóǒò", "u": "ūúǔù", "ü": "ǖǘǚǜ",
    "A": "ĀÁǍÀ", "E": "ĒÉĚÈ", "I": "ĪÍǏÌ",
    "O": "ŌÓǑÒ", "U": "ŪÚǓÙ", "Ü": "ǕǗǙǛ",
}

VOWELS = "aeiouüAEIOUÜ"


def mark_syllable(syllable):
    """'hou4' -> 'hòu'.  'lu:4' -> 'lǜ'.  'de5' -> 'de'.  'Qu1' -> 'Qū'."""

    # CC-CEDICT writes ü as 'u:' (and occasionally 'v').
    syllable = syllable.replace("u:", "ü").replace("U:", "Ü").replace("v", "ü")

    if not syllable or not syllable[-1].isdigit():
        return syllable          # not a toned syllable: punctuation, a number, "xx"

    tone = int(syllable[-1])
    body = syllable[:-1]

    if tone in (0, 5):
        return body              # neutral tone carries no mark

    # Where the mark goes. This is the standard rule and it is only three cases:
    #   an 'a' always wins, otherwise an 'e' wins, otherwise in 'ou' it is the o,
    #   and failing all that it is the last vowel in the syllable.
    lowered = body.lower()
    if "a" in lowered:
        position = lowered.index("a")
    elif "e" in lowered:
        position = lowered.index("e")
    elif "ou" in lowered:
        position = lowered.index("ou")
    else:
        vowel_positions = [i for i, c in enumerate(body) if c in VOWELS]
        if not vowel_positions:
            return body          # no vowel to mark, e.g. the erhua 'r5'
        position = vowel_positions[-1]

    vowel = body[position]
    if vowel not in TONE_MARKS:
        return body

    return body[:position] + TONE_MARKS[vowel][tone - 1] + body[position + 1:]


def to_tone_marks(numbered):
    """'hou4 duan4' -> 'hòu duàn'."""
    return " ".join(mark_syllable(s) for s in numbered.split())


def build():
    if not SOURCE.exists():
        sys.exit(f"Source dictionary not found at {SOURCE}")

    if OUTPUT.exists():
        OUTPUT.unlink()          # rebuild from scratch every time

    db = sqlite3.connect(OUTPUT)
    db.executescript("""
        CREATE TABLE entries (
            simplified       TEXT NOT NULL,
            traditional      TEXT NOT NULL,
            pinyin           TEXT NOT NULL,   -- tone marks, for display
            pinyin_numbered  TEXT NOT NULL,   -- as CC-CEDICT wrote it
            definitions      TEXT NOT NULL    -- glosses, one per line
        );
    """)

    rows = []
    skipped = 0

    with SOURCE.open(encoding="utf-8") as f:
        for line in f:
            if line.startswith("#") or not line.strip():
                continue

            match = LINE.match(line)
            if not match:
                skipped += 1
                continue

            traditional, simplified, numbered, glosses = match.groups()
            rows.append((
                simplified,
                traditional,
                to_tone_marks(numbered),
                numbered,
                "\n".join(glosses.split("/")),
            ))

    db.executemany("INSERT INTO entries VALUES (?, ?, ?, ?, ?)", rows)

    # Indexes go in after the bulk insert, which is much faster than
    # maintaining them for every one of 125,000 rows.
    db.executescript("""
        CREATE INDEX index_simplified  ON entries(simplified);
        CREATE INDEX index_traditional ON entries(traditional);
    """)

    db.commit()

    longest = max(len(r[0]) for r in rows)
    size_mb = OUTPUT.stat().st_size / 1_000_000

    print(f"Wrote {len(rows):,} entries to {OUTPUT.name} ({size_mb:.1f} MB)")
    print(f"Skipped {skipped} unparseable lines")
    print(f"Longest simplified headword: {longest} characters")

    db.close()


if __name__ == "__main__":
    build()
