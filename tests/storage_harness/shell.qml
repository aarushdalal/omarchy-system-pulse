import QtQuick
import QtQuick.Window
import Quickshell
import Quickshell.Io
import "services"
import "cards"

ShellRoot {
    id: root
    property int step: 0
    property int checks: 0
    property string directory: Qt.resolvedUrl(".").toString().substring(7)
    function check(ok, message) {
        if (!ok) { console.error("STORAGE-FAIL " + message); Qt.quit(); return false }
        checks++
        return true
    }
    function texts(item) {
        var output = item.text === undefined ? [] : [String(item.text)]
        for (var i = 0; i < item.children.length; i++) output = output.concat(texts(item.children[i]))
        return output
    }
    FileView { id: fixture; path: root.directory + "/services/fixture-mode"; printErrors: true }
    HardwareStats { id: hw; active: false; backgroundPolling: false }
    Window {
        id: window
        visible: true; width: 760; height: 700; color: "#070809"
        StorageCard {
            id: card
            anchors.left: parent.left; anchors.right: parent.right; anchors.margins: 20
            y: 20
            hardwareStats: hw
            foregroundColor: "#e1e1de"; fontFamily: "monospace"
        }
    }
    Timer { id: start; interval: 50; onTriggered: hw.refresh() }
    Timer {
        interval: 300; repeat: true; running: true
        onTriggered: {
            if (root.step === 0) {
                if (!root.check(hw.storageState.state === "loading", "initial loading")) return
                fixture.setText("partial"); start.restart()
            } else if (root.step === 1) {
                if (!root.check(hw.storageState.state === "partial", "real handler partial")) return
                if (!root.check(hw.nvmeTemp === 0, "zero temperature preserved")) return
                if (!root.check(hw.ramPercent === 50 && hw.cpuTemp === 60 && (hw.sampleCount === undefined || hw.sampleCount === 1), "other metrics preserved")) return
                var text = root.texts(card).join("\n")
                if (!root.check(text.indexOf("Partial telemetry") >= 0 && text.indexOf("NVMe Temp: 0°C") >= 0, "card semantics")) return
                if (!root.check(text.indexOf("Grade") < 0 && text.indexOf("Optimal") < 0 && text.indexOf("99%") < 0, "no fabricated health")) return
                card.grabToImage(function(image) { image.saveToFile(root.directory + "/partial-storage.png") })
                fixture.setText("error"); start.restart()
            } else if (root.step === 2) {
                if (!root.check(hw.storageState.state === "error" && hw.rootDisk.used === 148, "bad JSON retains labelled previous sample")) return
                fixture.setText("exit"); start.restart()
            } else if (root.step === 3) {
                if (!root.check(hw.storageState.state === "error" && hw.rootDisk.used === 148, "nonzero collector exit rejects its plausible output")) return
                fixture.setText("unavailable"); start.restart()
            } else if (root.step === 4) {
                if (!root.check(hw.storageState.state === "unavailable" && hw.rootDisk === null && hw.nvmeTemp === null, "missing storage clears previous values")) return
                fixture.setText("unsupported"); start.restart()
            } else if (root.step === 5) {
                if (!root.check(hw.storageState.state === "unsupported", "explicit unsupported")) return
                fixture.setText("valid"); start.restart()
            } else if (root.step === 6) {
                if (!root.check(hw.storageState.state === "valid" && hw.storageError === "", "fresh recovery")) return
                hw.storageNowMs = hw.storageSampledAtMs + hw.storageStaleAfterMs + 1
                if (!root.check(hw.storageState.state === "stale", "clock freshness")) return
                if (!root.check(root.texts(card).join(" ").indexOf("previous") >= 0, "stale visible")) return
                console.log("STORAGE-PASS " + root.checks + " integration checks")
                Qt.quit()
            }
            root.step++
        }
    }
}
