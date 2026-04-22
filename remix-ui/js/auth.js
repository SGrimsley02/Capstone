/**
  * auth.js - Authentication helper functions for the Remix dashboard
  * This file contains functions to handle user authentication, including
  * binding event handlers for the login and signup forms and managing session data.
  * Authors: Kiara Rose
  * Created: March 24, 2026
  * Last updated: April 22, 2026
*/

import { loginUser, signupUser } from "./api.js";
import { saveSession } from "./storage.js";
import { setLanguage, applyTranslations } from "./i18n.js";

export function bindAuthHandlers({ elements, render, setView, setTab, t }) {
  elements.tabLogin.addEventListener("click", () => setTab("login"));
  elements.tabSignup.addEventListener("click", () => setTab("signup"));

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

  window.addEventListener("languageChanged", () => {
    updateAuthMessage();
    updateSignupMessage();
  });

  elements.formSignup.addEventListener("submit", async (e) => {
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
          translate: () =>
            t("auth.registrationFailed", "Registration failed") +
            (t(data.translation) ? `: ${t(data.translation)}` : "")
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

  elements.formLogin.addEventListener("submit", async (e) => {
    e.preventDefault();

    const username = elements.formLogin.loginUser.value.trim();
    const password = elements.formLogin.loginPass.value;

    try {
      const { ok, data } = await loginUser(username, password);

      if (ok) {
        lastAuthError = null;
        elements.authMsg.textContent = t("auth.loggedIn", "Logged in ✓");
        elements.formLogin.reset();

        const url = new URL(window.location.href);
        const watchSessionId = url.searchParams.get("sessionId");
        const websiteSessionId = data.sessionId || null;
        const sessionId = watchSessionId || websiteSessionId;

        if (!sessionId) {
          lastAuthError = {
            type: "missingSession",
            translate: () => "Login succeeded, but no valid session was returned."
          };
          elements.authMsg.textContent = lastAuthError.translate();
          console.error("Missing sessionId in login flow:", data);
          return;
        }

        saveSession({ username, sessionId });
        console.log("Saved session to sessionStorage:", { username, sessionId });

        if (data.language) {
          console.log(`Setting language from login response: ${data.language}`);
          await setLanguage(data.language);
          applyTranslations();
          document.title = t("meta.title", document.title);
          elements.languageSelect.value = data.language;
        }

        if (watchSessionId != null) {
          await fetch("https://kyajhve0ek.execute-api.us-east-2.amazonaws.com/dev/session/store", {
            method: "PUT",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
              sessionId: watchSessionId,
              username: username
            })
          });

          url.searchParams.delete("sessionId");
          window.history.replaceState({}, document.title, url.pathname + url.search);
        }

        await render();
        setView("setup");
      } else {
        lastAuthError = {
          type: "loginFailed",
          translation: data.translation,
          translate: () =>
            t("auth.loginFailed", "Login failed") +
            (t(data.translation) ? `: ${t(data.translation)}` : "")
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
      console.error("Login exception:", e2);
    }
  });
}