/**
  * app.js - Main application logic for the Remix dashboard
  * This file initializes the application, manages global state, and coordinates
  * interactions between the UI, authentication, and preferences modules.
  * Authors: Kiara Rose
  * Created: March 24, 2026
  * Last updated: March 25, 2026
*/

import { API_BASE, FRONTEND_BASE } from "./config.js";
import { clearSession, loadSession } from "./storage.js";
import { getCurrentUser } from "./api.js";
import { bindAuthHandlers } from "./auth.js";
import { bindPreferencesHandlers, bindPreferenceToggles } from "./prefs.js";
import { applyTranslations, getLanguage, initI18n, setLanguage, t } from "./i18n.js";
import {
  getElements,
  renderConnectedState,
  setTab as setTabUI,
  setView as setViewUI
} from "./ui.js";

const elements = getElements();
const state = {
  currentUser: null
};

function setView(which) {
  setViewUI(elements, which);
}

function setTab(which) {
  setTabUI(elements, which);
}

async function render() { // Main render function to initialize the app state and UI based on authentication status
  const session = loadSession();
  const signedIn = !!session.username;

  elements.pillState.textContent = signedIn
    ? t("header.signedIn", "Signed in: {{username}}").replace("{{username}}", loadSession().username)
    : t("header.signedOut", "Signed out");

  if (!signedIn) {
    setView("auth");
    elements.googleStatus.textContent = t("setup.notConnected", "Not connected");
    elements.spotifyStatus.textContent = t("setup.notConnected", "Not connected");
    elements.googleStatus.className = "warn";
    elements.spotifyStatus.className = "warn";
    return;
  }

  state.currentUser = await getCurrentUser(session.username);

  if (!state.currentUser) {
    setView("setup");
    elements.authMsg.textContent = t(
      "auth.profileLoadFailed",
      "Signed in, but couldn’t load profile from API. Refresh in a second."
    );
    return;
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

const params = new URLSearchParams(window.location.search);
if (params.get("spotify") === "connected" || params.get("google") === "connected") {
  window.history.replaceState({}, document.title, window.location.pathname);
}

async function bootstrap() {
  await initI18n();
  applyTranslations();
  document.title = t("meta.title", document.title);

  elements.languageSelect.value = getLanguage();
  elements.languageSelect.addEventListener("change", async (e) => {
    await setLanguage(e.target.value);
    applyTranslations();
    document.title = t("meta.title", document.title);
    await render();
  });

  setTab("login");
  await render();
}

bootstrap();
