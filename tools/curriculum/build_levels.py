#!/usr/bin/env python3
"""Builds the English course: every world and level, from tables.

The course teaches one new thing per level in 8 to 10 games, and no two
games of a level are of the same kind (a child notices a repeat; a shorter
level is better than a repeated game). This script writes the levels from
the tables here and in later_worlds.py, so a change to the plan is one edit,
not 210 hand-edited files. Every world has 15 levels and ends in its boss:

    world 1  Letter Land        1-15   capitals A-M in alphabet order, nine games a
                                       letter, a review after G, the Sleepy Snail boss
    world 2  Alphabet Jungle    16-30  capitals N-Z, a review after T, the Sleepy Monkey
    world 3  Small Letter Beach 31-45  small a-m with their sounds, the Sleepy Crab
    world 4  Letter Forest      46-60  small n-z with their sounds, the Sleepy Bear
    worlds 5-14                 61-210 phonics, first words, letter pairs, blends,
                                       sight words, sentences, doing words,
                                       questions, reading, stories (later_worlds.py)

Worlds 1 and 2 (all 26 capitals) are free; Likho Plus from world 3 on.
Writing is always on the one paper pad.

    python3 tools/curriculum/build_levels.py          # write the levels
    python3 tools/curriculum/build_levels.py --check  # print the plan, write nothing

Then add any new pictures (tools/illustrations; --check lists them) and
record the new lines (tools/voice). Level numbers are what progress is
stored by: change the plan only before the course is published, or move
saved progress with it.
"""

import argparse
import json
import pathlib
import random
import re
import shutil

ROOT = pathlib.Path(__file__).resolve().parent.parent.parent
COURSE = ROOT / "backend" / "content" / "courses" / "english-handwriting"
WORLDS = COURSE / "worlds"
SCHEMA = "../../../../../schema/level.schema.json"

FREE_UP_TO = 30  # worlds 1 and 2 (capitals A-Z) are free; Likho Plus from world 3 on

# ------------------------------------------------------------------ letters

# letter -> (picture word, picture key, word with the letter to fill, index
# of the letter in it). The picture word starts with the letter's sound
# (short vowels: apple, egg, insect, octopus, umbrella). X has no word that
# starts with its sound, so it is "in box".
WORDS = {
    "a": ("apple", "apple", "apple", 0),
    "b": ("ball", "ball", "ball", 0),
    "c": ("cat", "cat", "cat", 0),
    "d": ("dog", "dog", "dog", 0),
    "e": ("egg", "egg", "egg", 0),
    "f": ("fish", "fish", "fish", 0),
    "g": ("goat", "goat", "goat", 0),
    "h": ("hat", "hat", "hat", 0),
    "i": ("insect", "insect", "pig", 1),
    "j": ("jam", "jam", "jam", 0),
    "k": ("kite", "kite", "kite", 0),
    "l": ("lion", "lion", "lion", 0),
    "m": ("moon", "moon", "moon", 0),
    "n": ("nest", "nest", "nest", 0),
    "o": ("octopus", "octopus", "dog", 1),
    "p": ("pig", "pig", "pig", 0),
    "q": ("queen", "queen", "queen", 0),
    "r": ("robot", "robot", "robot", 0),
    "s": ("sun", "sun", "sun", 0),
    "t": ("tiger", "tiger", "tiger", 0),
    "u": ("umbrella", "umbrella", "bus", 1),
    "v": ("violin", "violin", "violin", 0),
    "w": ("whale", "whale", "whale", 0),
    "x": ("box", "box", "box", 2),
    "y": ("yo-yo", "yoyo", "yoyo", 0),
    "z": ("zebra", "zebra", "zebra", 0),
}

# How the voice says a letter's name and its sound: {shown|IPA} (see
# tools/voice). Names are spelled out so "A" is not read as the word "a".
NAME = {
    "a": "ˈeɪ", "b": "bˈiː", "c": "sˈiː", "d": "dˈiː", "e": "ˈiː", "f": "ˈɛf", "g": "ʤˈiː", "h": "ˈeɪʧ", "i": "ˈaɪ",
    "j": "ʤˈeɪ", "k": "kˈeɪ", "l": "ˈɛl", "m": "ˈɛm", "n": "ˈɛn", "o": "ˈoʊ", "p": "pˈiː", "q": "kjˈuː", "r": "ˈɑːɹ",
    "s": "ˈɛs", "t": "tˈiː", "u": "jˈuː", "v": "vˈiː", "w": "dˈʌbəljuː", "x": "ˈɛks", "y": "wˈaɪ", "z": "zˈiː",
}
SOUND = {
    "a": "æ", "b": "bʌ", "c": "kʌ", "d": "dʌ", "e": "ɛ", "f": "fːː", "g": "ɡʌ", "h": "hʌ", "i": "ɪ", "j": "ʤʌ",
    "k": "kʌ", "l": "lːː", "m": "mːː", "n": "nːː", "o": "ɑ", "p": "pʌ", "q": "kwʌ", "r": "ɹːː", "s": "sːː", "t": "tʌ",
    "u": "ʌ", "v": "vːː", "w": "wʌ", "x": "ks", "y": "jʌ", "z": "zːː",
}

