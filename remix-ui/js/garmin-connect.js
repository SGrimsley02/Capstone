import { connectGarmin } from "./api.js";
import { applyTranslations, initI18n, t } from "./i18n.js";
import { loadSession } from "./storage.js";

document.addEventListener("DOMContentLoaded", async () => {
  await initI18n();
  applyTranslations();

  const form = document.getElementById("formGarminConnect");
  const emailInput = document.getElementById("garminEmail");
  const passwordInput = document.getElementById("garminPassword");
  const mfaInput = document.getElementById("garminMfaCode");
  const mfaBlock = document.getElementById("mfaBlock");
  const errorEl = document.getElementById("garminConnectError");
  const btnCancel = document.getElementById("btnGarminCancel");
  const btnSubmit = document.getElementById("btnGarminSubmit");
  let awaitingMfa = false;

  function showError(message) {
    errorEl.textContent = message;
    errorEl.hidden = !message;
  }

  function clearError() {
    showError("");
  }

  function enterMfaMode(message) {
    awaitingMfa = true;
    if (mfaBlock) {
      mfaBlock.hidden = false;
      mfaBlock.removeAttribute("hidden");
      mfaBlock.style.display = "block";
    }
    if (mfaInput) {
      mfaInput.required = true;
      mfaInput.focus();
    }
    btnSubmit.textContent = t("connect.verifyAndConnect", "Verify and connect");
    showError(message || t("connect.mfaRequired", "Enter your verification code to continue."));
  }

  function isMfaChallenge(status, data) {
    if (Number(status) === 202) return true;
    return Boolean(
      data?.mfa_required === true
    );
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
      const mfaCode = mfaInput.value.trim();
      if (!garminEmail || !garminPassword || (awaitingMfa && !mfaCode)) {
        if (awaitingMfa && !mfaCode) {
          showError(t("connect.mfaRequired", "Enter your verification code to continue."));
        }
        btnSubmit.disabled = false;
        return;
      }

      try {
        console.log("MFA:", mfaCode);
        const { ok, status, data } = await connectGarmin(username, garminEmail, garminPassword, mfaCode);
        btnSubmit.disabled = false;

        if (isMfaChallenge(status, data)) {
          enterMfaMode(data?.message ? String(data.message) : "");
          return;
        }

        else if (ok && status === 200) {
          window.location.replace("./index.html?garmin=connected");
          return;
        }

        if (awaitingMfa) {
          mfaInput.select();
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
        if (awaitingMfa) {
          mfaInput.select();
        }
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