import { API_BASE } from "./config.js";

async function parseResponse(res) {
  const data = await res.json().catch(() => ({}));
  return { ok: res.ok, data };
}

export async function getCurrentUser(username) {
  if (!username) return null;

  try {
    const res = await fetch(`${API_BASE}/user?username=${encodeURIComponent(username)}`);
    if (res.ok) return res.json();
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

export async function updatePreferences(username, prefs) {
  const res = await fetch(`${API_BASE}/preferences?username=${encodeURIComponent(username)}`, {
    method: "PUT",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(prefs)
  });

  return parseResponse(res);
}