# Letters that look alike: the wrong answers in picks and hunts.
LOOKALIKE = {
    "A": "RHN", "B": "RPD", "C": "OGQ", "D": "OPB", "E": "FLH", "F": "EPT", "G": "COQ", "H": "NIE", "I": "LTH",
    "J": "ULI", "K": "XRH", "L": "TIE", "M": "NWH", "N": "MZH", "O": "QCD", "P": "RBD", "Q": "OGC", "R": "PBK",
    "S": "ZGC", "T": "ILF", "U": "VJO", "V": "WYU", "W": "MVN", "X": "YKV", "Y": "VXT", "Z": "NSX",
    "a": "doe", "b": "dph", "c": "eoa", "d": "baq", "e": "cao", "f": "tlj", "g": "qpy", "h": "nbk", "i": "jlt",
    "j": "igy", "k": "hxl", "l": "itk", "m": "nwh", "n": "mhu", "o": "ace", "p": "qbd", "q": "pgd", "r": "nvm",
    "s": "zce", "t": "fli", "u": "nvy", "v": "wuy", "w": "mvu", "x": "kzy", "y": "gvj", "z": "sxn",
}

# The alphabet worlds: capitals A to Z, then small a to z, in alphabet order
# (the order children and parents know), thirteen letters a world. A review
# follows the world's seventh letter and the world ends in its boss, which
# plays six letters from across the world and wakes on a word to finish.
#   folder, world.json fields, small letters?, letters before the review, the
#   review's name, letters after it, boss: (name, its letters, the word, the
#   word's picture, what Pencil says, intro text, intro picture)
ALPHABET = [
    ("01-letter-land", {"name": "Letter Land", "skill": "Capitals A to M", "icon": "grass", "themeId": "letterLand",
                        "boss": {"id": "snail", "name": "Sleepy Snail"}},
     False, "ABCDEFG", "A to G", "HIJKLM",
     ("Wake the Snail", "CFHJLM", "CAT", "cat", "{Shh|ʃːː}, the snail is sleeping. Let's wake it up with our capital letters!",
      "A B C", "snail")),
    ("02-alphabet-jungle", {"name": "Alphabet Jungle", "skill": "Capitals N to Z", "icon": "spa", "themeId": "actionJungle",
                            "boss": {"id": "monkey", "name": "Sleepy Monkey"}},
     False, "NOPQRST", "N to T", "UVWXYZ",
     ("Wake the Monkey", "PRSUWZ", "SUN", "sun",
      "The little monkey is fast asleep in the jungle. Let's write our capital letters to wake it up!", "N O P", "monkey")),
    ("03-small-letter-beach", {"name": "Small Letter Beach", "skill": "Small a to m & sounds", "icon": "beach_access", "themeId": "blendBeach",
                               "boss": {"id": "crab", "name": "Sleepy Crab"}},
     True, "abcdefg", "a to g", "hijklm",
     ("Wake the Crab", "bdghkm", "cat", "cat", "The crab is fast asleep on the beach. Let's write our small letters to wake it up!", "a b c", "crab")),
    ("04-letter-forest", {"name": "Letter Forest", "skill": "Small n to z & sounds", "icon": "forest", "themeId": "phonicsForest",
                          "boss": {"id": "bear", "name": "Sleepy Bear"}},
     True, "nopqrst", "n to t", "uvwxyz",
     ("Wake the Bear", "npqsuy", "nest", "nest", "The bear is fast asleep in the forest. Let's write our small letters to wake it up!",
      "n o p", "bear")),
]

# Pick shapes (letters float on the first four), taken in turn so
# neighbouring levels look different. Writing is always on the paper pad.
LETTER_SHAPES = ["balloon", "bubble", "kite", "fish", "shell", "mushroom", "cloud"]
PICTURE_SHAPES = ["card", "planet", "jar", "bucket"]


def name(ch):
    """The letter's name as the voice should say it."""
    return f"{{{ch}|{NAME[ch.lower()]}}}"


