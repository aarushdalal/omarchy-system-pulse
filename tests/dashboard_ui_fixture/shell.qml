import QtQuick
import QtQuick.Window
import QtTest
import Quickshell
import qs.Commons as Core
import "services"
import "components/polish" as Polish
ShellRoot {
 id:root
 property int step:0
 property int checks:0
 property bool failed:false
 function find(item,name) {
  if (item.objectName === name) return item
  if (item.children === undefined) return null
  for(var i=0;i<item.children.length;i++){var found=find(item.children[i],name);if(found)return found}
  return null
 }
 function check(ok,message){if(!ok){failed=true;console.error("UI-FAIL "+message);Qt.quit();return false}checks++;return true}
 function page(i){return find(dash,"dashboard-page-"+i)}
 function tab(i){return find(dash,"dashboard-tab-"+i)}
 function settled(index){
  for(var i=0;i<6;i++){
   if(!check(page(i).enabled === (dash.open && i===index),"input ownership "+i))return false
   if(!check(Math.abs(page(i).opacity-(i===index?1:0))<.001,"opacity "+i))return false
   if(!check(page(i).visible === (i===index),"visibility "+i))return false
  }
  return check(Math.abs(page(index).x)<.001 && Math.abs(page(index).scale-1)<.001,"selected neutral transform")
 }
 QtObject {id:bar;property color barForeground:"#dededb";property string fontFamily:"monospace";property string position:"top";property var activePopout:null;function requestPopout(x){} function releasePopout(x){} }
 HardwareStats {id:hw}
 Window {
  id:win;visible:true;width:900;height:800;color:"#050608"
  Dashboard {id:dash;x:40;y:40;bar:bar;anchorItem:null;open:true;triggerMode:"hover";anchorHovered:true}
  TestCase {id:input;when:false;name:"DashboardInput"}
 }
 Timer {id:fast;interval:25;onTriggered:{dash.activeTabIndex=1}}
 Timer {id:intermediate;interval:50;onTriggered:{
  console.log("MIDFRAME",page(0).x,page(0).opacity,page(1).x,page(1).opacity)
  check(page(0).opacity>0 && page(0).opacity<1 && page(1).opacity>0 && page(1).opacity<1,"intermediate crossfade")
  check(Math.abs(page(1).x)>0 && Math.abs(page(1).x)<Polish.MotionAdapter.dashboardTravel,"intermediate bounded incoming travel")
  check(page(0).x<0 && page(1).x>0,"forward transition preserves direction")
  check(page(0).visible && page(1).visible && !page(0).enabled && page(1).enabled,"intermediate visibility and input")
  check(page(0).motionRunning && page(1).motionRunning,"transition running midflight")
  Core.Motion.reducedMotion=true
  reducedCheck.restart()
 }}
 Timer {id:reducedCheck;interval:30;onTriggered:{
  for(var i=0;i<6;i++){
   check(page(i).x===0 && page(i).scale===1,"reduced midflight neutral "+i)
   check(!page(i).motionRunning,"reduced midflight stopped "+i)
  }
  check(page(0).opacity===0 && page(1).opacity===1,"reduced midflight snapped opacity")
 }}
 Timer {
  interval:300;running:true;repeat:true
  onTriggered:{
   if(root.failed)return
   if(step===0){
    if(!check(settled(0),"initial storage"))return
    dash.activeTabIndex=5;fast.restart()
   }else if(step===1){
    if(!check(settled(1),"rapid 0-5-1 settles"))return
    dash.activeTabIndex=0
    dash.open=false
    if(!check(!dash.dashboardMotionEnabled,"closed motion disabled"))return
    dash.activeTabIndex=4
    if(!check(settled(4),"closed switch snaps"))return
    find(dash,"dashboard-tabs").request(1,true)
    dash.handleWheel(-120,true)
    if(!check(dash.activeTabIndex===4 && !tab(4).enabled,"closed controls ignore requests"))return
    dash.open=true
   }else if(step===2){
    if(!check(settled(4),"reopen stays correct"))return
    tab(4).forceActiveFocus();win.requestActivate()
    input.keyClick(Qt.Key_Home)
    if(!check(dash.activeTabIndex===0,"Home selects first"))return
    input.keyClick(Qt.Key_Right)
    if(!check(dash.activeTabIndex===1,"Right selects next"))return
    input.keyClick(Qt.Key_End)
    if(!check(dash.activeTabIndex===5,"End selects last"))return
    input.keyClick(Qt.Key_Left)
    if(!check(dash.activeTabIndex===4,"Left selects previous"))return
    input.keyClick(Qt.Key_Space)
    if(!check(dash.activeTabIndex===4 && tab(4).activeFocus,"Space preserves focused tab"))return
    input.mouseClick(tab(2),tab(2).width/2,tab(2).height/2,Qt.LeftButton)
    if(!check(dash.activeTabIndex===2,"mouse selects Audio"))return
   }else if(step===3){
    if(!check(settled(2),"Audio selected"))return
    Core.Motion.intensity="subtle"
    if(!check(Polish.MotionAdapter.dashboardTravel>0 && Polish.MotionAdapter.dashboardTravel<=12,"subtle travel bound"))return
    Core.Motion.activePreset="quantum";Core.Motion.standard=130;Core.Motion.liquidMoveDuration=160
    if(!check(Polish.MotionAdapter.dashboardDuration===130 && Polish.MotionAdapter.dashboardPillDuration===160,"preset timing follows provider"))return
    Core.Motion.activePreset="jelly";Core.Motion.standard=320;Core.Motion.liquidMoveDuration=500
    if(!check(Polish.MotionAdapter.dashboardDuration===220 && Polish.MotionAdapter.dashboardPillDuration===180 && Polish.MotionAdapter.activePreset==="jelly","expressive timing bounded"))return
    Core.Motion.intensity="expressive"
    if(!check(Polish.MotionAdapter.dashboardTravel>20 && Polish.MotionAdapter.dashboardTravel<=27,"expressive travel bound"))return
    dash.activeTabIndex=5
    Core.Motion.reducedMotion=true
   }else if(step===4){
    if(!check(settled(5),"reduced during animation settles"))return
    for(var i=0;i<6;i++) if(!check(page(i).x===0 && page(i).scale===1,"reduced neutral "+i))return
    if(!check(Polish.MotionAdapter.dashboardDuration===1 && Polish.MotionAdapter.dashboardTravel===0,"reduced duration"))return
    var rail=find(dash,"dashboard-tab-rail"),pill=find(dash,"dashboard-active-pill")
    if(!check(Math.abs(pill.x-(rail.inset+5*(rail.tabWidth+rail.gap)))<.001,"reduced pill snaps"))return
    dash.activeTabIndex=0;dash.contentWidth=480
   }else if(step===5){
    for(var i=0;i<6;i++)if(!check(tab(i).width>0 && tab(i).x>=0,"480px tab "+i))return
    if(!check(page(0).children[0].implicitHeight<=page(0).height,"Storage remains fully visible at480"))return
    dash.contentWidth=760
   }else if(step===6){
    var rail=find(dash,"dashboard-tab-rail"),pill=find(dash,"dashboard-active-pill")
    if(!check(pill.x>=0 && pill.x+pill.width<=rail.width,"760px active bounds"))return
    if(!check(page(0).children[0].implicitHeight<=page(0).height,"Storage fully visible at760"))return
    Core.Motion.reducedMotion=false;Core.Motion.intensity="balanced"
    Core.Motion.activePreset="jelly";dash.activeTabIndex=5;dash.open=false;dash.open=true;dash.open=false
   }else if(step===7){
    var surface=find(dash,"refined-popup-surface")
    if(!check(surface.opacity===0 && dash.visible===false,"interrupted popup closes"))return
    Core.Motion.reducedMotion=true;dash.open=true;dash.contentWidth=560;dash.activeTabIndex=0
   }else if(step===8){
    var surface=find(dash,"refined-popup-surface")
    if(!check(surface.opacity===1 && surface.transform[0].x===0 && surface.transform[0].y===0 && surface.transform[1].xScale===1,"reduced popup neutral"))return
    if(!check(settled(0),"final storage state"))return
    Core.Motion.reducedMotion=false
    dash.activeTabIndex=1
    intermediate.restart()
   }else if(step===9){
    if(!check(settled(1),"normal transition completes"))return
    for(var i=0;i<6;i++)if(!check(!page(i).motionRunning,"idle animation stopped "+i))return
    dash.contentHeight=330;dash.activeTabIndex=0
   }else if(step===10){
    var viewport=find(dash,"dashboard-page-viewport")
    if(!check(viewport.overflow && viewport.contentHeight>viewport.height,"Short screen retains scrollable content"))return
    viewport.forceActiveFocus();input.keyClick(Qt.Key_End)
    if(!check(viewport.contentY>0 && viewport.contentY+viewport.height>=viewport.contentHeight-1,"Keyboard reaches content bottom"))return
    input.keyClick(Qt.Key_Home)
    if(!check(viewport.contentY===0,"Keyboard returns to content top"))return
    input.mouseWheel(viewport,viewport.width/2,viewport.height/2,0,-120,Qt.NoButton,Qt.NoModifier)
   }else if(step===11){
    var viewport=find(dash,"dashboard-page-viewport")
    if(!check(dash.activeTabIndex===0 && viewport.contentY>0,"Vertical overflow wheel scrolls without changing section: index="+dash.activeTabIndex+" y="+viewport.contentY+" height="+viewport.height+" content="+viewport.contentHeight))return
    dash.activeTabIndex=1
    if(!check(viewport.contentY===0,"New section starts at top"))return
    console.log("UI-PASS "+checks+" checks")
    Qt.quit()
   }
   step++
  }
 }
}
