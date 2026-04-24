/**
  * storage.js - Storage helper functions for the Remix dashboard
  * This file contains functions to manage session data in session storage.
  * Authors: Kiara Rose
  * Created: March 24, 2026
  * Last updated: April 21, 2026
*/

import { LS_SESSION } from "./config.js";

export function loadSession() {
  try {
    return JSON.parse(sessionStorage.getItem(LS_SESSION)) || {};
  } catch {
    return {};
  }
}

export function saveSession(session) {
  sessionStorage.setItem(LS_SESSION, JSON.stringify(session));
}

export function clearSession() {
  sessionStorage.removeItem(LS_SESSION);
}
