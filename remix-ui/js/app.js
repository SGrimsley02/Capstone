/**
  * app.js - Main application logic for the Remix dashboard
  * This file initializes the application, manages global state, and coordinates
  * interactions between the UI, authentication, and preferences modules.
  * Authors: Kiara Rose
  * Created: March 24, 2026
  * Last updated: April 22, 2026
*/

import { API_BASE, FRONTEND_BASE } from "./config.js";
import { clearSession, loadSession } from "./storage.js";
import { getCurrentUser, updateLanguage, deleteAccount } from "./api.js";
import { bindAuthHandlers } from "./auth.js";
import { bindPreferencesHandlers, bindPreferenceToggles } from "./prefs.js";
import { applyTranslations, getLanguage, initI18n, setLanguage, t } from "./i18n.js";
import {
  getElements,
  renderConnectedState,
  setTab as setTabUI,
  setView as setViewUI,
  toggleAccountMenu
} from "./ui.js";

const elements = getElements();
const state = {
  currentUser: null
};

let accountMenuBound = false;

function bindAccountMenuHandlers() {
  if (accountMenuBound) return;
  accountMenuBound = true;

  elements.btnAccountMenu?.addEventListener("click", (e) => {
    e.stopPropagation();
    toggleAccountMenu(elements);
  });

  document.addEventListener("click", () => {
    elements.accountDropdown?.classList.add("hide");
    elements.btnAccountMenu?.setAttribute("aria-expanded", "false");
  });
}

function setView(which) {
  setViewUI(elements, which);
}

function setTab(which) {
  setTabUI(elements, which);
}

async function render() {
  const session = loadSession();
  const signedIn = !!session.username;
  
  // Show/Hide the whole dropdown trigger based on login status
  elements.btnAccountMenu?.classList.toggle("hide", !signedIn);

  // Ensure dropdown is closed on re-render
  elements.accountDropdown?.classList.add("hide");
  elements.btnAccountMenu?.setAttribute("aria-expanded", "false");

  elements.pillState.textContent = signedIn
    ? t("header.signedIn", "Signed in: {{username}}").replace("{{username}}", session.username)
    : t("header.signedOut", "Signed out");

  if (!signedIn) {
    state.currentUser = null;
    setView("auth");
    elements.googleStatus.textContent = t("setup.notConnected", "Not connected");
    elements.spotifyStatus.textContent = t("setup.notConnected", "Not connected");
    elements.garminStatus.textContent = t("setup.notConnected", "Not connected");
    elements.googleStatus.className = "warn";
    elements.spotifyStatus.className = "warn";
    elements.garminStatus.className = "warn";
    return;
  }

  state.currentUser = await getCurrentUser(session.username);

  if (!state.currentUser) {
    setView("setup");
    elements.authMsg.textContent = t(
      "auth.profileLoadFailed",
      "Signed in, but couldn't load profile from API. Refresh in a second."
    );
    return;
  }

  console.log("User data from backend:", state.currentUser);
  console.log("Language field in user object:", state.currentUser.language);
  console.log("Current UI language:", getLanguage());

  if (state.currentUser.language && state.currentUser.language !== getLanguage()) {
    console.log(`Restoring user language from backend: ${state.currentUser.language}`);
    await setLanguage(state.currentUser.language);
    elements.languageSelect.value = state.currentUser.language;
    applyTranslations();
    document.title = t("meta.title", document.title);
  } else {
    console.log("Language not restored - either missing from backend or matches current language");
  }

  const { gOK, sOK } = renderConnectedState(elements, state.currentUser, t);
  elements.btnToPrefs.disabled = !(gOK && sOK);

  if (!elements.viewSetup.classList.contains("hide") || !elements.viewPrefs.classList.contains("hide")) return;

  setView("setup");
}

bindPreferenceToggles(elements);
bindAuthHandlers({ elements, render, setView, setTab, t });
bindPreferencesHandlers({ elements, state, render, setView, t });

elements.btnGoogle.addEventListener("click", () => {
  const userID = state.currentUser.username;
  window.location.href = `${API_BASE}/auth/google/login?username=${encodeURIComponent(userID)}&returnTo=${encodeURIComponent(FRONTEND_BASE)}`;
});

elements.btnSpotify.addEventListener("click", () => {
  const userID = state.currentUser.username;
  window.location.href = `${API_BASE}/auth/spotify/login?username=${encodeURIComponent(userID)}&returnTo=${encodeURIComponent(FRONTEND_BASE)}`;
});

elements.btnGarmin.addEventListener("click", () => {
  if (!state.currentUser?.username) return;
  window.location.href = "./garmin-connect.html";
});

elements.btnLogout.addEventListener("click", () => {
  clearSession();
  setView("auth");
  render();
});

elements.btnResetAll.addEventListener("click", () => {
  clearSession();
  setView("auth");
  setTab("login");
});

async function handleDeleteAccount() {
  const session = loadSession();
  const sessionId = session.sessionId;

  if (!sessionId) {
    alert("You must be logged in with a valid session to delete your account.");
    return;
  }

  const confirmed = window.confirm(
    "Are you sure you want to delete your account? This will permanently remove your REMix account and saved data."
  );

  if (!confirmed) {
    return;
  }

  try {
    const { ok, data } = await deleteAccount(sessionId);

    if (!ok) {
      const message = data?.message || "Failed to delete account.";
      alert(message);
      return;
    }

    clearSession();
    state.currentUser = null;
    setView("auth");
    setTab("login");
    elements.authMsg.textContent = "Account deleted successfully.";
    await render();
  } catch (error) {
    console.error("Error deleting account:", error);
    alert("Error deleting account.");
  }
}

elements.btnDeleteAccountHeader?.addEventListener("click", handleDeleteAccount);

const params = new URLSearchParams(window.location.search);
if (
  params.get("spotify") === "connected" ||
  params.get("google") === "connected" ||
  params.get("garmin") === "connected"
) {
  window.history.replaceState({}, document.title, window.location.pathname);
}

async function bootstrap() {
  await initI18n();
  applyTranslations();
  document.title = t("meta.title", document.title);

  elements.languageSelect.value = getLanguage();

  bindAccountMenuHandlers();

  elements.languageSelect.addEventListener("change", async (e) => {
    const newLanguage = e.target.value;

    await setLanguage(newLanguage);
    applyTranslations();
    document.title = t("meta.title", document.title);

    const session = loadSession();
    if (session.username) {
      try {
        const response = await updateLanguage(session.username, newLanguage);
        if (!response.ok) {
          console.error("Failed to save language preference to backend:", response.data);
        } else {
          console.log(`Language preference saved to backend: ${newLanguage}`);
          if (state.currentUser) {
            state.currentUser.language = newLanguage;
          }
        }
      } catch (error) {
        console.error("Error saving language preference:", error);
      }
    }
  });

  setTab("login");
  await render();
}

bootstrap();