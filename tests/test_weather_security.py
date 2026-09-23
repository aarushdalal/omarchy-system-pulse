#!/usr/bin/env python3
"""
Comprehensive security regression test suite for omarchy-system-pulse.
Tests the real network -> pipe buffer limit -> jq parser/serializer -> cache -> QML sink boundary.
"""

import http.server
import json
import os
import re
import socketserver
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT_PATH = REPO_ROOT / "services" / "weather-fetcher.sh"
WEATHER_CARD_QML = REPO_ROOT / "cards" / "WeatherCard.qml"
AUDIO_CARD_QML = REPO_ROOT / "cards" / "AudioCard.qml"
BAR_WIDGET_QML = REPO_ROOT / "BarWidget.qml"


class MockWeatherHandler(http.server.BaseHTTPRequestHandler):
    """Configurable mock HTTP server for weather responses."""
    response_mode = "normal"
    custom_payload = b""
    bytes_streamed = 0
    client_disconnected = False

    def log_message(self, format, *args):
        pass  # Suppress HTTP server stderr output in test runner

    def do_GET(self):
        MockWeatherHandler.bytes_streamed = 0
        MockWeatherHandler.client_disconnected = False

        if MockWeatherHandler.response_mode == "oversized":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.end_headers()
            # Stream up to 10 MB in 64 KB chunks until pipe breaks
            chunk = b"A" * 65536
            try:
                for _ in range(160):  # 160 * 64KB = ~10.2 MB
                    self.wfile.write(chunk)
                    self.wfile.flush()
                    MockWeatherHandler.bytes_streamed += len(chunk)
            except (BrokenPipeError, ConnectionResetError):
                MockWeatherHandler.client_disconnected = True
            except Exception:
                MockWeatherHandler.client_disconnected = True
            return

        elif MockWeatherHandler.response_mode == "empty":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return

        elif MockWeatherHandler.response_mode == "slow":
            time.sleep(5)
            self.send_response(200)
            self.end_headers()
            return

        elif MockWeatherHandler.response_mode == "custom":
            payload = MockWeatherHandler.custom_payload
            self.send_response(200)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)
            self.wfile.flush()
            MockWeatherHandler.bytes_streamed = len(payload)
            return


class MockServer:
    def __init__(self):
        self.server = socketserver.TCPServer(("127.0.0.1", 0), MockWeatherHandler)
        self.port = self.server.server_address[1]
        self.thread = threading.Thread(target=self.server.serve_forever)
        self.thread.daemon = True
        self.thread.start()

    def set_mode(self, mode, payload=b""):
        MockWeatherHandler.response_mode = mode
        MockWeatherHandler.custom_payload = payload
        MockWeatherHandler.bytes_streamed = 0
        MockWeatherHandler.client_disconnected = False

    def get_url(self):
        return f"http://127.0.0.1:{self.port}/?format=%l|%t|%C|%h|%w"

    def shutdown(self):
        self.server.shutdown()
        self.server.server_close()


def run_fetcher(url, env_overrides=None, args=None):
    """Executes the actual production script under test with an isolated environment."""
    env = os.environ.copy()
    env["OMARCHY_WEATHER_URL"] = url
    if env_overrides:
        env.update(env_overrides)

    cmd = [str(SCRIPT_PATH)]
    if args:
        cmd.extend(args)
    else:
        cmd.append("--force")

    res = subprocess.run(cmd, capture_output=True, text=True, env=env)
    return res