def sound(ch):
    return f"{{/{ch.lower()}/|{SOUND[ch.lower()]}}}"


def pic(key, label=None):
    return {"key": key, "label": label or key.replace("_", " "), "url": None}


def card(text=None, picture=None, listen=False):
    return {"text": text, "picture": picture, "listen": listen}


# ------------------------------------------------------------------ rounds

class Level:
    """Collects one level's rounds; ids are <level id>-r<n>, options <round>-o<n>."""

    def __init__(self, number, seed):
        self.number = number
        self.id = f"level-{number:02d}"
        self.rounds = []
        self.rnd = random.Random(seed)

    def _add(self, kind, text, say, crd, payload):
        rid = f"{self.id}-r{len(self.rounds) + 1}"
        prompt = {"text": text}
        if say and say != text:
            prompt["say"] = say
        r = {"id": rid, "type": kind, "prompt": prompt, "card": crd, kind: payload}
        if kind == "pick":
            for i, o in enumerate(payload["options"]):
                o["id"] = f"{rid}-o{i + 1}"
        self.rounds.append(r)

    def pick(self, text, say, crd, labels, answer, shape=None, pictures=None, hide=False, keep_order=False):
        order = list(labels)
        if not keep_order:  # the words of a sentence to tap stay in order
            self.rnd.shuffle(order)
        options = [{"id": "", "label": lab, "picture": (pictures or {}).get(lab), "color": None, "hideLabel": hide} for lab in order]
        self._add("pick", text, say, crd, {
            "options": options, "answer": {"kind": "label", "value": answer}, "shape": shape, "layout": None,
            "count": None, "choiceKey": None, "fixCapital": False,
        })

    def write(self, text, say, crd, mode, target, guide=None, word=None, missing=None):
        self._add("write", text, say, crd, {
            "mode": mode, "target": target, "guide": guide if guide is not None else target, "word": word,
            "missingIndex": missing, "sentence": False, "story": False,
        })

    def order(self, text, say, crd, tiles):
        self._add("order", text, say, crd, {"tiles": tiles})

    def speak(self, text, say, crd, expected):
        self._add("speak", text, say, crd, {"expected": expected})

    def hunt(self, text, say, crd, target, others, cells=12, found=4):
        grid = [target] * found + [others[i % len(others)] for i in range(cells - found)]
        self.rnd.shuffle(grid)
        self._add("hunt", text, say, crd, {"target": target, "grid": grid})

    def fix(self, text, say, crd, items):
        """Pencil's notebook: items are (text, how it is wrong: "mirror" / "upside" / None, letter index or None)."""
        self._add("fix", text, say, crd, {"items": [{"text": t, "wrong": how, "at": at} for t, how, at in items]})

    def sort(self, text, say, crd, bins, items):
        """bins: [(label, picture)]; items: [(label, picture, bin or None)], shuffled."""
        things = list(items)
        self.rnd.shuffle(things)
        self._add("sort", text, say, crd, {
            "bins": [{"label": lab, "picture": p, "bin": None} for lab, p in bins],
            "items": [{"label": lab, "picture": p, "bin": b} for lab, p, b in things],
        })

    def match(self, text, say, crd, pairs):
        """pairs: [((text, picture), (text, picture))]."""
        side = lambda x: {"text": x[0], "picture": x[1]}
        self._add("match", text, say, crd, {"pairs": [{"a": side(a), "b": side(b)} for a, b in pairs]})

    def pop(self, text, say, crd, target, others, count=5):
        self._add("pop", text, say, crd, {"target": target, "others": [o for o in unique(others) if o != target][:3], "count": count})

    def truth(self, text, say, crd, sentence, picture, answer):
        self._add("truth", text, say, crd, {"text": sentence, "picture": picture, "answer": answer})


def letter_case(ch, small):
    return ch.lower() if small else ch.upper()


def alphabet_run(ch, n=4, small=False):
    """n letters of the alphabet around ch (A B C D for A, W X Y Z for Z)."""
    abc = "abcdefghijklmnopqrstuvwxyz"
    i = abc.index(ch.lower())
    start = min(max(0, i - 1), 26 - n)
    return [letter_case(c, small) for c in abc[start:start + n]]


# letters whose words start with the same sound: never wrong answers for each other
SAME_SOUND = [set("ckq")]


def unique(xs):
    return list(dict.fromkeys(xs))


