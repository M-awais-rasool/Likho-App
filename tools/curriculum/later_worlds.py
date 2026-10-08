"""Worlds 3 to 12 of the English course: from blending c-a-t to writing a story.

Every level is one new idea in 8 to 10 games, no two of one kind, with older
words mixed in, like the alphabet worlds (build_levels.py). The games the course
had before (Paint Shop, Doctor Pencil, Cupcake Count, Talk to Aliens, My
Story, ...) live on inside these levels: their rounds are kept in
classic_rounds.json and placed where they teach.

    3  Phonics Forest     blending three-letter words, one short vowel at a time
    4  Word Town          first words: colours, numbers, animals, body, family, food, school
    5  Sound Mountain     two letters, one sound: sh ch th ck ng ee oo ai oa ar or
    6  Blend Beach        blends (st, fl, tr, -nd) and words of two beats
    7  Sight Word Garden  words to know on sight: the, said, was, they ...
    8  Sentence Sky       spaces, capitals, full stops, a/an, plurals, writing a sentence
    9  Action Jungle      doing words, describing words, opposites, in/on/under
    10 Question Island    who, what, where, ? and !, days of the week, talking
    11 Reading River      reading sentences and short passages, answering questions
    12 Story Space        story order, first/next/last, writing about me, my story

Pictures: a word's picture key is in PICTURE (default: the word itself);
keys that are not drawn yet are listed by `--check` (tools/illustrations).
"""

import copy
import json
import pathlib

import build_levels as B

HERE = pathlib.Path(__file__).resolve().parent
CLASSIC = json.loads((HERE / "classic_rounds.json").read_text(encoding="utf-8"))

# word -> picture key, when the key is not the word
PICTURE = {
    "mother": "family_mother", "father": "family_father", "sister": "family_sister", "brother": "family_brother",
    "baby": "family_baby", "teeth": "tooth", "read": "story", "fly": "bird_in_sky", "kick": "ball", "big": "elephant",
    "small": "mouse", "cold": "snowman", "day": "sun", "yo-yo": "yoyo", "zoo": "zoo_bus", "fast": "rabbit", "slow": "snail",
    "lip": "mouth", "sit": "chair",
}

# Pictures these worlds add to the app: key -> Fluent Emoji name, or (name,
# skin tone) for people. tools/illustrations reads this table.
NEW_PICTURES = {
    "bag": "Backpack", "bat": "Bat", "bath": "Bathtub", "bin": "Wastebasket", "blue": "Blue heart", "green": "Green heart",
    "pink": "Pink heart", "black": "Black heart", "boat": "Sailboat", "book": "Closed book",
    "boot": "Hiking boot", "brush": "Toothbrush", "bug": "Bug", "calendar": "Spiral calendar", "chain": "Chains",
    "chair": "Chair", "cheese": "Cheese wedge", "clock": "Mantelpiece clock", "corn": "Ear of corn",
    "crayon": "Crayon", "dance": ("Woman dancing", "Medium"), "down": "Down arrow", "drum": "Drum", "ear": ("Ear", "Medium"),
    "elephant": "Elephant", "eye": "Eye", "flag": "Triangular flag", "food": "Pot of food",
    "foot": ("Foot", "Medium"), "one": "Keycap 1", "two": "Keycap 2", "three": "Keycap 3",
    "four": "Keycap 4", "six": "Keycap 6", "gift": "Wrapped gift", "glove": "Gloves", "hand": ("Hand with fingers splayed", "Medium"), "hut": "Hut", "jump": "Kangaroo", "king": ("Prince", "Medium"), "lamp": "Diya lamp",
    "leg": ("Leg", "Medium"), "lemon": "Lemon", "milk": "Glass of milk", "monkey": "Monkey face",
    "mouse": "Mouse face", "mouth": "Mouth", "nail": "Nail polish", "nose": ("Nose", "Medium"), "nut": "Chestnut", "pen": "Pen", "pin": "Pushpin",
    "plane": "Airplane", "pot": "Teapot", "question": "Red question mark", "rabbit": "Rabbit face",
    "rice": "Cooked rice", "ring": "Ring", "sad": "Crying face", "sheep": "Ewe", "ship": "Ship",
    "shop": "Convenience store", "sing": "Microphone", "sleep": "Sleeping face", "snake": "Snake", "sock": "Socks", "spoon": "Spoon", "stop": "Stop sign", "swim": ("Person swimming", "Medium"),
    "tent": "Tent", "thumb": ("Thumbs up", "Medium"), "tooth": "Tooth",
    "truck": "Delivery truck", "turtle": "Turtle", "up": "Up arrow", "watch": "Watch",
    "web": "Spider web", "wing": "Wing",
}

# Scenes these worlds add (tools/illustrations draws them): an animal under a chair
NEW_SCENES = {"cat_under_chair": "Cat", "dog_under_chair": "Dog"}

ILLUSTRATIONS = B.ROOT / "media" / "pictures"


def has_picture(word):
    key = PICTURE.get(word, word)
    return key in NEW_PICTURES or key in NEW_SCENES or (ILLUSTRATIONS / f"{key}.png").exists()

# Short vowel sounds (for {shown|IPA}) and the sounds of letter pairs
SOUNDS = {
    "a": "æ", "e": "ɛ", "i": "ɪ", "o": "ɑ", "u": "ʌ", "sh": "ʃːː", "ch": "ʧʌ", "th": "θːː", "ck": "kʌ", "ng": "ŋːː",
    "ee": "iː", "oo": "uː", "ai": "eɪ", "oa": "oʊ", "ar": "ɑːɹ", "or": "ɔːɹ", "qu": "kwʌ",
}


def say_sound(g):
    return f"{{/{g}/|{SOUNDS[g]}}}"


def picture(word):
    """The word's picture, or None for words without one (the, said ...)."""
    return B.pic(PICTURE.get(word, word.replace(" ", "_")), word) if has_picture(word) else None


def word_card(word):
    """A card that shows the word's picture, or the word when it has none."""
    p = picture(word)
    return B.card(None, p) if p else B.card(word)


def tiles_of(word, focus=None):
    """The word in letter tiles; a letter pair (focus) stays one tile."""
    out, i = [], 0
    while i < len(word):
        if focus and len(focus) > 1 and word.startswith(focus, i):
            out.append(focus)
            i += len(focus)
        else:
            out.append(word[i])
            i += 1
    return out


def classic(name, take=None):
    """Rounds of a game the course had before (copies, without ids)."""
    rounds = copy.deepcopy(CLASSIC[name]["rounds"])
    return rounds if take is None else [rounds[i] for i in take]


