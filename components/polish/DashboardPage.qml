import QtQuick

// One shared page definition keeps six transitions consistent and compiled once.
Item {
    id: page
    property int pageIndex: 0
    property int selectedIndex: 0
    readonly property bool selected: selectedIndex === pageIndex
    property bool motionEnabled: true
    property real travel: MotionAdapter.dashboardTravel
    readonly property real preferredHeight: children.length ? Math.max(0, children[0].implicitHeight) : 0
    readonly property bool motionRunning: pageTransition.running
    visible: selected || opacity > 0
    state: (motionEnabled ? "" : "instant-") + (selected ? "active" : "inactive")
    states: [
        State { name: "active"; PropertyChanges { target: page; x: 0; scale: 1; opacity: 1 } },
        State { name: "inactive"; PropertyChanges {
            target: page
            x: (page.pageIndex < page.selectedIndex ? -1 : 1) * page.travel
            scale: MotionAdapter.dashboardScale; opacity: 0
        } },
        State { name: "instant-active"; extend: "active" },
        State { name: "instant-inactive"; extend: "inactive" }
    ]
    transitions: Transition {
        id: pageTransition
        from: "active,inactive"; to: "active,inactive"
        enabled: page.motionEnabled
        NumberAnimation { properties: "x,scale"; duration: MotionAdapter.dashboardDuration; easing.type: MotionAdapter.easeStandard }
        NumberAnimation { property: "opacity"; duration: MotionAdapter.dashboardDuration; easing.type: MotionAdapter.easeMicro }
    }
}
