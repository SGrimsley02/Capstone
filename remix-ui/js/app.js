import { API_BASE, FRONTEND_BASE } from "./config.js";
import { clearSession, loadSession } from "./storage.js";
import { getCurrentUser } from "./api.js";
import { bindAuthHandlers } from "./auth.js";
import { bindPreferencesHandlers, bindPreferenceToggles } from "./prefs.js";
import {
  getElements,
  renderConnectedState,
  renderSignedOutDebug,
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

async function render() {
  const session = loadSession();
  const signedIn = !!session.username;

  elements.pillState.textContent = signedIn ? `Signed in: ${loadSession().username}` : "Signed out";

  if (!signedIn) {
    setView("auth");
    renderSignedOutDebug(elements);
    return;
  }

  state.currentUser = await getCurrentUser(session.username);

  if (!state.currentUser) {
    setView("setup");
    elements.authMsg.textContent = "Signed in, but couldn’t load profile from API. Refresh in a second.";
    return;
  }

  const { gOK, sOK } = renderConnectedState(elements, state.currentUser);
  elements.btnToPrefs.disabled = !(gOK && sOK);

  if (!elements.viewSetup.classList.contains("hide") || !elements.viewPrefs.classList.contains("hide")) return;

  setView("setup");
}

bindPreferenceToggles(elements);
bindAuthHandlers({ elements, render, setView, setTab });
bindPreferencesHandlers({ elements, state, render, setView });

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

setTab("login");
render();