class Words:
    """Helpers that add one game each to a level."""

    def __init__(self, L, step):
        self.L, self.step, self.rnd = L, step, L.rnd

    def shape(self, k=0):
        return B.LETTER_SHAPES[(self.step + k) % len(B.LETTER_SHAPES)]

    def pshape(self, k=0):
        return B.PICTURE_SHAPES[(self.step + k) % len(B.PICTURE_SHAPES)]

    def others(self, word, pool, n=2):
        rest = [w for w in B.unique(pool) if w != word]
        self.rnd.shuffle(rest)
        return rest[:n]

    # -- reading and hearing words
    def which_picture(self, word, pool):
        if not has_picture(word):
            return self.hear_word(word, pool)
        opts = [word] + self.others(word, [w for w in pool if has_picture(w)])
        pics = {w: picture(w) for w in opts}
        self.L.pick(f"Which picture is {word}?", f"Read the word. Which picture is {word}?", B.card(word), opts, word,
                    shape=self.pshape(), pictures=pics, hide=True)

    def which_word(self, word, pool):
        if not has_picture(word):
            return self.hunt(word, pool)
        opts = [word] + self.others(word, pool)
        self.L.pick("What is this?", "What is this? Find the word!", word_card(word), opts, word, shape="card")

    def hear_word(self, word, pool, k=0):
        opts = [word] + self.others(word, pool)
        self.L.pick("Find the word you hear", f"Listen! Find the word {word}.", B.card(None, None, listen=True), opts, word,
                    shape=self.shape(k))

    def hear_picture(self, word, pool):
        if not has_picture(word):
            return self.hear_word(word, pool, 3)
        opts = [word] + self.others(word, [w for w in pool if has_picture(w)])
        pics = {w: picture(w) for w in opts}
        self.L.pick("Find the picture you hear", f"Listen! Find {word}.", B.card(None, None, listen=True), opts, word,
                    shape=self.pshape(1), pictures=pics, hide=True)

    def has_sound(self, focus, word, without):
        opts = [word] + self.others(word, without)
        self.L.pick(f"Which word has /{focus}/?", f"Which word has {say_sound(focus)}?", B.card(focus, None, listen=True), opts, word,
                    shape=self.shape(2))

    def hunt(self, word, pool, cells=9, found=3):
        others = [w for w in B.unique(pool) if w != word] or [word[::-1]]
        self.L.hunt(f"Find every {word}!", f"Find every word {word}!", B.card(word), word, others, cells=cells, found=found)

    # -- building and writing words
    def build(self, word, focus=None, k=0):
        t = tiles_of(word, focus)
        # the train has room for three wagons and the bridge for four planks; longer words go on the rainbow
        fits = ["plank", "wagon", "stripe"] if len(t) <= 3 else (["plank", "stripe"] if len(t) == 4 else ["stripe"])
        slot = fits[(self.step + k) % len(fits)]
        if len(t) < 2:
            return self.spell(word)
        self.L.order("Build the word!", f"{word.capitalize()}! Build the word {word}.", word_card(word), t)
        self.L.rounds[-1]["order"]["slot"] = slot

    def _no_guide(self):
        self.L.rounds[-1]["write"]["guide"] = None  # words and sentences: each letter guides itself, or none

    def spell(self, word):
        self.L.write(f"Spell {word}", f"{word.capitalize()}! Write it one letter at a time.", word_card(word), "spell", word,
                     word=word)
        self._no_guide()

    def missing(self, word, at=None):
        if at is None:
            vowels = [i for i, c in enumerate(word) if c in "aeiou"]
            at = vowels[0] if vowels else 0
        self.L.write("Which letter is missing?", f"{word.capitalize()}! Which letter is missing?", word_card(word), "missing",
                     word[at], word=word, missing=at)

    def write_word(self, word):
        self.L.write(f"Write {word}", f"Write the word {word}.", B.card(word, picture(word)), "free", word)
        self._no_guide()
        self.L.rounds[-1]["write"]["sentence"] = True  # the wide pad, written freely

    def say(self, words, pic_word=None):
        line = ", ".join(words) + "!"
        self.L.speak(f"Say: {line}", f"Say them with me! {line}", B.card(line, picture(pic_word) if pic_word else None, listen=True), line)

    # -- sentences
    def order_sentence(self, sentence, pic_key=None):
        words = sentence.rstrip(".?!").split()
        assert len(words) <= 6, f"{sentence!r}: the rainbow has room for six words"
        self.L.order("Put the words in order!", f"{sentence} Put the words in order.", B.card(None, B.pic(pic_key) if pic_key else None), words)
        self.L.rounds[-1]["order"]["slot"] = "stripe"

    def order_words(self, text, say, crd, tiles):
        """Whole words to put in order, on the rainbow (room for long words)."""
        self.L.order(text, say, crd, tiles)
        self.L.rounds[-1]["order"]["slot"] = "stripe"

    def write_sentence(self, sentence):
        self.L.write("Write the sentence", f"{sentence} Now write it!", B.card(sentence), "free", sentence)
        self._no_guide()
        self.L.rounds[-1]["write"]["sentence"] = True

    def cloze(self, sentence, answer, options, pic_key=None):
        shown = sentence.replace(answer, "___", 1)
        # the sentence alone on the card: next to a picture it breaks into one word a line
        self.L.pick("Which word fits?", f"{shown.replace('___', 'what')} Which word fits?", B.card(shown),
                    B.unique([answer] + options), answer, shape="card")

    def read_match(self, sentence, answer_key, other_keys):
        keys = B.unique([answer_key] + other_keys)
        pics = {k.replace("_", " "): B.pic(k) for k in keys}
        self.L.pick(sentence, f"{sentence} Find the picture!", B.card(sentence), list(pics), answer_key.replace("_", " "),
                    shape="planet", pictures=pics, hide=True)

    def yes_no(self, sentence, pic_key, yes):
        self.L.pick("Yes or no?", f"Look at the picture. {sentence} Yes or no?", B.card(sentence, B.pic(pic_key)), ["Yes", "No"],
                    "Yes" if yes else "No", shape="cloud")

    def fix_capital(self, sentence):
        words = sentence.rstrip(".?!").split()
        wrong = [w for w in words if w[0].isupper()]
        low = [w[0].lower() + w[1:] if w in wrong else w for w in words]
        answer = low[words.index(wrong[0])]
        self.L.pick("Fix it!", "This sentence needs a capital letter. Tap the word to fix it!", B.card("Fix it!"), low, answer)
        r = self.L.rounds[-1]["pick"]
        r["layout"], r["fixCapital"] = "flow", True

    def end_mark(self, sentence):
        mark = sentence[-1]
        body = sentence[:-1]
        self.L.pick("Which mark ends it?", f"{sentence} Which mark goes at the end?", B.card(body + " ___"), [".", "?", "!"], mark, shape=self.shape(1))

    def story_question(self, text, question, answer, others):
        """A short passage on the card, a question about it, the answers under the stars."""
        self.L.pick(question, f"{text} {question}", B.card(text), B.unique([answer] + others), answer, shape="card")
        self.L.rounds[-1]["pick"]["stage"] = "stars"

    def picture_strip(self, keys, say="Put the pictures in order."):
        """Story pictures to put in order (first, next, last)."""
        self.L.order("Put the story in order!", say, B.card("1 · 2 · 3"), keys)
        self.L.rounds[-1]["order"]["slot"] = "panel"

    def speak_line(self, line, pic_key=None):
        self.L.speak(f"Say: {line}", f"{line} Now you say it!", B.card(line, B.pic(pic_key) if pic_key else None, listen=True), line)

    def classic(self, name, take=None):
        for r in classic(name, take):
            self.L._add(r["type"], r["prompt"]["text"], r["prompt"].get("say"), r.get("card"), r[r["type"]])


# ------------------------------------------------------------------ word levels

def word_level(n, step, words, focus, earlier, extra=None):
    """Reading and writing words with one sound (or one topic); finalize() keeps one game of each kind."""
    L = B.Level(n, seed=f"words{n}")
    W = Words(L, step)
    w = (words * 2)[:6]
    pool = words + earlier[-6:]
    W.which_picture(w[0], words)
    W.build(w[0], focus)
    W.hear_word(w[1], words)
    if focus and len(focus) == 1:
        W.missing(w[1], w[1].index(focus) if focus in w[1] else None)
    else:
        W.missing(w[1])
    W.spell(w[2])
    W.hunt(w[3], pool)
    if focus and earlier:
        W.has_sound(focus, w[4], [x for x in earlier if focus not in x] or earlier)
    else:
        W.hear_picture(w[4], pool)
    W.which_word(w[5], pool)
    W.build(w[3], focus, 1)
    W.spell(w[4])
    if extra:
        extra(W)
    W.say(words[:4], words[0])
    if earlier:
        W.spell(earlier[(n * 7) % len(earlier)])
    W.write_word(w[2])
    if len(L.rounds) < 13:
        W.hear_picture(w[5], pool)
    return L


def word_in(sentence, words):
    """The first of [words] in [sentence], as written there ("Look" for look)."""
    for token in sentence.rstrip(".?!").split():
        if token.lower() in [w.lower() for w in words]:
            return token
    raise ValueError(f"none of {words} in {sentence!r}")


def sight_level(n, step, words, sentences, earlier):
    """Words to know on sight (no pictures)."""
    L = B.Level(n, seed=f"sight{n}")
    W = Words(L, step)
    w = (words * 2)[:5]
    pool = words + earlier[-6:]
    W.hear_word(w[0], pool)
    W.hunt(w[0], pool)
    if len(w[0]) > 1:
        W.spell(w[0])
    else:
        W.hear_word(w[0], pool, 1)
    s0, k0 = sentences[0]
    W.cloze(s0, word_in(s0, words), words, k0)
    W.order_sentence(s0, k0)
    W.hear_word(w[1], pool, 2)
    W.build(w[1])
    W.spell(w[2])
    W.hunt(w[3], pool)
    s1, k1 = sentences[1]
    W.cloze(s1, word_in(s1, words), words, k1)
    W.speak_line(s1, k1)
    W.write_word(w[3])
    W.order_sentence(sentences[-1][0], sentences[-1][1])
    if earlier:
        W.spell(earlier[(n * 5) % len(earlier)])
    return L


# ------------------------------------------------------------------ the plan

def phonics_forest():
    """World 3: blending three-letter words."""
    return [
        ("First Sounds", "Sounds at the start", "phishing", "a", "apple", "Apple starts with {a|æ}! Let's hear the first sounds.",
         lambda n, s, e: mixed(n, s, e, ["cat", "dog", "sun", "pig", "hen"], classic_names=[("Mushroom Sounds", None)])),
        ("Short a", "c-a-t words", "pets", "cat", "cat", "{c|kʌ}, {a|æ}, {t|tʌ}... cat! Let's blend words with {a|æ}.",
         lambda n, s, e: word_level(n, s, ["cat", "hat", "bat", "map", "bag", "jam"], "a", e,
                                    extra=lambda W: W.classic("Blend Bridge", [0]))),
        ("Short e", "h-e-n words", "egg", "hen", "hen", "{h|hʌ}, {e|ɛ}, {n|nːː}... hen! Words with {e|ɛ}.",
         lambda n, s, e: word_level(n, s, ["hen", "bed", "pen", "net", "web", "leg"], "e", e)),
        ("Short i", "p-i-g words", "pets", "pig", "pig", "{p|pʌ}, {i|ɪ}, {g|ɡʌ}... pig! Words with {i|ɪ}.",
         lambda n, s, e: word_level(n, s, ["pig", "pin", "bin", "lip", "six"], "i", e)),
        ("Short o", "d-o-g words", "pets", "dog", "dog", "{d|dʌ}, {o|ɑ}, {g|ɡʌ}... dog! Words with {o|ɑ}.",
         lambda n, s, e: word_level(n, s, ["dog", "box", "pot", "fox", "log"], "o", e)),
        ("Short u", "b-u-s words", "directions_bus", "bus", "bus", "{b|bʌ}, {u|ʌ}, {s|sːː}... bus! Words with {u|ʌ}.",
         lambda n, s, e: word_level(n, s, ["bus", "sun", "cup", "bug", "hut", "nut"], "u", e)),
        ("Rhyme Frogs", "Rhyming words", "flutter_dash", "cat hat", "frog", "Cat, hat, bat! Let's hop to words that rhyme.",
         lambda n, s, e: mixed(n, s, e, ["cat", "hat", "dog", "log", "sun", "bun"], classic_names=[("Rhyme Frogs", None)])),
        ("Vowel Owl", "a e i o u", "visibility", "a e i o u", "owl", "{A|ˈeɪ}, {E|ˈiː}, {I|ˈaɪ}, {O|ˈoʊ}, {U|jˈuː}! The owl loves vowels.",
         lambda n, s, e: mixed(n, s, e, ["cat", "bed", "pig", "dog", "cup", "hen"], classic_names=[("Vowel Owl", None)])),
    ]


