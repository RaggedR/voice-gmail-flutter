#!/usr/bin/env python3
"""
Vosk WebSocket server with constrained vocabulary for voice commands.

Receives PCM audio via WebSocket, returns transcriptions using only
the allowed command vocabulary.

Usage:
    python server.py [--port 8765] [--model vosk-model-small-en-us-0.15]

Connect from Flutter:
    ws://localhost:8765
    Send: raw PCM audio (16-bit, 16kHz, mono)
    Receive: JSON {"text": "...", "partial": "..."}
"""

import asyncio
import json
import logging
import os
import sys
import urllib.request
import zipfile
from pathlib import Path

# Check for required packages
try:
    import websockets
    from vosk import Model, KaldiRecognizer, SetLogLevel
except ImportError as e:
    print(f"Missing dependency: {e}")
    print("Install with: pip install -r requirements.txt")
    sys.exit(1)

from vocabulary import get_grammar_string, VOCABULARY

# Configuration
DEFAULT_PORT = 8765
SAMPLE_RATE = 16000
MODEL_DIR = Path(__file__).parent / "models"
DEFAULT_MODEL = "vosk-model-small-en-us-0.15"
MODEL_URL = f"https://alphacephei.com/vosk/models/{DEFAULT_MODEL}.zip"

# Logging
logging.basicConfig(
    level=logging.INFO,
    format='[%(asctime)s] %(levelname)s: %(message)s',
    datefmt='%H:%M:%S'
)
log = logging.getLogger("vosk-server")

# Reduce Vosk's internal logging
SetLogLevel(-1)


def download_model(model_name: str) -> Path:
    """Download Vosk model if not present."""
    model_path = MODEL_DIR / model_name

    if model_path.exists():
        log.info(f"Model found: {model_path}")
        return model_path

    MODEL_DIR.mkdir(parents=True, exist_ok=True)
    zip_path = MODEL_DIR / f"{model_name}.zip"

    if not zip_path.exists():
        log.info(f"Downloading model from {MODEL_URL}...")
        log.info("This may take a few minutes (50MB)...")
        urllib.request.urlretrieve(MODEL_URL, zip_path)
        log.info("Download complete.")

    log.info("Extracting model...")
    with zipfile.ZipFile(zip_path, 'r') as zf:
        zf.extractall(MODEL_DIR)

    # Clean up zip
    zip_path.unlink()
    log.info(f"Model ready: {model_path}")

    return model_path


class VoskServer:
    def __init__(self, model_path: Path, port: int = DEFAULT_PORT):
        self.port = port
        self.model = Model(str(model_path))
        self.grammar = get_grammar_string()
        log.info(f"Loaded vocabulary: {len(VOCABULARY)} words")
        log.info(f"Sample words: {', '.join(VOCABULARY[:15])}...")

    def create_recognizer(self) -> KaldiRecognizer:
        """Create a new recognizer with constrained grammar."""
        rec = KaldiRecognizer(self.model, SAMPLE_RATE, self.grammar)
        rec.SetWords(True)  # Include word-level timing
        return rec

    async def handle_client(self, websocket):
        """Handle a single WebSocket client connection."""
        client_id = id(websocket)
        log.info(f"[{client_id}] Client connected")

        recognizer = self.create_recognizer()

        try:
            async for message in websocket:
                if isinstance(message, bytes):
                    # Process audio chunk
                    if recognizer.AcceptWaveform(message):
                        # Final result for this utterance
                        result = json.loads(recognizer.Result())
                        text = result.get("text", "").strip()
                        log.debug(f"[{client_id}] Vosk result: {result}")
                        if text:
                            log.info(f"[{client_id}] Final: \"{text}\"")
                            response = json.dumps({"type": "final", "text": text})
                            log.debug(f"[{client_id}] Sending: {response}")
                            await websocket.send(response)
                        else:
                            log.debug(f"[{client_id}] Empty final result, skipping")
                    else:
                        # Partial result
                        partial = json.loads(recognizer.PartialResult())
                        partial_text = partial.get("partial", "").strip()
                        if partial_text:
                            response = json.dumps({"type": "partial", "text": partial_text})
                            await websocket.send(response)

                elif isinstance(message, str):
                    # Handle control messages
                    try:
                        data = json.loads(message)
                        if data.get("type") == "reset":
                            recognizer = self.create_recognizer()
                            log.info(f"[{client_id}] Recognizer reset")
                        elif data.get("type") == "eof":
                            # End of stream - get final result
                            result = json.loads(recognizer.FinalResult())
                            text = result.get("text", "").strip()
                            if text:
                                log.info(f"[{client_id}] EOF Final: \"{text}\"")
                                await websocket.send(json.dumps({
                                    "type": "final",
                                    "text": text
                                }))
                    except json.JSONDecodeError:
                        pass

        except websockets.exceptions.ConnectionClosed:
            log.info(f"[{client_id}] Connection closed")
        except Exception as e:
            log.error(f"[{client_id}] Error: {e}")
        finally:
            log.info(f"[{client_id}] Client disconnected")

    async def run(self):
        """Start the WebSocket server."""
        log.info(f"Starting Vosk server on ws://localhost:{self.port}")
        log.info("Constrained vocabulary mode - only command words recognized")
        log.info("Waiting for connections...")

        async with websockets.serve(
            self.handle_client,
            "localhost",
            self.port,
            ping_interval=20,
            ping_timeout=60,
        ):
            await asyncio.Future()  # Run forever


def main():
    import argparse

    parser = argparse.ArgumentParser(description="Vosk WebSocket server")
    parser.add_argument("--port", type=int, default=DEFAULT_PORT,
                        help=f"WebSocket port (default: {DEFAULT_PORT})")
    parser.add_argument("--model", type=str, default=DEFAULT_MODEL,
                        help=f"Model name (default: {DEFAULT_MODEL})")
    args = parser.parse_args()

    # Download model if needed
    model_path = download_model(args.model)

    # Start server
    server = VoskServer(model_path, args.port)

    try:
        asyncio.run(server.run())
    except KeyboardInterrupt:
        log.info("Server stopped.")


if __name__ == "__main__":
    main()
