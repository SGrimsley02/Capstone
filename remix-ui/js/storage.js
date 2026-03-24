import { LS_SESSION } from "./config.js";

export function loadSession() {
  try {
    return JSON.parse(localStorage.getItem(LS_SESSION)) || {};
  } catch {
    return {};
  }
}

export function saveSession(session) {
  localStorage.setItem(LS_SESSION, JSON.stringify(session));
}

export function clearSession() {
  localStorage.removeItem(LS_SESSION);
}
