import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

// Bar entry point.
//
// Left click opens the browser overlay, middle click pulls a fresh random
// wallpaper, right click flips rotation on and off. Everything it shows is
// read from files the CLI and the service write, so it needs no direct handle
// on either of them.
BarWidget {
  id: root
  moduleName: "co.klair.wallarchy"

  readonly property string cliPath: Qt.resolvedUrl("wallarchy").toString().replace(/^file:\/\//, "")
  readonly property string home: Quickshell.env("HOME")

  property var photo: ({})
  property int rotateMinutes: 0
  property string query: ""
  property string categories: "100"
  property bool working: false

  readonly property bool showLabel: setting("showLabel", false) === true
  readonly property string labelText: Model.singleLine(photo && photo.label ? photo.label : "", 24)
  readonly property color foreground: bar ? bar.barForeground : Color.foreground
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family
  readonly property string tooltipText: Model.barTooltip({
    photo: photo,
    query: query,
    categories: categories,
    rotateMinutes: rotateMinutes
  })

  onTooltipTextChanged: if (interactionArea.containsMouse && bar) bar.showTooltip(root, tooltipText)

  function applyConfig(raw) {
    var config = Model.parseJson(raw, {}, 65536)
    var minutes = Number(config.rotateMinutes)
    rotateMinutes = isFinite(minutes) && minutes > 0 ? Math.round(minutes) : 0
    query = Model.singleLine(config.query || "", 40)
    categories = Model.normalizeBits(config.categories || "100")
  }

  function applyCurrent(raw) {
    photo = Model.parseJson(raw, {}, 262144)
  }

  function openBrowser() {
    Quickshell.execDetached(["omarchy-shell", "shell", "toggle", "co.klair.wallarchy", "{}"])
  }

  function nextWallpaper() {
    if (working) return
    working = true
    nextProcess.command = [root.cliPath, "next"]
    nextProcess.running = true
  }

  // Right click is a coarse on/off: it remembers nothing, so flipping back on
  // lands on a sane default rather than whatever obscure interval was set in
  // the overlay. The overlay is where a specific interval gets chosen.
  function toggleRotation() {
    if (configProcess.running) return
    configProcess.command = [root.cliPath, "config", "set", "rotateMinutes",
      rotateMinutes > 0 ? "0" : "60"]
    configProcess.running = true
  }

  implicitWidth: content.implicitWidth + Style.space(10)
  implicitHeight: barSize

  FileView {
    path: root.home + "/.config/omarchy/wallarchy.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.applyConfig(text())
    onFileChanged: reload()
    onLoadFailed: root.applyConfig("{}")
  }

  FileView {
    path: root.home + "/.local/state/wallarchy/current.json"
    watchChanges: true
    printErrors: false
    onLoaded: root.applyCurrent(text())
    onFileChanged: reload()
    onLoadFailed: root.applyCurrent("{}")
  }

  Process {
    id: nextProcess
    command: []
    onExited: root.working = false
  }

  Process {
    id: configProcess
    command: []
  }

  Row {
    id: content
    anchors.centerIn: parent
    spacing: Style.space(6)

    OpticalGlyph {
      anchors.verticalCenter: parent.verticalCenter
      width: Style.bar.iconSlot
      height: Style.bar.iconSlot
      text: root.rotateMinutes > 0 ? "󰑖" : "󰋩"
      fontFamily: root.fontFamily
      fontSize: Style.font.icon
      color: root.foreground
      opacity: root.working ? 0.5 : 1

      Behavior on opacity { NumberAnimation { duration: 120 } }
    }

    Text {
      anchors.verticalCenter: parent.verticalCenter
      visible: root.showLabel && root.labelText !== "" && !root.vertical
      text: root.labelText
      color: root.foreground
      font.family: root.fontFamily
      font.pixelSize: Style.font.body
      renderType: Text.NativeRendering
    }
  }

  MouseArea {
    id: interactionArea
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    cursorShape: Qt.PointingHandCursor
    onClicked: function(mouse) {
      if (mouse.button === Qt.MiddleButton) root.nextWallpaper()
      else if (mouse.button === Qt.RightButton) root.toggleRotation()
      else root.openBrowser()
    }
    onEntered: if (root.bar) root.bar.showTooltip(root, root.tooltipText)
    onExited: if (root.bar) root.bar.hideTooltip(root)
  }
}
