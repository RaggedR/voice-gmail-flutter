"""
Constrained vocabulary for voice commands.
Vosk will ONLY recognize these words.
"""

# Wake word
WAKE_WORDS = ["jarvis"]

# Core command words
COMMANDS = [
    # Navigation
    "show", "open", "go", "my",
    "inbox", "email", "emails", "unread", "sent", "drafts",
    "starred", "spam", "trash", "refresh", "check",

    # Actions
    "delete", "archive", "star", "mark", "read",
    "next", "previous", "first", "last", "back",

    # Email operations
    "reply", "forward", "compose", "send", "cancel", "discard",
    "message", "subject", "body", "draft",

    # Attachments & PDF
    "attachment", "attachments", "pdf", "download", "save",
    "scroll", "down", "up", "page", "zoom", "close", "exit",

    # Labels
    "label", "labels", "add", "remove",

    # Search
    "search", "find", "from", "to", "about",

    # Contacts
    "contact", "contacts", "sender",

    # Numbers (for "email 3", "page 5", etc.)
    # Use spelled-out words only - Vosk doesn't have pronunciations for digits
    "one", "two", "three", "four", "five",
    "six", "seven", "eight", "nine", "ten",
    "eleven", "twelve", "thirteen", "fourteen", "fifteen",
    "twenty", "thirty", "forty", "fifty",
    "first", "second", "third", "fourth", "fifth",
    "sixth", "seventh", "eighth", "ninth", "tenth",

    # Common words needed for natural phrasing
    "the", "this", "that", "it", "a", "an",
    "is", "are", "was", "to", "for", "of", "in", "on",
    "new", "all", "more", "how", "many", "what",
    "yes", "no", "okay", "ok",

    # System
    "stop", "help", "repeat", "commands",

    # Filler/connecting words
    "please", "now", "just", "can", "you",

    # Additional words from COMMANDS.md
    "beginning", "end", "continue", "done",
    "folder", "list", "mail", "view", "write",
    "respond", "say", "with", "out",
    "bigger", "smaller", "count",
    "never", "mind",
]

# Build the full vocabulary list
VOCABULARY = sorted(set(WAKE_WORDS + COMMANDS))

def get_grammar_string():
    """Return vocabulary as JSON array string for Vosk grammar."""
    import json
    # Vosk grammar format: JSON array of allowed words
    # Adding "[unk]" allows unknown words to be recognized as "[unk]"
    # instead of forcing a match (optional - remove for strict mode)
    words = VOCABULARY + ["[unk]"]
    return json.dumps(words)

if __name__ == "__main__":
    print(f"Vocabulary size: {len(VOCABULARY)} words")
    print(f"\nWords:\n{', '.join(VOCABULARY)}")
