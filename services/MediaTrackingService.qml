import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire

Item {
  id: root

  // --------------------------------------------------------------------------
  // BROWSER & DUMMY FILTERS
  // --------------------------------------------------------------------------
  function isWallpaperOrDummy(p) {
    if (!p) return true
    var name = String(p.identity || p.desktopEntry || p.dbusName || "").toLowerCase()
    var track = String(p.trackTitle || "").toLowerCase()
    if (name.indexOf("mpvpaper") !== -1 || name.indexOf("paper") !== -1) return true
    if (name.indexOf("mpv") !== -1 && (track.indexOf(".mp4") !== -1 || track.indexOf(".mkv") !== -1 || track.indexOf(".webm") !== -1 || track === "" || track === "no media playing")) {
      return true
    }
    return false
  }

  function isBrowserName(str) {
    var s = String(str || "").toLowerCase()
    return s.indexOf("brave") !== -1 ||
           s.indexOf("chrome") !== -1 ||
           s.indexOf("chromium") !== -1 ||
           s.indexOf("firefox") !== -1 ||
           s.indexOf("zen") !== -1 ||
           s.indexOf("edge") !== -1 ||
           s.indexOf("opera") !== -1 ||
           s.indexOf("vivaldi") !== -1 ||
           s.indexOf("librewolf") !== -1 ||
           s.indexOf("waterfox") !== -1
  }

  // --------------------------------------------------------------------------
  // PIPEWIRE REAL-TIME AUDIO STREAM MONITORS
  // --------------------------------------------------------------------------
  readonly property var pwNodes: Pipewire.nodes ? Pipewire.nodes.values : []

  readonly property bool hasBrowserAudioStream: {
    for (var i = 0; i < pwNodes.length; i++) {
      var n = pwNodes[i]
      if (!n || !n.isStream || !n.audio) continue
      var mediaClass = String(n.type || "")
      if (n.isSink !== true && mediaClass.indexOf("Stream/Output/Audio") === -1 && mediaClass.indexOf("AudioOutStream") === -1) continue
      var props = (n.ready && n.properties) ? n.properties : {}
      var appName = String(props["application.name"] || n.name || "").toLowerCase()
      var binName = String(props["application.process.binary"] || "").toLowerCase()
      var iconName = String(props["application.icon-name"] || "").toLowerCase()
      if (isBrowserName(appName) || isBrowserName(binName) || isBrowserName(iconName)) {
        var corked = props["pulse.corked"] === true || props["pulse.corked"] === "true"
        if (!corked) return true
      }
    }
    return false
  }

  readonly property bool hasPlaybackStream: {
    for (var i = 0; i < pwNodes.length; i++) {
      var n = pwNodes[i]
      if (n && n.isStream && n.audio) {
        var mediaClass = String(n.type || "")
        if (n.isSink === true || mediaClass.indexOf("Stream/Output/Audio") !== -1 || mediaClass.indexOf("AudioOutStream") !== -1) {
          if (String(n.name || "").indexOf("easyeffects") === -1 && String(n.name || "").indexOf("quickshell") === -1) {
            return true
          }
        }
      }
    }
    return false
  }

  // --------------------------------------------------------------------------
  // MPRIS FALLBACK PLAYER SELECTION
  // --------------------------------------------------------------------------
  function hasStreamForPlayer(p) {
    if (!p) return false
    var pName = String(p.desktopEntry || p.identity || p.dbusName || "").toLowerCase()
    for (var i = 0; i < pwNodes.length; i++) {
      var n = pwNodes[i]
      if (!n || !n.isStream || !n.audio) continue
      var props = (n.ready && n.properties) ? n.properties : {}
      var appName = String(props["application.name"] || n.name || "").toLowerCase()
      var binName = String(props["application.process.binary"] || "").toLowerCase()
      if (isBrowserName(pName) && (isBrowserName(appName) || isBrowserName(binName))) {
        var corked = props["pulse.corked"] === true || props["pulse.corked"] === "true"
        if (!corked) return true
      }
    }
    return false
  }

  readonly property var activePlayer: {
    if (!Mpris.players || !Mpris.players.values) return null
    var vals = Mpris.players.values

    // 1. Actively playing non-dummy player
    for (var i = 0; i < vals.length; i++) {
      var p = vals[i]
      if (p && !isWallpaperOrDummy(p) && p.isPlaying) return p
    }

    // 2. Player matching an uncorked PipeWire playback stream
    for (var j = 0; j < vals.length; j++) {
      var p2 = vals[j]
      if (p2 && !isWallpaperOrDummy(p2) && hasStreamForPlayer(p2)) return p2
    }

    // 3. Fallback: any non-dummy player
    for (var k = 0; k < vals.length; k++) {
      var p3 = vals[k]
      if (p3 && !isWallpaperOrDummy(p3)) return p3
    }
    return null
  }

  readonly property bool isBrowserPlayer: {
    if (hasBrowserAudioStream) return true
    if (activePlayer) {
      var pName = String(activePlayer.desktopEntry || activePlayer.identity || activePlayer.dbusName || "")
      return isBrowserName(pName)
    }
    return false
  }

  // --------------------------------------------------------------------------
  // BROWSER TITLE RECONCILIATION
  // --------------------------------------------------------------------------
  function cleanBrowserTitle(raw) {
    if (!raw) return { title: "", isMedia: false, service: "" }
    var t = String(raw).trim()
    // Strip leading notification count, e.g. "(448) " or "[2] "
    t = t.replace(/^[\(\[]\d+[\)\]]\s*/, "")
    // Strip trailing browser suffixes (handling hyphens, en-dashes, em-dashes)
    t = t.replace(/[\s\-—–]+(?:Brave|Google Chrome|Chromium|Mozilla Firefox|Firefox|Zen Browser|Microsoft Edge|Vivaldi|Opera)$/i, "")
    
    var isMedia = false
    var service = "Browser"

    if (/[\s\-—–]+YouTube(?:\s*Music)?$/i.test(t)) {
      isMedia = true
      service = "YouTube"
      t = t.replace(/[\s\-—–]+YouTube(?:\s*Music)?$/i, "")
    } else if (/[\s\|—–]+Stream free on SoundCloud$/i.test(t)) {
      isMedia = true
      service = "SoundCloud"
      t = t.replace(/[\s\|—–]+Stream free on SoundCloud$/i, "")
    } else if (/[\s\-—–]+Spotify$/i.test(t)) {
      isMedia = true
      service = "Spotify"
      t = t.replace(/[\s\-—–]+Spotify$/i, "")
    } else if (/[\s\-—–]+Twitch$/i.test(t)) {
      isMedia = true
      service = "Twitch"
      t = t.replace(/[\s\-—–]+Twitch$/i, "")
    } else if (/[\s\-—–]+(?:Bilibili|Vimeo|Dailymotion|Netflix|Prime Video)$/i.test(t)) {
      isMedia = true
      service = "Video"
      t = t.replace(/[\s\-—–]+(?:Bilibili|Vimeo|Dailymotion|Netflix|Prime Video)$/i, "")
    }

    return {
      title: t.trim(),
      isMedia: isMedia,
      service: service
    }
  }

  property string cachedBrowserMediaTitle: ""
  property string cachedBrowserService: ""

  function updateBrowserMediaInfo() {
    var toplevels = (ToplevelManager.toplevels && ToplevelManager.toplevels.values) ? ToplevelManager.toplevels.values : []
    
    // 1. Search all toplevels for a browser with an explicit media window title (e.g. YouTube)
    for (var i = 0; i < toplevels.length; i++) {
      var t = toplevels[i]
      if (!t) continue
      if (isBrowserName(t.appId) || isBrowserName(t.title)) {
        var parsed = cleanBrowserTitle(t.title)
        if (parsed.isMedia && parsed.title !== "") {
          root.cachedBrowserMediaTitle = parsed.title
          root.cachedBrowserService = parsed.service
          return
        }
      }
    }

    // 2. If active toplevel is a browser, check if its title has valid media
    var active = ToplevelManager.activeToplevel
    if (active && (isBrowserName(active.appId) || isBrowserName(active.title))) {
      var parsedActive = cleanBrowserTitle(active.title)
      if (parsedActive.isMedia && parsedActive.title !== "") {
        root.cachedBrowserMediaTitle = parsedActive.title
        root.cachedBrowserService = parsedActive.service
        return
      }
    }

    // 3. If browser is actively streaming audio and has an open window with non-empty title
    if (root.hasBrowserAudioStream) {
      for (var j = 0; j < toplevels.length; j++) {
        var t2 = toplevels[j]
        if (t2 && isBrowserName(t2.appId)) {
          var p2 = cleanBrowserTitle(t2.title)
          var lowTitle = p2.title.toLowerCase()
          if (p2.title !== "" && lowTitle !== "new tab" && lowTitle !== "home" && lowTitle !== "brave" && lowTitle !== "chrome") {
            if (root.cachedBrowserMediaTitle === "") {
              root.cachedBrowserMediaTitle = p2.title
              root.cachedBrowserService = p2.service || "Web Audio"
            }
            return
          }
        }
      }
    }

    // 4. If no browser is running or streaming audio, clear the cache
    if (!root.hasBrowserAudioStream && !root.isPlaying) {
      root.cachedBrowserMediaTitle = ""
      root.cachedBrowserService = ""
    }
  }

  Connections {
    target: ToplevelManager.toplevels
    function onValuesChanged() { root.updateBrowserMediaInfo() }
  }

  Connections {
    target: ToplevelManager
    function onActiveToplevelChanged() { root.updateBrowserMediaInfo() }
  }

  Timer {
    interval: 1000
    running: true
    repeat: true
    onTriggered: root.updateBrowserMediaInfo()
  }

  Component.onCompleted: {
    root.updateBrowserMediaInfo()
  }

  // --------------------------------------------------------------------------
  // RECONCILED METADATA & STATE
  // --------------------------------------------------------------------------
  readonly property bool isPlaying: {
    if (activePlayer && activePlayer.isPlaying) return true
    if (hasBrowserAudioStream) return true
    return false
  }

  readonly property string title: {
    if (isBrowserPlayer) {
      if (cachedBrowserMediaTitle !== "") return cachedBrowserMediaTitle
      if (activePlayer && activePlayer.trackTitle) return activePlayer.trackTitle
      if (hasBrowserAudioStream) return "Web Audio"
    }
    if (activePlayer && activePlayer.trackTitle) return activePlayer.trackTitle
    if (hasPlaybackStream) return "System Audio"
    return "No Media Playing"
  }

  readonly property string artist: {
    if (isBrowserPlayer) {
      if (cachedBrowserService !== "") return cachedBrowserService
      if (activePlayer && activePlayer.trackArtist) return activePlayer.trackArtist
      return "Browser"
    }
    if (activePlayer && activePlayer.trackArtist) return activePlayer.trackArtist
    return "Ready"
  }

  readonly property string album: {
    if (isBrowserPlayer) return ""
    return (activePlayer && activePlayer.trackAlbum) ? activePlayer.trackAlbum : ""
  }

  readonly property string artUrl: {
    if (!activePlayer || !activePlayer.trackArtUrl) return ""
    if (isBrowserPlayer) {
      var mprisT = String(activePlayer.trackTitle || "").toLowerCase()
      var recT = String(title).toLowerCase()
      // Guard against showing stale thumbnails of older tabs
      if (mprisT === recT || (recT !== "" && mprisT.indexOf(recT.substring(0, 10)) !== -1)) {
        return activePlayer.trackArtUrl
      }
      return ""
    }
    return activePlayer.trackArtUrl
  }

  readonly property string identity: {
    if (isBrowserPlayer) {
      if (activePlayer && (activePlayer.identity || activePlayer.desktopEntry)) {
        var idName = String(activePlayer.identity || activePlayer.desktopEntry)
        if (idName.toLowerCase().indexOf("brave") !== -1) return "Brave Browser"
        if (idName.toLowerCase().indexOf("chrome") !== -1) return "Google Chrome"
        if (idName.toLowerCase().indexOf("firefox") !== -1) return "Firefox"
        return idName
      }
      return "Brave Browser"
    }
    return activePlayer ? (activePlayer.identity || activePlayer.desktopEntry || "Media Player") : "Local Audio"
  }

  // Track Length & Position Handling
  readonly property real rawLength: {
    if (!activePlayer) return 0
    if (activePlayer.length && activePlayer.length > 0) return Number(activePlayer.length)
    if (activePlayer.trackLength && activePlayer.trackLength > 0) return Number(activePlayer.trackLength)
    if (activePlayer.metadata) {
      if (activePlayer.metadata["mpris:length"]) return Number(activePlayer.metadata["mpris:length"])
      if (activePlayer.metadata.length) return Number(activePlayer.metadata.length)
    }
    return 0
  }
  readonly property real lengthSec: rawLength > 10000 ? Math.floor(rawLength / 1000000) : rawLength

  property real localPositionSec: 0

  function syncPosition() {
    if (!activePlayer) {
      root.localPositionSec = 0
      return
    }
    var pos = activePlayer.position || 0
    root.localPositionSec = pos > 10000 ? (pos / 1000000.0) : pos
  }

  Connections {
    target: root.activePlayer
    function onPositionChanged() { root.syncPosition() }
    function onPlaybackStateChanged() { root.syncPosition() }
    function onIsPlayingChanged() { root.syncPosition() }
    function onTrackTitleChanged() { root.syncPosition() }
  }

  Timer {
    interval: 500
    running: root.isPlaying
    repeat: true
    onTriggered: root.syncPosition()
  }

  // --------------------------------------------------------------------------
  // MEDIA CONTROL ACTIONS
  // --------------------------------------------------------------------------
  function togglePlayPause() {
    if (!root.activePlayer || root.isWallpaperOrDummy(root.activePlayer)) return
    if (root.activePlayer.canTogglePlaying && typeof root.activePlayer.togglePlaying === "function") {
      root.activePlayer.togglePlaying()
    } else if (root.isPlaying && root.activePlayer.canPause && typeof root.activePlayer.pause === "function") {
      root.activePlayer.pause()
    } else if (!root.isPlaying && root.activePlayer.canPlay && typeof root.activePlayer.play === "function") {
      root.activePlayer.play()
    } else if (typeof root.activePlayer.togglePlaying === "function") {
      root.activePlayer.togglePlaying()
    }
  }

  function nextTrack() {
    if (root.activePlayer && !root.isWallpaperOrDummy(root.activePlayer) && typeof root.activePlayer.next === "function") {
      root.activePlayer.next()
    }
  }

  function prevTrack() {
    if (root.activePlayer && !root.isWallpaperOrDummy(root.activePlayer) && typeof root.activePlayer.previous === "function") {
      root.activePlayer.previous()
    }
  }

  function seek(targetSec) {
    if (!root.activePlayer) return
    var targetMicro = targetSec * 1000000
    if (typeof root.activePlayer.setPosition === "function" && root.activePlayer.trackId) {
      root.activePlayer.setPosition(root.activePlayer.trackId, targetMicro)
    } else if (typeof root.activePlayer.seek === "function") {
      var deltaMicro = (targetSec - root.localPositionSec) * 1000000
      root.activePlayer.seek(deltaMicro)
    }
    root.localPositionSec = targetSec
  }
}
