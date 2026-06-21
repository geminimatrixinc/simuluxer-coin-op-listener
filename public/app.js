const scanner = {
  buffer: "",
  startedAt: 0,
  lastAt: 0,
  resetDelayMs: 120,
  minPayloadLength: 8,
  strictTiming: true
};

const form = document.getElementById("arcadeForm");
const fields = {
  name: document.getElementById("name"),
  email: document.getElementById("email"),
  phone: document.getElementById("phone")
};
const statusNode = document.getElementById("status");
const sessionOutput = document.getElementById("sessionOutput");
const startRacingBtn = document.getElementById("startRacingBtn");
const testPayloadNode = document.getElementById("testPayload");
const simulateScanBtn = document.getElementById("simulateScanBtn");
const strictTimingToggle = document.getElementById("strictTiming");
const diagnosticsEnabledToggle = document.getElementById("diagnosticsEnabled");
const clearDiagBtn = document.getElementById("clearDiagBtn");
const diagOutput = document.getElementById("diagOutput");
const diagBufferLength = document.getElementById("diagBufferLength");
const diagDuration = document.getElementById("diagDuration");
const diagSpeed = document.getElementById("diagSpeed");
const diagClass = document.getElementById("diagClass");

const diagnostics = {
  enabled: true,
  lines: []
};

let activeSessionId = null;

function setStatus(message, mode = "ready") {
  statusNode.textContent = message;
  statusNode.className = `status ${mode}`;
}

function appendDiagLine(message) {
  if (!diagnostics.enabled || !diagOutput) {
    return;
  }

  const stamp = new Date().toLocaleTimeString();
  diagnostics.lines.unshift(`[${stamp}] ${message}`);
  diagnostics.lines = diagnostics.lines.slice(0, 12);
  diagOutput.textContent = diagnostics.lines.join("\n");
}

function updateDiagnostics(rawData, durationMs, classification) {
  if (diagBufferLength) {
    diagBufferLength.textContent = String(rawData ? rawData.length : 0);
  }

  if (diagDuration) {
    diagDuration.textContent = String(Math.max(0, Math.round(durationMs || 0)));
  }

  const cps = durationMs > 0 ? (rawData.length / (durationMs / 1000)) : rawData.length;
  if (diagSpeed) {
    diagSpeed.textContent = Number.isFinite(cps) ? cps.toFixed(1) : "0";
  }

  if (diagClass) {
    diagClass.textContent = classification;
  }
}

function fillForm(userData) {
  fields.name.value = userData.name || "";
  fields.email.value = userData.email || "";
  fields.phone.value = userData.phone || "";
}

function clearForm() {
  fields.name.value = "";
  fields.email.value = "";
  fields.phone.value = "";
}