def mixed(n, step, earlier, words, classic_names=(), sentences=()):
    """A level that opens with a classic game, then plays its words."""
    L = B.Level(n, seed=f"mixed{n}")
    W = Words(L, step)
    for name_, take in classic_names:
        W.classic(name_, take)
    pool = words + earlier[-6:]
    games = [
        lambda: W.which_picture(words[0], words),
        lambda: W.build(words[1]),
        lambda: W.hear_word(words[2], pool),
        lambda: W.spell(words[3]),
        lambda: W.hunt(words[4], pool),
        lambda: W.which_word(words[5 % len(words)], pool),
        lambda: W.missing(words[0]),
        lambda: W.hear_picture(words[1], pool),
        lambda: W.say(words[:4], words[0]),
        lambda: W.write_word(words[2]),
    ]
    for s, k in sentences:
        games.insert(2, lambda s=s, k=k: W.order_sentence(s, k))
    for game in games:
        game()
    return L


WORLDS = [
    # folder, world.json fields, levels: (name, skill, icon, intro text, intro picture word, intro say, build(n, step, earlier) -> Level, words learnt)
    ("03-phonics-forest", {"name": "Phonics Forest", "skill": "Sounds & words", "icon": "forest", "themeId": "phonicsForest",
                           "boss": {"id": "bear", "name": "Sleepy Bear"}}, "phonics"),
    ("04-word-town", {"name": "Word Town", "skill": "First words", "icon": "location_city", "themeId": "wordTown",
                      "boss": {"id": "robotBus", "name": "Robot-Bus"}}, "town"),
    ("05-sound-mountain", {"name": "Sound Mountain", "skill": "Letter pairs", "icon": "landscape", "themeId": "soundMountain",
                           "boss": {"id": "goat", "name": "Sleepy Goat"}}, "mountain"),
    ("06-blend-beach", {"name": "Blend Beach", "skill": "Blends", "icon": "beach_access", "themeId": "blendBeach",
                        "boss": {"id": "crab", "name": "Sleepy Crab"}}, "beach"),
    ("07-sight-word-garden", {"name": "Sight Word Garden", "skill": "Sight words", "icon": "local_florist", "themeId": "sightGarden",
                              "boss": {"id": "ladybug", "name": "Sleepy Ladybug"}}, "garden"),
    ("08-sentence-sky", {"name": "Sentence Sky", "skill": "Sentences", "icon": "cloud", "themeId": "sentenceSky",
                         "boss": {"id": "cloud", "name": "Sleepy Cloud"}}, "sky"),
    ("09-action-jungle", {"name": "Action Jungle", "skill": "Doing & describing words", "icon": "directions_run", "themeId": "actionJungle",
                          "boss": {"id": "monkey", "name": "Sleepy Monkey"}}, "jungle"),
    ("10-question-island", {"name": "Question Island", "skill": "Questions", "icon": "help", "themeId": "questionIsland",
                            "boss": {"id": "turtle", "name": "Sleepy Turtle"}}, "island"),
    ("11-reading-river", {"name": "Reading River", "skill": "Reading", "icon": "menu_book", "themeId": "readingRiver",
                          "boss": {"id": "frog", "name": "Sleepy Frog"}}, "river"),
    ("12-story-space", {"name": "Story Space", "skill": "Stories", "icon": "rocket_launch", "themeId": "storySpace",
                        "boss": {"id": "moon", "name": "Sleepy Moon"}}, "space"),
]


