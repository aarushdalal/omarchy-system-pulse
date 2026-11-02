pragma Singleton
import QtQuick
import qs.Commons as Core

// Semantic surface geometry layered over the existing shell motion provider.
// Theme, fonts, preset identity and state ownership stay with the host shell.
QtObject {
    readonly property string activePreset: Core.Motion.activePreset
    readonly property bool reducedMotion: Core.Motion.reducedMotion
    readonly property string intensity: Core.Motion.intensity
    readonly property int micro: Core.Motion.micro
    readonly property int standard: Core.Motion.standard
    readonly property int expressive: Core.Motion.expressive
    readonly property int entryDuration: Core.Motion.entryDuration
    readonly property int exitDuration: Math.max(40, Math.round(entryDuration * 0.65))
    readonly property int easeMicro: Core.Motion.easeMicro
    readonly property int easeStandard: Core.Motion.easeStandard
    readonly property int easeExpressive: Core.Motion.easeExpressive
    readonly property real springOvershoot: Core.Motion.springOvershoot
    readonly property real amplitude: reducedMotion ? 0 : (intensity === "subtle" ? 0.45 : intensity === "expressive" ? 1.1 : 0.8)
    readonly property real entryScaleStart: reducedMotion ? 1 : Math.max(0.65, 1 - (1 - Core.Motion.entryScaleStart) * amplitude)
    readonly property real entryYOffset: activePreset === "tokyo" ? 0 : Math.max(-60, Math.min(60, Core.Motion.entryYOffset * amplitude))
    readonly property real entryXOffset: reducedMotion ? 0 : (activePreset === "tokyo" ? -22 * amplitude : activePreset === "parallax" ? -8 * amplitude : 0)
    readonly property real pressScale: Core.Motion.pressScale
    readonly property real hoverScale: Core.Motion.hoverScale
    readonly property int liquidMoveDuration: Core.Motion.liquidMoveDuration

    // Repeated dashboard actions stay compact while retaining preset timing and intensity.
    readonly property int dashboardDuration: reducedMotion ? 1 : Math.min(220, Core.Motion.standard)
    readonly property int dashboardPillDuration: reducedMotion ? 1 : Math.min(180, Core.Motion.liquidMoveDuration)
    readonly property int dashboardMicro: reducedMotion ? 1 : Math.min(90, Core.Motion.micro)
    readonly property real dashboardTravel: reducedMotion ? 0 : 24 * amplitude
    readonly property real dashboardScale: reducedMotion ? 1 : 1 - .012 * amplitude
    readonly property real dashboardPressScale: reducedMotion ? 1 : Math.max(.975, Core.Motion.pressScale)

    function duration(opening) { return opening ? entryDuration : exitDuration }
    function calculateOrigin(anchor, rect, position) { return Core.Motion.calculateOrigin(anchor, rect, position) }
}
