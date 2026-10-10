"""Worlds 5 to 14 of the English course: from blending c-a-t to writing a story.

Every level is one new idea in 8 to 10 games, no two of one kind, with older
words mixed in, like the alphabet worlds (build_levels.py). Every world has 15
levels, the last one its boss. The games the course had before (Paint Shop,
Doctor Pencil, Cupcake Count, Talk to Aliens, My Story, ...) live on inside
these levels: their rounds are kept in classic_rounds.json and placed where
they teach.

    5  Phonics Island     blending three-letter words, a word family after each short vowel,
                          last sounds, rhymes
    6  Word Garden        first words: colours, numbers to ten, animals, pets, body, clothes,
                          family, home, food, fruit, school, toys, weather
    7  Sound Castle       letters that make one sound: sh ch th ck ng ee oo ai igh oa ar or
                          ow/ou er/ir/ur wh/ph
    8  Blend Mountain     blends at the start and the end, words of two and three beats,
                          compound words
    9  Sight Word Town    words to know on sight: the, said, was, they, with, many, their ...
    10 Sentence Sky       spaces, naming words, capitals, full stops, ! and, commas, a/an,
                          plurals, writing a sentence
    11 Action Cove        doing words, animal actions, -ing and -ed, describing words,
                          feelings, opposites, where things are, big/bigger/biggest
    12 Question River     who, what, where, when, why, how many, yes/no questions, days,
                          months, asking politely
    13 Reading Bay        reading sentences, signs, lists, steps and stories, picture clues,
                          feelings and guessing what happens next
    14 Story Space        story order, story beginnings, writing about me, my pet, my
                          friend, my school, food, describing a picture, a letter, my story

Pictures: a word's picture key is in PICTURE (default: the word itself);
keys that are not drawn yet are listed by `--check` (tools/illustrations).
"""

import copy
import json
import pathlib
import re

import build_levels as B

HERE = pathlib.Path(__file__).resolve().parent
CLASSIC = json.loads((HERE / "classic_rounds.json").read_text(encoding="utf-8"))

# word -> picture key, when the key is not the word
PICTURE = {
    "mother": "family_mother", "father": "family_father", "sister": "family_sister", "brother": "family_brother",
    "baby": "family_baby", "teeth": "tooth", "read": "story", "fly": "bird_in_sky", "kick": "ball", "big": "elephant",
    "small": "mouse", "cold": "snowman", "day": "sun", "yo-yo": "yoyo", "zoo": "zoo_bus", "fast": "rabbit", "slow": "snail",
    "lip": "mouth", "sit": "chair",
    "man": "family_father", "girl": "family_sister", "jet": "plane", "win": "prize", "slide": "play", "present": "gift",
    "sunflower": "flower", "toothbrush": "brush", "football": "ball", "ladybird": "insect", "open": "story", "closed": "book",
    "sour": "lemon", "young": "family_baby", "asleep": "sleep", "awake": "wake_up", "behind": "cat_behind_box",
    "between": "cat_between_boxes",
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
    # added with the 14 worlds
    "penguin": "Penguin", "rat": "Rat", "van": "Minibus", "fan": "Folding hand fan", "pan": "Cooking", "ten": "Keycap 10",
    "net": "Goal net", "wet": "Droplet", "tin": "Canned food", "prize": "Trophy", "dot": "Red circle",
    "hug": "People hugging", "five": "Keycap 5", "seven": "Keycap 7", "eight": "Keycap 8", "nine": "Keycap 9",
    "parrot": "Parrot", "hamster": "Hamster", "coat": "Coat", "dress": "Dress", "shirt": "T-shirt", "shoe": "Running shoe",
    "house": "House", "door": "Door", "window": "Window", "mango": "Mango", "orange": "Tangerine", "grapes": "Grapes",
    "pear": "Pear", "teddy": "Teddy bear", "balloon": "Balloon", "snow": "Snowflake", "wind": "Wind face",
    "light": "Light bulb", "night": "Night with stars", "crown": "Crown", "clown": "Clown face", "bird": "Bird",
    "purse": "Purse", "phone": "Mobile phone", "dolphin": "Dolphin", "photo": "Camera with flash", "sled": "Sled",
    "broom": "Broom", "brick": "Brick", "skate": "Ice skate", "scarf": "Scarf", "scooter": "Kick scooter",
    "smile": "Smiling face with smiling eyes", "skunk": "Skunk", "salt": "Salt", "mask": "Diving mask",
    "straw": "Cup with straw", "scroll": "Scroll", "scream": "Face screaming in fear", "splash": "Sweat droplets",
    "butterfly": "Butterfly", "potato": "Potato", "dinosaur": "Sauropod", "kangaroo": "Kangaroo", "snowman": "Snowman",
    "popcorn": "Popcorn", "happy": "Grinning face with big eyes", "angry": "Angry face", "scared": "Fearful face",
    "tired": "Yawning face", "horse": "Horse", "climb": ("Person climbing", "Medium"), "loud": "Speaker high volume",
    "quiet": "Muted speaker", "sweet": "Lollipop", "old": ("Old man", "Medium"), "toilet": "Toilet", "bus_stop": "Bus stop",
    "hospital": "Hospital", "traffic_light": "Vertical traffic light", "sandwich": "Sandwich", "soap": "Soap",
    "teacher": ("Teacher", "Medium"), "roti": "Flatbread", "envelope": "Envelope", "postbox": "Postbox", "fox": "Fox",
}

# Scenes these worlds add (tools/illustrations draws them): an animal under a chair, behind,
# next to or between boxes, a cat and a dog, three balls from small to big
NEW_SCENES = {"cat_under_chair": "Cat", "dog_under_chair": "Dog", "cat_behind_box": "Cat", "dog_behind_box": "Dog",
              "cat_next_to_box": "Cat", "dog_next_to_box": "Dog", "cat_between_boxes": "Cat", "dog_between_boxes": "Dog",
              "cat_and_dog": "Cat, Dog", "sizes": "Soccer ball"}

ILLUSTRATIONS = B.ROOT / "media" / "pictures"


def has_picture(word):
    key = PICTURE.get(word, word)
    return key in NEW_PICTURES or key in NEW_SCENES or (ILLUSTRATIONS / f"{key}.png").exists()

# Short vowel sounds (for {shown|IPA}) and the sounds of letter pairs
SOUNDS = {
    "a": "æ", "e": "ɛ", "i": "ɪ", "o": "ɑ", "u": "ʌ", "sh": "ʃːː", "ch": "ʧʌ", "th": "θːː", "ck": "kʌ", "ng": "ŋːː",
    "ee": "iː", "oo": "uː", "ai": "eɪ", "oa": "oʊ", "ar": "ɑːɹ", "or": "ɔːɹ", "qu": "kwʌ",
    "igh": "aɪ", "ow": "aʊ", "ou": "aʊ", "er": "ɜː", "ir": "ɜː", "ur": "ɜː", "wh": "wʌ", "ph": "fːː",
}

# The ends of word families (-at, -an ...)
RIMES = {"at": "æt", "an": "æn", "en": "ɛn", "et": "ɛt", "ig": "ɪɡ", "in": "ɪn", "og": "ɑɡ", "ot": "ɑt", "ug": "ʌɡ", "un": "ʌn"}

# Marks have names when they are said
MARKS = {".": "full stop", "?": "question mark", "!": "exclamation mark", ",": "comma"}

# How a true-or-silly game says what the picture is ("It is big.", "I can run.", "This is an egg.")
DESCRIBING = {"big", "small", "little", "hot", "cold", "happy", "sad", "fast", "slow", "wet", "angry", "scared", "tired", "loud",
              "quiet", "sweet", "sour", "old", "young", "open", "closed", "awake", "asleep"}
DOING = {"run", "jump", "swim", "eat", "sleep", "read", "kick", "sing", "fly", "sit", "walk", "dance", "hug", "climb", "win",
         "smile", "play"}
NO_ARTICLE = {"one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten", "red", "blue", "green", "pink", "black",
              "yellow", "milk", "rice", "bread", "cheese", "jam", "food", "salt", "rain", "snow", "wind", "fog", "popcorn", "corn",
              "paint", "night", "family", "school"}
PLURAL = {"grapes", "teeth", "socks", "eggs", "cats", "dogs"}


# words whose picture is a scene
SCENE_LINES = {"behind": "The cat is behind the box.", "between": "The cat is between the boxes."}