def level_specs(world):
    """(name, skill, icon, intro text, intro picture, intro say, build) for a world, boss last."""
    if world == "phonics":
        return phonics_forest() + [boss_words("Wake the Bear", "Boss · words", "bear",
                                                      "The bear is fast asleep. Let's spell words to wake it up!",
                                                      ["cat", "hen", "pig", "dog", "bus", "jam"], ("Wake the Bear", None))]
    if world == "town":
        return [
            ("Paint Shop", "Colours", "format_paint", "red blue", "paint", "Red, blue, yellow! Let's paint with colour words.",
             lambda n, s, e: mixed(n, s, e, ["red", "blue", "green", "pink", "yellow", "black"], [("Paint Shop", None)])),
            ("Cupcake Count", "Numbers", "cake", "1 2 3", "cupcake", "One, two, three! Let's count the cupcakes.",
             lambda n, s, e: mixed(n, s, e, ["one", "two", "three", "four", "five", "six"], [("Cupcake Count", None)])),
            ("Zoo Bus", "Animals", "directions_bus", "Moo!", "zoo_bus", "Moo! All aboard the zoo bus!",
             lambda n, s, e: mixed(n, s, e, ["cow", "duck", "lion", "goat", "horse", "frog"], [("Zoo Bus", None)])),
            ("Doctor Pencil", "Body parts", "medical_services", "nose", "doctor", "Doctor Pencil is here! Let's learn the parts of the body.",
             lambda n, s, e: mixed(n, s, e, ["nose", "eye", "ear", "hand", "leg", "foot"], [("Doctor Pencil", None)])),
            ("Family Album", "Family", "photo_library", "family", "family", "Mother, father, sister, brother! Let's look at the family album.",
             lambda n, s, e: mixed(n, s, e, ["mother", "father", "sister", "brother", "baby", "family"], [("Family Album", None)])),
            ("Lunch Time", "Food", "restaurant", "food", "bread", "Yum! Let's read the names of food.",
             lambda n, s, e: word_level(n, s, ["egg", "milk", "rice", "cake", "bread", "apple"], None, e)),
            ("School Bag", "School things", "backpack", "school", "school", "Let's pack the school bag!",
             lambda n, s, e: word_level(n, s, ["book", "bag", "pen", "pencil", "crayon", "school"], None, e)),
            boss_words("Wake the Robot-Bus", "Boss · words", "robotBus", "The robot bus is sleeping. Let's write words to wake it up!",
                       ["red", "two", "cow", "hand", "milk", "book"], ("Wake the Robot-Bus", None)),
        ]
    if world == "mountain":
        pairs = [
            ("sh", ["ship", "shop", "fish", "shell", "sheep", "brush"], "ship"),
            ("ch", ["chick", "chair", "cheese", "cherry", "peach", "watch"], "chick"),
            ("th", ["thumb", "bath", "tooth", "three", "mouth", "teeth"], "thumb"),
            ("ck", ["duck", "sock", "clock", "rock", "truck", "chick"], "duck"),
            ("ng", ["ring", "king", "wing", "sing", "song"], "ring"),
            ("ee", ["tree", "bee", "sheep", "feet", "seed", "teeth"], "tree"),
            ("oo", ["moon", "boot", "book", "spoon", "zoo", "food"], "moon"),
            ("ai", ["rain", "snail", "train", "nail", "paint", "chain"], "rain"),
        ]
        specs = [(f"The {f} Sound", f"{f} words", "graphic_eq", f, key, f"Two letters, one sound: {say_sound(f)}! Like {key}.",
                  lambda n, s, e, f=f, ws=ws: word_level(n, s, ws, f, e)) for f, ws, key in pairs]
        specs.append(("oa, ar, or", "More letter pairs", "sailing", "oa ar or", "boat",
                      f"Boat, car, fork! Let's hear {say_sound('oa')}, {say_sound('ar')} and {say_sound('or')}.",
                      lambda n, s, e: word_level(n, s, ["boat", "goat", "car", "star", "fork", "corn"], None, e)))
        specs.append(boss_words("Wake the Goat", "Boss · letter pairs", "goat", "The goat is sleeping on the mountain. Let's read and write to wake it up!",
                                ["ship", "chick", "thumb", "duck", "ring", "moon"]))
        return specs
    if world == "beach":
        groups = [
            ("Starfish Blends", "st sn sp sw", "star", ["star", "stop", "snake", "spoon", "swim", "snail"], "star",
             "Star, snake, spoon! Two sounds at the start."),
            ("Flying Flags", "fl cl pl gl", "flag", ["flag", "clock", "plane", "flower", "glass", "glove"], "flag",
             "Flag, clock, plane! Let's blend the sounds."),
            ("Frog Pond", "fr tr dr cr gr", "frog", ["frog", "tree", "drum", "crab", "grapes", "train"], "frog",
             "Frog, tree, drum! Hear the two sounds at the start."),
            ("Sand Tent", "nd nt mp st at the end", "tent", ["hand", "tent", "lamp", "nest", "milk", "gift"], "tent",
             "Hand, tent, lamp! Two sounds at the end."),
        ]
        specs = [(nm, sk, "beach_access", key, key, line, lambda n, s, e, ws=ws: word_level(n, s, ws, None, e)) for nm, sk, key, ws, _, line in groups]
        specs.append(("Firefly Claps", "Syllables", "flutter_dash", "ba-na-na", "banana", "Ba, na, na! Let's clap the parts of words with the fireflies.",
                      lambda n, s, e: mixed(n, s, e, ["rabbit", "robot", "pencil", "tiger", "rainbow", "banana"], [("Firefly Claps", None)])))
        specs.append(("Long Words", "Words of two beats", "auto_awesome", "rainbow", "rainbow", "Rain, bow... rainbow! Let's read longer words.",
                      lambda n, s, e: word_level(n, s, ["rabbit", "robot", "rainbow", "pencil", "tiger", "lemon"], None, e)))
        specs.append(boss_words("Wake the Crab", "Boss · blends", "crab", "The crab is sleeping in the sand. Let's spell words to wake it up!",
                                ["star", "flag", "frog", "tent", "hand", "drum"]))
        return specs
    if world == "garden":
        sets = [
            (["the", "a", "I", "is"], [("I see the cat.", "cat"), ("The sun is hot.", "hot_sun"), ("It is a dog.", "dog")]),
            (["and", "to", "see", "can"], [("I can see a bird.", "bird_in_sky"), ("A cat and a dog.", "cat_on_box"), ("I can run to the bus.", "run")]),
            (["he", "she", "we", "me", "my"], [("He is my brother.", "family_brother"), ("She is my sister.", "family_sister"), ("We can play.", "play")]),
            (["you", "it", "in", "on", "up"], [("It is in the box.", "cat_on_box"), ("The cat is on the box.", "cat_on_box"), ("You can go up.", "kite")]),
            (["look", "go", "come", "play", "here"], [("Look at the kite.", "kite"), ("Come and play.", "play"), ("Go to the park.", "park")]),
            (["said", "was", "are", "they", "have"], [("They are my friends.", "family"), ("I have a red ball.", "ball"), ("The dog was sad.", "sad")]),
            (["like", "big", "little", "this", "what"], [("I like this cake.", "cake"), ("What is this?", "box"), ("A big cat, a little cat.", "many_cats")]),
        ]
        specs = [("Sight Word Kites", "Sight words", "air", "the", "kite", "The! Let's fly the word kites.",
                  lambda n, s, e: kites_level(n, s, e))]
        for i, (ws, ss) in enumerate(sets[1:], 2):
            specs.append((f"Word Garden {i}", "Sight words", "local_florist", " ".join(ws[:3]), "flower",
                          f"Words to know by sight: {', '.join(ws)}!", lambda n, s, e, ws=ws, ss=ss: sight_level(n, s, ws, ss, e)))
        specs.append(boss_words("Wake the Ladybug", "Boss · sight words", "ladybug", "The ladybug is sleeping on a leaf. Let's read sight words to wake it up!",
                                ["the", "said", "was", "they", "have", "like"], sight=True))
        return specs
    if world == "sky":
        return [
            ("Word Spaces", "Spaces between words", "space_bar", "I see", "cat", "Words need spaces! Let's put the words in order.",
             lambda n, s, e: sentence_level(n, s, e, "spaces")),
            ("Fix-It Pencil", "Capital letters", "edit", "Aa", "pencil", "Sentences start with a capital letter! Let's fix them.",
             lambda n, s, e: sentence_level(n, s, e, "capitals", [("Fix-It Pencil", None)])),
            ("Full Stop", "Ending a sentence", "fiber_manual_record", ".", "star", "A sentence ends with a full stop. Let's find it!",
             lambda n, s, e: sentence_level(n, s, e, "stops")),
            ("a or an?", "Articles", "cloud", "a an", "apple", "An apple, a ball! Let's choose a or an.",
             lambda n, s, e: sentence_level(n, s, e, "articles", [("a or an?", None)])),
            ("One or Many", "Plurals", "filter_none", "cat cats", "many_cats", "One bird, many birds! Let's make more than one.",
             lambda n, s, e: sentence_level(n, s, e, "plurals", [("One or Many", None)])),
            ("Sentence Rainbow", "Word order", "looks", "I see", "rainbow", "I see a rainbow! Let's put the words in order.",
             lambda n, s, e: sentence_level(n, s, e, "order", [("Sentence Rainbow", None)])),
            ("My First Sentences", "Writing sentences", "edit_note", "I can", "pencil", "Let's write whole sentences!",
             lambda n, s, e: sentence_level(n, s, e, "writing")),
            ("Wake the Cloud", "Boss · sentences", "bedtime", "I see a cat.", "cloud", "The cloud is sleeping. Let's write sentences to wake it up!",
             lambda n, s, e: sentence_level(n, s, e, "boss", [("Wake the Cloud", None)])),
        ]
    if world == "jungle":
        return [
            ("Action Words", "Doing words", "directions_run", "run", "run", "Run, jump, swim! Words for things we do.",
             lambda n, s, e: word_level(n, s, ["run", "jump", "swim", "eat", "sleep", "read"], None, e,
                                        extra=lambda W: W.order_sentence("I can run.", "run"))),
            ("More Actions", "Doing words", "sports_soccer", "kick", "ball", "Kick, sing, fly! More doing words.",
             lambda n, s, e: word_level(n, s, ["kick", "sing", "fly", "sit", "walk", "dance"], None, e,
                                        extra=lambda W: W.order_sentence("The bird can fly.", "bird_in_sky"))),
            ("Describing Words", "Big, small, hot, cold", "zoom_out_map", "big", "elephant", "Big, small, hot, cold! Words that tell us more.",
             lambda n, s, e: word_level(n, s, ["big", "small", "hot", "cold", "happy", "sad"], None, e,
                                        extra=lambda W: W.cloze("The elephant is big.", "big", ["small", "sad"], "elephant"))),
            ("Opposites", "Opposites", "swap_horiz", "up down", "up", "Up and down, day and night! Words that are opposite.",
             lambda n, s, e: sentence_level(n, s, e, "opposites")),
            ("In, On, Under", "Where things are", "pets", "in on", "cat_on_box", "Is the cat in, on or under? Let's look!",
             lambda n, s, e: sentence_level(n, s, e, "positions")),
            ("-ing Words", "Running, jumping", "directions_run", "ing", "run", "Run, running! Jump, jumping! Let's add i n g.",
             lambda n, s, e: sentence_level(n, s, e, "ing")),
            ("Jungle Sentences", "Writing what we do", "edit_note", "I can", "monkey", "Let's write sentences about what we can do!",
             lambda n, s, e: sentence_level(n, s, e, "actions")),
            ("Wake the Monkey", "Boss · action words", "bedtime", "jump", "monkey", "The monkey is asleep in a tree. Let's wake it up!",
             lambda n, s, e: sentence_level(n, s, e, "jungle_boss")),
        ]
    if world == "island":
        return [
            ("Question Marks", "Asking a question", "help", "?", "question", "A question ends with a question mark! Let's find them.",
             lambda n, s, e: sentence_level(n, s, e, "marks")),
            ("Who?", "Asking about people", "person", "Who?", "family", "Who is it? Let's ask about people.",
             lambda n, s, e: sentence_level(n, s, e, "who")),
            ("What?", "Asking about things", "category", "What?", "box", "What is it? Let's ask about things.",
             lambda n, s, e: sentence_level(n, s, e, "what")),
            ("Where?", "Asking about places", "place", "Where?", "school", "Where is it? Let's ask about places.",
             lambda n, s, e: sentence_level(n, s, e, "where")),
            ("Days of the Week", "Days", "calendar_month", "Monday", "calendar", "Monday, Tuesday, Wednesday! Let's learn the days.",
             lambda n, s, e: sentence_level(n, s, e, "days")),
            ("Talk to Aliens", "Speaking", "record_voice_over", "Hi!", "alien", "Hi! Let's talk to the friendly aliens.",
             lambda n, s, e: sentence_level(n, s, e, "aliens", [("Talk to Aliens", None)])),
            ("Answer Me", "Answering in sentences", "question_answer", "Yes, I can.", "robot", "Let's answer questions with a whole sentence.",
             lambda n, s, e: sentence_level(n, s, e, "answers")),
            ("Wake the Turtle", "Boss · questions", "bedtime", "?", "turtle", "The turtle is sleeping in its shell. Let's ask and answer to wake it up!",
             lambda n, s, e: sentence_level(n, s, e, "island_boss")),
        ]
    if world == "river":
        return [
            ("Read & Match", "Reading", "view_carousel", "Read!", "storybook", "Read the sentence, then find the picture!",
             lambda n, s, e: sentence_level(n, s, e, "match", [("Read & Match", None)])),
            ("Yes or No?", "Reading carefully", "check_circle", "Yes No", "cat", "Read, look, and say yes or no!",
             lambda n, s, e: sentence_level(n, s, e, "yesno")),
            ("Missing Words", "Words that fit", "edit", "___", "storybook", "One word is missing. Which word fits?",
             lambda n, s, e: sentence_level(n, s, e, "cloze")),
            ("Star Questions", "Comprehension", "auto_awesome", "Who? What?", "star", "Who? What? Where? Let's answer the star questions.",
             lambda n, s, e: sentence_level(n, s, e, "passage1", [("Star Questions", None)])),
            ("Little Stories", "Reading stories", "auto_stories", "Sam", "story", "Let's read little stories and answer questions!",
             lambda n, s, e: sentence_level(n, s, e, "passage2")),
            ("Rhyme Time", "Poems and rhymes", "music_note", "cat hat", "frog", "Cat, hat, sat! Let's read rhymes.",
             lambda n, s, e: sentence_level(n, s, e, "rhymes")),
            ("River Reading", "Reading and writing", "menu_book", "Read!", "fish_in_sea", "Let's read, then write!",
             lambda n, s, e: sentence_level(n, s, e, "readwrite")),
            ("Wake the Frog", "Boss · reading", "bedtime", "Read!", "frog", "The frog is sleeping on a lily pad. Let's read to wake it up!",
             lambda n, s, e: sentence_level(n, s, e, "river_boss")),
        ]
    if world == "space":
        return [
            ("Story Order", "Sequencing", "view_carousel", "1 2 3", "storybook", "First, next, last! Let's put the story in order.",
             lambda n, s, e: sentence_level(n, s, e, "sequence", [("Story Order", None)])),
            ("First, Next, Last", "Story words", "format_list_numbered", "First", "sprout", "First, next, last! Words that tell a story.",
             lambda n, s, e: sentence_level(n, s, e, "fnl")),
            ("Who and Where", "Story people and places", "map", "Who? Where?", "dragon", "Every story has someone and somewhere!",
             lambda n, s, e: sentence_level(n, s, e, "setting")),
            ("All About Me", "Writing about me", "face", "I am", "warm-up", "Let's write about you!",
             lambda n, s, e: sentence_level(n, s, e, "me")),
            ("My Family", "Writing about family", "family_restroom", "My family", "family", "Let's write about your family!",
             lambda n, s, e: sentence_level(n, s, e, "family")),
            ("My Day", "Writing about my day", "wb_sunny", "Today", "sun", "Morning, school, play, sleep! Let's write about your day.",
             lambda n, s, e: sentence_level(n, s, e, "day")),
            ("My Story", "Creative writing", "edit", "Once...", "storybook", "Let's make up our very own story!",
             lambda n, s, e: sentence_level(n, s, e, "mystory", [("My Story", None)])),
            ("Wake the Moon", "Boss · final", "bedtime", "The End", "moon", "The moon is sleeping. Let's read and write to wake it up!",
             lambda n, s, e: sentence_level(n, s, e, "final", [("Wake the Moon", None)])),
        ]
    raise ValueError(world)


