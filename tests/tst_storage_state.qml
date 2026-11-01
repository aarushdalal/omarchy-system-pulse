import QtQuick
import QtTest
import "../services/StorageState.js" as Storage

TestCase {
    name: "StorageEvidence"
    function capacity() { return { name: "Root", total: 187, used: 148, free: 38, pct: 80 } }
    function complete() { return { root: capacity(), nvme_temp: 36, smart: { state: "valid", status: "Passed" } } }
    function model(raw, now, error, sampled) {
        return Storage.snapshot(raw, 1000, now === undefined ? 1500 : now, 5000,
                                error || "", sampled === undefined ? true : sampled)
    }
    function test_seven_states_data() {
        return [
            {tag: "loading", raw: null, sampled: false, now: 1500, error: "", state: "loading"},
            {tag: "valid", raw: complete(), sampled: true, now: 1500, error: "", state: "valid"},
            {tag: "partial", raw: {root: capacity(), nvme_temp: 0, smart: "Unknown"}, sampled: true, now: 1500, error: "", state: "partial"},
            {tag: "stale", raw: complete(), sampled: true, now: 6001, error: "", state: "stale"},
            {tag: "unsupported", raw: {state: "unsupported"}, sampled: true, now: 1500, error: "", state: "unsupported"},
            {tag: "unavailable", raw: null, sampled: true, now: 1500, error: "", state: "unavailable"},
            {tag: "error", raw: complete(), sampled: true, now: 1500, error: "exit", state: "error"}
        ]
    }
    function test_seven_states(row) { compare(model(row.raw, row.now, row.error, row.sampled).state, row.state) }
    function test_temperature_not_truthiness() {
        var raw = {root: capacity(), nvme_temp: 0}
        compare(model(raw).nvmeTemp, 0)
        var bad = [null, undefined, "", "36", NaN, Infinity, -Infinity, -41, 151, {}, false]
        for (var i = 0; i < bad.length; i++) {
            raw.nvme_temp = bad[i]
            compare(model(raw).nvmeTemp, null, "temperature " + i)
        }
        raw.nvme_temp = -5
        compare(model(raw).nvmeTemp, -5) // Below freezing is not the same as absent.
    }
    function test_capacity_validation() {
        var invalid = [null, [], {}, {total: 0, used: 0, free: 0, pct: 0},
            {total: 10, used: 11, free: 0, pct: 100}, {total: 10, used: 0, free: 11, pct: 0},
            {total: 10, used: -1, free: 10, pct: 0}, {total: 10, used: 1, free: 9, pct: 101},
            {total: 10, used: 1, free: 9, pct: NaN}, {total: "10", used: 1, free: 9, pct: 10}, {total: 100, used: 90, free: 90, pct: 90}]
        for (var i = 0; i < invalid.length; i++) compare(Storage.disk(invalid[i]), null, "capacity " + i)
        var empty = Storage.disk({total: 10, used: 0, free: 10, pct: 0})
        verify(Storage.disk({total: 10, used: 5, free: 6, pct: 50}) !== null)
        compare(empty.used, 0)
        compare(empty.pct, 0)
        compare(Storage.capacityText(empty), "0 GiB / 10 GiB (0%)")
        compare(Storage.capacityText(null), "Capacity unavailable")
    }
    function test_smart_strings_are_not_evidence() {
        var values = ["Unknown", "Passed", "NVMe Optimal", {state: "valid", status: "Unknown"},
                      {state: "valid", status: " Unknown "}, {state: "valid", status: ""}, {status: "Passed"}]
        for (var i = 0; i < values.length; i++) {
            var raw = complete(); raw.smart = values[i]
            compare(model(raw).state, "partial", "SMART " + i)
            compare(model(raw).smartState, "unavailable")
        }
        var unsupported = complete(); unsupported.smart = {state: "unsupported"}
        compare(model(unsupported).state, "partial")
        compare(model(unsupported).smartText, "SMART: unsupported")
    }
    function test_freshness_boundaries_and_recovery() {
        compare(model(complete(), 6000).state, "valid")
        compare(model(complete(), 6001).state, "stale")
        compare(model(complete(), 999).state, "stale") // Backward wall clock cannot certify freshness.
        compare(Storage.snapshot(complete(), 1000, 16000, 15000, "", true).state, "valid")
        compare(Storage.snapshot(complete(), 1000, 16001, 15000, "", true).state, "stale")
        compare(model(complete(), 1500, "bad-json").state, "error")
        compare(model(complete(), 1500, "").state, "valid")
        compare(model(complete(), 1500, "failed").root.used, 148)
        verify(model(complete(), 1500, "failed").detail.indexOf("previous sample") >= 0)
    }
    function test_invalid_secondary_prevents_complete_state() {
        var raw = complete(); raw.volume2 = {total: 0}
        compare(model(raw).state, "partial")
        compare(model(raw).volume2, null)
        raw.volume2 = capacity()
        compare(model(raw).state, "valid")
    }
}