def test_normal_response(server, tmp_dir):
    print("[TEST] 1. Normal valid weather response...")
    payload = b"London, GB|+15\xc2\xb0C|Clear|45%|12km/h\n"
    server.set_mode("custom", payload)

    res = run_fetcher(server.get_url(), env_overrides={"XDG_CACHE_HOME": str(tmp_dir)})
    assert res.returncode == 0, f"Expected exit 0, got {res.returncode}: {res.stderr}"

    data = json.loads(res.stdout.strip())
    assert data["location"] == "London, United Kingdom", f"Unexpected location: {data['location']}"
    assert data["temp"] == "15°C", f"Unexpected temp: {data['temp']}"
    assert data["feels_like"] == "18°C", f"Unexpected feels_like: {data['feels_like']}"
    assert data["condition"] == "Clear", f"Unexpected condition: {data['condition']}"
    assert data["humidity"] == "45%", f"Unexpected humidity: {data['humidity']}"
    assert data["wind"] == "12km/h", f"Unexpected wind: {data['wind']}"
    assert data["icon"] == "󰖙", f"Unexpected icon: {data['icon']}"

    # Verify cache was written
    cache_file = tmp_dir / "omarchy" / "weather_cache.json"
    assert cache_file.exists(), "Cache file was not created"
    cached_data = json.loads(cache_file.read_text())
    assert cached_data == data, "Cache content does not match stdout JSON"
    print("  [PASS] Normal response succeeds and caches properly.")


def test_oversized_response(server, tmp_dir):
    print("[TEST] 2. Oversized response stream rejection & bounded buffering...")
    server.set_mode("oversized")

    cache_file = tmp_dir / "omarchy" / "weather_cache.json"
    if cache_file.exists():
        cache_file.unlink()

    res = run_fetcher(server.get_url(), env_overrides={"XDG_CACHE_HOME": str(tmp_dir)})

    # 1. Verify fetcher rejected the oversized payload
    assert res.returncode != 0, f"Expected non-zero exit code for oversized response, got {res.returncode}"
    assert "exceeded maximum size limit" in res.stderr.lower(), f"Expected size limit error on stderr, got: {res.stderr}"

    # 2. Verify server detected pipe termination (curl SIGPIPE)
    assert MockWeatherHandler.client_disconnected is True or MockWeatherHandler.bytes_streamed < 1000000, (
        f"Server streamed {MockWeatherHandler.bytes_streamed} bytes without client disconnecting"
    )

    # 3. Verify the cache was NOT overwritten with oversized data
    if cache_file.exists():
        cached = cache_file.read_text()
        assert len(cached) < 2048, "Cache file contains oversized data!"

    print(f"  [PASS] Oversized stream rejected: server broke pipe after {MockWeatherHandler.bytes_streamed} bytes, fetcher exited {res.returncode}.")


def test_quotes(server, tmp_dir):
    print("[TEST] 3. Weather fields containing quotes & unclosed quotes...")
    payload = b'"Seattle", US|+20\xc2\xb0C|"Sunny"|50%|10km/h\n'
    server.set_mode("custom", payload)

    res = run_fetcher(server.get_url(), env_overrides={"XDG_CACHE_HOME": str(tmp_dir)})
    assert res.returncode == 0, f"Failed on quotes input: {res.stderr}"

    data = json.loads(res.stdout.strip())
    assert data["location"] == '"Seattle", United States'
    assert data["condition"] == '"Sunny"'
    print("  [PASS] Quotes correctly serialized without xargs/shell crash.")


def test_backslashes(server, tmp_dir):
    print("[TEST] 4. Weather fields containing backslashes...")
    payload = b'C:\\Weather\\City|+15\xc2\xb0C|Cloudy\\Mist|60%|5km/h\n'
    server.set_mode("custom", payload)

    res = run_fetcher(server.get_url(), env_overrides={"XDG_CACHE_HOME": str(tmp_dir)})
    assert res.returncode == 0, f"Failed on backslash input: {res.stderr}"

    data = json.loads(res.stdout.strip())
    assert data["location"] == r"C:\Weather\City"
    assert data["condition"] == r"Cloudy\Mist"
    print("  [PASS] Backslashes correctly preserved and escaped.")


def test_embedded_newlines(server, tmp_dir):
    print("[TEST] 5. Weather fields containing embedded newlines...")
    payload = b"Line1\nLine2|+18\xc2\xb0C|Rain\nHeavy|90%|25km/h\n"
    server.set_mode("custom", payload)

    res = run_fetcher(server.get_url(), env_overrides={"XDG_CACHE_HOME": str(tmp_dir)})
    assert res.returncode == 0, f"Failed on embedded newlines: {res.stderr}"

    data = json.loads(res.stdout.strip())
    assert "\n" in data["location"] or "\\n" in res.stdout
    assert "\n" in data["condition"] or "\\n" in res.stdout
    print("  [PASS] Newlines safely serialized according to RFC 8259.")