def boss_words(title, skill, boss, say, words, classic_level=None, sight=False):
    def build(n, step, earlier):
        L = B.Level(n, seed=f"boss{n}")
        W = Words(L, step)
        if classic_level:
            W.classic(*classic_level)
        pool = words + earlier[-8:]
        for i, w in enumerate(words):
            [lambda: W.spell(w), lambda: W.hear_word(w, pool, i), lambda: W.hunt(w, pool),
             lambda: (W.L.pick("What is this?", "What is this?", B.card(w), [w] + W.others(w, pool), w, shape="card") if sight else W.which_word(w, pool)),
             lambda: W.write_word(w), lambda: W.build(w)][i % 6]()
        for w in pool[len(words):]:
            W.hear_word(w, pool, 1)
        W.say(words[:4], None if sight else words[0])
        return L
    return (title, skill, "bedtime", " ".join(words[:3]), "star", say, build)


def kites_level(n, step, earlier):
    L = B.Level(n, seed=f"kites{n}")
    W = Words(L, step)
    W.classic("Sight Word Kites", None)
    words = ["the", "a", "I", "is"]
    W.hunt("the", words + ["he", "she"])
    W.spell("the")
    W.cloze("I see the cat.", "the", ["is", "a"], "cat")
    W.order_sentence("The sun is hot.", "hot_sun")
    W.spell("is")
    W.hunt("is", ["it", "in", "is", "if"])
    W.speak_line("It is a dog.", "dog")
    W.write_word("the")
    return L


# ------------------------------------------------------------------ sentence levels

SENTENCES = {
    "spaces": [("I see a cat.", "cat"), ("I can run.", "run"), ("The sun is hot.", "hot_sun"), ("I like red.", "red"),
               ("We can play.", "play"), ("A dog can run.", "dog_running")],
    "writing": [("I can run.", "run"), ("I see a dog.", "dog"), ("I like cake.", "cake"), ("The cat is big.", "cat"),
                ("I have a kite.", "kite"), ("The sun is up.", "sun")],
    "actions": [("I can jump.", "jump"), ("I can swim.", "swim"), ("The bird can fly.", "bird_in_sky"), ("I like to read.", "story"),
                ("We can dance.", "dance"), ("The cat can sleep.", "cat_in_bed")],
    "readwrite": [("The fish is in the sea.", "fish_in_sea"), ("The cat is on the box.", "cat_on_box"), ("I see a red car.", "red_car"),
                  ("The dog can run.", "dog_running"), ("The sun is hot.", "hot_sun"), ("A bird is in the sky.", "bird_in_sky")],
}


