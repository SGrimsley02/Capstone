/**
  * auth.js - Authentication helper functions for the Remix dashboard
  * This file contains functions to handle user authentication, including
  * binding event handlers for the login and signup forms and managing session data.
  * Authors: Kiara Rose
  * Created: March 24, 2026
  * Last updated: March 25, 2026
*/

import { loginUser, signupUser } from "./api.js";
import { saveSession } from "./storage.js";

export function bindAuthHandlers({ elements, render, setView, setTab, t }) {
  /**
   * Bind event handlers for the authentication forms, including switching between
   * login and signup tabs, handling form submissions, and managing session data.
   * In charge of user authentication and session management.
   */
  elements.tabLogin.addEventListener("click", () => setTab("login"));
  elements.tabSignup.addEventListener("click", () => setTab("signup"));

  elements.formSignup.addEventListener("submit", async (e) => { // Handle user registration
    e.preventDefault();
    const username = elements.formSignup.signupUser.value.trim();
    const password = elements.formSignup.signupPass.value;

    if (!username || !password) return;

    try {
      const { ok, data } = await signupUser(username, password);

      if (ok) {
        elements.signupMsg.textContent = t("auth.accountCreated", "Account created ✓");
        setTab("login");
        elements.formSignup.reset();
      } else {
        elements.signupMsg.textContent = data.message || t("auth.registrationFailed", "Registration failed");
      }
    } catch (e2) {
      elements.signupMsg.textContent = t("auth.errorPrefix", "Error: ") + e2.message;
    }
  });

  elements.formLogin.addEventListener("submit", async (e) => { // Handle user login
    e.preventDefault();
    const username = elements.formLogin.loginUser.value.trim();
    const password = elements.formLogin.loginPass.value;

    try {
      const { ok, data } = await loginUser(username, password);

      if (ok) {
        elements.authMsg.textContent = t("auth.loggedIn", "Logged in ✓");
        elements.formLogin.reset();
        saveSession({ username });
        const sessionId = new URLSearchParams(window.location.search).get("sessionId");
        if (sessionId != null) {
          await fetch('https://kyajhve0ek.execute-api.us-east-2.amazonaws.com/dev/session/store', {
              method: 'PUT',
              headers: { "Content-Type": "application/json" },
              body: JSON.stringify({sessionId: sessionId, username: username })
          });
        }
        await render();
        setView("setup");
      } else {
        elements.authMsg.textContent = data.message || t("auth.loginFailed", "Login failed");
      }
    } catch (e2) {
      elements.authMsg.textContent = t("auth.errorPrefix", "Error: ") + e2.message;
    }
  });

  elements.btnDemoSignup.addEventListener("click", async () => { // Handle demo account signup/login
    try {
      const { ok } = await signupUser("demo", "demo123");

      if (ok) {
        await loginUser("demo", "demo123");
      }

      saveSession({ username: "demo" });
      await render();
      setView("setup");
    } catch (e2) {
      elements.signupMsg.textContent = t("auth.errorPrefix", "Error: ") + e2.message;
    }
  });
}
