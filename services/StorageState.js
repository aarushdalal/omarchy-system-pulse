.pragma library

// Storage evidence only: filesystem capacity and hwmon temperature never imply
// SMART health, endurance, TRIM status, model or PCIe link characteristics.
function number(value, minimum, maximum) {
    if (typeof value !== "number" || !isFinite(value)) return null
    if (value < minimum || value > maximum) return null
    return value
}

function disk(value) {
    if (!value || typeof value !== "object" || Array.isArray(value)) return null
    var total = number(value.total, 0, 1000000000)
    var used = number(value.used, 0, 1000000000)
    var free = number(value.free, 0, 1000000000)
    var pct = number(value.pct, 0, 100)
    // df -BG rounds fields up independently; used + free may exceed total by
    // one GiB, but larger discrepancies are not a coherent capacity sample.
    if (total === null || total <= 0 || used === null || free === null || pct === null
            || used > total || free > total || used + free > total + 1) return null
    return { name: typeof value.name === "string" ? value.name.substring(0, 160) : "Storage volume",
             total: total, used: used, free: free, pct: pct }
}

function capacityText(value) {
    return value ? value.used + " GiB / " + value.total + " GiB (" + value.pct + "%)" : "Capacity unavailable"
}

function snapshot(raw, sampledAt, now, staleAfter, error, sampled) {
    var data = raw && typeof raw === "object" && !Array.isArray(raw) ? raw : null
    var root = data ? disk(data.root) : null
    var secondary = data ? disk(data.volume2) : null
    var temperature = data ? number(data.nvme_temp, -40, 150) : null
    // A human-looking status string is not proof that a SMART probe succeeded.
    var smart = data && data.smart && typeof data.smart === "object" ? data.smart : null
    var secondaryExpected = data && data.volume2 !== undefined && data.volume2 !== null
    var smartKnown = smart && smart.state === "valid" && typeof smart.status === "string"
            && smart.status.trim().length > 0 && smart.status.trim().toLowerCase() !== "unknown"
    var smartState = smartKnown ? "valid" : smart && smart.state === "unsupported" ? "unsupported" : "unavailable"
    var age = sampled && sampledAt > 0 ? now - sampledAt : null
    var state = "loading"
    var detail = "Waiting for the first storage sample."
    if (sampled) {
        if (!data) {
            state = "unavailable"
            detail = "Storage data was not supplied by the collector."
        } else if (data.state === "unsupported" && !root && temperature === null && !smartKnown) {
            state = "unsupported"
            detail = "Storage telemetry is not supported by this collector."
        } else if (!root && temperature === null && !smartKnown) {
            state = "unavailable"
            detail = "Capacity, temperature and SMART data are unavailable."
        } else if (root && temperature !== null && smartKnown && (!secondaryExpected || secondary)) {
            state = "valid"
            detail = "Capacity, temperature and SMART samples are available."
        } else {
            state = "partial"
            detail = "Some storage measurements are unavailable; no health grade is inferred."
        }
        if (age === null || age < 0 || age > staleAfter) {
            state = "stale"
            detail = "Last sample is stale; the displayed values are not current."
        }
    }
    if (error) {
        state = "error"
        detail = sampled ? "Collector error; displayed values are from the previous sample."
                         : "Collector error; no storage sample is available."
    }
    var titles = { loading: "Loading", valid: "Telemetry available", partial: "Partial telemetry",
                   stale: "Stale sample", unsupported: "Unsupported", unavailable: "Unavailable", error: "Collector error" }
    return { state: state, title: titles[state], detail: detail, root: root, volume2: secondary,
             nvmeTemp: temperature, ageMs: age, smartState: smartState,
             smartText: smartKnown ? "SMART: " + smart.status.substring(0, 120)
                       : smartState === "unsupported" ? "SMART: unsupported"
                       : "SMART: not collected / unavailable" }
}