def sentence_level(n, step, earlier, kind, classics=()):
    """Sentence, grammar, question, reading and story games."""
    L = B.Level(n, seed=f"{kind}{n}")
    W = Words(L, step)
    for name_, take in classics:
        W.classic(name_, take)
    g = []  # games, played in order until the level is full

    def add(*fs):
        g.extend(fs)

    if kind in ("spaces", "writing", "actions", "readwrite"):
        ss = SENTENCES[kind]
        for i, (s, k) in enumerate(ss):
            add(lambda s=s, k=k: W.order_sentence(s, k))
            add(lambda s=s, k=k, i=i: [W.write_sentence(s), W.speak_line(s, k), W.read_match(s, k, [ss[(i + 1) % len(ss)][1], ss[(i + 2) % len(ss)][1]])][i % 3])
        add(lambda: W.end_mark(ss[0][0]), lambda: W.cloze(ss[1][0], ss[1][0].split()[1], ["dog", "is"], ss[1][1]))
    elif kind == "capitals":
        for s in ["I see a cat.", "The dog can run.", "My name is Sara.", "We go to school.", "Ali has a kite.", "The sun is hot."]:
            add(lambda s=s: W.fix_capital(s))
        add(lambda: W.write_sentence("I can see."), lambda: W.order_sentence("Sara has a cat.", "cat"),
            lambda: W.L.pick("Which one is right?", "Which sentence starts the right way?", B.card(None, B.pic("pencil")),
                             ["The cat is big.", "the cat is big."], "The cat is big.", shape="card"),
            lambda: W.speak_line("A sentence starts with a capital letter.", "pencil"),
            lambda: W.write_sentence("My cat is little."), lambda: W.order_sentence("We like to play.", "play"))
    elif kind == "stops":
        for s in ["I see a cat.", "The sun is hot.", "Is it a dog?", "I like cake.", "Can you jump?", "Look at me!"]:
            add(lambda s=s: W.end_mark(s))
        add(lambda: W.order_sentence("I can see the moon.", "moon"), lambda: W.write_sentence("I see a star."),
            lambda: W.L.pick("Which one is right?", "Which sentence has a full stop at the end?", B.card(None, B.pic("star")),
                             ["I see a star.", "I see a star"], "I see a star.", shape="card"),
            lambda: W.speak_line("A full stop ends a sentence.", "star"), lambda: W.write_sentence("The dog is big."),
            lambda: W.order_sentence("The cat is on the box.", "cat_on_box"), lambda: W.write_sentence("I like my school."))
    elif kind == "articles":
        for noun, art, k in [("ant", "an", "ant"), ("cat", "a", "cat"), ("orange", "an", "orange"), ("bus", "a", "bus"), ("owl", "an", "owl"),
                             ("egg", "an", "egg"), ("hat", "a", "hat")]:
            add(lambda noun=noun, art=art, k=k: W.L.pick(f"__ {noun}", f"A {noun}, or an {noun}?", B.card(f"__ {noun}", B.pic(k)), ["a", "an"], art,
                                                         shape="cloud"))
        add(lambda: W.order_sentence("I have an apple.", "apple"), lambda: W.write_sentence("I see an owl."),
            lambda: W.speak_line("An apple, a ball, an egg, a cat!", "apple"), lambda: W.cloze("It is an egg.", "an", ["a"], "egg"),
            lambda: W.order_sentence("I see a red bus.", "red_bus"), lambda: W.write_sentence("I have a hat."))
    elif kind == "plurals":
        for one, many, k in [("cat", "cats", "many_cats"), ("dog", "dogs", "many_dogs"), ("hat", "hats", "many_hats"), ("cup", "cups", "many_cups"),
                             ("bird", "birds", "many_birds")]:
            add(lambda one=one, many=many, k=k: W.L.pick(f"One {one}, many...?", f"One {one}. Many...?", B.card(None, B.pic(k)), [one, many], many,
                                                         shape="card"))
        add(lambda: W.cloze("I see two cats.", "cats", ["cat"], "many_cats"), lambda: W.order_sentence("I have three hats.", "many_hats"),
            lambda: W.write_sentence("I see two dogs."), lambda: W.speak_line("One cat, two cats, three cats!", "many_cats"),
            lambda: W.cloze("I have one cup.", "cup", ["cups"], "cup"), lambda: W.spell("cats"), lambda: W.write_sentence("I like birds."),
            lambda: W.order_sentence("The dogs can run.", "many_dogs"))
    elif kind == "order":
        for s, k in [("I see a rainbow.", "rainbow"), ("The cat is on the box.", "cat_on_box"), ("I can see a bird.", "bird_in_sky"),
                     ("We like to play.", "play"), ("The fish is in the sea.", "fish_in_sea"), ("I have a red ball.", "ball")]:
            add(lambda s=s, k=k: W.order_sentence(s, k))
        add(lambda: W.write_sentence("I see a rainbow."), lambda: W.speak_line("The fish is in the sea.", "fish_in_sea"),
            lambda: W.read_match("The cat is on the box.", "cat_on_box", ["cat_in_bed", "dog_on_box"]), lambda: W.write_sentence("We like to play."))
    elif kind == "boss":
        add(lambda: W.write_sentence("I can jump."), lambda: W.fix_capital("Ali can run."), lambda: W.end_mark("Is it a cat?"),
            lambda: W.L.pick("__ owl", "A owl, or an owl?", B.card("__ owl", B.pic("owl")), ["a", "an"], "an", shape="cloud"),
            lambda: W.order_sentence("I have two hats.", "many_hats"), lambda: W.write_sentence("The sun is hot."),
            lambda: W.order_sentence("We can see the moon.", "moon"), lambda: W.speak_line("I can write a sentence!", "pencil"))
    elif kind == "opposites":
        pairs = [("up", "down", "up", "down"), ("big", "small", "elephant", "mouse"), ("hot", "cold", "hot", "snowman"),
                 ("day", "night", "sun", "night"), ("happy", "sad", "happy", "sad"), ("fast", "slow", "rabbit", "snail")]
        for a, b, ka, kb in pairs:
            add(lambda a=a, b=b, ka=ka, kb=kb: W.L.pick(f"The opposite of {a}?", f"{a.capitalize()}! What is the opposite of {a}?",
                                                         B.card(a, B.pic(ka)), [b, a, "red"], b, shape="card"))
        add(lambda: W.cloze("The sun is hot. The snow is cold.", "cold", ["hot", "big"], "snowman"), lambda: W.spell("down"),
            lambda: W.spell("night"), lambda: W.order_sentence("The kite goes up.", "kite"), lambda: W.speak_line("Up and down, big and small!", "up"),
            lambda: W.write_sentence("I am happy."), lambda: W.hunt("up", ["down", "on", "us", "at"]))
    elif kind == "positions":
        scenes = [("The cat is in the bed.", "cat_in_bed"), ("The cat is on the box.", "cat_on_box"), ("The cat is under the chair.", "cat_under_chair"),
                  ("The fish is in the bowl.", "fish_in_bowl"), ("The dog is on the box.", "dog_on_box"), ("The dog is under the chair.", "dog_under_chair")]
        for i, (s, k) in enumerate(scenes):
            add(lambda s=s, k=k, i=i: W.read_match(s, k, [scenes[(i + 1) % 6][1], scenes[(i + 2) % 6][1]]))
        add(lambda: W.cloze("The cat is under the chair.", "under", ["in", "on"], "cat_under_chair"),
            lambda: W.cloze("The fish is in the bowl.", "in", ["on", "under"], "fish_in_bowl"),
            lambda: W.order_sentence("The dog is on the box.", "dog_on_box"), lambda: W.spell("under"),
            lambda: W.write_sentence("The cat is in the bed."), lambda: W.speak_line("In, on, under!", "cat_on_box"),
            lambda: W.hunt("on", ["in", "no", "an", "up"]))
    elif kind == "ing":
        for base, ing, k in [("run", "running", "run"), ("jump", "jumping", "jump"), ("eat", "eating", "eat"), ("read", "reading", "story"),
                             ("sing", "singing", "sing"), ("sleep", "sleeping", "sleep")]:
            add(lambda base=base, ing=ing, k=k: W.cloze(f"The boy is {ing}.", ing, [base, "red"], k))
        add(lambda: W.spell("jumping"), lambda: W.order_sentence("The dog is running.", "dog_running"),
            lambda: W.write_sentence("I am reading."), lambda: W.speak_line("Run, running! Jump, jumping!", "run"),
            lambda: W.hunt("ing", ["in", "ink", "king", "sing"]), lambda: W.write_sentence("We are singing."),
            lambda: W.order_sentence("The cat is sleeping.", "cat_in_bed"))
    elif kind == "jungle_boss":
        add(lambda: W.which_word("swim", ["swim", "run", "eat", "fly"]), lambda: W.spell("jump"),
            lambda: W.L.pick("The opposite of big?", "Big! What is the opposite of big?", B.card("big", B.pic("elephant")), ["small", "big", "red"], "small", shape="card"),
            lambda: W.read_match("The cat is under the chair.", "cat_under_chair", ["cat_on_box", "cat_in_bed"]),
            lambda: W.cloze("The bird is flying.", "flying", ["fly", "big"], "bird_in_sky"), lambda: W.write_sentence("I can jump."),
            lambda: W.order_sentence("The monkey is happy.", "monkey"), lambda: W.hunt("run", ["sun", "fun", "ran", "rug"]),
            lambda: W.spell("happy"), lambda: W.write_sentence("The dog is running."), lambda: W.cloze("The ice is cold.", "cold", ["hot", "sad"], "snowman"),
            lambda: W.order_sentence("We can swim in the sea.", "swim"), lambda: W.speak_line("I can run, jump and swim!", "monkey"))
    elif kind == "marks":
        for s in ["Is it a cat?", "I see a cat.", "Can you swim?", "What is this?", "I like the sun.", "Where is the dog?"]:
            add(lambda s=s: W.end_mark(s))
        add(lambda: W.order_sentence("Can you see the bird?", "bird_in_sky"), lambda: W.write_sentence("Is it a dog?"),
            lambda: W.L.pick("Which one asks?", "Which one is a question?", B.card(None, B.pic("question")), ["Is it red?", "It is red."], "Is it red?", shape="card"),
            lambda: W.speak_line("Is it a cat? Yes, it is!", "cat"), lambda: W.hunt("?", [".", "!", ","]),
            lambda: W.write_sentence("Can you jump?"), lambda: W.order_sentence("Do you like cake?", "cake"))
    elif kind in ("who", "what", "where"):
        data = {
            "who": [("Who is this? It is my mother.", "mother", "family_mother", ["father", "baby"]),
                    ("Who is this? It is a doctor.", "doctor", "doctor", ["teacher", "baby"]),
                    ("Who is this? It is my father.", "father", "family_father", ["mother", "sister"]),
                    ("Who is this? It is a teacher.", "teacher", "teacher", ["doctor", "mother"]),
                    ("Who is this? It is a baby.", "baby", "family_baby", ["sister", "father"])],
            "what": [("What is this? It is a cup.", "cup", "cup", ["hat", "box"]), ("What is this? It is a kite.", "kite", "kite", ["cake", "ball"]),
                     ("What is this? It is a clock.", "clock", "clock", ["sock", "bus"]), ("What is this? It is a book.", "book", "book", ["bag", "pen"]),
                     ("What is this? It is a star.", "star", "star", ["moon", "sun"])],
            "where": [("Where is the cat? It is on the box.", "box", "cat_on_box", ["bed", "chair"]),
                      ("Where is the fish? It is in the bowl.", "bowl", "fish_in_bowl", ["sea", "box"]),
                      ("Where do you learn? At school.", "school", "school", ["house", "park"]),
                      ("Where do you live? In a house.", "house", "house", ["school", "shop"]),
                      ("Where do you play? In the park.", "park", "park", ["shop", "school"])],
        }[kind]
        for i, (s, ans, k, others) in enumerate(data):
            q, a = s.split("? ")
            add(lambda q=q, ans=ans, k=k, others=others: W.L.pick(q + "?", f"Look! {q}?", B.card(q + "?", B.pic(k)), [ans] + others, ans, shape="card"))
            add(lambda a=a, k=k, i=i: [W.order_sentence(a, k), W.write_sentence(a), W.speak_line(a, k)][i % 3])
        add(lambda: W.spell(kind), lambda: W.hunt(kind, ["who", "what", "where", "when", "why"]), lambda: W.write_sentence(data[0][0].split("? ")[0] + "?"))
    elif kind == "days":
        days = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        add(lambda: W.order_words("Put the days in order!", "Monday, Tuesday, Wednesday... Put the days in order!", B.card(None, B.pic("calendar")), days[:3]),
            lambda: W.order_words("Put the days in order!", "Put the days in order!", B.card(None, B.pic("calendar")), days[3:6]),
            lambda: W.cloze("Monday, Tuesday, Wednesday.", "Tuesday", ["Sunday", "Friday"], "calendar"),
            lambda: W.cloze("Friday, Saturday, Sunday.", "Saturday", ["Monday", "Thursday"], "calendar"),
            lambda: W.hear_word("Friday", days), lambda: W.hear_word("Sunday", days, 1), lambda: W.spell("Monday"),
            lambda: W.speak_line("Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, Sunday!", "calendar"),
            lambda: W.write_sentence("Today is Monday."), lambda: W.order_sentence("We go to school on Monday.", "school"),
            lambda: W.L.pick("How many days?", "How many days are in a week?", B.card(None, B.pic("calendar")), ["seven", "five", "two"], "seven", shape="card"),
            lambda: W.hunt("Sunday", ["Monday", "Friday", "Sunday", "sun"]), lambda: W.write_word("Friday"))
    elif kind == "aliens":
        add(lambda: W.order_sentence("My name is Ali.", "alien"), lambda: W.write_sentence("I am six."),
            lambda: W.L.pick("Answer: How old are you?", "How old are you? Pick the answer!", B.card("How old are you?", B.pic("alien")),
                             ["I am six.", "I am a cat.", "It is red."], "I am six.", shape="card"),
            lambda: W.L.pick("Answer: What is your name?", "What is your name? Pick the answer!", B.card("What is your name?", B.pic("alien")),
                             ["My name is Sara.", "I like cake.", "I am big."], "My name is Sara.", shape="card"),
            lambda: W.order_sentence("I like the colour blue.", "alien"), lambda: W.write_sentence("Goodbye!"),
            lambda: W.speak_line("Hello! How are you?", "alien"), lambda: W.order_sentence("I have a pet cat.", "cat"))
    elif kind == "answers":
        qa = [("Can you jump?", "Yes, I can.", "jump"), ("Is it a cat?", "Yes, it is.", "cat"), ("Is the sun cold?", "No, it is not.", "hot_sun"),
              ("Can a fish fly?", "No, it can not.", "fish"), ("Do you like cake?", "Yes, I do.", "cake")]
        for i, (q, a, k) in enumerate(qa):
            wrong = qa[(i + 1) % len(qa)][1]
            add(lambda q=q, a=a, k=k, wrong=wrong: W.L.pick(q, f"{q} Pick the answer!", B.card(q, B.pic(k)), B.unique([a, wrong, "I am red."]), a, shape="card"))
            add(lambda a=a, k=k, i=i: [W.order_sentence(a, k), W.write_sentence(a)][i % 2])
        add(lambda: W.speak_line("Can you swim? Yes, I can!", "swim"), lambda: W.write_sentence("Yes, I can."), lambda: W.write_sentence("No, I can not."))
    elif kind == "island_boss":
        add(lambda: W.end_mark("Where is the dog?"), lambda: W.L.pick("Who is this?", "Look! Who is this?", B.card("Who is this?", B.pic("doctor")),
                                                                      ["doctor", "baby", "cat"], "doctor", shape="card"),
            lambda: W.cloze("Monday, Tuesday, Wednesday.", "Wednesday", ["Sunday", "Friday"], "calendar"),
            lambda: W.order_sentence("Where is the cat?", "cat_on_box"), lambda: W.write_sentence("Can you swim?"),
            lambda: W.L.pick("Can you jump?", "Can you jump? Pick the answer!", B.card("Can you jump?", B.pic("jump")), ["Yes, I can.", "It is red."], "Yes, I can.", shape="card"),
            lambda: W.spell("where"), lambda: W.write_sentence("Today is Friday."), lambda: W.hunt("what", ["who", "what", "when", "hat"]),
            lambda: W.order_sentence("What is your name?", "turtle"), lambda: W.end_mark("I like the sea."), lambda: W.write_sentence("Yes, I can."),
            lambda: W.speak_line("What is this? It is a turtle!", "turtle"))
    elif kind == "match":
        sc = [("The dog is asleep.", "dog_asleep"), ("The cat can run.", "cat_running"), ("The fish is in the bowl.", "fish_in_bowl"),
              ("A bird is in the sky.", "bird_in_sky"), ("I see a red bus.", "red_bus"), ("It is raining.", "rain_cloud")]
        for i, (s, k) in enumerate(sc):
            add(lambda s=s, k=k, i=i: W.read_match(s, k, [sc[(i + 2) % 6][1], sc[(i + 4) % 6][1]]))
        add(lambda: W.write_sentence("The dog is asleep."), lambda: W.order_sentence("I see a red bus.", "red_bus"),
            lambda: W.speak_line("A bird is in the sky.", "bird_in_sky"))
    elif kind == "yesno":
        for s, k, yes in [("The cat is on the box.", "cat_on_box", True), ("The dog can fly.", "dog", False), ("The sun is hot.", "hot_sun", True),
                          ("The fish is in the bed.", "fish_in_bowl", False), ("I see three cats.", "many_cats", True), ("The bus is blue.", "red_bus", False),
                          ("The bird is in the sky.", "bird_in_sky", True), ("The moon is a cake.", "moon", False)]:
            add(lambda s=s, k=k, yes=yes: W.yes_no(s, k, yes))
        add(lambda: W.write_sentence("The sun is hot."), lambda: W.order_sentence("The bus is red.", "red_bus"),
            lambda: W.speak_line("Yes, the cat is on the box!", "cat_on_box"), lambda: W.write_sentence("I see three cats."),
            lambda: W.cloze("The bus is red.", "red", ["blue", "big"], "red_bus"))
    elif kind == "cloze":
        for s, a, o, k in [("The cat is on the box.", "on", ["in", "up"], "cat_on_box"), ("I can see the moon.", "moon", ["sun", "cake"], "moon"),
                           ("The fish can swim.", "swim", ["fly", "run"], "fish"), ("I like to eat cake.", "eat", ["read", "sit"], "cake"),
                           ("The sun is hot.", "hot", ["cold", "sad"], "hot_sun"), ("A bird can fly.", "fly", ["swim", "dig"], "bird_in_sky"),
                           ("The dog is asleep.", "asleep", ["red", "up"], "dog_asleep"), ("We go to school.", "school", ["moon", "bed"], "school")]:
            add(lambda s=s, a=a, o=o, k=k: W.cloze(s, a, o, k))
        add(lambda: W.write_sentence("The fish can swim."), lambda: W.order_sentence("I can see the moon.", "moon"),
            lambda: W.speak_line("A bird can fly.", "bird_in_sky"), lambda: W.write_sentence("We go to school."),
            lambda: W.order_sentence("I like to eat cake.", "cake"), lambda: W.write_sentence("The sun is hot."))
    elif kind in ("passage1", "passage2", "river_boss"):
        stories = {
            "passage1": [("Ali has a kite. The kite is red.", [("What does Ali have?", "a kite", ["a cat", "a bus"]), ("What colour is the kite?", "red", ["blue", "green"])], "kite"),
                         ("Mia has a cat. The cat is on the bed.", [("Who has a cat?", "Mia", ["Ali", "Sam"]), ("Where is the cat?", "on the bed", ["in the box", "up a tree"])], "cat_in_bed"),
                         ("Sam can swim. He swims in the sea.", [("What can Sam do?", "swim", ["fly", "sing"]), ("Where does he swim?", "in the sea", ["in a bed", "at school"])], "swim")],
            "passage2": [("Sara goes to school. She has a big bag. In the bag is a red book.", [("Where does Sara go?", "to school", ["to the park", "to the zoo"]), ("What is in the bag?", "a red book", ["a cat", "a cake"])], "school"),
                         ("The dog is sad. It has no ball. Ali gives it a ball. Now the dog is happy!", [("Why is the dog sad?", "It has no ball.", ["It is cold.", "It is big."]), ("How is the dog at the end?", "happy", ["sad", "asleep"])], "dog"),
                         ("It is hot. Mia and Ali go to the sea. They swim and play in the sand.", [("Who goes to the sea?", "Mia and Ali", ["Sam and Sara", "a cat"]), ("What do they do?", "swim and play", ["sleep", "read"])], "fish_in_sea")],
            "river_boss": [("The frog sits on a log. It sees a bug. Snap! The frog eats the bug.", [("Where does the frog sit?", "on a log", ["in a bed", "on a bus"]), ("What does the frog eat?", "a bug", ["a cake", "a fish"])], "frog"),
                           ("Ali has a red kite. It is windy. The kite goes up, up, up!", [("What colour is the kite?", "red", ["green", "pink"]), ("Where does the kite go?", "up", ["down", "in the sea"])], "kite"),
                           ("Mia sees a big fish in the sea. The fish is blue. It swims away.", [("What does Mia see?", "a big fish", ["a cat", "a bus"]), ("What colour is the fish?", "blue", ["red", "yellow"])], "fish_in_sea")],
        }[kind]
        for text, qs, k in stories:
            for q, a, o in qs:
                add(lambda text=text, q=q, a=a, o=o: W.story_question(text, q, a, o))
        add(lambda: W.write_sentence(stories[0][0].split(". ")[0] + "."), lambda: W.order_sentence(stories[0][0].split(". ")[1].rstrip(".") + ".", stories[0][2]),
            lambda: W.speak_line(stories[-1][0].split(". ")[0] + ".", stories[-1][2]), lambda: W.yes_no(stories[0][0].split(". ")[0] + ".", stories[0][2], True),
            lambda: W.write_sentence(stories[-1][0].split(". ")[0] + "."), lambda: W.read_match("The cat is on the bed.", "cat_in_bed", ["cat_on_box", "dog_on_box"]),
            lambda: W.cloze("The frog sits on a log.", "log", ["cake", "bus"], "frog"), lambda: W.speak_line("I can read a story!", "storybook"))
    elif kind == "rhymes":
        for word, rhyme, others in [("cat", "hat", ["dog", "sun"]), ("dog", "log", ["cup", "bee"]), ("sun", "bun", ["cat", "pig"]),
                                    ("bee", "tree", ["box", "hen"]), ("star", "car", ["fish", "moon"]), ("cake", "snake", ["drum", "kite"])]:
            pics = {w: picture(w) for w in [rhyme] + others}
            add(lambda word=word, rhyme=rhyme, pics=pics: W.L.pick(f"What rhymes with {word}?", f"{word.capitalize()}! What rhymes with {word}?",
                                                                  B.card(word, picture(word)), list(pics), rhyme, shape="pad", pictures=pics, hide=True))
        add(lambda: W.cloze("The cat sat on a hat.", "hat", ["dog", "sun"], "hat"), lambda: W.speak_line("Twinkle, twinkle, little star!", "star"),
            lambda: W.order_sentence("The bee is in the tree.", "bee"), lambda: W.write_sentence("A cat in a hat."),
            lambda: W.cloze("A big pig can dig.", "dig", ["run", "fly"], "pig"), lambda: W.write_sentence("The sun is fun."),
            lambda: W.hunt("at", ["cat", "hat", "bat", "it"]))
    elif kind == "sequence":
        add(lambda: W.picture_strip(["egg", "crack", "chick"], "First, next, last! Put the pictures in order."),
            lambda: W.picture_strip(["dough", "oven", "bread"]),
            lambda: W.order_sentence("First the seed, then the flower.", "flower"), lambda: W.write_sentence("The egg cracks."),
            lambda: W.speak_line("First, next, last!", "chick"), lambda: W.cloze("First the egg, then the chick.", "chick", ["cake", "bus"], "chick"),
            lambda: W.write_sentence("The seed grows."), lambda: W.order_sentence("The chick says peep.", "chick"))
    elif kind == "fnl":
        for s, a, o, k in [("First, I wake up.", "First", ["Last", "Next"], "wake_up"), ("Next, I eat.", "Next", ["First", "Last"], "eat"),
                           ("Last, I go to school.", "Last", ["First", "Next"], "school"), ("First, the seed.", "First", ["Last"], "seed"),
                           ("Next, the sprout.", "Next", ["First"], "sprout"), ("Last, the flower.", "Last", ["First"], "flower")]:
            add(lambda s=s, a=a, o=o, k=k: W.cloze(s, a, o, k))
        add(lambda: W.spell("first"), lambda: W.spell("next"), lambda: W.spell("last"), lambda: W.write_sentence("First, I wake up."),
            lambda: W.order_sentence("Next, I go to school.", "school"), lambda: W.speak_line("First, next, last!", "seed"),
            lambda: W.write_sentence("Last, I go to bed."))
    elif kind == "setting":
        for q, a, o, k in [("Who is in the story? A dragon.", "dragon", ["cat", "bus"], "dragon"), ("Where is the dragon? In the forest.", "forest", ["sea", "school"], "forest"),
                           ("Who is in the story? A robot.", "robot", ["dog", "hen"], "robot"), ("Where is the robot? In space.", "space", ["bed", "zoo"], "planet"),
                           ("Who is in the story? A fish.", "fish", ["lion", "owl"], "fish"), ("Where is the fish? In the sea.", "sea", ["sky", "box"], "fish_in_sea")]:
            add(lambda q=q, a=a, o=o, k=k: W.L.pick(q.split("? ")[0] + "?", q, B.card(q.split("? ")[0] + "?", B.pic(k)), [a] + o, a, shape="card"))
        add(lambda: W.write_sentence("A dragon lives in the forest."), lambda: W.order_sentence("The robot flies in space.", "robot"),
            lambda: W.speak_line("Once upon a time, a fish lived in the sea.", "fish_in_sea"), lambda: W.write_sentence("The fish can swim."),
            lambda: W.spell("forest"), lambda: W.order_sentence("The dragon is in the forest.", "dragon"), lambda: W.write_sentence("The robot is my friend."))
    elif kind in ("me", "family", "day"):
        lines = {
            "me": [("My name is ___.", "warm-up"), ("I am six.", "cake"), ("I like red.", "red"), ("I can run.", "run"), ("I have a pet cat.", "cat"),
                   ("I like to read.", "story")],
            "family": [("This is my mother.", "family_mother"), ("This is my father.", "family_father"), ("I have a sister.", "family_sister"),
                       ("I have a brother.", "family_brother"), ("We eat together.", "eat"), ("I love my family.", "family")],
            "day": [("I wake up.", "wake_up"), ("I eat bread.", "bread"), ("I go to school.", "school"), ("I play with my friends.", "play"),
                    ("I read a book.", "story"), ("I go to bed.", "bed")],
        }[kind]
        for i, (s, k) in enumerate(lines):
            if "___" in s:
                add(lambda s=s: W.write_sentence(s.replace("___", "Sara")))
                continue
            add(lambda s=s, k=k: W.order_sentence(s, k))
            add(lambda s=s, k=k, i=i: [W.write_sentence(s), W.speak_line(s, k)][i % 2])
        add(lambda: W.write_sentence("I am happy."))
    elif kind == "mystory":
        add(lambda: W.order_sentence("Once upon a time.", "storybook"), lambda: W.write_sentence("The End."),
            lambda: W.speak_line("Once upon a time, there was a cat.", "cat"), lambda: W.order_sentence("The cat can fly.", "cat"),
            lambda: W.write_sentence("My cat is my friend."), lambda: W.order_sentence("They go to the moon.", "moon"),
            lambda: W.cloze("Once upon a time, there was a dragon.", "dragon", ["red", "up"], "dragon"), lambda: W.write_sentence("They play all day."),
            lambda: W.speak_line("And they lived happily ever after!", "storybook"))
    elif kind == "final":
        add(lambda: W.order_sentence("I can read and write.", "pencil"), lambda: W.write_sentence("I can write a story."),
            lambda: W.speak_line("I did it! I can read and write!", "moon"), lambda: W.cloze("The moon is in the sky.", "sky", ["sea", "box"], "moon"),
            lambda: W.end_mark("Can you read?"), lambda: W.fix_capital("Ali can write."), lambda: W.write_sentence("Good night, moon."),
            lambda: W.order_sentence("The moon is awake now.", "moon"))
    else:
        raise ValueError(kind)
    for game in g:
        game()
    return L


