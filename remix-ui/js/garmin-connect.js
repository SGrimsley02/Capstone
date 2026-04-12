import { connectGarmin } from "./api.js";
import { applyTranslations, initI18n, t } from "./i18n.js";
import { loadSession } from "./storage.js";

document.addEventListener("DOMContentLoaded", async () => {
  await initI18n();
  applyTranslations();

  const form = document.getElementById("formGarminConnect");
  const emailInput = document.getElementById("garminEmail");
  const passwordInput = document.getElementById("garminPassword");
  const errorEl = document.getElementById("garminConnectError");
  const btnCancel = document.getElementById("btnGarminCancel");
  const btnSubmit = document.getElementById("btnGarminSubmit");

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
      btnSubmit.disabled = true;
      clearError();
      const garminEmail = emailInput.value.trim();
      const garminPassword = passwordInput.value;
      if (!garminEmail || !garminPassword) return;

      try {
        const { ok, data } = await connectGarmin(username, garminEmail, garminPassword);
        passwordInput.value = "";
        btnSubmit.disabled = false;

        if (ok) {
          window.location.replace("./index.html?garmin=connected");
          return;
        }

        const serverMsg = data?.message || data?.error;
        const reasonTemplate = t("connect.errorWithReason", "Could not connect Garmin: {{reason}}");
        showError(
          serverMsg
            ? reasonTemplate.replace("{{reason}}", String(serverMsg))
            : t(
              "connect.errorGeneric",
              "Could not connect Garmin. Check your credentials and try again."
            )
        );
      } catch {
        passwordInput.value = "";
        showError(
          t(
            "connect.errorGeneric",
            "Could not connect Garmin. Check your credentials and try again."
          )
        );
        btnSubmit.disabled = false;
      }
    });
  }
});