def picture_choices(ch, rnd, count=3):
    """The letter's picture and pictures of other letters' words."""
    clash = set().union(*[g for g in SAME_SOUND if ch.lower() in g]) | {ch.lower()}
    others = [c for c in WORDS if c not in clash and WORDS[c][0][0] not in clash]
    rnd.shuffle(others)
    keys = [ch.lower()] + others[:count - 1]
    return {WORDS[k][0]: pic(WORDS[k][1], WORDS[k][0]) for k in keys}


# Pictures whose word starts with the letter's sound (the hungry monster and
# the two baskets). Blends (fr, st) and letter pairs (sh, ch) are left out.
STARTS = {
    "a": ["apple"], "b": ["ball", "bat", "bag", "bed", "bee", "bus", "bug", "boat", "book"],
    "c": ["cat", "cake", "car", "cow", "cup", "corn"], "d": ["dog", "duck", "doctor"], "e": ["egg", "elephant"],
    "f": ["fish", "foot", "four"], "g": ["goat", "gift"], "h": ["hat", "hen", "hand", "hut"], "i": ["insect"],
    "j": ["jam", "jump"], "k": ["kite", "king"], "l": ["lion", "lamp", "leg", "lemon", "log"],
    "m": ["moon", "milk", "monkey", "mouse"], "n": ["nest", "nose", "nut", "nail"], "o": ["octopus"],
    "p": ["pig", "pen", "pin", "pot", "pencil"], "q": ["queen"], "r": ["robot", "rabbit", "rain", "ring"],
    "s": ["sun", "six", "sock", "seed"], "t": ["tiger", "tent", "tooth", "turtle"], "u": ["umbrella"], "v": ["violin"],
    "w": ["whale", "web", "watch", "wing"], "x": [], "y": ["yoyo"], "z": ["zebra"],
}

# Fix Pencil's mistakes: a letter is written backwards, or upside down when
# it looks the same backwards. Letters that look the same both ways, or turn
# into another letter (M/W, n/u), have no such game.
SAME_MIRRORED = set("AHIMOTUVWXYilmnouvwx")
NO_FIX = set("HIOXMWlmnoux")


def fix_how(ch):
    return None if ch in NO_FIX else ("upside" if ch in SAME_MIRRORED else "mirror")


def start_pics(ch):
    return [pic(w, "yo-yo" if w == "yoyo" else w) for w in STARTS[ch.lower()]]


def contrast(ch):
    """A letter to sort against ch by sound: near it in the alphabet, with pictures, another sound."""
    abc = "abcdefghijklmnopqrstuvwxyz"
    i = abc.index(ch.lower())
    clash = set().union(*[g for g in SAME_SOUND if ch.lower() in g]) | {ch.lower()}
    for d in (-1, 1, -2, 2, -3, 3, -4, 4, -5, 5):
        c = abc[(i + d) % 26]
        if c not in clash and len(STARTS[c]) >= 2:
            return c
    return "b"


def is_new(r):
    """One of the games added for varied levels (pop, fix, sort, match, truth, writing from memory)."""
    return r["type"] in ("pop", "fix", "sort", "match", "truth") or (r["type"] == "write" and r["write"]["mode"] == "flash")


