import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import "Model.js" as Model

// Talks to filetransferd purely through the `ftctl` CLI, same pattern the
// Dropbox plugin uses for its status.py helper: no direct socket code in
// QML, just short-lived subprocesses whose stdout we parse as JSON. This
// keeps the shell process free of any privileged/long-lived IO of its own.
Item {
  id: root

  property var settings: ({})
  property var jobs: []
  property bool lastOk: true
  property string lastError: ""
  property bool refreshing: false

  readonly property int pollIntervalSec: intSetting("pollIntervalSec", 2, 1, 30)
  readonly property bool busy: controlProcess.running
  readonly property int activeCount: Model.activeCount(jobs)
  readonly property bool hasFinished: Model.hasFinished(jobs)

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  function intSetting(name, fallback, min, max) {
    var n = parseInt(String(setting(name, fallback)), 10)
    if (!isFinite(n)) n = fallback
    if (n < min) n = min
    if (n > max) n = max
    return n
  }

  function refresh() {
    if (listProcess.running) return
    refreshing = true
    listProcess.command = ["ftctl", "list"]
    listProcess.running = true
  }

  function pause(id) { runControl(["ftctl", "pause", id]) }
  function resume(id) { runControl(["ftctl", "resume", id]) }
  function cancel(id) { runControl(["ftctl", "cancel", id]) }
  function reorder(id, position) { runControl(["ftctl", "reorder", id, String(position)]) }
  function clearFinished() { runControl(["ftctl", "clear"]) }

  function runControl(command) {
    if (controlProcess.running) return
    controlProcess.command = command
    controlProcess.running = true
  }

  Timer {
    id: pollTimer
    interval: root.pollIntervalSec * 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Process {
    id: listProcess
    running: false
    command: []
    stdout: StdioCollector { id: listStdout; waitForEnd: true }
    stderr: StdioCollector { id: listStderr; waitForEnd: true }
    onExited: function(exitCode) {
      root.refreshing = false
      var parsed = Model.parseListOutput(listStdout.text || "")
      root.lastOk = parsed.ok
      root.jobs = parsed.jobs
      root.lastError = parsed.ok ? "" : (parsed.error || String(listStderr.text || "").trim() || "Could not reach the transfer daemon")
    }
  }

  Process {
    id: controlProcess
    running: false
    command: []
    stdout: StdioCollector { id: controlStdout; waitForEnd: true }
    stderr: StdioCollector { id: controlStderr; waitForEnd: true }
    onExited: function(exitCode) {
      if (exitCode !== 0) root.lastError = String(controlStderr.text || controlStdout.text || "Action failed").trim()
      root.refresh()
    }
  }
}