function parseScannerPayload(text) {
  const cleaned = text.trim();
  let parsed;

  try {
    parsed = JSON.parse(cleaned);
  } catch (_err) {
    // Allow single-quoted JSON-like payloads for easier local testing.
    parsed = JSON.parse(cleaned.replace(/'/g, '"'));
  }

  const requiredKeys = ["name", "email", "phone"];

  for (const key of requiredKeys) {
    if (typeof parsed[key] !== "string" || !parsed[key].trim()) {
      throw new Error(`Invalid or missing field: ${key}`);
    }
  }

  return {
    name: parsed.name.trim(),
    email: parsed.email.trim(),
    phone: parsed.phone.trim()
  };
}

async function startSession(payload) {
  setStatus("Payload accepted. Starting session...", "loading");

  const response = await fetch("/api/session/start", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  });

  const result = await response.json();

  if (!response.ok || !result.ok) {
    throw new Error(result.error || "Unable to start session");
  }

  setStatus(`Session live for ${result.session.name}`, "ready");

  activeSessionId = result.session.id;
  if (startRacingBtn) {
    startRacingBtn.hidden = false;
    startRacingBtn.disabled = false;
    startRacingBtn.textContent = "START RACING NOW";
  }
  sessionOutput.hidden = false;
  sessionOutput.textContent = JSON.stringify(result, null, 2);
}

function looksLikeScannerInput(rawData, durationMs) {
  if (!rawData) {
    return false;
  }

  if (durationMs <= 0) {
    return true;
  }

  const charsPerSecond = rawData.length / (durationMs / 1000);
  return charsPerSecond >= 35;
}

function processBuffer(rawData, metadata = {}) {
  const durationMs = metadata.durationMs || 0;
  const scannerLike = looksLikeScannerInput(rawData, durationMs);
  const classification = scannerLike ? "scanner-like" : "human-like";

  updateDiagnostics(rawData || "", durationMs, classification);
  appendDiagLine(`Scan end len=${rawData.length} duration=${Math.round(durationMs)}ms class=${classification}`);

  if (!rawData || rawData.length < scanner.minPayloadLength) {
    appendDiagLine("Rejected: payload too short.");
    setStatus("Scan ignored. Waiting for valid payload...", "error");
    return;
  }

  if (scanner.strictTiming && !scannerLike) {
    appendDiagLine("Rejected: strict timing enabled and input too slow.");
    setStatus("Input too slow for scanner mode. Use Simulate Scan or disable strict timing.", "error");
    return;
  }

  try {
    const payload = parseScannerPayload(rawData);
    appendDiagLine("Payload parsed successfully. Starting session...");
    fillForm(payload);
    startSession(payload).catch((err) => {
      appendDiagLine(`Session API error: ${err.message}`);
      setStatus(err.message, "error");
    });
  } catch (err) {
    appendDiagLine(`Rejected: invalid payload format (${err.message}).`);
    clearForm();
    setStatus(`Invalid QR payload: ${err.message}`, "error");
  }
}

window.addEventListener("keydown", (event) => {
  const now = Date.now();
  if (now - scanner.lastAt > scanner.resetDelayMs) {
    scanner.buffer = "";
    scanner.startedAt = now;
    appendDiagLine("Buffer reset due to idle gap.");
  }

  if (!scanner.startedAt) {
    scanner.startedAt = now;
  }

  scanner.lastAt = now;

  if (event.key === "Enter") {
    event.preventDefault();
    processBuffer(scanner.buffer, { durationMs: now - scanner.startedAt });
    scanner.buffer = "";
    scanner.startedAt = 0;
    updateDiagnostics("", 0, "idle");
    return;
  }

  if (event.key.length === 1) {
    scanner.buffer += event.key;
    updateDiagnostics(scanner.buffer, now - scanner.startedAt, "collecting");
  }
});

form.addEventListener("submit", (event) => {
  event.preventDefault();
  const payload = {
    name: fields.name.value,
    email: fields.email.value,
    phone: fields.phone.value
  };

  startSession(payload).catch((err) => {
    setStatus(err.message, "error");
  });
});

if (strictTimingToggle) {
  strictTimingToggle.addEventListener("change", (event) => {
    scanner.strictTiming = Boolean(event.target.checked);
    appendDiagLine(`Strict timing ${scanner.strictTiming ? "enabled" : "disabled"}.`);
  });
}

if (simulateScanBtn && testPayloadNode) {
  simulateScanBtn.addEventListener("click", () => {
    appendDiagLine("Simulated scan triggered from test panel.");
    processBuffer(testPayloadNode.value, { durationMs: 0 });
  });
}

if (diagnosticsEnabledToggle) {
  diagnosticsEnabledToggle.addEventListener("change", (event) => {
    diagnostics.enabled = Boolean(event.target.checked);
    if (!diagnostics.enabled && diagOutput) {
      diagOutput.textContent = "Diagnostics disabled.";
    }
    if (diagnostics.enabled) {
      appendDiagLine("Diagnostics enabled.");
    }
  });
}

if (clearDiagBtn) {
  clearDiagBtn.addEventListener("click", () => {
    diagnostics.lines = [];
    if (diagOutput) {
      diagOutput.textContent = "Diagnostics cleared.";
    }
    updateDiagnostics("", 0, "idle");
  });
}

if (startRacingBtn) {
  startRacingBtn.addEventListener("click", async () => {
    startRacingBtn.disabled = true;
    startRacingBtn.textContent = "LAUNCHING...";
    setStatus("Launching iRacing...", "loading");
    appendDiagLine("Start Racing clicked. Triggering launcher script.");

    try {
      const response = await fetch("/api/game/start", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({ sessionId: activeSessionId })
      });
      const result = await response.json();
      if (!response.ok || !result.ok) {
        throw new Error(result.error || "Launcher failed");
      }
      setStatus("Race launched. Have fun!", "ready");
      startRacingBtn.textContent = "RACE STARTED";
      appendDiagLine("Launcher script triggered successfully.");
    } catch (err) {
      setStatus(err.message, "error");
      startRacingBtn.disabled = false;
      startRacingBtn.textContent = "START RACING NOW";
      appendDiagLine(`Launcher error: ${err.message}`);
    }
  });
}

setStatus("Ready for scanner input...", "ready");
appendDiagLine("Diagnostics ready.");
