from pathlib import Path
import shutil,re,sys
origin=Path(sys.argv[1])
folder=Path(sys.argv[2])
folder.mkdir(parents=True,exist_ok=True)
for directory in ['Commons','Ui','components/polish','cards','services']:(folder/directory).mkdir(parents=True,exist_ok=True)
def put(rel,text): (folder/rel).write_text(text)
def copy(rel): shutil.copy2(origin/rel,folder/rel)
entry='SystemPlusDashboard.qml' if (origin/'SystemPlusDashboard.qml').exists() else 'SystemPulseDashboard.qml'
put('Dashboard.qml',(origin/entry).read_text())
for rel in ['components/polish/MotionAdapter.qml','components/polish/RefinedPopupCard.qml','components/polish/qmldir','cards/StorageCard.qml','services/StorageState.js']:
 copy(rel)
for extra in ['DashboardTabs.qml','DashboardPage.qml']:
 if (origin/'components/polish'/extra).exists():copy('components/polish/'+extra)
s=(folder/'components/polish/RefinedPopupCard.qml').read_text()
s=s.replace('PopupWindow {','Item {',1).replace('  color: "transparent"','  property color color: "transparent"',1)
a=s.index('  HyprlandFocusGrab {');b=s.index('  readonly property var originData:',a)
s=s[:a]+'''  // Fixture replaces only native anchoring/focus: no compositor input grab.
  property QtObject popupAnchor: QtObject { property var rect: ({x:0, y:0}) }
'''+s[b:]
put('components/polish/RefinedPopupCard.qml',s)
put('Commons/qmldir','module qs.Commons\nsingleton Color 1.0 Color.qml\nsingleton Style 1.0 Style.qml\nsingleton Border 1.0 Border.qml\nsingleton Theme 1.0 Theme.qml\nsingleton Motion 1.0 Motion.qml\n')
put('Commons/Color.qml','''pragma Singleton
import QtQuick
QtObject { property color foreground: "#dededb"; property color background: "#0b0d0f"; property color accent: "#8ea0b4"; property color urgent: "#bd7b7b"; property var popups: ({border: "#343a42"}) }
''')
put('Commons/Style.qml','''pragma Singleton
import QtQuick
QtObject {
 property int cornerRadius: 10; property int gapsOut: 8
 property var spacing: ({popupPadding:14})
 property var font: ({family:"monospace",title:16,body:13,bodySmall:12,caption:11})
 function space(x) { return x }
 function normalFillFor(f,a) { return Qt.rgba(f.r,f.g,f.b,.04) }
 function hoverFillFor(f,a) { return Qt.rgba(f.r,f.g,f.b,.08) }
 function selectedFillFor(f,a) { return Qt.rgba(f.r,f.g,f.b,.18) }
}
''')
put('Commons/Border.qml','''pragma Singleton
import QtQuick
QtObject {
 function none() { return {type:"none"} }
 function surfaceSpec() { return {type:"solid"} }
 function top(s) { return s && s.type !== "none" ? 1 : 0 }
 function right(s) { return top(s) }
 function bottom(s) { return top(s) }
 function left(s) { return top(s) }
}
''')
put('Commons/Theme.qml','''pragma Singleton
import QtQuick
QtObject { property color surface: "#0b0d0f"; property color borderSubtle:"#2b3037"; property int radiusLarge:14 }
''')
put('Commons/Motion.qml','''pragma Singleton
import QtQuick
QtObject {
 property string activePreset:"tokyo"; property bool reducedMotion:false; property string intensity:"balanced"
 property int micro: reducedMotion ? 1 : 85; property int standard:reducedMotion ? 1 : 175
 property int expressive:reducedMotion ? 1 : 240; property int entryDuration:reducedMotion ? 1 : 280
 property int easeMicro:Easing.OutQuad; property int easeStandard:Easing.OutCubic; property int easeExpressive:Easing.OutCubic
 property real springOvershoot:reducedMotion ? 0 : .7
 property real entryScaleStart: reducedMotion ? 1 : .9
 property real entryYOffset:reducedMotion ? 0 : 16
 property real pressScale:reducedMotion ? 1 : .97
 property real hoverScale:reducedMotion ? 1 : 1.025
 property int liquidMoveDuration:reducedMotion ? 1 : 240
 function calculateOrigin(a,r,p) { return {originX:.5,originY:0,directionY:1} }
}
''')
put('Ui/qmldir','module qs.Ui\nBorderSurface 1.0 BorderSurface.qml\n')
put('Ui/BorderSurface.qml','''import QtQuick
Rectangle {
 property var borderSpec:({type:"none"});property real padding:0
 readonly property real contentTopInset:padding+1;readonly property real contentRightInset:padding+1
 readonly property real contentBottomInset:padding+1;readonly property real contentLeftInset:padding+1
 border.width:1;border.color:"#2b3037"
}
''')
for card in ['ComputeCard','AudioCard','DeckCard','WeatherCard','FanCard']:
 put('cards/'+card+'.qml','''import QtQuick
Rectangle {
 property var hardwareStats:null;property var mediaService:null;property var visualizerService:null;property var bar:null;property var fanService:null
 property color foregroundColor:"white";property string fontFamily:"monospace"
 implicitHeight:320;radius:10;color:"#12161c"
 Text {anchors.centerIn:parent;text:"'''+card.removesuffix('Card')+''' fixture content";color:parent.foregroundColor;font.family:parent.fontFamily;font.pixelSize:18}
}
''')
put('services/FanService.qml','import QtQuick\nItem { property var hardwareStats:null }\n')
# Public source owns a different collector. This fixture is frozen synthetic data.
put('services/HardwareStats.qml','''import QtQuick
Item {
 property bool active:false
 readonly property var storageState: ({state:"partial",title:"Partial telemetry",detail:"Capacity and temperature measured; SMART is not collected.",root:{name:"Root",total:187,used:148,free:38,pct:80},volume2:{name:"Archive",total:128,used:45,free:84,pct:35},nvmeTemp:36,smartText:"SMART: not collected / unavailable"})
}
''')
put('shell.qml','''import QtQuick
import QtQuick.Window
import Quickshell
import "services"
ShellRoot {
 property string outputPath: Qt.resolvedUrl("capture.png").toString().substring(7)
 QtObject {id:bar; property color barForeground:"#dededb";property string fontFamily:"monospace";property string position:"top";property var activePopout:null;function requestPopout(x){} function releasePopout(x){} }
 HardwareStats {id:hw}
 Window {
  id:win;visible:true;width:640;height:680;color:"#050608"
  Dashboard { id:dash;x:40;y:40;bar:bar;anchorItem:null;open:true;triggerMode:"hover";anchorHovered:true
'''+('  hardwareStats:hw\n' if 'property var hardwareStats:' in (origin/entry).read_text() else '')+'''  }
 }
 Timer {interval:900;running:true;onTriggered:win.contentItem.grabToImage(function(image){image.saveToFile(outputPath);console.log("CAPTURE-OK");Qt.quit()})}
}
''')
print(folder)