# ------------------------------------------------------------------ finishing a level

signature = B.signature


def finalize(L, step, earlier, boss):
    """8-10 games, no two of one kind. A boss level ends with its own last game."""
    last = L.rounds[-1] if boss else None
    seen = {signature(last)} if boss else set()
    body = []
    for r in L.rounds[:-1] if boss else L.rounds:
        if signature(r) not in seen:
            seen.add(signature(r))
            body.append(r)
    L.rounds = body
    # too few kinds: games every level can play, on what it already knows
    W = Words(L, step)
    pool = [w for w in earlier if w.isalpha()][-12:] or ["cat", "dog", "sun"]
    ss = SENTENCES["readwrite"]
    fillers = [
        lambda i: W.speak_line(*ss[i % len(ss)]),
        lambda i: W.order_sentence(*ss[(i + 1) % len(ss)]),
        lambda i: W.write_sentence(ss[(i + 2) % len(ss)][0]),
        lambda i: W.hunt(pool[i % len(pool)], pool),
        lambda i: W.spell(pool[(i + 3) % len(pool)]),
        lambda i: W.read_match(*ss[(i + 3) % len(ss)], [ss[(i + 4) % len(ss)][1], ss[(i + 5) % len(ss)][1]]),
        lambda i: W.hear_word(pool[(i + 5) % len(pool)], pool, i),
        lambda i: W.end_mark(ss[(i + 2) % len(ss)][0]),
    ]
    for i, filler in enumerate(fillers):
        if len(L.rounds) + (1 if boss else 0) >= 8:
            break
        before = len(L.rounds)
        filler(i)
        if len(L.rounds) > before:
            if signature(L.rounds[-1]) in seen:
                L.rounds.pop()
            else:
                seen.add(signature(L.rounds[-1]))
    L.rounds = L.rounds[:10 - (1 if boss else 0)] + ([last] if boss else [])
    for k, r in enumerate(L.rounds):  # ids follow the final order
        r["id"] = f"{L.id}-r{k + 1}"
        for j, o in enumerate((r.get("pick") or {}).get("options", [])):
            o["id"] = f"{r['id']}-o{j + 1}"


def plan(first_number, start_step):
    """(world folder, world.json, level doc) for worlds 3-12."""
    out, n, step, earlier = [], first_number, start_step, []
    for folder, world, key in WORLDS:
        specs = level_specs(key)
        wdoc = {"$schema": "../../../../schema/world.schema.json", "id": f"world-{int(folder[:2])}", "order": int(folder[:2]), **world}
        for i, (title, skill, icon, text, pic_word, say, build) in enumerate(specs):
            boss = i == len(specs) - 1
            L = build(n, step, earlier)
            finalize(L, step, earlier, boss)
            assert 8 <= len(L.rounds) <= 10, (title, len(L.rounds))
            for r in L.rounds:
                for w in _words_in(r):
                    if w not in earlier:
                        earlier.append(w)
            ipic = picture(pic_word)
            doc = B.level_doc(L, title, skill, icon, {"text": text, "word": pic_word.replace("_", " "), "say": say, "picture": ipic}, boss=boss)
            out.append((folder, wdoc, doc))
            n += 1
            step += 1
    return out


def _words_in(r):
    """Single words the round taught (for later review)."""
    w = r.get("write") or {}
    if w.get("mode") == "spell" and w.get("word") and w["word"].isalpha():
        return [w["word"]]
    return []