def test_html_like_text(server, tmp_dir):
    print("[TEST] 6. HTML-like markup and injection payloads...")
    payload = b"<script>alert(1)</script>, GB|+10\xc2\xb0C|<b>Sunny</b> <img src=x>|70%|15km/h\n"
    server.set_mode("custom", payload)

    res = run_fetcher(server.get_url(), env_overrides={"XDG_CACHE_HOME": str(tmp_dir)})
    assert res.returncode == 0, f"Failed on HTML-like text: {res.stderr}"

    data = json.loads(res.stdout.strip())
    assert "<script>alert(1)</script>, United Kingdom" in data["location"]
    assert "<b>Sunny</b> <img src=x>" in data["condition"]
    print("  [PASS] HTML-like tags remain literal string data in JSON.")


def test_unicode(server, tmp_dir):
    print("[TEST] 7. Unicode and non-ASCII character handling...")
    payload = "München, DE|+22°C|Heiter ☀️|55%|8km/h\n".encode("utf-8")
    server.set_mode("custom", payload)

    res = run_fetcher(server.get_url(), env_overrides={"XDG_CACHE_HOME": str(tmp_dir)})
    assert res.returncode == 0, f"Failed on Unicode: {res.stderr}"

    data = json.loads(res.stdout.strip())
    assert "München" in data["location"]
    assert "☀️" in data["condition"]
    print("  [PASS] Unicode characters safely parsed and serialized.")


def test_control_characters(server, tmp_dir):
    print("[TEST] 8. Control characters (tab, CR)...")
    payload = b"City\tTab\rCR|+25\xc2\xb0C|Clear\tSky|40%|10km/h\n"
    server.set_mode("custom", payload)

    res = run_fetcher(server.get_url(), env_overrides={"XDG_CACHE_HOME": str(tmp_dir)})
    assert res.returncode == 0, f"Failed on control characters: {res.stderr}"

    data = json.loads(res.stdout.strip())
    assert "City\tTab\rCR" in data["location"]
    print("  [PASS] Control characters correctly escaped in output JSON.")


def test_malformed_response(server, tmp_dir):
    print("[TEST] 9. Malformed API response (missing pipes)...")
    server.set_mode("custom", b"Error 500: Internal server error or HTML page\n")

    res = run_fetcher(server.get_url(), env_overrides={"XDG_CACHE_HOME": str(tmp_dir)})
    assert res.returncode != 0, f"Expected error on malformed response, got {res.returncode}"
    # Must emit valid fallback or error, never raw HTML or corrupt JSON
    try:
        json.loads(res.stdout.strip())
    except Exception as e:
        assert False, f"Stdout is not valid JSON: {res.stdout}"
    print("  [PASS] Malformed response fails safely with valid fallback JSON.")


def test_empty_response(server, tmp_dir):
    print("[TEST] 10. Empty API response...")
    server.set_mode("empty")

    res = run_fetcher(server.get_url(), env_overrides={"XDG_CACHE_HOME": str(tmp_dir)})
    assert res.returncode != 0, f"Expected error on empty response, got {res.returncode}"
    try:
        json.loads(res.stdout.strip())
    except Exception as e:
        assert False, f"Stdout is not valid JSON: {res.stdout}"
    print("  [PASS] Empty response fails safely without crash.")


