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
import { setLanguage, applyTranslations } from "./i18n.js";

export function bindAuthHandlers({ elements, render, setView, setTab, t }) {
  /**
   * Bind event handlers for the authentication forms, including switching between
   * login and signup tabs, handling form submissions, and managing session data.
   * In charge of user authentication and session management.
   */
  elements.tabLogin.addEventListener("click", () => setTab("login"));
  elements.tabSignup.addEventListener("click", () => setTab("signup"));

  // Store the last error state for each form to re-render on language change
  let lastAuthError = null;
  let lastSignupError = null;

  const updateAuthMessage = () => {
    if (lastAuthError) {
      elements.authMsg.textContent = lastAuthError.translate();
    }
  };

  const updateSignupMessage = () => {
    if (lastSignupError) {
      elements.signupMsg.textContent = lastSignupError.translate();
    }
  };

  // Listen for language changes and update error messages
  window.addEventListener("languageChanged", () => {
    updateAuthMessage();
    updateSignupMessage();
  });


  elements.formSignup.addEventListener("submit", async (e) => { // Handle user signup
    e.preventDefault();
    const username = elements.formSignup.signupUser.value.trim();
    const password = elements.formSignup.signupPass.value;

    if (!username || !password) return;

    try {
      const { ok, data } = await signupUser(username, password);

      if (ok) {
        lastSignupError = null;
        elements.signupMsg.textContent = t("auth.accountCreated", "Account created ✓");
        setTab("login");
        elements.formSignup.reset();
      } else {
        lastSignupError = {
          type: "registrationFailed",
          translation: data.translation,
          translate: () => t("auth.registrationFailed", "Registration failed") + (t(data.translation) ? `: ${t(data.translation)}` : "")
        };
        elements.signupMsg.textContent = lastSignupError.translate();
        console.log("Signup failed with response:", data.message);
      }
    } catch (e2) {
      lastSignupError = {
        type: "error",
        message: e2.message,
        translate: () => t("auth.errorPrefix", "Error: ") + e2.message
      };
      elements.signupMsg.textContent = lastSignupError.translate();
    }
  });

  elements.formLogin.addEventListener("submit", async (e) => { // Handle user login
    e.preventDefault();
    const username = elements.formLogin.loginUser.value.trim();
    const password = elements.formLogin.loginPass.value;

    try {
      const { ok, data } = await loginUser(username, password);

      if (ok) {
        lastAuthError = null;
        elements.authMsg.textContent = t("auth.loggedIn", "Logged in ✓");
        elements.formLogin.reset();
        saveSession({ username });

        // Apply language from login response immediately
        if (data.language) {
          console.log(`Setting language from login response: ${data.language}`);
          await setLanguage(data.language);
          applyTranslations();
          document.title = t("meta.title", document.title);

          // Update the language dropdown to reflect the loaded language
          elements.languageSelect.value = data.language;
        }

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
        lastAuthError = {
          type: "loginFailed",
          translation: data.translation,
          translate: () => t("auth.loginFailed", "Login failed") + (t(data.translation) ? `: ${t(data.translation)}` : "")
        };
        elements.authMsg.textContent = lastAuthError.translate();
        console.log("Login failed with response:", data.message);
      }
    } catch (e2) {
      lastAuthError = {
        type: "error",
        message: e2.message,
        translate: () => t("auth.errorPrefix", "Error: ") + e2.message
      };
      elements.authMsg.textContent = lastAuthError.translate();
    }
  });

  elements.btnDemoSignup.addEventListener("click", async () => { // Handle demo account signup/login
    try {
      const { ok } = await signupUser("demo", "demo123");

      if (ok) {
        const { data } = await loginUser("demo", "demo123");

        // Apply language from login response if available
        if (data && data.language) {
          console.log(`Setting language from demo login: ${data.language}`);
          await setLanguage(data.language);
          applyTranslations();
          elements.languageSelect.value = data.language;
        }
      }

      lastAuthError = null;
      lastSignupError = null;
      saveSession({ username: "demo" });
      await render();
      setView("setup");
    } catch (e2) {
      lastSignupError = {
        type: "error",
        message: e2.message,
        translate: () => t("auth.errorPrefix", "Error: ") + e2.message
      };
      elements.signupMsg.textContent = lastSignupError.translate();
    }
  });
}