def this_is(word):
    """A sentence that says what a picture of [word] shows."""
    if word in SCENE_LINES:
        return SCENE_LINES[word]
    if word in DESCRIBING:
        return f"It is {word}."
    if word in DOING:
        return f"I can {word}."
    if word in PLURAL:
        return f"These are {word}."
    if word in NO_ARTICLE or word[:1].isupper():
        return f"This is {word}."
    return f"This is {'an' if word[0] in 'aeiou' else 'a'} {word}."


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
        if word in MARKS:  # a mark is said by its name
            self.L.hunt(f"Find every {word}", f"Find every {MARKS[word]}!", B.card(word), word, others, cells=cells, found=found)
        else:
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

    def write_sentence(self, sentence, text="Write the sentence"):
        said = sentence if sentence[-1] in ".?!" else sentence + "."
        self.L.write(text, f"{said} Now write it!", B.card(sentence), "free", sentence)
        self._no_guide()
        self.L.rounds[-1]["write"]["sentence"] = True

    def cloze(self, sentence, answer, options, pic_key=None):
        shown = re.sub(rf"(?<![A-Za-z]){re.escape(answer)}(?![A-Za-z])", "___", sentence, count=1)
        # the other words look like the answer: a capital at the start of the sentence, never the answer again
        cap = answer[:1].isupper() and shown.startswith("___")
        others = [o[:1].upper() + o[1:] if cap else o for o in options if o.lower() != answer.lower()]
        # the sentence alone on the card: next to a picture it breaks into one word a line
        self.L.pick("Which word fits?", f"{shown.replace('___', 'what')} Which word fits?", B.card(shown),
                    B.unique([answer] + others), answer, shape="card")

    def read_match(self, sentence, answer_key, other_keys):
        keys = B.unique([answer_key] + other_keys)
        pics = {k.replace("_", " "): B.pic(k) for k in keys}
        self.L.pick(sentence, f"{sentence} Find the picture!", B.card(sentence), list(pics), answer_key.replace("_", " "),
                    shape="planet", pictures=pics, hide=True)

    def yes_no(self, sentence, pic_key, yes):
        self.L.truth("True or silly?", f"Look at the picture. {sentence} True, or silly?", B.card(None, None, listen=True), sentence,
                     B.pic(pic_key), yes)

    def fix_capital(self, sentence):
        words = sentence.rstrip(".?!").split()
        wrong = [w for w in words if w[0].isupper()]
        low = [w[0].lower() + w[1:] if w in wrong else w for w in words]
        answer = low[words.index(wrong[0])]
        self.L.pick("Fix it!", "This sentence needs a capital letter. Tap the word to fix it!", B.card("Fix it!"), low, answer,
                    keep_order=True)
        r = self.L.rounds[-1]["pick"]
        r["layout"], r["fixCapital"] = "flow", True

    def end_mark(self, sentence):
        mark = sentence[-1]
        body = sentence[:-1]
        self.L.pick("Which mark ends it?", f"{sentence} Which mark goes at the end?", B.card(body + " ___"), [".", "?", "!"], mark, shape=self.shape(1))

    def story_question(self, text, question, answer, others):
        """A short passage on the card, a question about it, the answers under the stars."""
        said = text if text[-1] in ".?!" else text + "."
        self.L.pick(question, f"{said} {question}", B.card(text), B.unique([answer] + others), answer, shape="card")
        self.L.rounds[-1]["pick"]["stage"] = "stars"

    def picture_strip(self, keys, say="Put the pictures in order.", text="Put the story in order!"):
        """Story pictures to put in order (first, next, last)."""
        self.L.order(text, say, B.card("1 · 2 · 3"), keys)
        self.L.rounds[-1]["order"]["slot"] = "panel"

    def speak_line(self, line, pic_key=None):
        self.L.speak(f"Say: {line}", f"{line} Now you say it!", B.card(line, B.pic(pic_key) if pic_key else None, listen=True), line)

    # -- the games that make levels differ (finalize() adds some to every level)
    def pop_word(self, word, pool):
        others = [w for w in B.unique(pool) if w != word and len(w) <= 5]
        others.sort(key=lambda w: (abs(len(w) - len(word)), w[0] != word[0], w))
        self.L.pop(f"Pop every {word}!", f"Pop every bubble that says {word}!", B.card(word), word, others[:3], count=4)

    def fix_words(self, words):
        """Pencil wrote the words; in two of them one letter is backwards."""
        ws = B.unique(words)[:4]
        # letters that look plainly wrong backwards (a backwards t or l hardly shows)
        letters = [[i for i, c in enumerate(w) if c.isalpha() and B.fix_how(c) == "mirror" and c not in "tlI"] for w in ws]
        can = [k for k, ls in enumerate(letters) if ls]
        wrong = set(self.rnd.sample(can, min(2, len(can))))
        self.L.fix("Fix Pencil's mistakes!", "Oops! Pencil wrote a letter the wrong way. Tap the words to fix them!", B.card("Fix it!"),
                   [(w, "mirror" if k in wrong else None, self.rnd.choice(letters[k]) if k in wrong else None) for k, w in enumerate(ws)])

    def monster(self, focus, food, other):
        items = [(w, picture(w), 0) for w in food[:3]] + [(w, picture(w), None) for w in other[:3]]
        self.L.sort(f"Feed it /{focus}/!", f"This monster only eats words with {say_sound(focus)}. Feed it!", B.card(focus),
                    [(focus, None)], items)

    def baskets(self, a, b):
        """Pictures sorted by their first sound: letters a and b."""
        pa, pb = B.start_pics(a), B.start_pics(b)
        self.rnd.shuffle(pa)
        self.rnd.shuffle(pb)
        self.L.sort("Sort the pictures!", f"Sort the pictures! Do they start with {B.sound(a)} or {B.sound(b)}?", B.card(f"{a} {b}"),
                    [(a, None), (b, None)], [(q["label"], q, 0) for q in pa[:3]] + [(q["label"], q, 1) for q in pb[:3]])

    def match_words(self, words, sight=False):
        with_pics = [w for w in B.unique(words) if has_picture(w)]
        if len(with_pics) >= 3 and not sight:
            self.L.match("Find the pairs!", "Find the pairs! Match each word to its picture.", B.card("Find the pairs!"),
                         [((w, None), (None, picture(w))) for w in with_pics[:3]])
        else:
            ws = [w for w in B.unique(words) if w.islower()][:3]
            self.L.match("Find the pairs!", "Find the pairs! Match each word to the same word with a capital letter.", B.card("the = The"),
                         [((w, None), (w.capitalize(), None)) for w in ws])

    def truth_word(self, word, other, right):
        shown = word if right else other
        line = this_is(word)
        self.L.truth("True or silly?", f"{line} True, or silly?", B.card(None, None, listen=True), line, picture(shown), right)

    def flash_word(self, word):
        self.L.write(f"Look, then write {word}", f"Look at the word {word}. Then write it from memory!", word_card(word) if has_picture(word) else B.card(None, None, listen=True),
                     "flash", word)
        self._no_guide()

    def classic(self, name, take=None):
        for r in classic(name, take):
            self.L._add(r["type"], r["prompt"]["text"], r["prompt"].get("say"), r.get("card"), r[r["type"]])

    # -- games of the topic levels (TOPICS)
    def ask(self, text, say, crd, options, answer):
        """A question with word or sentence answers on cards."""
        self.L.pick(text, say, crd, B.unique(options), answer, shape="card")

    def pick_picture(self, text, say, crd, choices, answer):
        """Answers are pictures: words that have one, or {label: picture key}."""
        if isinstance(choices, dict):
            pics = {lab: B.pic(k, lab) for lab, k in choices.items()}
        else:
            pics = {w: picture(w) for w in choices}
        assert all(pics.values()), f"{text}: a choice has no picture"
        self.L.pick(text, say, crd, list(pics), answer, shape=self.pshape(), pictures=pics, hide=True)

    def tap_word(self, text, say, sentence, answer):
        """The sentence on lined paper, its words in order: tap the one asked for."""
        words = sentence.rstrip(".?!").split()
        assert answer in words, (sentence, answer)
        self.L.pick(text, say, B.card(sentence), words, answer, keep_order=True)
        self.L.rounds[-1]["pick"]["layout"] = "flow"

    def fix_name(self, sentence, name):
        """A name written without its capital: tap it to fix it."""
        words = [w.lower() if w == name else w for w in sentence.rstrip(".?!").split()]
        self.L.pick("Fix it!", "This name needs a capital letter. Tap the name to fix it!", B.card("Fix it!"), words, name.lower(),
                    keep_order=True)
        r = self.L.rounds[-1]["pick"]
        r["layout"], r["fixCapital"] = "flow", True

    NUMBERS = ["zero", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"]

    def count(self, n, options):
        """Cupcakes pop in: how many?"""
        self.L.pick("How many?", "How many cupcakes? Count them!", B.card("How many?"), B.unique([self.NUMBERS[n]] + options),
                    self.NUMBERS[n], shape="card")
        r = self.L.rounds[-1]["pick"]
        r["count"], r["stage"] = n, "count"

    def sort_into(self, text, say, crd, bins, items):
        """bins: (label, picture key or None); items: (label, picture key or None, bin)."""
        p = lambda lab, k: B.pic(k, lab) if k else None
        self.L.sort(text, say, crd, [(lab, p(lab, k)) for lab, k in bins], [(lab, p(lab, k), b) for lab, k, b in items])

    def family_sort(self, a, b, words_a, words_b):
        """Words of two families to read and sort by how they end (-at or -an)."""
        self.sort_into(f"Sort the words: -{a} or -{b}?", f"Read each word. Does it end in {{{a}|{RIMES[a]}}} or {{{b}|{RIMES[b]}}}?",
                       B.card(f"-{a} -{b}"), [(f"-{a}", None), (f"-{b}", None)],
                       [(w, None, 0) for w in words_a] + [(w, None, 1) for w in words_b])

    def spelling_sort(self, spellings, groups):
        """Words to read and sort by how a sound is written in them (ow or ou)."""
        spelt = [" ".join(B.name(c) for c in sp) for sp in spellings]
        self.sort_into(f"Sort the words: {' or '.join(spellings)}?", f"Read each word. Is it {' or '.join(spelt)}?",
                       B.card(" ".join(spellings)), [(sp, None) for sp in spellings],
                       [(w, None, i) for i, g in enumerate(groups) for w in g])

    def match_pairs(self, text, say, crd, pairs, pictures=False):
        """Pairs of words (or a word and the picture of key b) to match."""
        self.L.match(text, say, crd, [((a, None), (None, B.pic(b, a.lower())) if pictures else (b, None)) for a, b in pairs])


# ------------------------------------------------------------------ word levels

def word_level(n, step, words, focus, earlier, extra=None):
    """Reading and writing words with one sound (or one topic); finalize() keeps one game of each kind."""
    L = B.Level(n, seed=f"words{n}")
    L.words, L.focus = words, focus
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
    for token in sentence.split():
        token = token.strip(",.?!")
        if token.lower() in [w.lower() for w in words]:
            return token
    raise ValueError(f"none of {words} in {sentence!r}")


def sight_level(n, step, words, sentences, earlier):
    """Words to know on sight (no pictures). sentences: (sentence, picture key[, the wrong words of its gap]); the
    first is the one with a gap, so its wrong words must not fit (He / She is my brother: give Me, My)."""
    L = B.Level(n, seed=f"sight{n}")
    L.words, L.sight = words, True
    W = Words(L, step)
    w = (words * 2)[:5]
    pool = words + earlier[-6:]
    W.hear_word(w[0], pool)
    W.hunt(w[0], pool)
    if len(w[0]) > 1:
        W.spell(w[0])
    else:
        W.hear_word(w[0], pool, 1)
    s0, k0, *wrong = sentences[0]
    gap = word_in(s0, words)
    W.cloze(s0, gap, wrong[0] if wrong else W.others(gap.lower(), words), k0)
    W.order_sentence(*next(x[:2] for x in sentences if len(x[0].rstrip(".?!").split()) <= 6))
    W.hear_word(w[1], pool, 2)
    W.build(w[1])
    W.spell(w[2])
    W.hunt(w[3], pool)
    s1, k1 = sentences[1][:2]
    W.cloze(s1, word_in(s1, words), W.others(word_in(s1, words).lower(), words), k1)
    W.speak_line(s1, k1)
    W.write_word(w[3])
    W.order_sentence(*sentences[-1][:2])
    if earlier:
        W.spell(earlier[(n * 5) % len(earlier)])
    return L


# ------------------------------------------------------------------ the plan

def phonics_forest():
    """World 5: blending three-letter words, each short vowel followed by its word families."""
    fam = lambda a, b, wa, wb: (lambda W: W.family_sort(a, b, wa, wb))
    return [
        ("First Sounds", "Sounds at the start", "phishing", "a", "apple", "Apple starts with {a|æ}! Let's hear the first sounds.",
         lambda n, s, e: mixed(n, s, e, ["cat", "dog", "sun", "pig", "hen"], classic_names=[("Mushroom Sounds", None)])),
        ("Short a", "c-a-t words", "pets", "cat", "cat", "{c|kʌ}, {a|æ}, {t|tʌ}... cat! Let's blend words with {a|æ}.",
         lambda n, s, e: word_level(n, s, ["cat", "hat", "bat", "map", "bag", "jam"], "a", e,
                                    extra=lambda W: W.classic("Blend Bridge", [0]))),
        ("-at & -an Families", "Word families", "pets", "-at -an", "van",
         "Cat, hat, bat, rat: the {at|æt} family! Van, fan, pan, man: the {an|æn} family!",
         lambda n, s, e: word_level(n, s, ["rat", "van", "fan", "bat", "pan", "man"], None, e,
                                    extra=fam("at", "an", ["cat", "hat", "bat", "rat"], ["van", "fan", "pan", "man"]))),
        ("Short e", "h-e-n words", "egg", "hen", "hen", "{h|hʌ}, {e|ɛ}, {n|nːː}... hen! Words with {e|ɛ}.",
         lambda n, s, e: word_level(n, s, ["hen", "bed", "pen", "net", "web", "leg"], "e", e)),
        ("-en & -et Families", "Word families", "egg", "-en -et", "net",
         "Hen, pen, ten: the {en|ɛn} family! Net, jet, wet: the {et|ɛt} family!",
         lambda n, s, e: word_level(n, s, ["wet", "net", "ten", "jet", "pen", "hen"], None, e,
                                    extra=fam("en", "et", ["hen", "pen", "ten", "men"], ["net", "jet", "wet", "pet"]))),
        ("Short i", "p-i-g words", "pets", "pig", "pig", "{p|pʌ}, {i|ɪ}, {g|ɡʌ}... pig! Words with {i|ɪ}.",
         lambda n, s, e: word_level(n, s, ["pig", "pin", "bin", "lip", "six"], "i", e)),
        ("-ig & -in Families", "Word families", "pets", "-ig -in", "pin",
         "Pig, big, dig: the {ig|ɪɡ} family! Pin, bin, tin, win: the {in|ɪn} family!",
         lambda n, s, e: word_level(n, s, ["win", "pig", "tin", "big", "bin", "pin"], None, e,
                                    extra=fam("ig", "in", ["pig", "big", "dig", "wig"], ["pin", "bin", "tin", "win"]))),
        ("Short o", "d-o-g words", "pets", "dog", "dog", "{d|dʌ}, {o|ɑ}, {g|ɡʌ}... dog! Words with {o|ɑ}.",
         lambda n, s, e: word_level(n, s, ["dog", "box", "pot", "fox", "log"], "o", e)),
        ("-og & -ot Families", "Word families", "pets", "-og -ot", "frog",
         "Dog, log, frog: the {og|ɑɡ} family! Pot, hot, dot: the {ot|ɑt} family!",
         lambda n, s, e: word_level(n, s, ["hot", "log", "pot", "dog", "dot", "frog"], None, e,
                                    extra=fam("og", "ot", ["dog", "log", "frog", "fog"], ["pot", "hot", "dot", "cot"]))),
        ("Short u", "b-u-s words", "directions_bus", "bus", "bus", "{b|bʌ}, {u|ʌ}, {s|sːː}... bus! Words with {u|ʌ}.",
         lambda n, s, e: word_level(n, s, ["bus", "sun", "cup", "bug", "hut", "nut"], "u", e)),
        ("-ug & -un Families", "Word families", "directions_bus", "-ug -un", "bug",
         "Bug, hug, rug: the {ug|ʌɡ} family! Sun, bun, run: the {un|ʌn} family!",
         lambda n, s, e: word_level(n, s, ["hug", "bun", "bug", "run", "sun"], None, e,
                                    extra=fam("ug", "un", ["bug", "hug", "rug", "mug"], ["sun", "bun", "run", "fun"]))),
        ("Ending Sounds", "Sounds at the end", "graphic_eq", "cat", "cat", "Cat ends with {t|tʌ}! Let's hear the last sounds.",
         lambda n, s, e: sentence_level(n, s, e, "endings")),
        ("Rhyme Frogs", "Rhyming words", "flutter_dash", "cat hat", "frog", "Cat, hat, bat! Let's hop to words that rhyme.",
         lambda n, s, e: mixed(n, s, e, ["cat", "hat", "dog", "log", "sun", "bun"], classic_names=[("Rhyme Frogs", None)])),
        ("Vowel Owl", "a e i o u", "visibility", "a e i o u", "owl", "{A|ˈeɪ}, {E|ˈiː}, {I|ˈaɪ}, {O|ˈoʊ}, {U|jˈuː}! The owl loves vowels.",
         lambda n, s, e: mixed(n, s, e, ["cat", "bed", "pig", "dog", "cup", "hen"], classic_names=[("Vowel Owl", None)])),
    ]


def mixed(n, step, earlier, words, classic_names=(), sentences=()):
    """A level that opens with a classic game, then plays its words."""
    L = B.Level(n, seed=f"mixed{n}")
    L.words = words
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
    # folder, world.json fields, the key of its levels in level_specs
    # each world's look (theme, boss, place in its name) follows the colour
    # wheel, so neighbouring worlds are neighbouring colours; the levels are
    # keyed by what they teach
    ("05-phonics-island", {"name": "Phonics Island", "skill": "Sounds & words", "icon": "sailing", "themeId": "questionIsland",
                           "boss": {"id": "turtle", "name": "Sleepy Turtle"}}, "phonics"),
    ("06-word-garden", {"name": "Word Garden", "skill": "First words", "icon": "local_florist", "themeId": "sightGarden",
                        "boss": {"id": "ladybug", "name": "Sleepy Ladybug"}}, "town"),
    ("07-sound-castle", {"name": "Sound Castle", "skill": "Letter pairs", "icon": "castle", "themeId": "alphabetCastle",
                         "boss": {"id": "dragon", "name": "Sleepy Dragon"}}, "mountain"),
    ("08-blend-mountain", {"name": "Blend Mountain", "skill": "Blends & long words", "icon": "landscape", "themeId": "soundMountain",
                           "boss": {"id": "goat", "name": "Sleepy Goat"}}, "beach"),
    ("09-sight-word-town", {"name": "Sight Word Town", "skill": "Sight words", "icon": "location_city", "themeId": "wordTown",
                            "boss": {"id": "robotBus", "name": "Robot-Bus"}}, "garden"),
    ("10-sentence-sky", {"name": "Sentence Sky", "skill": "Sentences", "icon": "cloud", "themeId": "sentenceSky",
                         "boss": {"id": "cloud", "name": "Sleepy Cloud"}}, "sky"),
    ("11-action-cove", {"name": "Action Cove", "skill": "Doing & describing words", "icon": "waves", "themeId": "smallLetterCove",
                        "boss": {"id": "fish", "name": "Sleepy Fish"}}, "jungle"),
    ("12-question-river", {"name": "Question River", "skill": "Questions", "icon": "help", "themeId": "readingRiver",
                           "boss": {"id": "frog", "name": "Sleepy Frog"}}, "island"),
    ("13-reading-bay", {"name": "Reading Bay", "skill": "Reading", "icon": "ac_unit", "themeId": "frostyBay",
                        "boss": {"id": "penguin", "name": "Sleepy Penguin"}}, "river"),
    ("14-story-space", {"name": "Story Space", "skill": "Stories", "icon": "rocket_launch", "themeId": "storySpace",
                        "boss": {"id": "moon", "name": "Sleepy Moon"}}, "space"),
]