def test_qml_plain_text_sinks():
    print("[TEST] 11. Static audit of QML Text sinks for Text.PlainText...")
    content = WEATHER_CARD_QML.read_text(encoding="utf-8")

    weather_props = [
        "root.location",
        "root.weatherIcon",
        "root.temperature",
        "root.feelsLike",
        "root.condition",
        "root.humidity",
        "root.wind",
    ]

    for prop in weather_props:
        pattern = re.compile(r"Text\s*\{([^}]*?" + re.escape(prop) + r"[^}]*?)\}", re.DOTALL)
        matches = pattern.findall(content)
        assert len(matches) > 0, f"Did not find Text block containing {prop} in WeatherCard.qml"
        for block in matches:
            assert "textFormat: Text.PlainText" in block, (
                f"VULNERABILITY: Weather text sink for '{prop}' lacks 'textFormat: Text.PlainText':\n{block}"
            )

    # Check AudioCard.qml MPRIS sinks
    audio_content = AUDIO_CARD_QML.read_text(encoding="utf-8")
    for prop in ["root.identity", "root.title", "root.artist"]:
        pattern = re.compile(r"Text\s*\{([^}]*?" + re.escape(prop) + r"[^}]*?)\}", re.DOTALL)
        matches = pattern.findall(audio_content)
        for block in matches:
            assert "textFormat: Text.PlainText" in block, (
                f"MPRIS text sink for '{prop}' in AudioCard.qml lacks 'textFormat: Text.PlainText':\n{block}"
            )

    # Check BarWidget.qml trackTitle sink
    bar_content = BAR_WIDGET_QML.read_text(encoding="utf-8")
    pattern = re.compile(r"Text\s*\{([^}]*?root\.trackTitle[^}]*?)\}", re.DOTALL)
    matches = pattern.findall(bar_content)
    for block in matches:
        assert "textFormat: Text.PlainText" in block, (
            f"BarWidget trackTitle sink lacks 'textFormat: Text.PlainText':\n{block}"
        )

    print("  [PASS] All dynamic weather and MPRIS text sinks enforce Text.PlainText.")


def test_response_below_and_at_limit(server, tmp_dir):
    print("[TEST] 12. Response exactly at and below limit (2047 and 2048 bytes)...")
    # Tail part: "|20C|Clear|50%|10km/h\n" (21 bytes)
    tail = b"|20C|Clear|50%|10km/h\n"
    # Below limit (2047 bytes)
    loc_below = b"A" * (2047 - len(tail))
    server.set_mode("custom", loc_below + tail)
    res = run_fetcher(server.get_url(), env_overrides={"XDG_CACHE_HOME": str(tmp_dir)})
    assert res.returncode == 0, f"Expected success at 2047 bytes, got {res.returncode}: {res.stderr}"
    data = json.loads(res.stdout.strip())
    assert len(data["location"]) == len(loc_below)

    # At limit (2048 bytes)
    loc_at = b"B" * (2048 - len(tail))
    server.set_mode("custom", loc_at + tail)
    res = run_fetcher(server.get_url(), env_overrides={"XDG_CACHE_HOME": str(tmp_dir)})
    assert res.returncode == 0, f"Expected success at 2048 bytes, got {res.returncode}: {res.stderr}"
    data = json.loads(res.stdout.strip())
    assert len(data["location"]) == len(loc_at)
    print("  [PASS] Responses at and below limit processed successfully.")


def test_response_exceeding_limit_by_one_byte(server, tmp_dir):
    print("[TEST] 13. Response exceeding limit by 1 byte (2049 bytes)...")
    tail = b"|20C|Clear|50%|10km/h\n"
    loc_over = b"C" * (2049 - len(tail))
    server.set_mode("custom", loc_over + tail)
    res = run_fetcher(server.get_url(), env_overrides={"XDG_CACHE_HOME": str(tmp_dir)})
    assert res.returncode != 0, f"Expected failure at 2049 bytes, got {res.returncode}"
    assert "exceeded maximum size limit" in res.stderr.lower()
    print("  [PASS] 2049-byte response rejected as oversized.")


def test_malformed_oversized_response(server, tmp_dir):
    print("[TEST] 14. Malformed oversized response (50KB binary junk)...")
    server.set_mode("custom", b"MALFORMED_NO_PIPES_" * 2500)
    res = run_fetcher(server.get_url(), env_overrides={"XDG_CACHE_HOME": str(tmp_dir)})
    assert res.returncode != 0, f"Expected failure on oversized malformed data, got {res.returncode}"
    assert "exceeded maximum size limit" in res.stderr.lower()
    # Must emit valid fallback JSON
    data = json.loads(res.stdout.strip())
    assert "location" in data
    print("  [PASS] Malformed oversized response rejected without unbounded buffering.")


