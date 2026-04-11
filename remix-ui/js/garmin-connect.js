import { connectGarmin } from "./api.js";
import { loadSession } from "./storage.js";

const form = document.getElementById("formGarminConnect");
const emailInput = document.getElementById("garminEmail");
const passwordInput = document.getElementById("garminPassword");
const errorEl = document.getElementById("garminConnectError");
const btnCancel = document.getElementById("btnGarminCancel");

function showError(message) {
  errorEl.textContent = message;
  errorEl.hidden = !message;
}

function clearError() {
  showError("");
}

const session = loadSession();
if (!session.username) {
  window.location.replace("./index.html");
} else {
  const username = session.username;

  btnCancel.addEventListener("click", () => {
    window.location.href = "./index.html";
  });

  form.addEventListener("submit", async (e) => {
    e.preventDefault();
    clearError();
    const garminEmail = emailInput.value.trim();
    const garminPassword = passwordInput.value;
    if (!garminEmail || !garminPassword) return;

    try {
      const { ok, data } = await connectGarmin(username, garminEmail, garminPassword);
      passwordInput.value = "";

      if (ok) {
        window.location.replace("./index.html?garmin=connected");
        return;
      }

      const serverMsg = data?.message || data?.error;
      showError(
        serverMsg
          ? `Could not connect Garmin: ${String(serverMsg)}`
          : "Could not connect Garmin. Check your credentials and try again."
      );
    } catch {
      passwordInput.value = "";
      showError("Could not connect Garmin. Check your credentials and try again.");
    }
  });
}
