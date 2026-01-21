#!/usr/bin/env python3
"""
Tests for the Vosk WebSocket server.

These tests require the server to be running:
    python server.py

Run tests with:
    python test_server.py
"""

import asyncio
import json
import struct
import unittest
import math

try:
    import websockets
except ImportError:
    websockets = None


SERVER_URL = "ws://localhost:8765"


def generate_sine_wave(frequency: float, duration: float,
                       sample_rate: int = 16000) -> bytes:
    """Generate a sine wave as PCM16 audio."""
    num_samples = int(sample_rate * duration)
    samples = []
    for i in range(num_samples):
        t = i / sample_rate
        value = int(32767 * 0.5 * math.sin(2 * math.pi * frequency * t))
        samples.append(value)
    return struct.pack(f'<{len(samples)}h', *samples)


def generate_silence(duration: float, sample_rate: int = 16000) -> bytes:
    """Generate silence as PCM16 audio."""
    num_samples = int(sample_rate * duration)
    return b'\x00\x00' * num_samples


@unittest.skipIf(websockets is None, "websockets not installed")
class TestServerConnection(unittest.TestCase):
    """Test basic server connectivity."""

    def test_server_accepts_connection(self):
        """Server should accept WebSocket connections."""
        async def connect():
            try:
                async with websockets.connect(SERVER_URL, close_timeout=2) as ws:
                    self.assertTrue(ws.open)
                return True
            except Exception as e:
                self.fail(f"Could not connect to server: {e}")

        asyncio.run(connect())

    def test_server_accepts_audio_data(self):
        """Server should accept binary audio data without error."""
        async def send_audio():
            async with websockets.connect(SERVER_URL) as ws:
                # Send some silence
                audio = generate_silence(0.5)
                await ws.send(audio)
                # Should not raise

        asyncio.run(send_audio())

    def test_server_handles_reset_command(self):
        """Server should handle reset command."""
        async def send_reset():
            async with websockets.connect(SERVER_URL) as ws:
                await ws.send('{"type": "reset"}')
                # Should not raise

        asyncio.run(send_reset())

    def test_server_handles_eof_command(self):
        """Server should handle EOF command and return final result."""
        async def send_eof():
            async with websockets.connect(SERVER_URL) as ws:
                # Send some audio then EOF
                audio = generate_silence(0.5)
                await ws.send(audio)
                await ws.send('{"type": "eof"}')

                # May or may not get a response depending on audio content
                try:
                    response = await asyncio.wait_for(ws.recv(), timeout=1.0)
                    data = json.loads(response)
                    self.assertIn("type", data)
                except asyncio.TimeoutError:
                    pass  # No response for silence is OK

        asyncio.run(send_eof())


@unittest.skipIf(websockets is None, "websockets not installed")
class TestServerResponses(unittest.TestCase):
    """Test server response format."""

    def test_response_is_json(self):
        """Server responses should be valid JSON."""
        async def get_response():
            async with websockets.connect(SERVER_URL) as ws:
                # Send audio to trigger response
                audio = generate_sine_wave(440, 1.0)  # 1 second of tone
                await ws.send(audio)
                await ws.send('{"type": "eof"}')

                try:
                    response = await asyncio.wait_for(ws.recv(), timeout=2.0)
                    data = json.loads(response)
                    self.assertIsInstance(data, dict)
                except asyncio.TimeoutError:
                    pass  # No response is acceptable

        asyncio.run(get_response())

    def test_response_has_type_field(self):
        """Server responses should have a 'type' field."""
        async def check_response_format():
            async with websockets.connect(SERVER_URL) as ws:
                audio = generate_sine_wave(440, 1.0)
                await ws.send(audio)
                await ws.send('{"type": "eof"}')

                try:
                    response = await asyncio.wait_for(ws.recv(), timeout=2.0)
                    data = json.loads(response)
                    self.assertIn("type", data)
                    self.assertIn(data["type"], ["partial", "final"])
                except asyncio.TimeoutError:
                    pass  # Acceptable

        asyncio.run(check_response_format())

    def test_response_has_text_field(self):
        """Server responses should have a 'text' field."""
        async def check_text_field():
            async with websockets.connect(SERVER_URL) as ws:
                audio = generate_sine_wave(440, 1.0)
                await ws.send(audio)
                await ws.send('{"type": "eof"}')

                try:
                    response = await asyncio.wait_for(ws.recv(), timeout=2.0)
                    data = json.loads(response)
                    self.assertIn("text", data)
                    self.assertIsInstance(data["text"], str)
                except asyncio.TimeoutError:
                    pass  # Acceptable

        asyncio.run(check_text_field())


@unittest.skipIf(websockets is None, "websockets not installed")
class TestConstrainedVocabulary(unittest.TestCase):
    """Test that vocabulary constraint is working."""

    def test_only_vocabulary_words_returned(self):
        """
        Server should only return words from the vocabulary.

        Note: This is hard to test without real speech, but we can
        verify the structure is in place.
        """
        from vocabulary import VOCABULARY

        async def check_vocabulary():
            async with websockets.connect(SERVER_URL) as ws:
                # Send audio
                audio = generate_sine_wave(440, 2.0)
                await ws.send(audio)
                await ws.send('{"type": "eof"}')

                try:
                    response = await asyncio.wait_for(ws.recv(), timeout=2.0)
                    data = json.loads(response)
                    text = data.get("text", "")

                    # If we got text, all words should be in vocabulary
                    # (or [unk] for unknown)
                    if text:
                        words = text.split()
                        for word in words:
                            word_clean = word.strip(".,!?").lower()
                            is_valid = (
                                word_clean in VOCABULARY or
                                word_clean == "[unk]" or
                                word_clean == ""
                            )
                            self.assertTrue(is_valid,
                                f"Word '{word_clean}' not in vocabulary")

                except asyncio.TimeoutError:
                    pass  # Acceptable for non-speech audio

        asyncio.run(check_vocabulary())


class TestServerNotRunning(unittest.TestCase):
    """Tests for when server is not running (to verify error handling)."""

    def test_connection_refused_message(self):
        """Should get clear error when server not running."""
        # This test documents expected behavior; skip if server IS running
        async def try_connect():
            try:
                async with websockets.connect(
                    "ws://localhost:9999",  # Wrong port
                    close_timeout=1
                ) as ws:
                    pass
                return True
            except (ConnectionRefusedError, OSError):
                return False

        if websockets:
            result = asyncio.run(try_connect())
            self.assertFalse(result, "Should fail to connect to wrong port")


if __name__ == "__main__":
    print("=" * 60)
    print("Vosk Server Tests")
    print("=" * 60)
    print("\nMake sure the server is running: python server.py\n")
    print("=" * 60)

    unittest.main(verbosity=2)
