const express = require("express");
const path = require("path");
const fs = require("fs");
const { spawn } = require("child_process");

const app = express();
const PORT = process.env.PORT || 3000;

const LOG_DIR = path.join(__dirname, "logs");
const CSV_PATH = path.join(LOG_DIR, "sessions.csv");
const IRACING_SCRIPT = path.join(__dirname, "scripts", "start-iracing.bat");

if (!fs.existsSync(LOG_DIR)) {
  fs.mkdirSync(LOG_DIR, { recursive: true });
}

if (!fs.existsSync(CSV_PATH)) {
  fs.writeFileSync(CSV_PATH, "id,startedAt,name,email,phone,launched\n", "utf8");
}

function csvEscape(value) {
  const text = String(value ?? "");
  if (/[",\n]/.test(text)) {
    return `"${text.replace(/"/g, '""')}"`;
  }
  return text;
}

function appendSessionToCsv(session, launched) {
  const row = [
    session.id,
    session.startedAt,
    session.name,
    session.email,
    session.phone,
    launched ? "yes" : "no"
  ].map(csvEscape).join(",");
  fs.appendFileSync(CSV_PATH, row + "\n", "utf8");
}

app.use(express.json({ limit: "64kb" }));
app.use(express.static(path.join(__dirname, "public")));

const sessions = [];

app.post("/api/session/start", (req, res) => {
  const { name, email, phone } = req.body || {};

  if (!name || !email || !phone) {
    return res.status(400).json({
      ok: false,
      error: "Missing required fields: name, email, phone"
    });
  }

  const session = {
    id: `S-${Date.now()}-${Math.floor(Math.random() * 1000)}`,
    name: String(name).trim(),
    email: String(email).trim(),
    phone: String(phone).trim(),
    startedAt: new Date().toISOString()
  };

  sessions.push(session);

  return res.json({
    ok: true,
    message: "Session started",
    session
  });
});

app.get("/api/session/latest", (_req, res) => {
  const latest = sessions[sessions.length - 1] || null;
  res.json({ ok: true, latest, total: sessions.length });
});

app.post("/api/game/start", (req, res) => {
  const { sessionId } = req.body || {};
  const session = sessionId
    ? sessions.find((s) => s.id === sessionId)
    : sessions[sessions.length - 1];

  if (!session) {
    return res.status(404).json({ ok: false, error: "No matching session found" });
  }

  if (!fs.existsSync(IRACING_SCRIPT)) {
    appendSessionToCsv(session, false);
    return res.status(500).json({
      ok: false,
      error: `Launcher script missing: ${IRACING_SCRIPT}`
    });
  }

  const child = spawn("cmd.exe", ["/c", IRACING_SCRIPT], {
    detached: true,
    stdio: "ignore",
    windowsHide: true
  });
  child.on("error", (err) => {
    console.error("Failed to launch iRacing script:", err.message);
  });
  child.unref();

  appendSessionToCsv(session, true);

  return res.json({
    ok: true,
    message: "iRacing launcher triggered",
    session,
    csv: CSV_PATH
  });
});

app.get("*", (_req, res) => {
  res.sendFile(path.join(__dirname, "public", "index.html"));
});

app.listen(PORT, () => {
  console.log(`Coin-op kiosk running at http://localhost:${PORT}`);
});
