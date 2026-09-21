import QtQuick
import Quickshell
import Quickshell.Hyprland
import Quickshell.Io
import Quickshell.Wayland
import qs.Commons

Item {
  id: root

  property var shell: null
  property var manifest: null
  property var pluginRegistry: null

  function open(payloadJson) {}
  function close() {}

  readonly property string layerNamespace: "NGNK.glass-clock"
  readonly property string glassRuleName: root.layerNamespace + "-glass"

  readonly property color glassTint: Color.popups.background
  readonly property color glassEdge: Color.popups.text
  readonly property color glassInk: Color.popups.text
  readonly property color glassAccent: Color.accent

  property bool blurEnabled: true
  property bool showSeconds: true

  readonly property real bodyAlpha: root.blurEnabled ? 0.42 : 0.64
  readonly property real sheenAlpha: 0.13
  readonly property real shadeAlpha: 0.14

  readonly property int cornerRadius: Math.max(Style.cornerRadius, Style.space(22))
  readonly property int padX: Style.space(40)
  readonly property int padY: Style.space(30)
  readonly property int edgeMargin: Style.space(30) + Style.gapsOut
  readonly property int topMargin: Style.bar.sizeHorizontal + Style.gapsOut + Style.space(20)
  readonly property int timeSize: Style.fontPx(4.2)
  readonly property int secondSize: Style.fontPx(1.35)
  readonly property int dateSize: Style.fontPx(1.1)

  readonly property var targetScreen: {
    var screens = Quickshell.screens || []
    var best = null
    for (var i = 0; i < screens.length; i++) {
      var candidate = screens[i]
      if (!candidate || candidate.width <= 0 || candidate.height <= 0) continue
      if (!best || candidate.width * candidate.height > best.width * best.height) best = candidate
    }
    return best
  }

  property var glassQueue: []

  function glassCommands() {
    if (Hyprland.usingLua) {
      return [[
        "hyprctl", "eval",
        'hl.layer_rule({ name = "' + glassRuleName + '"'
          + ', match = { namespace = "^' + layerNamespace + '$" }'
          + ", blur = true, ignore_alpha = 0.05, enabled = true })"
      ]]
    }
    return [
      ["hyprctl", "keyword", "layerrule", "blur, " + layerNamespace],
      ["hyprctl", "keyword", "layerrule", "ignorealpha 0.05, " + layerNamespace]
    ]
  }

  function applyGlass() {
    root.glassQueue = root.glassCommands()
    root.runNextGlass()
  }

  function runNextGlass() {
    if (blurProc.running || root.glassQueue.length === 0) return
    var pending = root.glassQueue.slice(1)
    blurProc.command = root.glassQueue[0]
    root.glassQueue = pending
    blurProc.running = true
  }

  function probeBlur() {
    blurProbe.running = true
  }

  Process {
    id: blurProc
    onExited: root.runNextGlass()
  }

  Process {
    id: blurProbe
    command: ["hyprctl", "-j", "getoption", "decoration:blur:enabled"]
    stdout: StdioCollector {
      id: blurProbeOut
      waitForEnd: true
      onStreamFinished: {
        try {
          root.blurEnabled = !!JSON.parse(blurProbeOut.text || "{}").bool
        } catch (error) {
          root.blurEnabled = true
        }
      }
    }
  }

  SystemClock {
    id: clock
    precision: root.showSeconds ? SystemClock.Seconds : SystemClock.Minutes
  }

  Component.onCompleted: {
    root.applyGlass()
    root.probeBlur()
  }

  Connections {
    target: Hyprland
    function onRawEvent(event) {
      if (event && event.name === "configreloaded") {
        root.applyGlass()
        root.probeBlur()
      }
    }
  }

  PanelWindow {
    id: win

    screen: root.targetScreen
    color: "transparent"

    WlrLayershell.namespace: root.layerNamespace
    WlrLayershell.layer: WlrLayer.Bottom
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
      top: true
      right: true
    }

    margins {
      top: root.topMargin
      right: root.edgeMargin
    }

    exclusionMode: ExclusionMode.Ignore
    mask: Region {}

    implicitWidth: content.implicitWidth + root.padX * 2
    implicitHeight: content.implicitHeight + root.padY * 2

    Rectangle {
      id: body
      anchors.fill: parent
      radius: root.cornerRadius
      color: Util.alpha(root.glassTint, root.bodyAlpha)
      border.width: 1
      border.color: Util.alpha(root.glassEdge, 0.16)

      Rectangle {
        anchors.fill: parent
        anchors.margins: body.border.width
        radius: Math.max(0, root.cornerRadius - body.border.width)
        gradient: Gradient {
          GradientStop { position: 0.0; color: Util.alpha("#ffffff", root.sheenAlpha) }
          GradientStop { position: 0.5; color: Util.alpha("#ffffff", 0.0) }
          GradientStop { position: 1.0; color: Util.alpha("#000000", root.shadeAlpha) }
        }
      }
    }

    Column {
      id: content
      anchors.centerIn: parent
      spacing: Style.space(6)

      Row {
        id: timeRow
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: Style.space(3)

        Text {
          id: hourText
          anchors.verticalCenter: parent.verticalCenter
          text: String((clock.date.getHours() % 12) || 12)
          color: root.glassInk
          font.family: Style.font.family
          font.pixelSize: root.timeSize
          font.letterSpacing: Style.space(2)
        }

        Text {
          anchors.verticalCenter: parent.verticalCenter
          text: ":"
          color: Util.alpha(root.glassAccent, 0.9)
          font.family: Style.font.family
          font.pixelSize: root.timeSize
          opacity: root.showSeconds ? (clock.date.getSeconds() % 2 === 0 ? 1.0 : 0.25) : 1.0
          Behavior on opacity { NumberAnimation { duration: 200 } }
        }

        Text {
          id: minuteText
          anchors.verticalCenter: parent.verticalCenter
          text: Qt.formatTime(clock.date, "mm")
          color: root.glassInk
          font.family: Style.font.family
          font.pixelSize: root.timeSize
          font.letterSpacing: Style.space(2)
        }

        Text {
          id: secondText
          visible: root.showSeconds
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: Math.round(root.timeSize * 0.26)
          text: Qt.formatTime(clock.date, "ss")
          color: Util.alpha(root.glassInk, 0.55)
          font.family: Style.font.family
          font.pixelSize: root.secondSize
        }

        Text {
          id: meridiemText
          anchors.verticalCenter: parent.verticalCenter
          anchors.verticalCenterOffset: Math.round(root.timeSize * 0.26)
          text: clock.date.getHours() < 12 ? "AM" : "PM"
          color: Util.alpha(root.glassAccent, 0.85)
          font.family: Style.font.family
          font.pixelSize: root.secondSize
        }
      }

      Text {
        id: dateText
        anchors.horizontalCenter: parent.horizontalCenter
        text: Qt.formatDate(clock.date, "dddd, d MMMM yyyy")
        color: Util.alpha(root.glassInk, 0.72)
        font.family: Style.font.family
        font.pixelSize: root.dateSize
        font.letterSpacing: Style.space(1)
      }
    }
  }
}
