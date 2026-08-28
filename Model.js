function formatBytes(bytes) {
  var n = Number(bytes)
  if (!isFinite(n) || n < 0) return "--"
  var units = ["B", "KB", "MB", "GB", "TB"]
  var i = 0
  while (n >= 1024 && i < units.length - 1) { n /= 1024; i++ }
  return (i === 0 ? n.toFixed(0) : n.toFixed(1)) + " " + units[i]
}

function formatRate(bytesPerSec) {
  var n = Number(bytesPerSec)
  if (!isFinite(n) || n <= 0) return "--"
  return formatBytes(n) + "/s"
}

function formatEta(sec) {
  var n = Number(sec)
  if (!isFinite(n) || n < 0) return "--"
  var h = Math.floor(n / 3600)
  var m = Math.floor((n % 3600) / 60)
  var s = Math.floor(n % 60)
  if (h > 0) return h + "h " + m + "m"
  if (m > 0) return m + "m " + s + "s"
  return s + "s"
}

function baseName(path) {
  var parts = String(path || "").replace(/\/$/, "").split("/")
  return parts.pop() || String(path || "")
}

function jobTitle(job) {
  if (!job || !job.sources || job.sources.length === 0) return "Transfer"
  var first = baseName(job.sources[0])
  var extra = job.sources.length - 1
  return extra > 0 ? (first + " + " + extra + " more") : first
}

function jobDestName(job) {
  if (!job || !job.dest) return ""
  return baseName(job.dest)
}

function statusLabel(job) {
  if (!job) return ""
  switch (job.state) {
    case "queued": return "Queued"
    case "running": return "Transferring"
    case "paused": return "Paused"
    case "done": return "Done"
    case "error": return "Failed"
    case "cancelled": return "Cancelled"
    default: return job.state || ""
  }
}

function percentFor(job) {
  if (!job || !job.bytesTotal || job.bytesTotal <= 0) return -1
  return Math.max(0, Math.min(100, Math.round((job.bytesDone / job.bytesTotal) * 100)))
}

function activeCount(jobs) {
  var n = 0
  for (var i = 0; i < jobs.length; i++) {
    var s = jobs[i].state
    if (s === "running" || s === "queued" || s === "paused") n++
  }
  return n
}

function hasFinished(jobs) {
  for (var i = 0; i < jobs.length; i++) {
    var s = jobs[i].state
    if (s === "done" || s === "error" || s === "cancelled") return true
  }
  return false
}

function firstByState(jobs, state) {
  for (var i = 0; i < jobs.length; i++) {
    if (jobs[i].state === state) return jobs[i]
  }
  return null
}

function parseListOutput(raw) {
  try {
    var parsed = JSON.parse(raw)
    if (!parsed || typeof parsed !== "object") return { ok: false, jobs: [], error: "bad response" }
    return { ok: parsed.ok === true, jobs: Array.isArray(parsed.jobs) ? parsed.jobs : [], error: parsed.error || "" }
  } catch (e) {
    return { ok: false, jobs: [], error: "bad response" }
  }
}
