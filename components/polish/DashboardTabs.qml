import QtQuick
import QtQuick.Layouts
import qs.Commons
import qs.Commons as OmarchyPalette

// Static local materials; only direct selection, hover, focus and press animate.
FocusScope {
    id: root
    objectName: "dashboard-tabs"
    property string title: "System Plus"
    property int currentIndex: 0
    property color foregroundColor: OmarchyPalette.Color.foreground
    property string fontFamily: Style.font.family
    property bool motionEnabled: true
    signal selectionRequested(int index)
    readonly property int selectedIndex: Math.max(0, Math.min(tabs.length - 1, currentIndex))
    property var tabs: [
        { icon: "󰋊", label: "Storage", detail: "Capacity, thermals & health evidence" },
        { icon: "󰍛", label: "Compute", detail: "Processor, memory & graphics" },
        { icon: "󰝚", label: "Audio", detail: "Playback, spectrum & sound controls" },
        { icon: "󰸗", label: "Deck", detail: "Calendar & everyday controls" },
        { icon: "󰖙", label: "Weather", detail: "Conditions & forecast" },
        { icon: "󰈐", label: "Fan", detail: "Thermals & fan curve model" }
    ]
    readonly property bool animate: motionEnabled && !MotionAdapter.reducedMotion
    implicitHeight: Style.space(48)
    Accessible.role: Accessible.PageTabList
    Accessible.name: title + " sections"

    function request(index, keyboard) {
        if (!root.enabled) return
        var next = Math.max(0, Math.min(tabs.length - 1, index))
        root.selectionRequested(next)
        if (keyboard && tabRepeater.itemAt(next)) tabRepeater.itemAt(next).forceActiveFocus()
    }
    function settleMotion() {
        pillSlide.complete()
        for (var i = 0; i < tabRepeater.count; i++) if (tabRepeater.itemAt(i)) tabRepeater.itemAt(i).settleMotion()
    }
    onAnimateChanged: if (!animate) settleMotion()

    Rectangle {
        id: rail
        objectName: "dashboard-tab-rail"
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: Style.space(48)
        radius: Math.max(8, Style.cornerRadius)
        color: Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, .035)
        border.width: 1
        border.color: Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, .075)
        readonly property real inset: Style.space(4)
        readonly property real gap: Style.space(3)
        readonly property real tabWidth: Math.max(1, (width - inset * 2 - gap * (root.tabs.length - 1)) / root.tabs.length)
        Rectangle {
            id: activePill
            objectName: "dashboard-active-pill"
            x: rail.inset + root.selectedIndex * (rail.tabWidth + rail.gap)
            y: rail.inset; width: rail.tabWidth; height: rail.height - rail.inset * 2
            radius: Math.max(6, rail.radius - 3)
            gradient: Gradient {
                GradientStop {position: 0; color: Qt.rgba(OmarchyPalette.Color.accent.r, OmarchyPalette.Color.accent.g, OmarchyPalette.Color.accent.b, .15)}
                GradientStop {position: 1; color: Qt.rgba(OmarchyPalette.Color.accent.r, OmarchyPalette.Color.accent.g, OmarchyPalette.Color.accent.b, .065)}
            }
            border.width: 1
            border.color: Qt.rgba(OmarchyPalette.Color.accent.r, OmarchyPalette.Color.accent.g, OmarchyPalette.Color.accent.b, .28)
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom
                anchors.bottomMargin: Style.space(3)
                width: Style.space(18); height: 2; radius: 1
                color: OmarchyPalette.Color.accent; opacity: .85
            }
            Behavior on x {
                enabled: root.animate
                NumberAnimation {id: pillSlide; duration: MotionAdapter.dashboardPillDuration; easing.type: MotionAdapter.easeStandard}
            }
        }
        Row {
            anchors.fill: parent; anchors.margins: rail.inset; spacing: rail.gap
            Repeater {
                id: tabRepeater
                model: root.tabs
                FocusScope {
                    id: tab
                    required property var modelData
                    required property int index
                    objectName: "dashboard-tab-" + index
                    width: rail.tabWidth; height: parent.height
                    activeFocusOnTab: true
                    readonly property bool selected: root.selectedIndex === index
                    scale: mouse.pressed && root.animate ? MotionAdapter.dashboardPressScale : 1
                    Accessible.role: Accessible.PageTab
                    Accessible.name: modelData.label
                    Accessible.selected: selected
                    Accessible.onPressAction: root.request(index, true)
                    function settleMotion() {pressAnimation.complete(); hoverAnimation.complete()}
                    Keys.onPressed: function(event) {
                        if (event.key === Qt.Key_Left) root.request((index + root.tabs.length - 1) % root.tabs.length, true)
                        else if (event.key === Qt.Key_Right) root.request((index + 1) % root.tabs.length, true)
                        else if (event.key === Qt.Key_Home) root.request(0, true)
                        else if (event.key === Qt.Key_End) root.request(root.tabs.length - 1, true)
                        else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space) root.request(index, true)
                        else return
                        event.accepted = true
                    }
                    Behavior on scale {
                        enabled: root.animate
                        NumberAnimation {id: pressAnimation; duration: MotionAdapter.dashboardMicro; easing.type: MotionAdapter.easeMicro}
                    }
                    Rectangle {
                        anchors.fill: parent; radius: Math.max(6, rail.radius - 3)
                        color: mouse.containsMouse && !tab.selected
                            ? Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, .055) : "transparent"
                        border.width: tab.activeFocus ? 1 : 0
                        border.color: OmarchyPalette.Color.accent
                        Behavior on color {
                            enabled: root.animate
                            ColorAnimation {id: hoverAnimation; duration: MotionAdapter.dashboardMicro; easing.type: MotionAdapter.easeMicro}
                        }
                    }
                    Row {
                        anchors.centerIn: parent; spacing: Style.space(5)
                        Text {
                            visible: rail.tabWidth >= Style.space(76)
                            text: tab.modelData.icon; textFormat: Text.PlainText
                            color: tab.selected ? OmarchyPalette.Color.accent : Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, .60)
                            font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall + 1
                            anchors.verticalCenter: parent.verticalCenter
                        }
                        Text {
                            text: tab.modelData.label; textFormat: Text.PlainText
                            color: tab.selected ? root.foregroundColor : Qt.rgba(root.foregroundColor.r, root.foregroundColor.g, root.foregroundColor.b, mouse.containsMouse ? .9 : .74)
                            font.family: root.fontFamily; font.pixelSize: Style.font.bodySmall
                            font.weight: tab.selected ? Font.DemiBold : Font.Normal
                            anchors.verticalCenter: parent.verticalCenter
                        }
                    }
                    MouseArea {
                        id: mouse; anchors.fill: parent; hoverEnabled: true; cursorShape: Qt.PointingHandCursor
                        onClicked: root.request(tab.index, false)
                        onWheel: function(wheel) { wheel.accepted = false }
                    }
                }
            }
        }
    }
}