LEVELS_PER_WORLD = 15


def topic(name, skill, icon, text, pic_word, say, kind, classics=()):
    """A level of sentence_level games (its kind)."""
    return (name, skill, icon, text, pic_word, say, lambda n, s, e: sentence_level(n, s, e, kind, classics))


def words_topic(name, skill, icon, text, pic_word, say, words, focus=None, extra=None):
    """A level of reading and writing words (word_level)."""
    return (name, skill, icon, text, pic_word, say, lambda n, s, e: word_level(n, s, words, focus, e, extra=extra))


def level_specs(world):
    """(name, skill, icon, intro text, intro picture, intro say, build) for a world, boss last."""
    if world == "phonics":
        return phonics_forest() + [boss_words("Wake the Turtle", "Boss · words", "turtle",
                                                      "The turtle is fast asleep on the island. Let's spell words to wake it up!",
                                                      ["cat", "hen", "pig", "dog", "bus", "jam"], ("Wake the Bear", None))]
    if world == "town":
        return [
            ("Paint Shop", "Colours", "format_paint", "red blue", "paint", "Red, blue, yellow! Let's paint with colour words.",
             lambda n, s, e: mixed(n, s, e, ["red", "blue", "green", "pink", "yellow", "black"], [("Paint Shop", None)])),
            ("Cupcake Count", "Numbers", "cake", "1 2 3", "cupcake", "One, two, three! Let's count the cupcakes.",
             lambda n, s, e: mixed(n, s, e, ["one", "two", "three", "four", "five", "six"], [("Cupcake Count", None)])),
            topic("More Numbers", "Numbers to ten", "cake", "7 8 9 10", "ten", "Seven, eight, nine, ten! Let's count all the way to ten.",
                  "numbers"),
            ("Zoo Bus", "Animals", "directions_bus", "Moo!", "zoo_bus", "Moo! All aboard the zoo bus!",
             lambda n, s, e: mixed(n, s, e, ["cow", "duck", "lion", "goat", "horse", "frog"], [("Zoo Bus", None)])),
            words_topic("Pet Shop", "Pets", "pets", "pets", "parrot", "Cat, dog, rabbit, parrot! Let's choose a pet.",
                        ["parrot", "fish", "cat", "rabbit", "dog", "hamster"]),
            ("Doctor Pencil", "Body parts", "medical_services", "nose", "doctor", "Doctor Pencil is here! Let's learn the parts of the body.",
             lambda n, s, e: mixed(n, s, e, ["nose", "eye", "ear", "hand", "leg", "foot"], [("Doctor Pencil", None)])),
            words_topic("Clothes Shop", "Clothes", "shopping_basket", "coat", "coat", "Coat, dress, shirt, shoe! Let's get dressed.",
                        ["coat", "shoe", "hat", "dress", "sock", "shirt"]),
            ("Family Album", "Family", "photo_library", "family", "family", "Mother, father, sister, brother! Let's look at the family album.",
             lambda n, s, e: mixed(n, s, e, ["mother", "father", "sister", "brother", "baby", "family"], [("Family Album", None)])),
            words_topic("My Home", "Home", "place", "home", "house", "House, door, window, bed! Let's look around my home.",
                        ["house", "bed", "door", "bath", "chair", "window"]),
            ("Lunch Time", "Food", "restaurant", "food", "bread", "Yum! Let's read the names of food.",
             lambda n, s, e: word_level(n, s, ["egg", "milk", "rice", "cake", "bread", "apple"], None, e)),
            words_topic("Fruit Market", "Fruit", "shopping_basket", "fruit", "mango", "Mango, banana, grapes, pear! Let's buy some fruit.",
                        ["mango", "pear", "grapes", "apple", "orange", "banana"]),
            ("School Bag", "School things", "backpack", "school", "school", "Let's pack the school bag!",
             lambda n, s, e: word_level(n, s, ["book", "bag", "pen", "pencil", "crayon", "school"], None, e)),
            words_topic("Toy Shop", "Toys", "sports_soccer", "toys", "teddy", "Teddy, ball, kite, drum! Let's play with toys.",
                        ["teddy", "kite", "ball", "drum", "balloon", "robot"]),
            topic("Weather", "Weather words", "wb_sunny", "sun rain", "rain", "Sunny, rainy, windy, snowy! What is the weather today?",
                  "weather"),
            boss_words("Wake the Ladybug", "Boss · words", "ladybug", "The ladybug is sleeping in the garden. Let's write words to wake it up!",
                       ["red", "ten", "cow", "coat", "milk", "book"], ("Wake the Robot-Bus", None)),
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
        specs.append(words_topic("The igh Sound", "igh words", "graphic_eq", "igh", "light",
                                 f"Three letters, one sound: {say_sound('igh')}! Like light and night.",
                                 ["light", "night", "high", "right", "bright"], "igh"))
        specs.append(("oa, ar, or", "More letter pairs", "sailing", "oa ar or", "boat",
                      f"Boat, car, fork! Let's hear {say_sound('oa')}, {say_sound('ar')} and {say_sound('or')}.",
                      lambda n, s, e: word_level(n, s, ["boat", "goat", "car", "star", "fork", "corn"], None, e)))
        specs.append(words_topic("ow, ou", "ow ou words", "graphic_eq", "ow ou", "cow",
                                 f"Cow, owl, crown! House, mouse, cloud! Two ways to write {say_sound('ow')}.",
                                 ["cow", "house", "crown", "mouse", "owl", "cloud"],
                                 extra=lambda W: W.spelling_sort(["ow", "ou"], [["cow", "owl", "crown", "down", "clown"],
                                                                               ["house", "mouse", "cloud", "out", "shout"]])))
        specs.append(words_topic("er, ir, ur", "er ir ur words", "graphic_eq", "er ir ur", "bird",
                                 f"Her, bird, turtle! Three ways to write {say_sound('er')}.",
                                 ["bird", "girl", "her", "turtle", "shirt", "purse"],
                                 extra=lambda W: W.spelling_sort(["er", "ir", "ur"], [["her", "fern", "term"], ["bird", "girl", "shirt"],
                                                                                     ["turtle", "purse", "burn"]])))
        specs.append(words_topic("wh, ph", "wh ph words", "graphic_eq", "wh ph", "whale",
                                 f"Whale and phone! Let's hear {say_sound('wh')} in whale and {say_sound('ph')} in phone.",
                                 ["whale", "phone", "white", "dolphin", "photo", "when"],
                                 extra=lambda W: W.spelling_sort(["wh", "ph"], [["whale", "white", "when", "wheel"],
                                                                               ["phone", "photo", "dolphin", "elephant"]])))
        specs.append(words_topic("Letter Pair Mix", "Review", "auto_awesome", "sh ch th", "ship",
                                 "Ship, chick, thumb, tree, moon, rain! Let's mix up our letter pairs.",
                                 ["ship", "chick", "thumb", "tree", "moon", "rain"],
                                 extra=lambda W: W.spelling_sort(["sh", "ch", "th"], [["ship", "shop", "fish"], ["chick", "chair", "lunch"],
                                                                                     ["thumb", "bath", "three"]])))
        specs.append(boss_words("Wake the Dragon", "Boss · letter pairs", "dragon", "The little dragon is sleeping in the castle. Let's read and write to wake it up!",
                                ["ship", "chick", "thumb", "moon", "light", "cow"]))
        return specs
    if world == "beach":
        def blend(name_, skill, key, words, line, extra=None):
            return words_topic(name_, skill, "beach_access", key, key, line, words, extra=extra)
        return [
            blend("Starfish Blends", "st sn sp sw", "star", ["star", "stop", "snake", "spoon", "swim", "snail"], "Star, snake, spoon! Two sounds at the start."),
            blend("Flying Flags", "fl cl pl gl", "flag", ["flag", "clock", "plane", "flower", "glass", "glove"], "Flag, clock, plane! Let's blend the sounds."),
            blend("Blue Sleds", "bl sl", "sled", ["sled", "blue", "slide", "black", "sleep"], "Blue, black, sled, slide! Two sounds at the start."),
            blend("Frog Pond", "fr tr dr cr gr", "frog", ["frog", "tree", "drum", "crab", "grapes", "train"], "Frog, tree, drum! Hear the two sounds at the start."),
            blend("Bread & Prizes", "br pr", "bread", ["bread", "broom", "prize", "brush", "brick", "present"], "Bread, broom, prize! Two sounds at the start."),
            blend("Smiling Skates", "sk sm sc", "skate", ["skate", "smile", "scarf", "skunk", "scooter"], "Skate, smile, scarf! Two sounds at the start."),
            blend("Sand Tent", "nd nt mp st at the end", "tent", ["hand", "tent", "lamp", "nest", "milk", "gift"], "Hand, tent, lamp! Two sounds at the end."),
            blend("Diving Masks", "sk lt lk ft at the end", "mask", ["mask", "salt", "belt", "milk", "desk", "soft"], "Mask, salt, milk, soft! Two sounds at the end."),
            blend("Strawberry Splash", "str spr scr", "straw", ["straw", "sprout", "scroll", "splash", "scream"],
                  "Straw, sprout, scroll! Three sounds at the start.",
                  extra=lambda W: W.spelling_sort(["str", "spr", "scr"], [["straw", "string", "street"], ["sprout", "spring", "spray"],
                                                                         ["scroll", "scrub", "scream"]])),
            words_topic("Blend Mix", "Review", "auto_awesome", "st fl tr", "star", "Star, flag, tree, sled! Let's mix up our blends.",
                        ["star", "flag", "tree", "sled", "skate", "drum"],
                        extra=lambda W: W.spelling_sort(["st", "fl", "tr"], [["star", "stop", "step"], ["flag", "flower", "fly"],
                                                                            ["tree", "train", "truck"]])),
            ("Firefly Claps", "Syllables", "flutter_dash", "ba-na-na", "banana", "Ba, na, na! Let's clap the parts of words with the fireflies.",
             lambda n, s, e: mixed(n, s, e, ["rabbit", "robot", "pencil", "tiger", "rainbow", "banana"], [("Firefly Claps", None)])),
            ("Long Words", "Words of two beats", "auto_awesome", "rainbow", "rainbow", "Rain, bow... rainbow! Let's read longer words.",
             lambda n, s, e: word_level(n, s, ["rabbit", "robot", "rainbow", "pencil", "tiger", "lemon"], None, e)),
            topic("Three Beats", "Words of three beats", "flutter_dash", "po-ta-to", "butterfly", "But, ter, fly... butterfly! Let's clap three beats.",
                  "beats3"),
            topic("Compound Words", "Two words in one", "auto_awesome", "sun + flower", "sunflower", "Sun and flower make sunflower! Two words make one.",
                  "compound"),
            boss_words("Wake the Goat", "Boss · blends", "goat", "The goat is sleeping on the mountain. Let's spell words to wake it up!",
                       ["star", "flag", "frog", "sled", "skate", "tent"]),
        ]
    if world == "garden":
        sets = [
            (["the", "a", "I", "is"], [("I see the cat.", "cat"), ("The sun is hot.", "hot_sun"), ("It is a dog.", "dog")]),
            (["and", "to", "see", "can"], [("I can see a bird.", "bird_in_sky", ["and", "to"]), ("A cat and a dog.", "cat_and_dog"),
                                           ("I can run to the bus.", "run")]),
            (["he", "she", "we", "me", "my"], [("He is my brother.", "family_brother", ["me", "my"]), ("She is my sister.", "family_sister"),
                                               ("We can play.", "play")]),
            (["you", "it", "in", "on", "up"], [("It is in the box.", "cat_on_box", ["in", "up"]), ("The cat is on the box.", "cat_on_box"),
                                               ("You can go up.", "kite")]),
            (["look", "go", "come", "play", "here"], [("Look at the kite.", "kite", ["go", "here"]), ("Come and play.", "play"),
                                                      ("Go to the park.", "play")]),
            (["said", "was", "are", "they", "have"], [("They are my friends.", "family", ["said", "was"]), ("I have a red ball.", "ball"),
                                                      ("The dog was sad.", "sad")]),
            (["like", "big", "little", "this", "what"], [("I like this cake.", "cake", ["big", "what"]), ("What is this?", "box"),
                                                         ("A big cat, a little cat.", "many_cats")]),
        ]
        later = [
            (["help", "find", "make", "away", "funny"], [("I can make a cake.", "cake", ["away", "funny"]), ("Help me find my cat.", "cat"),
                                                         ("The clown is funny.", "clown")]),
            (["for", "with", "but", "not", "all"], [("This gift is for you.", "gift", ["but", "all"]), ("I play with my dog.", "dog"),
                                                    ("We all go to school.", "school")]),
            (["do", "no", "yes", "so", "did"], [("I am so happy.", "happy", ["do", "did"]), ("Yes, I did it!", "prize"),
                                                ("Do you like cake?", "cake")]),
            (["out", "down", "over", "under", "into"], [("Please sit down.", "chair", ["into", "over"]), ("The cat is under the chair.", "cat_under_chair"),
                                                        ("The frog jumps into the pond.", "frog")]),
            (["some", "any", "many", "very", "every"], [("I see many birds.", "many_birds", ["very", "every"]), ("It is very hot.", "hot_sun"),
                                                        ("I have some apples.", "apple")]),
            (["his", "her", "your", "our", "their"], [("Sara has a cat. It is her cat.", "cat", ["his", "our"]), ("This is his hat.", "hat"),
                                                      ("Is this your bag?", "bag")]),
        ]
        sight = lambda ws, ss: (lambda n, s, e: sight_level(n, s, ws, ss, e))
        specs = [("Sight Word Kites", "Sight words", "air", "the", "kite", "The! Let's fly the word kites.",
                  lambda n, s, e: kites_level(n, s, e))]
        for i, (ws, ss) in enumerate(sets[1:], 2):
            specs.append((f"Word Garden {i}", "Sight words", "local_florist", " ".join(ws[:3]), "flower",
                          f"Words to know by sight: {', '.join(ws)}!", sight(ws, ss)))
        specs.append(("Garden Review", "Review", "auto_awesome", "what here", "flower",
                      "Let's look back at our sight words: what, here, you, come, are!",
                      sight(["what", "here", "you", "come", "are"],
                            [("What is this?", "box", ["come", "here"]), ("Here is my cat.", "cat"), ("Come and play.", "play")])))
        for i, (ws, ss) in enumerate(later, len(sets) + 1):
            specs.append((f"Word Garden {i}", "Sight words", "local_florist", " ".join(ws[:3]), "flower",
                          f"Words to know by sight: {', '.join(ws)}!", sight(ws, ss)))
        specs.append(boss_words("Wake the Robot-Bus", "Boss · sight words", "robotBus", "The robot bus is sleeping in the town. Let's read sight words to wake it up!",
                                ["the", "said", "they", "with", "many", "your"], sight=True))
        return specs
    if world == "sky":
        return [
            ("Word Spaces", "Spaces between words", "space_bar", "I see", "cat", "Words need spaces! Let's put the words in order.",
             lambda n, s, e: sentence_level(n, s, e, "spaces")),
            topic("Naming Words", "Nouns", "category", "cat school ball", "ball",
                  "Cat, school, ball! Naming words name a person, a place or a thing.", "nouns"),
            ("Fix-It Pencil", "Capital letters", "edit", "Aa", "pencil", "Sentences start with a capital letter! Let's fix them.",
             lambda n, s, e: sentence_level(n, s, e, "capitals", [("Fix-It Pencil", None)])),
            topic("Capital Names", "Names start with capitals", "person", "Ali Sara", "family",
                  "Ali, Sara, Lahore! Names of people and places start with a capital letter.", "names"),
            ("Full Stop", "Ending a sentence", "fiber_manual_record", ".", "star", "A sentence ends with a full stop. Let's find it!",
             lambda n, s, e: sentence_level(n, s, e, "stops")),
            topic("Telling Sentences", "Whole sentences", "edit_note", "The dog runs.", "dog_running",
                  "The dog runs. A telling sentence tells us something!", "telling"),
            topic("Exclamation Mark!", "Strong feelings", "celebration", "!", "rainbow",
                  "Wow! An exclamation mark shows a big feeling!", "exclaim"),
            ("a or an?", "Articles", "cloud", "a an", "apple", "An apple, a ball! Let's choose a or an.",
             lambda n, s, e: sentence_level(n, s, e, "articles", [("a or an?", None)])),
            ("One or Many", "Plurals", "filter_none", "cat cats", "many_cats", "One bird, many birds! Let's make more than one.",
             lambda n, s, e: sentence_level(n, s, e, "plurals", [("One or Many", None)])),
            ("Sentence Rainbow", "Word order", "looks", "I see", "rainbow", "I see a rainbow! Let's put the words in order.",
             lambda n, s, e: sentence_level(n, s, e, "order", [("Sentence Rainbow", None)])),
            topic("Joining Words", "Joining with and", "linear_scale", "and", "cat_and_dog",
                  "A cat and a dog! The word and joins things together.", "and"),
            topic("Commas in Lists", "Lists", "format_list_numbered", "red, blue and green", "paint",
                  "Red, blue and green! Commas go between the things in a list.", "commas"),
            ("My First Sentences", "Writing sentences", "edit_note", "I can", "pencil", "Let's write whole sentences!",
             lambda n, s, e: sentence_level(n, s, e, "writing")),
            topic("Sentence Mix", "Review", "auto_awesome", "Aa . ? !", "pencil",
                  "Capitals, full stops, and, commas! Let's mix it all up.", "sky_mix"),
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
            topic("Animal Actions", "What animals do", "pets", "hop", "frog", "Fish swim, birds fly, frogs hop! What can animals do?",
                  "animals"),
            ("-ing Words", "Running, jumping", "directions_run", "ing", "run", "Run, running! Jump, jumping! Let's add i n g.",
             lambda n, s, e: sentence_level(n, s, e, "ing")),
            topic("Yesterday", "Words with -ed", "calendar_month", "jumped", "jump", "Today I jump. Yesterday I jumped! Let's add e d.",
                  "past"),
            ("Describing Words", "Big, small, hot, cold", "zoom_out_map", "big", "elephant", "Big, small, hot, cold! Words that tell us more.",
             lambda n, s, e: word_level(n, s, ["big", "small", "hot", "cold", "happy", "sad"], None, e,
                                        extra=lambda W: W.cloze("The elephant is big.", "big", ["small", "sad"], "elephant"))),
            topic("Colour and Size", "Describing things", "format_paint", "a big red bus", "red_bus",
                  "A big red bus! Words can tell the colour and the size.", "colour_size"),
            topic("Feelings", "Feeling words", "face", "happy", "happy", "Happy, sad, angry, scared! How do you feel?", "feelings"),
            ("Opposites", "Opposites", "swap_horiz", "up down", "up", "Up and down, day and night! Words that are opposite.",
             lambda n, s, e: sentence_level(n, s, e, "opposites")),
            topic("More Opposites", "Opposites", "swap_horiz", "open closed", "open", "Open and closed, loud and quiet! More opposites.",
                  "opposites2"),
            ("In, On, Under", "Where things are", "pets", "in on", "cat_on_box", "Is the cat in, on or under? Let's look!",
             lambda n, s, e: sentence_level(n, s, e, "positions")),
            topic("Behind, Next To, Between", "Where things are", "pets", "behind", "cat_behind_box",
                  "Behind, next to, between! Where is the cat?", "positions2"),
            topic("Bigger and Biggest", "Comparing", "zoom_out_map", "big bigger biggest", "sizes",
                  "Big, bigger, biggest! Let's compare.", "sizes"),
            ("Jungle Sentences", "Writing what we do", "edit_note", "I can", "monkey", "Let's write sentences about what we can do!",
             lambda n, s, e: sentence_level(n, s, e, "actions")),
            ("Wake the Fish", "Boss · action words", "bedtime", "jump", "fish", "The fish is asleep in the cove. Let's wake it up!",
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
            topic("When?", "Asking about time", "calendar_month", "When?", "night", "When do you sleep? At night! Let's ask about time.",
                  "when"),
            topic("Why? Because", "Asking why", "help", "Why?", "umbrella", "Why do we need an umbrella? Because it is raining!",
                  "why"),
            topic("How Many?", "Asking how many", "cake", "How many?", "many_cats", "How many cats? Three cats! Let's count and ask.",
                  "how_many"),
            topic("Can You? Is It?", "Yes or no questions", "check_circle", "Can you?", "jump",
                  "Can you jump? Yes, I can! Let's ask yes or no questions.", "yesno_q"),
            ("Days of the Week", "Days", "calendar_month", "Monday", "calendar", "Monday, Tuesday, Wednesday! Let's learn the days.",
             lambda n, s, e: sentence_level(n, s, e, "days")),
            topic("Months of the Year", "Months", "calendar_month", "January", "calendar",
                  "January, February, March! There are twelve months in a year.", "months"),
            ("Talk to Aliens", "Speaking", "record_voice_over", "Hi!", "alien", "Hi! Let's talk to the friendly aliens.",
             lambda n, s, e: sentence_level(n, s, e, "aliens", [("Talk to Aliens", None)])),
            topic("Asking Politely", "Please and thank you", "record_voice_over", "please", "gift",
                  "Please and thank you! Let's ask nicely.", "polite"),
            ("Answer Me", "Answering in sentences", "question_answer", "Yes, I can.", "robot", "Let's answer questions with a whole sentence.",
             lambda n, s, e: sentence_level(n, s, e, "answers")),
            topic("Question or Telling?", "Asking or telling", "question_answer", "? .", "question",
                  "Is it a question, or a telling sentence? Let's find out!", "q_or_t"),
            ("Wake the Frog", "Boss · questions", "bedtime", "?", "frog", "The frog is sleeping by the river. Let's ask and answer to wake it up!",
             lambda n, s, e: sentence_level(n, s, e, "island_boss")),
        ]
    if world == "river":
        return [
            ("Read & Match", "Reading", "view_carousel", "Read!", "storybook", "Read the sentence, then find the picture!",
             lambda n, s, e: sentence_level(n, s, e, "match", [("Read & Match", None)])),
            topic("Read the Signs", "Signs", "place", "STOP", "stop", "Stop! Go! Exit! Let's read the signs around us.", "signs"),
            ("Yes or No?", "Reading carefully", "check_circle", "Yes No", "cat", "Read, look, and say yes or no!",
             lambda n, s, e: sentence_level(n, s, e, "yesno")),
            topic("Picture Clues", "Using the picture", "image", "?", "nest", "Stuck on a word? Look at the picture for a clue!", "clues"),
            ("Missing Words", "Words that fit", "edit", "___", "storybook", "One word is missing. Which word fits?",
             lambda n, s, e: sentence_level(n, s, e, "cloze")),
            topic("Read a List", "Lists", "shopping_basket", "milk, eggs", "milk", "Milk, eggs, bread! Let's read a shopping list.", "list"),
            ("Star Questions", "Comprehension", "auto_awesome", "Who? What?", "star", "Who? What? Where? Let's answer the star questions.",
             lambda n, s, e: sentence_level(n, s, e, "passage1", [("Star Questions", None)])),
            topic("Follow the Steps", "Instructions", "format_list_numbered", "1 2 3", "sandwich",
                  "First, next, last! Let's follow the steps.", "steps"),
            topic("How Do They Feel?", "Feelings in stories", "face", "?", "sad", "How does Sam feel? Let's read and find out!", "feel"),
            ("Little Stories", "Reading stories", "auto_stories", "Sam", "story", "Let's read little stories and answer questions!",
             lambda n, s, e: sentence_level(n, s, e, "passage2")),
            topic("What Happens Next?", "Guessing what happens", "auto_stories", "Next?", "rain",
                  "Dark clouds... what happens next? Let's guess!", "next"),
            ("Rhyme Time", "Poems and rhymes", "music_note", "cat hat", "frog", "Cat, hat, sat! Let's read rhymes.",
             lambda n, s, e: sentence_level(n, s, e, "rhymes")),
            topic("Longer Stories", "Reading longer stories", "menu_book", "Max", "dog",
                  "Let's read a longer story about Bilal and his dog!", "long"),
            ("River Reading", "Reading and writing", "menu_book", "Read!", "fish_in_sea", "Let's read, then write!",
             lambda n, s, e: sentence_level(n, s, e, "readwrite")),
            ("Wake the Penguin", "Boss · reading", "bedtime", "Read!", "penguin", "The penguin is sleeping on the ice. Let's read to wake it up!",
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
            topic("Once Upon a Time", "Starting and ending a story", "auto_stories", "Once upon a time", "storybook",
                  "Once upon a time... Let's start a story, and end it!", "once"),
            ("All About Me", "Writing about me", "face", "I am", "warm-up", "Let's write about you!",
             lambda n, s, e: sentence_level(n, s, e, "me")),
            ("My Family", "Writing about family", "family_restroom", "My family", "family", "Let's write about your family!",
             lambda n, s, e: sentence_level(n, s, e, "family")),
            topic("My Pet", "Writing about a pet", "pets", "My pet", "rabbit", "Do you have a pet? Let's write about pets!", "pet"),
            topic("My Best Friend", "Writing about a friend", "person", "My friend", "hug", "Let's write about your best friend!", "friend"),
            topic("My School", "Writing about school", "backpack", "My school", "school", "Let's write about your school!", "school_me"),
            topic("Favourite Food", "Writing about food", "restaurant", "Yum!", "mango", "Yum! Let's write about your favourite food.", "food"),
            ("My Day", "Writing about my day", "wb_sunny", "Today", "sun", "Morning, school, play, sleep! Let's write about your day.",
             lambda n, s, e: sentence_level(n, s, e, "day")),
            topic("Describe a Picture", "Describing what we see", "image", "I see...", "red_bus",
                  "What do you see? Let's tell about the picture!", "describe"),
            topic("A Letter to a Friend", "Writing a letter", "mail", "Dear Ali,", "envelope", "Dear Ali! Let's write a letter to a friend.",
                  "letter"),
            ("My Story", "Creative writing", "edit", "Once...", "storybook", "Let's make up our very own story!",
             lambda n, s, e: sentence_level(n, s, e, "mystory", [("My Story", None)])),
            ("Wake the Moon", "Boss · final", "bedtime", "The End", "moon", "The moon is sleeping. Let's read and write to wake it up!",
             lambda n, s, e: sentence_level(n, s, e, "final", [("Wake the Moon", None)])),
        ]
    raise ValueError(world)


def boss_words(title, skill, boss, say, words, classic_level=None, sight=False):
    def build(n, step, earlier):
        L = B.Level(n, seed=f"boss{n}")
        L.words, L.sight = words, sight
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
    L.words, L.sight = ["the", "a", "I", "is"], True
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


# ------------------------------------------------------------------ topic levels
#
# The levels added with the 14 worlds. Each is a function that plays its games in order of
# importance: finalize() keeps the first game of each kind, adds three star games and cuts the
# level to ten, so the games at the end are the ones that may go. TOPICS: kind -> (the level's
# words for the star games, its sentences with pictures for true-or-silly or None, the games).

def t_endings(W):
    W.ask("What sound is at the end?", "Cat! Which letter makes the sound at the end of cat?", B.card(None, B.pic("cat")), ["t", "c", "a"], "t")
    W.pick_picture("Which one ends with /n/?", f"Which one ends with {B.sound('n')}?", B.card("n"), ["hen", "dog", "cup"], "hen")
    W.sort_into("Sort the pictures!", f"Sort the pictures! Do they end with {B.sound('t')} or {B.sound('g')}?", B.card("t g"),
                [("t", None), ("g", None)], [("cat", "cat", 0), ("hat", "hat", 0), ("bat", "bat", 0), ("dog", "dog", 1), ("pig", "pig", 1),
                                             ("bag", "bag", 1)])
    W.missing("bus", 2)
    W.speak_line("Cat, hat, bat! They all end the same.", "hat")
    W.write_word("dog")
    W.hear_word("pin", ["pin", "pig", "pit"])
    W.build("sun")
    W.hunt("cat", ["cap", "can", "cab"])


def t_numbers(W):
    W.count(8, ["six", "ten"])
    W.order_words("Put the numbers in order!", "Seven, eight, nine, ten! Put the numbers in order.", B.card(None, B.pic("ten")),
                  ["seven", "eight", "nine", "ten"])
    W.which_picture("nine", ["seven", "eight", "nine", "ten"])
    W.cloze("Six, seven, eight, nine.", "eight", ["ten", "five"])
    W.speak_line("Seven, eight, nine, ten!", "ten")
    W.write_word("seven")
    W.hear_word("ten", ["seven", "eight", "nine", "ten"])
    W.spell("ten")
    W.hunt("nine", ["nice", "line", "mine"])


def t_weather(W):
    W.read_match("It is windy.", "wind", ["sun", "snow"])
    W.ask("What is the weather?", "Look! What is the weather?", B.card(None, B.pic("rain")), ["It is rainy.", "It is sunny.", "It is snowy."],
          "It is rainy.")
    W.yes_no("It is snowy.", "hot_sun", False)
    W.order_sentence("It is a sunny day.", "sun")
    W.write_sentence("It is cold.")
    W.speak_line("Rain, rain, go away!", "rain")
    W.hear_word("wind", ["sun", "rain", "snow", "wind"], 1)
    W.spell("snow")
    W.hunt("rain", ["ran", "train", "main"])


def t_beats3(W):
    W.ask("How many beats?", "Elephant! Clap it with me. How many beats?", B.card("elephant", B.pic("elephant")), ["1", "2", "3"], "3")
    W.order_words("Build the word!", "Po, ta, to... potato! Put the beats in order.", word_card("potato"), ["po", "ta", "to"])
    W.which_picture("butterfly", ["butterfly", "kangaroo", "dinosaur", "banana"])
    W.sort_into("Two beats or three?", "Clap each word! Does it have two beats, or three?", B.card("2 3"), [("2", None), ("3", None)],
                [("rabbit", "rabbit", 0), ("tiger", "tiger", 0), ("pencil", "pencil", 0), ("banana", "banana", 1), ("elephant", "elephant", 1),
                 ("potato", "potato", 1)])
    W.speak_line("But, ter, fly! Butterfly!", "butterfly")
    W.write_word("banana")
    W.hear_word("kangaroo", ["kangaroo", "elephant", "dinosaur"])
    W.spell("potato")
    W.hunt("potato", ["tomato", "photo", "pot"])


def t_compound(W):
    W.ask("sun + flower = ?", "Sun and flower. What word do they make?", B.card("sun + flower"), ["sunflower", "sunhat", "flowerpot"], "sunflower")
    W.order_words("Join the words!", "Cup and cake make cupcake! Put the two words together.", word_card("cupcake"), ["cup", "cake"])
    W.which_picture("snowman", ["snowman", "popcorn", "rainbow", "football"])
    W.match_pairs("Find the pairs!", "Find the pairs! Match the two words that make one.", B.card("rain + bow"),
                  [("rain", "bow"), ("foot", "ball"), ("pop", "corn")])
    W.speak_line("Sun and flower make sunflower!", "flower")
    W.write_word("cupcake")
    W.hear_word("popcorn", ["popcorn", "rainbow", "snowman"])
    W.spell("rainbow")
    W.hunt("rainbow", ["rain", "bow", "rainy"])


def t_nouns(W):
    W.sort_into("Person, place or thing?", "Is it a person, a place or a thing? Sort the pictures!", B.card("person place thing"),
                [("person", None), ("place", None), ("thing", None)],
                [("doctor", "doctor", 0), ("teacher", "teacher", 0), ("baby", "family_baby", 0), ("school", "school", 1), ("house", "house", 1),
                 ("shop", "shop", 1), ("ball", "ball", 2), ("cup", "cup", 2), ("kite", "kite", 2)])
    W.tap_word("Tap the naming word!", "The dog is big. Tap the naming word!", "The dog is big.", "dog")
    W.ask("Which is a naming word?", "Which word is a naming word?", B.card(None, B.pic("kite")), ["kite", "run", "big"], "kite")
    W.read_match("The doctor has a bag.", "doctor", ["teacher", "family_baby"])
    W.order_sentence("The cat sat on the mat.", "cat")
    W.write_sentence("The dog has a ball.")
    W.speak_line("A naming word names a person, a place or a thing.", "ball")
    W.spell("shop")
    W.hunt("cat", ["cut", "cot", "act"])


def t_names(W):
    W.fix_name("My friend is ali.", "ali")
    W.ask("Which one is right?", "Which name is written the right way?", B.card(None, B.pic("family_sister")), ["Sara", "sara"], "Sara")
    W.story_question("Sara lives in Karachi. Her friend Ali lives in Lahore.", "Where does Ali live?", "in Lahore", ["in Karachi", "with Sara"])
    W.order_sentence("Ali lives in Lahore.", "house")
    W.write_sentence("Ali and Sara are friends.")
    W.speak_line("Names start with a capital letter!", "pencil")
    W.hunt("Ali", ["ali", "All", "Al"])
    W.spell("Sara")


def t_telling(W):
    W.ask("Which one is a sentence?", "Which one is a whole sentence?", B.card(None, B.pic("dog_running")),
          ["The dog runs.", "the dog", "runs dog the"], "The dog runs.")
    W.read_match("The bird is in the sky.", "bird_in_sky", ["fish_in_sea", "cat_in_bed"])
    W.fix_capital("We go to the park.")
    W.story_question("Sam has a red ball. He kicks it.", "What does Sam do?", "He kicks the ball.", ["He eats the ball.", "He goes to sleep."])
    W.order_sentence("The cat sleeps on the bed.", "cat_in_bed")
    W.write_sentence("I like to read.")
    W.speak_line("A telling sentence tells us something.", "story")
    W.hunt(".", [",", "?", "!"])


def t_exclaim(W):
    W.end_mark("Look out!")
    W.read_match("Wow! A rainbow!", "rainbow", ["rain", "moon"])
    W.tap_word("Tap the word that shouts!", "Ouch, my leg hurts. Tap the word that needs an exclamation mark!", "Ouch my leg hurts.", "Ouch")
    W.story_question("The bus is coming. Mia shouts, Stop!", "What does Mia shout?", "Stop!", ["Hello.", "Is it red?"])
    W.order_sentence("Look at the big rainbow!", "rainbow")
    W.write_sentence("I did it!")
    W.speak_line("Wow! What a big cake!", "cake")
    W.hunt("!", [".", "?", ","])


def t_and(W):
    W.cloze("I have a cat and a dog.", "and", ["is", "the"])
    W.read_match("A cat and a dog.", "cat_and_dog", ["cat", "dog"])
    W.tap_word("Tap the joining word!", "Ali and Sara play. Tap the joining word!", "Ali and Sara play.", "and")
    W.story_question("Mia has a cat. Mia has a dog.", "Which sentence joins them?", "Mia has a cat and a dog.",
                     ["Mia has a cat a dog.", "Mia and has a cat."])
    W.order_sentence("I like milk and cake.", "cake")
    W.write_sentence("I can run and jump.")
    W.speak_line("Bread and jam, cat and dog!", "jam")
    W.spell("and")
    W.hunt("and", ["an", "hand", "sand"])


def t_commas(W):
    W.ask("Which list is right?", "Red, blue and green. Which list has its commas in the right place?", B.card(None, B.pic("paint")),
          ["red, blue and green", "red blue, and green", "red, blue, and, green"], "red, blue and green")
    W.tap_word("Where does the comma go?", "I like red blue and green. Tap the word that needs a comma after it!", "I like red blue and green.", "red")
    W.story_question("Sara has a cat, a dog and a fish.", "How many pets does Sara have?", "three", ["two", "one"])
    W.order_sentence("I see red, blue and green.", "paint")
    W.write_sentence("I like cats, dogs and fish.")
    W.speak_line("Mangoes, bananas and apples!", "mango")
    W.hunt(",", [".", "?", "!"])
    W.spell("list")


def t_sky_mix(W):
    W.fix_capital("Sara has a kite.")
    W.end_mark("Can you see me?")
    W.read_match("I see three cats.", "many_cats", ["cat", "many_hats"])
    W.story_question("Mia has a red hat, a blue bag and a pink cup.", "What colour is the bag?", "blue", ["red", "pink"])
    W.order_sentence("A cat and a dog.", "cat_and_dog")
    W.write_sentence("Ali has an apple.")
    W.speak_line("Wow! I can write sentences!", "pencil")
    W.hunt("an", ["a", "and", "in"])
    W.spell("birds")


def t_animals(W):
    W.ask("What can a fish do?", "What can a fish do?", B.card("fish", B.pic("fish")), ["swim", "fly", "hop"], "swim")
    W.read_match("A frog can hop.", "frog", ["fish", "bird"])
    W.yes_no("A fish can fly.", "fish", False)
    W.order_sentence("A monkey can climb.", "monkey")
    W.write_sentence("A bird can fly.")
    W.speak_line("Fish swim, birds fly, frogs hop!", "frog")
    W.spell("hop")
    W.hear_word("climb", ["climb", "hop", "swim", "fly"])
    W.hunt("swim", ["swam", "slim", "him"])


def t_past(W):
    W.cloze("Yesterday I played with my ball.", "played", ["play", "plays"])
    W.sort_into("Today or yesterday?", "Read each word. Is it today, or yesterday?", B.card("jump jumped"), [("today", None), ("yesterday", None)],
                [("jump", None, 0), ("play", None, 0), ("walk", None, 0), ("jumped", None, 1), ("played", None, 1), ("walked", None, 1)])
    W.story_question("Yesterday Ali played cricket. Then he walked home.", "What did Ali play?", "cricket", ["football", "tennis"])
    W.match_pairs("Find the pairs!", "Find the pairs! Match each word to the same word with e d.", B.card("jump = jumped"),
                  [("jump", "jumped"), ("kick", "kicked"), ("help", "helped")])
    W.order_sentence("We played in the park.", "play")
    W.write_sentence("I kicked the ball.")
    W.speak_line("Today I jump. Yesterday I jumped!", "jump")
    W.spell("jumped")
    W.hunt("jumped", ["jumps", "jump", "jumping"])


def t_colour_size(W):
    W.read_match("I see a red bus.", "red_bus", ["bus", "car"])
    W.ask("Which word tells the colour?", "A big red ball. Which word tells the colour?", B.card("a big red ball"), ["red", "big", "ball"], "red")
    W.tap_word("Tap the size word!", "The big dog runs. Tap the word that tells the size!", "The big dog runs.", "big")
    W.yes_no("The frog is green.", "frog", True)
    W.order_sentence("I see a big red bus.", "red_bus")
    W.write_sentence("I see a little green frog.")
    W.speak_line("A big red bus and a little yellow chick!", "red_bus")
    W.spell("little")
    W.hunt("big", ["bag", "dig", "pig"])


def t_feelings(W):
    W.which_picture("happy", ["happy", "sad", "angry", "scared", "tired"])
    W.cloze("Ali lost his ball. He is sad.", "sad", ["happy", "funny"])
    W.story_question("It is Mia's birthday. She has a big cake.", "How does Mia feel?", "happy", ["sad", "angry"])
    W.order_sentence("I feel happy today.", "happy")
    W.write_sentence("I feel sleepy.")
    W.speak_line("Happy, sad, angry, scared!", "happy")
    W.spell("sad")
    W.hear_word("scared", ["happy", "sad", "angry", "scared", "tired"])
    W.hunt("sad", ["sat", "said", "sand"])


def t_opposites2(W):
    W.ask("The opposite of open?", "Open! What is the opposite of open?", B.card("open", B.pic("story")), ["closed", "open", "red"], "closed")
    W.match_pairs("Find the opposites!", "Find the pairs! Match each word to its opposite.", B.card("open closed"),
                  [("open", "closed"), ("loud", "quiet"), ("sweet", "sour"), ("young", "old")])
    W.which_picture("loud", ["loud", "quiet", "sweet", "sour"])
    W.yes_no("The lemon is sweet.", "lemon", False)
    W.order_sentence("The door is open.", "door")
    W.write_sentence("The lemon is sour.")
    W.speak_line("Open and closed, loud and quiet!", "loud")
    W.spell("old")
    W.hunt("open", ["oven", "pen", "opens"])


def t_positions2(W):
    W.read_match("The cat is behind the box.", "cat_behind_box", ["cat_next_to_box", "cat_between_boxes"])
    W.ask("Where is the dog?", "Look! Where is the dog?", B.card(None, B.pic("dog_next_to_box")),
          ["next to the box", "behind the box", "on the box"], "next to the box")
    W.yes_no("The cat is between the boxes.", "cat_between_boxes", True)
    W.order_sentence("The dog is behind the box.", "dog_behind_box")
    W.write_sentence("The cat is next to the box.")
    W.speak_line("Behind, next to, between!", "cat_between_boxes")
    W.spell("behind")
    W.hunt("next", ["text", "nest", "net"])


def t_sizes(W):
    W.pick_picture("Which is the biggest?", "Which animal is the biggest?", B.card("biggest"), ["mouse", "dog", "elephant"], "elephant")
    W.order_words("Put the words in order!", "Big, bigger, biggest! Put the words in order.", B.card(None, B.pic("sizes")),
                  ["big", "bigger", "biggest"])
    W.cloze("A dog is bigger than a mouse.", "bigger", ["big", "biggest"])
    W.yes_no("A mouse is bigger than an elephant.", "mouse", False)
    W.write_sentence("The elephant is the biggest.")
    W.speak_line("Big, bigger, biggest!", "sizes")
    W.spell("bigger")
    W.hunt("biggest", ["bigger", "big", "bag"])


def t_when(W):
    W.ask("When do you sleep?", "When do you sleep?", B.card("When do you sleep?", B.pic("bed")), ["at night", "at lunch", "at school"], "at night")
    W.story_question("Ali wakes up in the morning. He goes to school. At night, he sleeps.", "When does Ali sleep?", "at night",
                     ["in the morning", "at school"])
    W.read_match("We see the moon at night.", "night", ["hot_sun", "school"])
    W.order_sentence("When do you eat lunch?", "eat")
    W.write_sentence("I sleep at night.")
    W.speak_line("When do you wake up? In the morning!", "wake_up")
    W.hear_word("morning", ["morning", "night", "today", "when"])
    W.spell("when")
    W.hunt("when", ["then", "where", "hen"])


def t_why(W):
    W.ask("Why do we need an umbrella?", "Why do we need an umbrella?", B.card("Why?", B.pic("umbrella")),
          ["Because it is raining.", "Because it is hot.", "Because I am hungry."], "Because it is raining.")
    W.story_question("Mia is sad because her kite is broken.", "Why is Mia sad?", "Her kite is broken.", ["She has a cake.", "It is sunny."])
    W.read_match("I eat because I am hungry.", "eat", ["sleep", "swim"])
    W.order_sentence("I am happy because I won.", "prize")
    W.write_sentence("I eat because I am hungry.")
    W.speak_line("Why do you smile? Because I am happy!", "happy")
    W.hear_word("because", ["because", "why", "when", "what"])
    W.spell("why")
    W.hunt("because", ["became", "begin", "bees"])


def t_how_many(W):
    W.count(7, ["six", "nine"])
    W.ask("How many legs?", "How many legs does a dog have?", B.card("How many legs?", B.pic("dog")), ["four", "two", "six"], "four")
    W.read_match("I see three cats.", "many_cats", ["cat", "many_birds"])
    W.story_question("Sara has two red balls and one blue ball.", "How many balls does Sara have?", "three", ["two", "one"])
    W.order_sentence("How many birds can you see?", "many_birds")
    W.write_sentence("I have two hands.")
    W.speak_line("How many? One, two, three!", "many_cats")
    W.spell("many")
    W.hunt("how", ["who", "now", "cow"])


def t_yesno_q(W):
    W.ask("Is the sun hot?", "Is the sun hot? Pick the answer!", B.card("Is the sun hot?", B.pic("hot_sun")), ["Yes, it is.", "No, it is not."],
          "Yes, it is.")
    W.sort_into("Can it fly?", "Can it fly? Sort the pictures into yes and no!", B.card("Can it fly?"), [("Yes", None), ("No", None)],
                [("bird", "bird", 0), ("plane", "plane", 0), ("kite", "kite", 0), ("dog", "dog", 1), ("cow", "cow", 1), ("fish", "fish", 1)])
    W.tap_word("Tap the asking word!", "Can you swim? Tap the word that asks!", "Can you swim?", "Can")
    W.story_question("Ali has a dog. It is brown and it likes to run.", "Is Ali's dog brown?", "Yes, it is.", ["No, it is not."])
    W.order_sentence("Is it a big dog?", "dog")
    W.write_sentence("Do you like rice?")
    W.speak_line("Can you jump? Yes, I can!", "jump")
    W.spell("yes")
    W.hunt("Can", ["can", "Cat", "Car"])


def t_months(W):
    W.order_words("Put the months in order!", "January, February, March! Put the months in order.", B.card(None, B.pic("calendar")),
                  ["January", "February", "March"])
    W.cloze("April, May, June.", "May", ["July", "March"])
    W.story_question("My birthday is in May. I have a big cake.", "When is the birthday?", "in May", ["in June", "in March"])
    W.read_match("It is cold in December.", "snowman", ["hot_sun", "flower"])
    W.hear_word("July", ["June", "July", "May", "March"])
    W.spell("June")
    W.speak_line("January, February, March, April, May, June!", "calendar")
    W.write_sentence("My birthday is in June.")
    W.hunt("June", ["July", "Jane", "jump"])


def t_polite(W):
    W.ask("Which one is polite?", "Which one asks nicely?", B.card(None, B.pic("milk")), ["May I have some milk, please?", "Give me milk!"],
          "May I have some milk, please?")
    W.read_match("Thank you for the gift!", "gift", ["cake", "ball"])
    W.tap_word("Tap the polite word!", "Pass the salt, please. Tap the polite word!", "Pass the salt please.", "please")
    W.story_question("Ali wants a pencil. He says, May I have a pencil, please? Sara gives him one.", "What does Ali say next?",
                     "Thank you!", ["Go away!", "No!"])
    W.order_sentence("May I play, please?", "play")
    W.write_sentence("Thank you very much.")
    W.speak_line("Excuse me, may I come in?", "door")
    W.spell("please")
    W.hunt("please", ["place", "peas", "plays"])


def t_q_or_t(W):
    W.end_mark("Where is my hat?")
    W.story_question("Ali asks, Can I play? Mia says, Yes, you can.", "Who asks a question?", "Ali", ["Mia", "the dog"])
    W.L.pick("Asking or telling?", "Listen! Do you like cake? Is it asking, or telling?", B.card(None, None, listen=True), ["asking", "telling"],
             "asking", shape=W.shape())
    W.tap_word("Tap the asking word!", "Where is my hat? Tap the word that asks!", "Where is my hat?", "Where")
    W.read_match("Is the cat on the box?", "cat_on_box", ["cat_in_bed", "dog_on_box"])
    W.order_sentence("Do you like the sea?", "fish_in_sea")
    W.write_sentence("Where is my bag?")
    W.speak_line("Is it raining? Yes, it is raining.", "rain")
    W.hunt("?", [".", "!", ","])


def t_signs(W):
    W.pick_picture("TOILET", "Read the sign. Which picture goes with it?", B.card("TOILET"),
                   {"toilet": "toilet", "bus stop": "bus_stop", "school": "school"}, "toilet")
    W.ask("The sign says PUSH.", "The sign on the door says PUSH. What do you do?", B.card("PUSH", B.pic("door")),
          ["push the door", "pull the door", "stop"], "push the door")
    W.match_pairs("Match the signs!", "Find the pairs! Match each sign to its picture.", B.card("Find the pairs!"),
                  [("STOP", "stop"), ("BUS STOP", "bus_stop"), ("HOSPITAL", "hospital")], pictures=True)
    W.L.truth("True or silly?", "Look at the picture. Red means go. True, or silly?", B.card(None, None, listen=True), "Red means go.",
              B.pic("traffic_light"), False)
    W.story_question("The sign on the shop door says CLOSED.", "Can we go in?", "No, we can not.", ["Yes, we can."])
    W.order_sentence("Stop at the red light.", "traffic_light")
    W.write_word("exit")
    W.speak_line("Stop, look and listen!", "stop")
    W.hunt("STOP", ["SHOP", "STEP", "SPOT"])
    W.spell("open")


def t_clues(W):
    W.ask("The ___ are in the nest.", "Look at the picture. The what are in the nest? Which word fits?", B.card(None, B.pic("nest")),
          ["eggs", "dogs", "cups"], "eggs")
    W.yes_no("The bird is in the nest.", "nest", False)
    W.read_match("The penguin is on the ice.", "penguin", ["duck", "fish"])
    W.order_sentence("The eggs are in the nest.", "nest")
    W.write_sentence("The bee is on the flower.")
    W.speak_line("Look at the picture for a clue!", "storybook")
    W.spell("nest")
    W.hunt("nest", ["next", "net", "rest"])


def t_list(W):
    W.sort_into("Is it on the list?", "The list says milk, eggs, bread. Sort the pictures! Is it on the list?", B.card("milk, eggs, bread"),
                [("yes", None), ("no", None)],
                [("milk", "milk", 0), ("egg", "egg", 0), ("bread", "bread", 0), ("cake", "cake", 1), ("fish", "fish", 1), ("rice", "rice", 1)])
    W.story_question("Shopping list: rice, mangoes, milk, bread.", "What is first on the list?", "rice", ["milk", "bread"])
    W.ask("What is on the list?", "The list says pen, book, bag. What is on the list?", B.card("pen, book, bag"), ["a book", "a cat", "a cake"],
          "a book")
    W.order_words("Put the list in order!", "One, milk. Two, eggs. Three, bread. Put the list in order.", B.card("1 milk  2 eggs  3 bread"),
                  ["milk", "eggs", "bread"])
    W.write_sentence("milk, eggs, bread", text="Write the list")
    W.which_picture("bread", ["bread", "milk", "egg", "rice"])
    W.speak_line("Milk, eggs, bread and rice!", "milk")
    W.spell("eggs")
    W.hunt("milk", ["mile", "silk", "mill"])


def t_steps(W):
    W.picture_strip(["bread", "cheese", "sandwich"], "First the bread, next the cheese, last the sandwich! Put the steps in order.",
                    "Put the steps in order!")
    W.story_question("First, wet your hands. Next, use soap. Last, dry your hands.", "What do you do first?", "wet your hands",
                     ["dry your hands", "use soap"])
    W.tap_word("Tap the doing word!", "Wash your hands. Tap the doing word!", "Wash your hands.", "Wash")
    W.read_match("Brush your teeth.", "brush", ["soap", "bed"])
    W.cloze("First, put on your socks. Next, put on your shoes.", "Next", ["Last", "First"])
    W.write_sentence("First, wash your hands.")
    W.speak_line("Wash, rinse, dry!", "soap")
    W.spell("wash")
    W.hunt("first", ["fist", "fast", "frost"])


def t_feel(W):
    W.story_question("Sam's ice cream fell on the ground.", "How does Sam feel?", "sad", ["happy", "sleepy"])
    W.pick_picture("How does Mia feel?", "Mia has a new kite. How does she feel? Find the face!", B.card("Mia has a new kite."),
                   ["happy", "sad", "angry"], "happy")
    W.cloze("A big dog barks at the cat. The cat is scared.", "scared", ["happy", "hungry"])
    W.yes_no("The baby is tired.", "tired", True)
    W.order_sentence("Mia is happy today.", "happy")
    W.write_sentence("I feel happy when I play.")
    W.speak_line("How do you feel today?", "happy")
    W.hear_word("angry", ["happy", "sad", "angry", "scared"])
    W.spell("tired")


def t_next(W):
    W.story_question("It is very hot. Mia has an ice cream in the sun.", "What happens next?", "The ice cream melts.",
                     ["It snows.", "The ice cream grows."])
    W.pick_picture("What happens next?", "The clouds are dark and grey. What happens next?", B.card("Dark clouds..."),
                   ["rain", "sun", "rainbow"], "rain")
    W.picture_strip(["egg", "chick", "hen"], "First an egg, then a chick, then a hen! Put them in order.")
    W.ask("What happens next?", "Sara plants a seed and gives it water. What happens next?", B.card(None, B.pic("seed")),
          ["It grows.", "It flies.", "It sings."], "It grows.")
    W.yes_no("A chick grows into a hen.", "chick", True)
    W.write_sentence("The ice cream melts.")
    W.speak_line("What happens next? Let's guess!", "storybook")
    W.spell("next")
    W.hunt("melts", ["meets", "belts", "melt"])


STORY = "Bilal has a little brown dog called Max. Every morning, they go to the park. Max runs after the ball. Then they go home and have a nap."


def t_long(W):
    W.story_question(STORY, "What is the dog called?", "Max", ["Bilal", "Sam"])
    W.cloze("Max runs after the ball.", "ball", ["cat", "bus"])
    W.read_match("They go to the park.", "play", ["school", "shop"])
    W.yes_no("Max runs after a cat.", "dog_running", False)
    W.order_sentence("Max runs after the ball.", "dog_running")
    W.write_sentence("Bilal has a little dog.")
    W.speak_line("Every morning, they go to the park.", "play")
    W.hear_word("morning", ["morning", "evening", "park"])
    W.spell("park")
    W.hunt("Max", ["Mix", "Map", "Mat"])


def t_once(W):
    W.ask("How does a story start?", "Which words start a story?", B.card(None, B.pic("storybook")), ["Once upon a time", "The End", "Goodbye"],
          "Once upon a time")
    W.story_question("Once upon a time, a little dragon lived in a cave. One day, it made a friend.", "Who is the story about?",
                     "a little dragon", ["a big fish", "a robot"])
    W.read_match("Once upon a time, there was a king.", "king", ["queen", "dragon"])
    W.order_sentence("One day, the fox went out.", "fox")
    W.write_sentence("Long ago, there was a king.")
    W.speak_line("Once upon a time... The End!", "storybook")
    W.spell("once")
    W.hunt("once", ["one", "ounce", "on"])


def t_pet(W):
    W.read_match("My pet has long ears.", "rabbit", ["fish", "parrot"])
    W.cloze("My cat likes to drink milk.", "milk", ["rice", "jam"])
    W.story_question("I have a pet fish. It is orange. It swims in a bowl.", "What colour is the fish?", "orange", ["green", "pink"])
    W.yes_no("A parrot can talk.", "parrot", True)
    W.order_sentence("My pet cat is fluffy.", "cat")
    W.write_sentence("I have a pet rabbit.")
    W.speak_line("My pet is a dog. His name is Max.", "dog")
    W.spell("pet")
    W.hunt("pet", ["pat", "pen", "bet"])


def t_friend(W):
    W.cloze("My best friend is kind.", "kind", ["cold", "wet"])
    W.story_question("My best friend is Hina. She likes to draw. We play together at school.", "What does Hina like to do?", "draw",
                     ["swim", "cook"])
    W.read_match("We play together.", "play", ["sleep", "eat"])
    W.order_sentence("We share our toys.", "teddy")
    W.write_sentence("My best friend is Ali.")
    W.speak_line("A good friend is kind and helps you.", "hug")
    W.spell("friend")
    W.hunt("friend", ["fried", "find", "friends"])


def t_school_me(W):
    W.sort_into("School or home?", "Do we use it at school, or at home? Sort the pictures!", B.card("school home"),
                [("school", "school"), ("home", "house")],
                [("pencil", "pencil", 0), ("book", "book", 0), ("crayon", "crayon", 0), ("bed", "bed", 1), ("bath", "bath", 1), ("spoon", "spoon", 1)])
    W.read_match("My teacher reads to us.", "teacher", ["doctor", "family_baby"])
    W.ask("What do we write with?", "At school, what do we write with?", B.card(None, B.pic("school")), ["a pencil", "a spoon", "a sock"], "a pencil")
    W.story_question("At school, I read books. I write with my pencil. At break, I play with my friends.", "What do I do at break?",
                     "play with my friends", ["read books", "go to sleep"])
    W.order_sentence("I go to school by bus.", "bus")
    W.write_sentence("My teacher is kind.")
    W.speak_line("I read, I write, I play at school!", "school")
    W.spell("class")
    W.hunt("school", ["cool", "spool", "stool"])


def t_food(W):
    W.read_match("I like to eat mangoes.", "mango", ["rice", "egg"])
    W.cloze("Yum! I love sweet mangoes.", "mangoes", ["socks", "shoes"])
    W.story_question("Ali likes rice. Sara likes roti. They both like mangoes.", "What do they both like?", "mangoes", ["rice", "roti"])
    W.order_sentence("My favourite food is rice.", "rice")
    W.write_sentence("I like to eat roti.")
    W.speak_line("Yum! My favourite food is mango!", "mango")
    W.spell("food")
    W.hunt("yum", ["yes", "yam", "you"])


def t_describe(W):
    W.ask("Which words tell about it?", "Look at the picture. Which words tell about it?", B.card(None, B.pic("red_bus")),
          ["a big red bus", "a little green frog", "a pink cake"], "a big red bus")
    W.read_match("I see a little yellow chick.", "chick", ["frog", "red_bus"])
    W.yes_no("The elephant is big and grey.", "elephant", True)
    W.story_question("In the picture, a black cat sits on a red box.", "What colour is the box?", "red", ["black", "blue"])
    W.order_sentence("I see a big red bus.", "red_bus")
    W.write_sentence("The sun is big and yellow.")
    W.speak_line("I see a tall green tree.", "tree")
    W.spell("green")
    W.hunt("tall", ["tail", "ball", "talk"])


def t_letter(W):
    W.story_question("Dear Sara, I am at the sea. The water is blue. I miss you! Love, Hina", "Who wrote the letter?", "Hina", ["Sara", "Mia"])
    W.ask("How does a letter start?", "Which words start a letter?", B.card(None, B.pic("envelope")), ["Dear Sara,", "The End.", "Goodbye!"],
          "Dear Sara,")
    W.pick_picture("Where does a letter go?", "Where do we post a letter?", B.card(None, B.pic("envelope")), ["postbox", "bin", "bath"], "postbox")
    W.yes_no("A letter goes in an envelope.", "envelope", True)
    W.order_sentence("Dear Ali, how are you?", "envelope")
    W.write_sentence("Dear Sara, how are you?")
    W.speak_line("Dear Ali, thank you for the gift!", "gift")
    W.spell("dear")
    W.hunt("Dear", ["Deer", "Bear", "Near"])


TOPICS = {
    "endings": (["cat", "dog", "hen", "bus", "sun", "pig"], None, t_endings),
    "numbers": (["seven", "eight", "nine", "ten"], None, t_numbers),
    "weather": (["sun", "rain", "snow", "wind", "cloud"],
                [("It is sunny.", "sun"), ("It is rainy.", "rain"), ("It is windy.", "wind"), ("It is snowy.", "snow")], t_weather),
    "beats3": (["banana", "potato", "dinosaur", "butterfly", "elephant", "kangaroo"], None, t_beats3),
    "compound": (["sunflower", "rainbow", "cupcake", "snowman", "popcorn", "football"], None, t_compound),
    "nouns": (["dog", "cat", "ball", "school", "shop", "cup"], [("The doctor has a bag.", "doctor"), ("I see a dog.", "dog"),
                                                                ("The cat sat on the mat.", "cat")], t_nouns),
    "names": (["Ali", "Sara", "Mia", "Sam"], None, t_names),
    "telling": (None, [("The bird is in the sky.", "bird_in_sky"), ("The cat sleeps on the bed.", "cat_in_bed"), ("The dog runs.", "dog_running")],
                t_telling),
    "exclaim": (["wow", "stop", "help", "look"], [("Wow! A rainbow!", "rainbow"), ("Hooray! I won!", "prize"), ("Ouch! My leg!", "leg")], t_exclaim),
    "and": (["and", "cat", "dog", "jam", "bread"], [("A cat and a dog.", "cat_and_dog"), ("I like milk and cake.", "cake"),
                                                    ("I can run and jump.", "run")], t_and),
    "commas": (["red", "blue", "green", "pink"], None, t_commas),
    "sky_mix": (None, None, t_sky_mix),
    "animals": (["swim", "fly", "hop", "run", "climb"], [("A fish can swim.", "fish"), ("A bird can fly.", "bird"), ("A frog can hop.", "frog"),
                                                         ("A monkey can climb.", "monkey"), ("A horse can run.", "horse")], t_animals),
    "past": (["jumped", "played", "walked", "kicked"], None, t_past),
    "colour_size": (["big", "small", "red", "green", "little"], [("I see a red bus.", "red_bus"), ("The frog is green.", "frog"),
                                                                 ("The elephant is big.", "elephant")], t_colour_size),
    "feelings": (["happy", "sad", "angry", "scared", "tired"], [("I feel happy today.", "happy"), ("The baby is tired.", "tired"),
                                                                ("The boy is angry.", "angry"), ("I am sad.", "sad")], t_feelings),
    "opposites2": (["open", "closed", "loud", "quiet", "sweet", "sour", "old", "young"], None, t_opposites2),
    "positions2": (["behind", "between", "box", "next"], [("The cat is behind the box.", "cat_behind_box"),
                                                          ("The dog is next to the box.", "dog_next_to_box"),
                                                          ("The cat is between the boxes.", "cat_between_boxes"),
                                                          ("The dog is behind the box.", "dog_behind_box")], t_positions2),
    "sizes": (["big", "bigger", "biggest", "small", "smaller"], [("The elephant is the biggest.", "elephant"), ("A mouse is small.", "mouse")],
              t_sizes),
    "when": (["when", "morning", "night", "today"], [("I sleep at night.", "night"), ("I wake up in the morning.", "wake_up"),
                                                     ("We go to school.", "school")], t_when),
    "why": (["why", "because"], None, t_why),
    "how_many": (["how", "many", "two", "three", "four"], [("I see three cats.", "many_cats"), ("I see three birds.", "many_birds"),
                                                          ("I have three hats.", "many_hats")], t_how_many),
    "yesno_q": (["can", "is", "do", "yes", "no"], None, t_yesno_q),
    "months": (["May", "June", "July", "March"], None, t_months),
    "polite": (["please", "thank", "sorry", "may"], None, t_polite),
    "q_or_t": (None, [("Is the cat on the box?", "cat_on_box"), ("The cat is in the bed.", "cat_in_bed"), ("Is the dog on the box?", "dog_on_box")],
               t_q_or_t),
    "signs": (["stop", "go", "open", "exit"], None, t_signs),
    "clues": (["nest", "egg", "bee", "kite"], [("The eggs are in the nest.", "nest"), ("The penguin is on the ice.", "penguin"),
                                               ("The bee is on the flower.", "bee")], t_clues),
    "list": (["milk", "egg", "bread", "rice", "apple"], None, t_list),
    "steps": (["wash", "brush", "first", "next", "last"], None, t_steps),
    "feel": (["happy", "sad", "angry", "scared", "tired"], [("Mia is happy today.", "happy"), ("The baby is tired.", "tired"),
                                                            ("Sam is sad.", "sad")], t_feel),
    "next": (["next", "melt", "grow", "rain"], None, t_next),
    "long": (["dog", "park", "ball", "home"], [("Max runs after the ball.", "dog_running"), ("They go to the park.", "play"),
                                               ("Bilal has a little dog.", "dog")], t_long),
    "once": (["once", "upon", "time", "end"], None, t_once),
    "pet": (["cat", "dog", "fish", "rabbit", "parrot"], None, t_pet),
    "friend": (["friend", "kind", "share", "play"], None, t_friend),
    "school_me": (["school", "teacher", "book", "pencil", "class"], None, t_school_me),
    "food": (["rice", "roti", "mango", "food", "yum"], None, t_food),
    "describe": (["big", "red", "little", "green", "tall"], None, t_describe),
    "letter": (["dear", "love", "from", "letter"], None, t_letter),
}


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
    L.sentences = SENTENCES.get(kind)
    W = Words(L, step)
    for name_, take in classics:
        W.classic(name_, take)
    if kind in TOPICS:
        L.words, L.sentences, games = TOPICS[kind]
        L.keep_first = True
        games(W)
        return L
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
    """8-10 games, no two of one kind, three of them new games (add_star_games). A boss level ends with its own last game."""
    L._boss = boss
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
    add_star_games(L, W, step, earlier, pool)
    L.rounds = L.rounds + ([last] if boss else [])
    for k, r in enumerate(L.rounds):  # ids follow the final order
        r["id"] = f"{L.id}-r{k + 1}"
        for j, o in enumerate((r.get("pick") or {}).get("options", [])):
            o["id"] = f"{r['id']}-o{j + 1}"


# The new games, turned through level by level: every level gets three, starting further on each time.
STAR_GAMES = ["pop", "match", "fix", "truth", "monster", "baskets", "flash"]


def add_star_games(L, W, step, earlier, pool):
    """Three of the new games (pop, match, fix, truth, sort, flash writing) on the level's words, spread through
    it; then the level is cut back to ten games (with the boss game), older picks going first."""
    words = [w for w in getattr(L, "words", None) or pool if w.isalpha()] or pool
    has = {signature(r) for r in L.rounds}
    focus = getattr(L, "focus", None)
    pics = [w for w in B.unique(words + pool) if has_picture(w)]
    letters = [c for c in B.unique(w[0] for w in words + pool) if c in B.STARTS and len(B.STARTS[c]) >= 2]
    ss = getattr(L, "sentences", None) or SENTENCES["readwrite"]
    own = [w for w in B.unique(words) if has_picture(w)]
    # a topic level plays its pictures and sentences only, never pictures of older words
    topic = getattr(L, "keep_first", False) and getattr(L, "words", None)
    star = []

    def make(kind):
        if kind in ("monster", "baskets") and any(r["type"] == "sort" for r in star):
            return  # one sorting game a level: the monster and the baskets are both drag-and-drop
        before = len(L.rounds)
        if kind == "pop":
            W.pop_word(words[step % len(words)], words + pool)
        elif kind == "match" and topic:
            if len(own) >= 3 or len([w for w in words if w.islower()]) >= 3:
                W.match_words(own if len(own) >= 3 else words, len(own) < 3)
        elif kind == "match" and (len(pics) >= 3 or len([w for w in words if w.islower()]) >= 3):
            sight = getattr(L, "sight", False) and len([w for w in words if w.islower()]) >= 3
            W.match_words(words if sight else words + pics, sight)
        elif kind == "fix" and len([w for w in words + pool if any(B.fix_how(c) == "mirror" and c not in "tlI" for c in w)]) >= 2:
            ws = [w for w in B.unique(words + pool) if len(w) <= 6]
            W.fix_words(ws[:4] if len(ws) >= 4 else ws + pool[:4 - len(ws)])
        elif kind == "truth" and topic and len(own) < 2 and getattr(L, "sentences", None) is None:
            pass
        elif kind == "truth":
            shown = own + [w for w in pics if w not in own]  # the level's own words first
            if getattr(L, "sentences", None) is None and len(shown) >= 2:
                w = shown[step % len(own if len(own) >= 2 else shown)]
                W.truth_word(w, shown[(step + 1) % len(shown)], step % 2 == 0)
            else:
                s, k = ss[step % len(ss)]
                other = ss[(step + 2) % len(ss)][1]
                W.yes_no(s, k if step % 2 == 0 else other, step % 2 == 0)
        elif kind == "monster" and focus in SOUNDS:
            food = [w for w in words if focus in w]
            other = [w for w in B.unique(earlier[::-1]) if focus not in w and w.isalpha()]
            if len(food) >= 2 and len(other) >= 2:
                W.monster(focus, food, other)
        elif kind == "baskets" and len(letters) >= 2:
            W.baskets(letters[step % len(letters)], letters[(step + 1) % len(letters)])
        elif kind == "flash":
            short = ([w for w in words if 2 <= len(w) <= 4] or [w for w in words if len(w) == 5]
                     or [w for w in pool if 2 <= len(w) <= 4])
            if short:
                W.flash_word(short[step % len(short)])
        if len(L.rounds) > before:
            r = L.rounds.pop()
            if signature(r) not in has:
                has.add(signature(r))
                star.append(r)

    k = (step * 3) % len(STAR_GAMES)
    for kind in STAR_GAMES[k:] + STAR_GAMES[:k]:
        if len(star) == 3:
            break
        make(kind)
    # spread them: after the first game, in the middle, near the end
    for r, at in zip(star, (1, len(L.rounds) // 2 + 1, len(L.rounds) - 1 + 2)):
        L.rounds.insert(min(at, len(L.rounds)), r)
    room = 10 - (1 if getattr(L, "_boss", False) else 0)
    while len(L.rounds) > room:
        old = [i for i, r in enumerate(L.rounds) if r not in star]
        picks = [i for i in old if L.rounds[i]["type"] == "pick"]
        writes = [i for i in old if L.rounds[i]["type"] == "write"]
        last = next(i for i in reversed(old) if not (L.rounds[i]["type"] == "write" and len(writes) == 1))
        # a topic level lists its games most important first: the last ones go
        drop = last if getattr(L, "keep_first", False) or not picks else picks[-1]
        L.rounds.pop(drop)


def plan(first_number, start_step):
    """(world folder, world.json, level doc) for worlds 5-14."""
    out, n, step, earlier = [], first_number, start_step, []
    for folder, world, key in WORLDS:
        specs = level_specs(key)
        assert len(specs) == LEVELS_PER_WORLD, f"{folder}: {len(specs)} levels, not {LEVELS_PER_WORLD}"
        wdoc = B.world_doc(folder, world)
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
    if w.get("mode") == "spell" and w.get("word") and w["word"].isalpha() and w["word"].islower():
        return [w["word"]]
    return []
