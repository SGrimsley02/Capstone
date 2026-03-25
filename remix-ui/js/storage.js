/**
  * storage.js - Storage helper functions for the Remix dashboard
  * This file contains functions to manage session data in local storage.
  * Authors: Kiara Rose
  * Created: March 24, 2026
  * Last updated: March 25, 2026
*/

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
