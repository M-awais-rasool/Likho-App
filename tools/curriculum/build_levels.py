#!/usr/bin/env python3
"""Builds the English course: every world and level, from tables.

The course teaches one new thing per level in 8 to 10 games, and no two
games of a level are of the same kind (a child notices a repeat; a shorter
level is better than a repeated game). This script writes the levels from
the tables here and in later_worlds.py, so a change to the plan is one edit,
not 144 hand-edited files:

    world 1  Letter Land        1-31  capitals A-Z in alphabet order, nine games a
                                      letter, a review after every five, the
                                      Sleepy Snail boss at 31
    world 2  Small Letter Cove  32-62 small a-z with their sounds, the same way,
                                      the Sleepy Fish boss at 62
    worlds 3-12                 63 on phonics, first words, letter pairs, blends,
                                      sight words, sentences, doing words,
                                      questions, reading, stories (later_worlds.py)

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

FREE_UP_TO = 31  # world 1 (capitals A-Z) is free; Likho Plus from world 2 on

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

# Capitals A to Z, then small a to z, in alphabet order (the order children
# and parents know). A review level follows every five letters; the last
# group ends in the world's boss.
CAPITAL_GROUPS = [("A to E", "ABCDE"), ("F to J", "FGHIJ"), ("K to O", "KLMNO"), ("P to T", "PQRST"), (None, "UVWXYZ")]
SMALL_GROUPS = [("a to e", "abcde"), ("f to j", "fghij"), ("k to o", "klmno"), ("p to t", "pqrst"), (None, "uvwxyz")]

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

    def pick(self, text, say, crd, labels, answer, shape=None, pictures=None, hide=False):
        order = list(labels)
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


def letter_level(number, ch, small, step):
    """One new letter in nine games, each a different kind."""
    L = Level(number, seed=f"{number}{ch}")
    word, key, fill, at = WORDS[ch.lower()]
    big = ch.upper()
    tag = f"small {name(ch)}" if small else name(ch)
    shown = f"small {ch}" if small else ch
    like = [letter_case(c, small) for c in LOOKALIKE[ch]]
    picture = pic(key, word)

    # 1 meet it: tap the letter (small letters: the small one of a capital)
    if small:
        L.pick(f"Find {shown}!", f"Big {name(big)}, small {name(ch)}! Find small {name(ch)}.", card(big, picture),
               [ch] + like[:3], ch, shape=LETTER_SHAPES[step % len(LETTER_SHAPES)])
    else:
        L.pick(f"Find {ch}!", f"Find {name(ch)}!", card(ch, picture), [ch] + like[:3], ch, shape=LETTER_SHAPES[step % len(LETTER_SHAPES)])
    # 2 trace it
    L.write(f"Trace {shown}", f"Trace {tag}.", card(ch, picture), "trace", ch)
    # 3 its sound: which picture starts with it
    choices = picture_choices(ch, L.rnd)
    x = ch.lower() == "x"
    L.pick(f"{'Which one has' if x else 'What starts with'} /{ch.lower()}/?",
           f"{name(ch)} says {sound(ch)}. Which one {'has' if x else 'starts with'} {sound(ch)}?",
           card(ch, None, listen=True), list(choices), word, shape=PICTURE_SHAPES[step % len(PICTURE_SHAPES)], pictures=choices, hide=True)
    # 4 join the dots
    L.write(f"Join the dots to make {shown}", f"Join the dots to make {tag}.", card(ch), "dots", ch)
    # 5 letter hunt
    L.hunt(f"Find every {shown}!", f"Find every {tag}!", card(ch), ch, like)
    # 6 fill a box: capitals in the alphabet, small letters at the start of their word
    if small:
        L.write("Finish the word!", f"{fill.capitalize()}! Write the missing letter.", card(None, pic(key if fill in (word, key) else fill, fill)),
                "missing", ch, word=fill, missing=at)
    else:
        run = alphabet_run(ch, 3)
        L.write("Which letter is missing?", f"{', '.join(name(c) if c != ch else '...' for c in run)}! Which letter is missing?",
                card(None, pic("bottle_message", "bottle message")), "missing", ch, word="".join(run), missing=run.index(ch))
    # 7 write it alone
    L.write(f"Write {shown} by yourself", f"Now write {tag} all by yourself!", card(ch), "free", ch)
    # 8 say it
    line = f"{ch} says /{ch}/ like {word}!" if small else f"{big} is for {word}!"
    say_line = f"{name(ch)} says {sound(ch)}, like {word}! Now you say it." if small else f"{name(ch)} is for {word}! Now you say it."
    L.speak(f"Say: {line}", say_line, card(line, picture, listen=True), line)
    # 9 its place in ABC order (three wagons fit the train)
    L.order("Put the letters in ABC order!", "Put the letters in A B C order!", card(None, pic("train")),
            alphabet_run(ch, 3, small))
    return L


def review_level(number, letters, small, step, boss=False):
    """The group's letters again, one game each, every game a different kind."""
    L = Level(number, seed=f"review{number}")
    say_small = "small " if small else ""
    g = [letter_case(c, small) for c in letters]
    picture = lambda c: pic(WORDS[c.lower()][1], WORDS[c.lower()][0])
    # 1 by ear
    L.pick("Which letter do you hear?", f"Listen! Find {say_small}{name(g[-1])}.", card(None, None, listen=True),
           unique([g[-1]] + g[:3] + [letter_case(x, small) for x in LOOKALIKE[g[-1]]])[:4], g[-1], shape=LETTER_SHAPES[step % len(LETTER_SHAPES)])
    # 2 trace
    L.write(f"Trace {say_small}{g[1]}", f"Trace {say_small}{name(g[1])}.", card(g[1], picture(g[1])), "trace", g[1])
    # 3 sound and picture
    choices = picture_choices(g[2], L.rnd)
    L.pick(f"What starts with /{g[2].lower()}/?", f"Which one starts with {sound(g[2])}?", card(None, None, listen=True), list(choices),
           WORDS[g[2].lower()][0], shape=PICTURE_SHAPES[step % len(PICTURE_SHAPES)], pictures=choices, hide=True)
    # 4 dots
    L.write(f"Join the dots to make {say_small}{g[3]}", f"Join the dots to make {say_small}{name(g[3])}.", card(g[3]), "dots", g[3])
    # 5 hunt
    L.hunt(f"Find every {say_small}{g[0]}!", f"Find every {say_small}{name(g[0])}!", card(g[0]), g[0],
           [c for c in g if c != g[0]] + [letter_case(x, small) for x in LOOKALIKE[g[0]]])
    # 6 write by ear
    L.write("Write the letter you hear", f"Listen, then write it! {say_small}{name(g[4])}.", card(None, None, listen=True), "free", g[4])
    # 7 ABC order
    L.order("Put the letters in ABC order!", "Put the letters in A B C order!", card(None, pic("train")), g[:3])
    # 8 say them all
    line = ", ".join(g) + "!"
    L.speak(f"Say: {line}", "Say all the letters with me! " + ", ".join(name(c) for c in g) + "!", card(line, None, listen=True), line)
    # 9 fill a box (the boss wakes up on this one)
    if boss:
        w = "cat" if small else "CAT"
        L.write("Finish the word!", "Cat! Write the missing letter to wake it up!", card(None, pic("cat")), "missing", w[0], word=w, missing=0)
    else:
        run = alphabet_run(g[1], 3, small)
        L.write("Which letter is missing?", "Which letter is missing?", card(None, pic("bottle_message", "bottle message")), "missing", g[1],
                word="".join(run), missing=run.index(g[1]))
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
    """(world folder, level doc) for worlds 1 and 2, in order."""
    out = []
    n = 0
    for world, groups, small, boss_name in (("01-letter-land", CAPITAL_GROUPS, False, "Wake the Snail"),
                                            ("02-small-letter-cove", SMALL_GROUPS, True, "Wake the Fish")):
        step = 0
        for gi, (review, letters) in enumerate(groups):
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
            group = list(letters)
            if gi == len(groups) - 1:
                L = review_level(n, letters, small, step, boss=True)
                say = ("The fish is fast asleep. Let's write our small letters to wake it up!" if small
                       else "{Shh|ʃːː}, the snail is sleeping. Let's wake it up with our capital letters!")
                out.append((world, level_doc(L, boss_name, "Boss · small letters" if small else "Boss · capitals", "bedtime",
                                             intro("a b c" if small else "A B C", "fish" if small else "snail", say, "fish" if small else "snail"),
                                             boss=True)))
            else:
                L = review_level(n, letters, small, step)
                say = f"{review}! Let's play with " + ", ".join(("small " if small else "") + name(c) for c in group) + "."
                out.append((world, level_doc(L, f"Small {review}" if small else review, "Review", "auto_awesome",
                                             intro(" ".join(group), "star", say, "star"))))
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

    # every world's levels are written from scratch
    for wdir in WORLDS.iterdir():
        if wdir.name >= "03":
            shutil.rmtree(wdir)
    for world in ("01-letter-land", "02-small-letter-cove"):
        shutil.rmtree(WORLDS / world / "levels", ignore_errors=True)
        (WORLDS / world / "levels").mkdir(parents=True)
    for world, d in levels:
        write_json(WORLDS / world / "levels" / f"{d['number']:02d}-{slug(d['name'])}.json", d)

    w2 = WORLDS / "02-small-letter-cove" / "world.json"
    wd = json.loads(w2.read_text(encoding="utf-8"))
    wd["skill"] = "Small letters & sounds"
    write_json(w2, wd)

    for folder, wdoc, d in later:
        (WORLDS / folder / "levels").mkdir(parents=True, exist_ok=True)
        write_json(WORLDS / folder / "world.json", wdoc)
        write_json(WORLDS / folder / "levels" / f"{d['number']:02d}-{slug(d['name'])}.json", d)
    print(f"{len(levels) + len(later)} levels in {len({f for f, _, _ in later}) + 2} worlds written")


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
