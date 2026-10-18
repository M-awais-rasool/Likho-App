"""Pencil's lines in easy English, and the same words on screen.

The app shows what Pencil says in his speech bubble, word for word, so a
line must read well too: no sound marks like /b/ on screen ("the {b|bʌ}
sound": the voice says the sound, the bubble shows "the b sound"), no hard
words ("from memory"). build_levels.py runs every prompt through
easy_prompt(); the same rules were run once over the existing levels.
"""

import re

# {/b/|bʌ}: a sound, written between slashes
SOUND = re.compile(r"\{/([^{}|/]+)/\|([^{}|]+)\}")


def _sound(m):
    return f"{{{m.group(1)}|{m.group(2)}}}"


def easy_part(say):
    """A sound button's line: just the sound ({/sh/|ʃːː} -> {sh|ʃːː})."""
    return SOUND.sub(_sound, say) if say else say


# (pattern, replacement) on the line as written ({shown|IPA} kept); S = a sound,
# which the last step turns into "the b sound"
_S = r"(\{/[^{}|/]+/\|[^{}|]+\})"
_RULES = [
    (rf"^Sort the pictures! Do they start with {_S} or {_S}\?$", r"Sort the pictures! Does each one start with the \1, or the \2?"),
    (rf"^(\{{[^{{}}|]+\|[^{{}}|]+\}}) says {_S}\. Which one (starts with|has) {_S}\?$", r"\1 makes the \2. Which one \3 that sound?"),
    (rf"^This monster only eats things that start with {_S}\. Feed it!$", r"This monster eats things that start with the \1. Feed it!"),
    (rf"^This monster only eats words with {_S}\. Feed it!$", r"This monster eats words with the \1. Feed it!"),
    (r"^Look at (.+)\. Then write it from memory!$", r"Look at \1. It will hide. Then write it!"),
    (r"^Join the dots, from (.+) to (.+)\. What will it be\?$", r"Tap the dots in order, from \1 to \2. What will it make?"),
    (r"^Find every word (\w+)!$", r'Tap every word that says "\1"!'),
    (r"^Oops! Pencil wrote a letter the wrong way\. Tap the words to fix them!$", r"Oops! Some words have a letter the wrong way. Tap them to fix them!"),
]


def easy_say(say):
    """The line in easy words, sounds as "the b sound" (see the module doc)."""
    if not say:
        return say
    for pat, rep in _RULES:
        say = re.sub(pat, rep, say)
    # "A B C": the letter A, not the word "a" ("uh")
    say = re.sub(r"(?<![|{])\bA B C\b", "{A|ˈeɪ} B C", say)
    # any other sound: "the b sound" ("the /b/" -> "the b sound")
    say = re.sub(rf"\bthe {_S}", lambda m: f"the {_sound(SOUND.match(m.group(1)))} sound", say)
    return SOUND.sub(lambda m: f"the {_sound(m)} sound", say)


def easy_fix(say, wrong):
    """A fix round's line when only [wrong] = 1 word is written wrong."""
    if wrong == 1 and say == "Oops! Some words have a letter the wrong way. Tap them to fix them!":
        return "Oops! One word has a letter the wrong way. Tap it to fix it!"
    return say


def easy_text(text):
    """A prompt's short text without sound marks ("Feed it /b/!" -> 'Feed it "b"!')."""
    return re.sub(r"/([a-z]{1,4})/", r'"\1"', text) if text else text


def easy_prompt(text, say):
    """(text, say) for a round's prompt; say stays None when the text is what Pencil says."""
    new_text = easy_text(text)
    if say:
        return new_text, easy_say(say)
    if SOUND.search(text or "") or text != new_text:
        return new_text, easy_say(text) if "{" in (text or "") else None
    return new_text, None


if __name__ == "__main__":
    for s in [
        "Sort the pictures! Do they start with {/l/|lːː} or {/f/|fːː}?",
        "{A|ˈeɪ} says {/a/|æ}. Which one starts with {/a/|æ}?",
        "This monster only eats things that start with {/b/|bʌ}. Feed it!",
        "This monster only eats words with {/ai/|eɪ}. Feed it!",
        "Look at small {z|zˈiː}. Then write it from memory!",
        "Join the dots, from {A|ˈeɪ} to {K|kˈeɪ}. What will it be?",
        "Find every word said!",
        "Which one starts with {/sh/|ʃːː}?",
        "Two letters, one sound: {/ai/|eɪ}! Like rain.",
        "Put the letters in A B C order!",
    ]:
        print(easy_say(s))