def test_connection_failure(tmp_dir):
    print("[TEST] 15. Connection failure (unreachable host/port)...")
    # Pick a port that is not listening
    unreachable_url = "http://127.0.0.1:59998/?format=%l|%t|%C|%h|%w"
    res = run_fetcher(unreachable_url, env_overrides={"XDG_CACHE_HOME": str(tmp_dir)})
    assert res.returncode != 0, f"Expected failure on connection error, got {res.returncode}"
    data = json.loads(res.stdout.strip())
    assert "location" in data
    print("  [PASS] Connection failure handled safely with fallback output.")


def test_timeout(server, tmp_dir):
    print("[TEST] 16. Network timeout handling...")
    server.set_mode("slow")
    start = time.time()
    res = run_fetcher(server.get_url(), env_overrides={"XDG_CACHE_HOME": str(tmp_dir)})
    elapsed = time.time() - start
    assert res.returncode != 0, f"Expected timeout failure, got {res.returncode}"
    # Curl was configured with --max-time 4
    assert elapsed < 7.0, f"Fetch took too long: {elapsed:.2f}s"
    data = json.loads(res.stdout.strip())
    assert "location" in data
    print(f"  [PASS] Timeout triggered and handled in {elapsed:.2f}s with safe fallback.")


def test_apostrophes(server, tmp_dir):
    print("[TEST] 17. Weather fields containing apostrophes...")
    payload = b"Bishop's Stortford, GB|+14\xc2\xb0C|It's Raining|80%|15km/h\n"
    server.set_mode("custom", payload)
    res = run_fetcher(server.get_url(), env_overrides={"XDG_CACHE_HOME": str(tmp_dir)})
    assert res.returncode == 0, f"Failed on apostrophe input: {res.stderr}"
    data = json.loads(res.stdout.strip())
    assert data["location"] == "Bishop's Stortford, United Kingdom"
    assert data["condition"] == "It's Raining"
    print("  [PASS] Apostrophes correctly preserved and serialized.")


def test_malicious_strings(server, tmp_dir):
    print("[TEST] 18. Malicious command injection strings...")
    payload = b"$(whoami)`touch /tmp/pwned`; rm -rf /;, US|+25\xc2\xb0C|${IFS}&|40%|5km/h\n"
    server.set_mode("custom", payload)
    res = run_fetcher(server.get_url(), env_overrides={"XDG_CACHE_HOME": str(tmp_dir)})
    assert res.returncode == 0, f"Failed on injection strings: {res.stderr}"
    data = json.loads(res.stdout.strip())
    assert "$(whoami)`touch /tmp/pwned`; rm -rf /;, United States" == data["location"]
    assert "${IFS}&" == data["condition"]
    assert not Path("/tmp/pwned").exists(), "Command injection vulnerability detected!"
    print("  [PASS] Command injection strings safely treated as literal data.")


def main():
    print("================================================================")
    print("STARTING OMARCHY SYSTEM PULSE SECURITY REGRESSION TEST SUITE")
    print("================================================================")

    server = MockServer()
    temp_cache_dir = tempfile.TemporaryDirectory()
    tmp_path = Path(temp_cache_dir.name)

    try:
        test_normal_response(server, tmp_path)
        test_oversized_response(server, tmp_path)
        test_response_below_and_at_limit(server, tmp_path)
        test_response_exceeding_limit_by_one_byte(server, tmp_path)
        test_malformed_oversized_response(server, tmp_path)
        test_connection_failure(tmp_path)
        test_timeout(server, tmp_path)
        test_quotes(server, tmp_path)
        test_apostrophes(server, tmp_path)
        test_backslashes(server, tmp_path)
        test_embedded_newlines(server, tmp_path)
        test_html_like_text(server, tmp_path)
        test_unicode(server, tmp_path)
        test_control_characters(server, tmp_path)
        test_malicious_strings(server, tmp_path)
        test_malformed_response(server, tmp_path)
        test_empty_response(server, tmp_path)
        test_qml_plain_text_sinks()

        print("================================================================")
        print("ALL 18 SECURITY REGRESSION TESTS PASSED SUCCESSFULLY!")
        print("================================================================")
    finally:
        server.shutdown()
        temp_cache_dir.cleanup()


if __name__ == "__main__":
    main()
