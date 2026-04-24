/**
  * api.js - API helper functions for the Remix dashboard
  * This file contains functions to interact with the backend API.
  * Authors: Kiara Rose, Audrey Pan
  * Created: March 24, 2026
  * Last updated: April 21, 2026
*/

import { API_BASE } from "./config.js";

async function parseResponse(res) {
  const data = await res.json().catch(() => ({}));
  return { ok: res.ok, status: res.status, data };
}

export async function getCurrentUser(username) {
  if (!username) return null;

  try {
    const res = await fetch(`${API_BASE}/user?username=${encodeURIComponent(username)}`);
    if (res.ok) {
      const userData = await res.json();
      console.log("Raw API response from /user endpoint:", userData);
      return userData;
    }
  } catch (e) {
    console.error("Error fetching user data:", e);
  }

  return null;
}

export async function signupUser(username, password) {
  const res = await fetch(`${API_BASE}/signup`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ username, password })
  });

  return parseResponse(res);
}

export async function loginUser(username, password) {
  const res = await fetch(`${API_BASE}/login`, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ username, password })
  });

  return parseResponse(res);
}

export async function connectGarmin(remixUsername, garminEmail, garminPassword, mfaCode) {
  console.log("Connecting Garmin with:", mfaCode);
  const payload = {
    username: remixUsername,
    garminEmail,
    garminPassword,
    mfaCode
  };

  const res = await fetch(`${API_BASE}/garmin`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(payload)
  });

  return parseResponse(res);
}

export async function updatePreferences(username, prefs) {
  const res = await fetch(`${API_BASE}/preferences?username=${encodeURIComponent(username)}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(prefs)
  });

  return parseResponse(res);
}

export async function updateLanguage(username, language) {
  const res = await fetch(`${API_BASE}/language?username=${encodeURIComponent(username)}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ language })
  });

  return parseResponse(res);
}

export async function deleteAccount(sessionId) {
  const res = await fetch(`${API_BASE}/delete-account`, {
    method: "DELETE",
    headers: {
      "Content-Type": "application/json",
      "X-Session-Id": sessionId
    }
  });

  return parseResponse(res);
}