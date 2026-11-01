pragma Singleton
import QtQuick
QtObject {
    property int cornerRadius: 10
    property var font: ({title: 17, body: 14, bodySmall: 13, caption: 12})
    function space(x) { return x }
    function normalFillFor(fg, accent) { return "#171b1a" }
    function hoverFillFor(fg, accent) { return "#212925" }
    function selectedFillFor(fg, accent) { return "#212925" }
}
