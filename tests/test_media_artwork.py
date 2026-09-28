#!/usr/bin/env python3
"""
Unit and regression test for MPRIS poster and artwork resolution in omarchy-system-pulse.
Ensures that album artwork/posters are preserved and displayed continuously
during playback and do not disappear when audio starts playing.
"""

import re
import sys
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
MEDIA_SERVICE_QML = REPO_ROOT / "services" / "MediaTrackingService.qml"
AUDIO_CARD_QML = REPO_ROOT / "cards" / "AudioCard.qml"
BAR_WIDGET_QML = REPO_ROOT / "BarWidget.qml"


def test_media_tracking_art_url():
    print("[TEST] 1. Auditing MediaTrackingService.qml artUrl property...")
    assert MEDIA_SERVICE_QML.exists(), f"Missing {MEDIA_SERVICE_QML}"
    content = MEDIA_SERVICE_QML.read_text(encoding="utf-8")

    # Extract artUrl definition
    art_match = re.search(r"readonly\s+property\s+string\s+artUrl\s*:\s*\{(.*?)\n  \}", content, re.DOTALL)
    assert art_match, "Could not find artUrl property in MediaTrackingService.qml"
    art_body = art_match.group(1)

    # Ensure stale tab comparison guard is NOT present
    assert "mprisT === recT" not in art_body, (
        "Regression: artUrl still contains stale title comparison guard 'mprisT === recT' which breaks artwork during playback!"
    )
    assert "if (isBrowserPlayer)" not in art_body, (
        "Regression: artUrl still discriminates against browser players during playback!"
    )

    # Ensure trackArtUrl is returned
    assert "activePlayer.trackArtUrl" in art_body, (
        "artUrl does not return activePlayer.trackArtUrl"
    )
    print("  [PASS] MediaTrackingService.qml artUrl cleanly resolves artwork without playback suppression.")


def test_audio_card_art_url():
    print("[TEST] 2. Auditing AudioCard.qml artUrl property and poster rendering...")
    assert AUDIO_CARD_QML.exists(), f"Missing {AUDIO_CARD_QML}"
    content = AUDIO_CARD_QML.read_text(encoding="utf-8")

    assert "root.artUrl" in content, "AudioCard.qml does not reference root.artUrl"
    assert "id: heroArtwork" in content, "AudioCard.qml missing heroArtwork Image component"
    assert "source: root.artUrl" in content, "heroArtwork source is not root.artUrl"

    print("  [PASS] AudioCard.qml heroArtwork correctly bound to root.artUrl.")


def test_bar_widget_poster_and_component():
    print("[TEST] 3. Auditing BarWidget.qml poster binding and dashboard component...")
    assert BAR_WIDGET_QML.exists(), f"Missing {BAR_WIDGET_QML}"
    content = BAR_WIDGET_QML.read_text(encoding="utf-8")

    assert "readonly property string trackArtUrl: mediaTracker.artUrl" in content, (
        "BarWidget.qml trackArtUrl not bound to mediaTracker.artUrl"
    )
    assert "id: barArtImg" in content, "BarWidget.qml missing barArtImg Image"
    assert "source: root.trackArtUrl" in content, "barArtImg source is not root.trackArtUrl"
    assert "SystemPulseDashboard {" in content, (
        "BarWidget.qml should instantiate SystemPulseDashboard matching repo component name"
    )

    print("  [PASS] BarWidget.qml correctly configured for poster display and SystemPulseDashboard.")


def main():
    print("================================================================")
    print("STARTING OMARCHY SYSTEM PULSE MEDIA ARTWORK REGRESSION TESTS")
    print("================================================================")
    test_media_tracking_art_url()
    test_audio_card_art_url()
    test_bar_widget_poster_and_component()
    print("================================================================")
    print("ALL MEDIA ARTWORK REGRESSION TESTS PASSED SUCCESSFULLY!")
    print("================================================================")


if __name__ == "__main__":
    main()