def choose(slots, step, feasible, at_least=2):
    """One game per slot, turning with the level (step), so neighbouring levels play different
    games. slots: [(variants, offset)]; feasible(name) says a game can be made. At least
    [at_least] new games a level."""
    picked = []
    for k, (variants, offset) in enumerate(slots):
        ok = [v for v in variants if feasible(v)]
        # the slots turn at different speeds (step // 6 shifts some), so a pattern does not come back every few levels
        picked.append(ok[(step + offset + (step // 6) * (k % 3)) % len(ok)])
    new = lambda v: v in ("pop", "fix", "monster", "baskets", "match", "truth", "flash")
    for k, (variants, _) in enumerate(slots):
        if sum(map(new, picked)) >= at_least:
            break
        if not new(picked[k]):
            alt = [v for v in variants if new(v) and feasible(v)]
            if alt:
                picked[k] = alt[step % len(alt)]
    return picked


def letter_level(number, ch, small, step):
    """One new letter in eight games, each a different kind. Every slot has a few games
    that teach the same thing; the level's step picks one, so no two letters play alike."""
    L = Level(number, seed=f"{number}{ch}")
    word, key, fill, at = WORDS[ch.lower()]
    big = ch.upper()
    tag = f"small {name(ch)}" if small else name(ch)
    shown = f"small {ch}" if small else ch
    like = [letter_case(c, small) for c in LOOKALIKE[ch]]
    picture = pic(key, word)
    x = ch.lower() == "x"

    def find():
        if small:
            L.pick(f"Find {shown}!", f"Big {name(big)}, small {name(ch)}! Find small {name(ch)}.", card(big, picture),
                   [ch] + like[:3], ch, shape=LETTER_SHAPES[step % len(LETTER_SHAPES)])
        else:
            L.pick(f"Find {ch}!", f"Find {name(ch)}!", card(ch, picture), [ch] + like[:3], ch, shape=LETTER_SHAPES[step % len(LETTER_SHAPES)])

    def pop():
        L.pop(f"Pop every {shown}!", f"Pop every {tag} bubble!", card(ch, picture), ch, like)

    def trace():
        L.write(f"Trace {shown}", f"Trace {tag}.", card(ch, picture), "trace", ch)

    def sound_pick():
        choices = picture_choices(ch, L.rnd)
        L.pick(f"{'Which one has' if x else 'What starts with'} /{ch.lower()}/?",
               f"{name(ch)} says {sound(ch)}. Which one {'has' if x else 'starts with'} {sound(ch)}?",
               card(ch, None, listen=True), list(choices), word, shape=PICTURE_SHAPES[step % len(PICTURE_SHAPES)], pictures=choices, hide=True)

    def monster():
        food = start_pics(ch)
        L.rnd.shuffle(food)
        other = [p for c in STARTS if c != ch.lower() and c not in set().union(*[g for g in SAME_SOUND if ch.lower() in g])
                 for p in start_pics(c)[:1]]
        L.rnd.shuffle(other)
        L.sort(f"Feed it /{ch.lower()}/!", f"This monster only eats things that start with {sound(ch)}. Feed it!", card(ch),
               [(ch, None)], [(p["label"], p, 0) for p in food[:3]] + [(p["label"], p, None) for p in other[:3]])

    def truth():
        right = step % 2 == 0
        other = next(w for w in picture_choices(ch, L.rnd) if w != word)
        shown_word = word if right else other
        thing = picture if right else pic(WORDS[other[0]][1] if other[0] in WORDS and WORDS[other[0]][0] == other else other, other)
        verb = "has" if x else "starts with"
        L.truth("True or silly?", f"{shown_word.capitalize()} {verb} {tag}. True, or silly?", card(None, None, listen=True),
                f"{shown_word.capitalize()} {verb} {ch}.", thing, right)

    def dots():
        L.write(f"Join the dots to make {shown}", f"Join the dots to make {tag}.", card(ch), "dots", ch)

    def hunt():
        L.hunt(f"Find every {shown}!", f"Find every {tag}!", card(ch), ch, like)

    def fix():
        wrong = set(L.rnd.sample(range(6), 2))
        L.fix("Fix Pencil's mistakes!", f"Oops! Pencil wrote some {tag} the wrong way. Tap them to fix them!", card(ch),
              [(ch, fix_how(ch) if i in wrong else None, None) for i in range(6)])

    def match():
        run = alphabet_run(ch, 3, small)
        if small:
            L.match("Find the pairs!", "Find the pairs! Match each big letter to its small letter.", card(f"{big}{ch}"),
                    [((c.upper(), None), (c, None)) for c in run])
        else:
            L.match("Find the pairs!", "Find the pairs! Match each letter to its picture.", card(ch, picture),
                    [((c, None), (None, pic(WORDS[c.lower()][1], WORDS[c.lower()][0]))) for c in run])

    def missing():
        if small:
            L.write("Finish the word!", f"{fill.capitalize()}! Write the missing letter.", card(None, pic(key if fill in (word, key) else fill, fill)),
                    "missing", ch, word=fill, missing=at)
        else:
            run = alphabet_run(ch, 3)
            L.write("Which letter is missing?", f"{', '.join(name(c) if c != ch else '...' for c in run)}! Which letter is missing?",
                    card(None, pic("bottle_message", "bottle message")), "missing", ch, word="".join(run), missing=run.index(ch))

    def order():
        L.order("Put the letters in ABC order!", "Put the letters in A B C order!", card(None, pic("train")), alphabet_run(ch, 3, small))

    def baskets():
        if len(STARTS[ch.lower()]) >= 2:
            c2 = letter_case(contrast(ch), small)
            a, b = start_pics(ch), start_pics(c2)
            L.rnd.shuffle(a)
            L.rnd.shuffle(b)
            L.sort("Sort the pictures!", f"Sort the pictures! Do they start with {sound(ch)} or {sound(c2)}?", card(f"{ch} {c2}"),
                   [(ch, None), (c2, None)], [(p["label"], p, 0) for p in a[:3]] + [(p["label"], p, 1) for p in b[:2]])
        else:
            c2 = like[0]
            L.sort("Sort the letters!", f"Put each letter in its basket: {tag} or {name(c2)}!", card(f"{ch} {c2}"),
                   [(ch, None), (c2, None)], [(ch, None, 0)] * 3 + [(c2, None, 1)] * 3)

    def free():
        L.write(f"Write {shown} by yourself", f"Now write {tag} all by yourself!", card(ch), "free", ch)

    def flash():
        L.write(f"Look, then write {shown}", f"Look at {tag}. Then write it from memory!", card(None, picture), "flash", ch)

    def speak():
        line = f"{ch} says /{ch}/ like {word}!" if small else f"{big} is for {word}!"
        say_line = f"{name(ch)} says {sound(ch)}, like {word}! Now you say it." if small else f"{name(ch)} is for {word}! Now you say it."
        L.speak(f"Say: {line}", say_line, card(line, picture, listen=True), line)

    games = {"find": find, "pop": pop, "trace": trace, "sound": sound_pick, "monster": monster, "truth": truth, "dots": dots,
             "hunt": hunt, "fix": fix, "match": match, "missing": missing, "order": order, "baskets": baskets, "free": free,
             "flash": flash, "speak": speak}
    feasible = lambda g: {"monster": len(STARTS[ch.lower()]) >= 2, "fix": fix_how(ch) is not None}.get(g, True)
    picked = choose([(["find", "pop"], 0), (["trace"], 0), (["sound", "monster", "truth"], 0), (["dots"], 0),
                     (["hunt", "fix", "match"], 1), (["missing", "order", "baskets"], 0), (["free", "flash"], 1), (["speak"], 0)],
                    step, feasible)
    if step % 2:  # every other letter: its look game before its sound game
        picked[2], picked[4] = picked[4], picked[2]
    for g in picked:
        games[g]()
    return L


def review_level(number, letters, small, step, boss=None):
    """The group's letters again, one game each, every game a different kind (turning like the letters).
    boss: (word, picture key) the boss wakes up on, a word to finish."""
    L = Level(number, seed=f"review{number}")
    say_small = "small " if small else ""
    g = [letter_case(c, small) for c in letters]
    picture = lambda c: pic(WORDS[c.lower()][1], WORDS[c.lower()][0])

    def by_ear():
        L.pick("Which letter do you hear?", f"Listen! Find {say_small}{name(g[-1])}.", card(None, None, listen=True),
               unique([g[-1]] + g[:3] + [letter_case(x, small) for x in LOOKALIKE[g[-1]]])[:4], g[-1], shape=LETTER_SHAPES[step % len(LETTER_SHAPES)])

    def pop():
        L.pop(f"Pop every {say_small}{g[-1]}!", f"Listen! Pop every {say_small}{name(g[-1])} bubble!", card(None, None, listen=True), g[-1], g[:3])

    def trace():
        L.write(f"Trace {say_small}{g[1]}", f"Trace {say_small}{name(g[1])}.", card(g[1], picture(g[1])), "trace", g[1])

    def sound_pick():
        choices = picture_choices(g[2], L.rnd)
        L.pick(f"What starts with /{g[2].lower()}/?", f"Which one starts with {sound(g[2])}?", card(None, None, listen=True), list(choices),
               WORDS[g[2].lower()][0], shape=PICTURE_SHAPES[step % len(PICTURE_SHAPES)], pictures=choices, hide=True)

    def baskets():
        with_pics = [c for c in g if len(STARTS[c.lower()]) >= 2][:2]
        a, b = with_pics
        pa, pb = start_pics(a), start_pics(b)
        L.rnd.shuffle(pa)
        L.rnd.shuffle(pb)
        L.sort("Sort the pictures!", f"Sort the pictures! Do they start with {sound(a)} or {sound(b)}?", card(f"{a} {b}"),
               [(a, None), (b, None)], [(p["label"], p, 0) for p in pa[:3]] + [(p["label"], p, 1) for p in pb[:3]])

    def dots():
        L.write(f"Join the dots to make {say_small}{g[3]}", f"Join the dots to make {say_small}{name(g[3])}.", card(g[3]), "dots", g[3])

    def hunt():
        L.hunt(f"Find every {say_small}{g[0]}!", f"Find every {say_small}{name(g[0])}!", card(g[0]), g[0],
               [c for c in g if c != g[0]] + [letter_case(x, small) for x in LOOKALIKE[g[0]]])

    def match():
        run = g[:4]
        if small:
            L.match("Find the pairs!", "Find the pairs! Match each big letter to its small letter.", card(" ".join(run)),
                    [((c.upper(), None), (c, None)) for c in run])
        else:
            L.match("Find the pairs!", "Find the pairs! Match each letter to its picture.", card(" ".join(run)),
                    [((c, None), (None, picture(c))) for c in run])

    def fix():
        fixable = [i for i, c in enumerate(g) if fix_how(c)]
        wrong = set(L.rnd.sample(fixable, 2))
        L.fix("Fix Pencil's mistakes!", "Oops! Pencil wrote some letters the wrong way. Tap them to fix them!", card(" ".join(g)),
              [(c, fix_how(c) if i in wrong else None, None) for i, c in enumerate(g)])

    def by_ear_write():
        L.write("Write the letter you hear", f"Listen, then write it! {say_small}{name(g[4])}.", card(None, None, listen=True), "free", g[4])

    def flash():
        L.write(f"Look, then write {say_small}{g[4]}", f"Look at {say_small}{name(g[4])}. Then write it from memory!",
                card(None, picture(g[4])), "flash", g[4])

    def order():
        L.order("Put the letters in ABC order!", "Put the letters in A B C order!", card(None, pic("train")), g[:3])

    def speak():
        line = ", ".join(g) + "!"
        L.speak(f"Say: {line}", "Say all the letters with me! " + ", ".join(name(c) for c in g) + "!", card(line, None, listen=True), line)

    def last():  # fill a box (the boss wakes up on this one)
        if boss:
            w, key = boss
            L.write("Finish the word!", f"{w.capitalize()}! Write the missing letter to wake it up!", card(None, pic(key)), "missing", w[0],
                    word=w, missing=0)
        else:
            run = alphabet_run(g[1], 3, small)
            L.write("Which letter is missing?", "Which letter is missing?", card(None, pic("bottle_message", "bottle message")), "missing", g[1],
                    word="".join(run), missing=run.index(g[1]))

    games = {"ear": by_ear, "pop": pop, "trace": trace, "sound": sound_pick, "baskets": baskets, "dots": dots, "hunt": hunt,
             "match": match, "fix": fix, "free": by_ear_write, "flash": flash, "order": order, "speak": speak, "last": last}
    feasible = lambda name_: {"baskets": len([c for c in g if len(STARTS[c.lower()]) >= 2]) >= 2,
                              "fix": len([c for c in g if fix_how(c)]) >= 2}.get(name_, True)
    picked = choose([(["ear", "pop"], 1), (["trace"], 0), (["sound", "baskets"], 0), (["dots"], 0), (["hunt", "match", "fix"], 0),
                     (["free", "flash"], 0), (["order"], 0), (["speak"], 0), (["last"], 0)], step, feasible)
    for name_ in picked:
        games[name_]()
    return L


def signature(r):
    """What kind of game a round is, as the child sees it: a level never has two of one kind.
    Every order game is one kind, so is every box to fill (a missing letter, a word to spell)."""
    t = r["type"]
    p = r.get(t) or {}
    if t == "write":
        return ("write", "boxes" if p.get("mode") in ("missing", "spell") else p.get("mode"))
    if t == "pick":
        pics = any(o.get("picture") for o in p.get("options", []))
        by_ear = bool((r.get("card") or {}).get("listen")) and not pics
        return ("pick", p.get("layout"), p.get("stage"), pics, by_ear)
    if t == "sort":
        return ("sort", len(p.get("bins", [])) == 1)
    return (t,)


# ------------------------------------------------------------------ files

def level_doc(L, name_, skill, icon, intro, presentation=None, boss=False):
    return {
        "$schema": SCHEMA,
        "id": L.id,
        "number": L.number,
        "name": name_,
        "skill": skill,
        "icon": icon,
        "isBoss": boss,
        "requiresSubscription": L.number > FREE_UP_TO,
        "intro": intro,
        "presentation": presentation or {"shape": None, "slot": None, "layout": None, "stage": None},
        "rounds": L.rounds,
    }


def intro(text, word, say, key):
    return {"text": text, "word": word, "say": say, "picture": pic(key, word)}


def slug(s):
    return re.sub(r"[^a-z0-9]+", "-", s.lower()).strip("-")


def plan():
    """(world folder, level doc) for the alphabet worlds (1 to 4), in order."""
    out = []
    n = step = 0
    was_small = False
    for world, _, small, first, review, rest, (boss_name, boss_letters, boss_word, boss_pic, boss_say, boss_text, boss_key) in ALPHABET:
        if small != was_small:  # the small letters turn through the games from the start again, like the capitals
            step, was_small = 0, small
        for letters, after in ((first, "review"), (rest, "boss")):
            for ch in letters:
                n += 1
                word = WORDS[ch.lower()][0]
                L = letter_level(n, ch, small, step)
                shown = f"{ch.upper()}{ch}" if small else ch
                say = (f"Big {name(ch.upper())}, small {name(ch)}! Small {name(ch)} says {sound(ch)}, like {word}."
                       if small else f"{name(ch)}! {name(ch)} is for {word}. Let's learn {name(ch)}!")
                title = f"Small {ch}" if small else f"Letter {ch}"
                skill = f"Small {ch} and its sound" if small else f"Capital {ch}"
                out.append((world, level_doc(L, title, skill, "spa" if small else "edit", intro(shown, word, say, WORDS[ch.lower()][1]))))
                step += 1
            n += 1
            if after == "review":
                L = review_level(n, letters, small, step)
                say = f"{review}! Let's play with " + ", ".join(("small " if small else "") + name(c) for c in letters) + "."
                out.append((world, level_doc(L, f"Small {review}" if small else review, "Review", "auto_awesome",
                                             intro(" ".join(letters), "star", say, "star"))))
            else:
                L = review_level(n, boss_letters, small, step, boss=(boss_word, boss_pic))
                out.append((world, level_doc(L, boss_name, "Boss · small letters" if small else "Boss · capitals", "bedtime",
                                             intro(boss_text, boss_key, boss_say, boss_key), boss=True)))
            step += 1
    return out


def write_json(path, doc):
    path.write_text(json.dumps(doc, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--check", action="store_true", help="print the plan, write nothing")
    args = ap.parse_args()

    import later_worlds

    levels = plan()
    later = later_worlds.plan(len(levels) + 1, len(levels))
    for _, d in levels + [(f, d) for f, _, d in later]:
        kinds = [signature(r) for r in d["rounds"]]
        assert len(set(kinds)) == len(kinds), f"level {d['number']} {d['name']}: two games of one kind"
        assert 8 <= len(kinds) <= 10, f"level {d['number']} {d['name']}: {len(kinds)} games"
    if args.check:
        for world, d in levels + [(f, d) for f, _, d in later]:
            kinds = ", ".join(r["type"] + (f"/{r['write']['mode']}" if r["type"] == "write" else "") for r in d["rounds"])
            print(f"{d['number']:3} {world[:2]} {d['name']:24} {len(d['rounds']):2} tasks  {kinds}")
        missing = sorted({k for k in picture_keys([d for _, d in levels] + [d for _, _, d in later])
                          if not (ROOT / "media" / "pictures" / f"{k}.png").exists()})
        print("pictures to draw (tools/illustrations):", ", ".join(missing) or "none")
        return

    # every world is written from scratch: folders of an older plan go too
    for wdir in WORLDS.iterdir():
        if wdir.is_dir():
            shutil.rmtree(wdir)
    for folder, world, *_ in ALPHABET:
        (WORLDS / folder / "levels").mkdir(parents=True)
        write_json(WORLDS / folder / "world.json", world_doc(folder, world))
    for world, d in levels:
        write_json(WORLDS / world / "levels" / f"{d['number']:02d}-{slug(d['name'])}.json", d)

    for folder, wdoc, d in later:
        (WORLDS / folder / "levels").mkdir(parents=True, exist_ok=True)
        write_json(WORLDS / folder / "world.json", wdoc)
        write_json(WORLDS / folder / "levels" / f"{d['number']:02d}-{slug(d['name'])}.json", d)
    print(f"{len(levels) + len(later)} levels in {len({f for f, _, _ in later}) + len(ALPHABET)} worlds written")


def world_doc(folder, fields):
    """world.json: the world's order is the number its folder starts with."""
    return {"$schema": "../../../../schema/world.schema.json", "id": f"world-{int(folder[:2])}", "order": int(folder[:2]), **fields}


def picture_keys(docs):
    """Every picture key the levels show."""
    keys = set()

    def walk(x):
        if isinstance(x, dict):
            if "key" in x and "label" in x and "url" in x:
                keys.add(x["key"])
            for v in x.values():
                walk(v)
        elif isinstance(x, list):
            for v in x:
                walk(v)

    for d in docs:
        walk(d)
        for r in d["rounds"]:
            if r["type"] == "order" and r["order"].get("slot") == "panel":
                keys.update(t.replace(" ", "_") for t in r["order"]["tiles"])
            if r["type"] == "pick" and r["pick"].get("choiceKey"):
                keys.update(o["label"] for o in r["pick"]["options"])
    return keys

if __name__ == "__main__":
    main()
