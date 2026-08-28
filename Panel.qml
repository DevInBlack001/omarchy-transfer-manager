import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "filetransfer"
  ipcTarget: "filetransfer"

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property var runningJob: Model.firstByState(transfer.jobs, "running")
  readonly property int overallPercent: root.runningJob ? Model.percentFor(root.runningJob) : -1
  readonly property bool hasActivity: transfer.activeCount > 0
  readonly property bool hasError: Model.hasError(transfer.jobs)

  // Three states, using the active theme's own palette rather than fixed
  // colors, so this tracks whatever theme the user has set: muted while
  // idle, the theme's accent while something is transferring, and the
  // theme's urgent/error color as soon as anything has failed -- that last
  // one takes priority even if something else is running, since a failure
  // is the thing that needs attention.
  readonly property color stateColor: {
    if (!transfer.lastOk) return Color.muted
    if (hasError) return Color.urgent
    if (hasActivity) return Color.accent
    return Color.muted
  }

  Service {
    id: transfer
    settings: root.settings
  }

  onOpenedChanged: if (opened) transfer.refresh()

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    tooltipText: root.hasError
      ? "A transfer failed"
      : (root.hasActivity ? (transfer.activeCount + " active transfer" + (transfer.activeCount === 1 ? "" : "s")) : "No ongoing transfer")
    iconComponent: Component {
      Item {
        TransferIcon {
          anchors.centerIn: parent
          iconSize: Style.space(12)
          color: root.stateColor
        }

        Text {
          visible: root.overallPercent >= 0 && !root.hasError
          anchors.right: parent.right
          anchors.bottom: parent.bottom
          text: root.overallPercent + "%"
          color: root.stateColor
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          font.bold: true
        }
      }
    }
    onPressed: function(buttonCode) {
      if (buttonCode === Qt.RightButton) transfer.refresh()
      else root.toggle()
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "r" || t === "R") transfer.refresh()
        else if (t === "c" || t === "C") transfer.clearFinished()
      }

      Flickable {
        id: panelFlick
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        flickableDirection: Flickable.VerticalFlick
        interactive: contentHeight > height
        ScrollBar.vertical: ScrollBar { policy: ScrollBar.AsNeeded }

        Column {
          id: column
          width: panelFlick.width
          spacing: Style.space(12)

          PanelHero {
            width: parent.width
            title: "Transfer Manager"
            meta: {
              if (!transfer.lastOk) return "Daemon unreachable"
              if (root.hasError) return "A transfer failed"
              if (transfer.activeCount > 0) return transfer.activeCount + " active"
              return "Nothing queued"
            }
            foreground: root.foreground
            fontFamily: root.fontFamily
            iconComponent: Component {
              TransferIcon {
                iconSize: Style.font.display
                color: root.stateColor
              }
            }
          }

          Text {
            visible: !transfer.lastOk
            width: parent.width
            text: transfer.lastError || "Could not reach the transfer daemon."
            color: root.urgent
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall
            wrapMode: Text.WordWrap
          }

          PanelSeparator {
            visible: transfer.jobs.length > 0
            foreground: root.foreground
          }

          Text {
            visible: transfer.lastOk && transfer.jobs.length === 0
            width: parent.width
            text: "No transfers yet."
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.body
            horizontalAlignment: Text.AlignHCenter
          }

          Column {
            width: parent.width
            spacing: Style.space(10)

            Repeater {
              model: transfer.jobs
              JobRow {
                required property var modelData
                width: column.width
                job: modelData
              }
            }
          }

          Text {
            visible: transfer.hasFinished
            text: "Clear finished"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.bodySmall

            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: transfer.clearFinished()
            }
          }
        }
      }
    }
  }

  component JobRow: Column {
    id: jobRow
    property var job: null
    spacing: Style.space(4)

    readonly property int pct: Model.percentFor(jobRow.job)
    readonly property bool isRunning: jobRow.job && jobRow.job.state === "running"
    readonly property bool isPaused: jobRow.job && jobRow.job.state === "paused"
    readonly property bool isDone: jobRow.job
      && (jobRow.job.state === "done" || jobRow.job.state === "error" || jobRow.job.state === "cancelled")

    RowLayout {
      width: parent.width
      spacing: Style.space(8)

      ColumnLayout {
        Layout.fillWidth: true
        spacing: Style.space(1)

        Text {
          Layout.fillWidth: true
          text: Model.jobTitle(jobRow.job) + " → " + Model.jobDestName(jobRow.job)
          color: root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.body
          elide: Text.ElideMiddle
        }

        Text {
          Layout.fillWidth: true
          text: Model.statusLabel(jobRow.job)
            + (jobRow.isRunning ? ("  " + Model.formatRate(jobRow.job.speedBps) + "  ETA " + Model.formatEta(jobRow.job.etaSec)) : "")
            + (jobRow.job && jobRow.job.state === "error" && jobRow.job.error ? ("  " + jobRow.job.error) : "")
          color: jobRow.job && jobRow.job.state === "error" ? root.urgent : root.dim
          font.family: root.fontFamily
          font.pixelSize: Style.font.caption
          elide: Text.ElideRight
        }
      }

      RowLayout {
        spacing: Style.space(4)

        PanelActionButton {
          visible: jobRow.isRunning
          iconText: "⏸"
          tooltipText: "Pause"
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: transfer.pause(jobRow.job.id)
        }
        PanelActionButton {
          visible: jobRow.isPaused
          iconText: "▶"
          tooltipText: "Resume"
          foreground: root.foreground
          fontFamily: root.fontFamily
          onClicked: transfer.resume(jobRow.job.id)
        }
        PanelActionButton {
          visible: !jobRow.isDone
          iconText: "✕"
          tooltipText: "Cancel"
          foreground: root.urgent
          fontFamily: root.fontFamily
          onClicked: transfer.cancel(jobRow.job.id)
        }
      }
    }

    Rectangle {
      visible: jobRow.isRunning || jobRow.isPaused
      width: parent.width
      height: Style.space(4)
      radius: height / 2
      color: Qt.darker(root.foreground, 3)

      Rectangle {
        width: jobRow.pct >= 0 ? parent.width * (jobRow.pct / 100.0) : parent.width * 0.15
        height: parent.height
        radius: height / 2
        color: jobRow.isPaused ? root.dim : Color.accent
      }
    }
  }
}
