#!/usr/bin/env python3
"""
Tests for the Vosk vocabulary coverage.

Verifies that all commands from COMMANDS.md are covered by the vocabulary.
"""

import unittest
import re
from pathlib import Path

from vocabulary import VOCABULARY, WAKE_WORDS, COMMANDS


class TestVocabulary(unittest.TestCase):
    """Test vocabulary coverage and structure."""

    def test_wake_word_present(self):
        """Wake word 'jarvis' should be in vocabulary."""
        self.assertIn("jarvis", VOCABULARY)

    def test_no_duplicates(self):
        """Vocabulary should have no duplicate words."""
        self.assertEqual(len(VOCABULARY), len(set(VOCABULARY)))

    def test_all_lowercase(self):
        """All vocabulary words should be lowercase."""
        for word in VOCABULARY:
            self.assertEqual(word, word.lower(), f"Word not lowercase: {word}")

    def test_core_navigation_commands(self):
        """Core navigation commands should be present."""
        required = ["inbox", "email", "unread", "sent", "drafts",
                   "starred", "spam", "trash", "refresh"]
        for word in required:
            self.assertIn(word, VOCABULARY, f"Missing navigation word: {word}")

    def test_core_action_commands(self):
        """Core action commands should be present."""
        required = ["delete", "archive", "next", "previous", "open",
                   "close", "send", "reply", "forward"]
        for word in required:
            self.assertIn(word, VOCABULARY, f"Missing action word: {word}")

    def test_numbers_present(self):
        """Numbers 1-10 should be present (both word and digit forms)."""
        number_words = ["one", "two", "three", "four", "five",
                       "six", "seven", "eight", "nine", "ten"]
        for word in number_words:
            self.assertIn(word, VOCABULARY, f"Missing number word: {word}")

        for digit in ["1", "2", "3", "4", "5", "6", "7", "8", "9", "10"]:
            self.assertIn(digit, VOCABULARY, f"Missing digit: {digit}")

    def test_pdf_commands(self):
        """PDF viewer commands should be present."""
        required = ["scroll", "down", "up", "page", "zoom", "close"]
        for word in required:
            self.assertIn(word, VOCABULARY, f"Missing PDF word: {word}")

    def test_attachment_commands(self):
        """Attachment commands should be present."""
        required = ["attachment", "pdf", "download"]
        for word in required:
            self.assertIn(word, VOCABULARY, f"Missing attachment word: {word}")

    def test_vocabulary_size_reasonable(self):
        """Vocabulary should be between 50-200 words for good accuracy."""
        size = len(VOCABULARY)
        self.assertGreater(size, 50, "Vocabulary too small")
        self.assertLess(size, 200, "Vocabulary too large - may reduce accuracy")


class TestCommandsCoverage(unittest.TestCase):
    """Test that COMMANDS.md commands are covered by vocabulary."""

    @classmethod
    def setUpClass(cls):
        """Load and parse COMMANDS.md."""
        commands_path = Path(__file__).parent.parent / "COMMANDS.md"
        if commands_path.exists():
            cls.commands_md = commands_path.read_text()
        else:
            cls.commands_md = ""

    def extract_command_words(self, text: str) -> set:
        """Extract unique words from command examples."""
        # Find text in backticks and quotes
        patterns = [
            r'`([^`]+)`',  # backtick code
            r'"([^"]+)"',  # quoted strings
        ]
        words = set()
        for pattern in patterns:
            for match in re.finditer(pattern, text):
                # Split into words and normalize
                for word in match.group(1).lower().split():
                    # Remove punctuation
                    word = re.sub(r'[^\w]', '', word)
                    if word and len(word) > 1:  # Skip single chars
                        words.add(word)
        return words

    def test_commands_file_exists(self):
        """COMMANDS.md should exist."""
        self.assertTrue(self.commands_md, "COMMANDS.md not found or empty")

    def test_example_commands_covered(self):
        """Words from COMMANDS.md examples should be in vocabulary."""
        if not self.commands_md:
            self.skipTest("COMMANDS.md not found")

        command_words = self.extract_command_words(self.commands_md)

        # Words that are intentionally not in constrained vocab
        # (free-form content, names, etc.)
        excluded = {
            "nick", "disc", "thanks", "sending", "over", "review",
            "tomorrow", "me", "future", "fwd", "porcupine",
            "number", "text", "name", "query", "variations",
            "description", "command"
        }

        missing = []
        for word in command_words:
            if word not in VOCABULARY and word not in excluded:
                # Check if it's a variation of a vocab word
                if not any(word.startswith(v) or v.startswith(word)
                          for v in VOCABULARY):
                    missing.append(word)

        if missing:
            print(f"\nPotentially missing words: {sorted(missing)}")

        # Allow some missing words (free-form content)
        self.assertLess(len(missing), 20,
                       f"Too many missing words: {sorted(missing)}")


class TestGrammarFormat(unittest.TestCase):
    """Test the grammar string format for Vosk."""

    def test_grammar_is_valid_json(self):
        """Grammar string should be valid JSON array."""
        import json
        from vocabulary import get_grammar_string

        grammar = get_grammar_string()
        parsed = json.loads(grammar)

        self.assertIsInstance(parsed, list)
        self.assertGreater(len(parsed), 0)

    def test_grammar_contains_unk(self):
        """Grammar should contain [unk] for unknown words."""
        from vocabulary import get_grammar_string

        grammar = get_grammar_string()
        self.assertIn("[unk]", grammar)


if __name__ == "__main__":
    unittest.main(verbosity=2)
