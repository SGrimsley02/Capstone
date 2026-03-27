/**
  * prefs.js - User preferences management for the Remix dashboard
  * This file contains functions to handle user preferences, including
  * binding event handlers for the preferences form and saving preferences
  * to the backend API.
  * Authors: Kiara Rose, Audrey Pan
  * Created: March 24, 2026
  * Last updated: March 26, 2026
*/

import { DEFAULT_NEWS_SOURCES } from "./config.js";
import { updatePreferences } from "./api.js";
import { loadSession } from "./storage.js";

export function bindPreferenceToggles(elements) {
  /**
   * Bind change event listeners to the podcast option checkboxes to show/hide
   * related settings when toggled.
   * In charge of showing/hiding dynamic content options.
   */
  elements.podHoroscope.addEventListener("change", () => {
    elements.zodiacOptions.classList.toggle("hide", !elements.podHoroscope.checked);
  });

  elements.podNews.addEventListener("change", () => {
    elements.newsOptions.classList.toggle("hide", !elements.podNews.checked);
  });

  elements.podWeather.addEventListener("change", () => {
    elements.weatherLocationOptions.classList.toggle("hide", !elements.podWeather.checked);
  });
}

export function bindPreferencesHandlers({ elements, state, render, setView, t }) {
  /**
   * Bind event handlers for the preferences form, including loading existing
   * preferences when entering the view and saving changes to the backend.
   * In charge of loading/saving user preferences and managing the preferences form.
   */
  elements.btnToPrefs.addEventListener("click", () => {
    setView("prefs");
    elements.prefsMsg.textContent = "";

    if (state.currentUser?.preferences) {
      elements.prefsForm.wakeStart.value = state.currentUser.preferences.wakeStart || "07:00";
      elements.prefsForm.wakeEnd.value = state.currentUser.preferences.wakeEnd || "07:30";
      elements.prefsForm.tone.value = state.currentUser.preferences.tone || "tone1";
      elements.prefsForm.explicit.value = state.currentUser.preferences.explicit || "filter";
      elements.prefsForm.city.value = state.currentUser.preferences.location?.city || "Lawrence";
      elements.prefsForm.state.value = state.currentUser.preferences.location?.state || "Kansas";
      elements.prefsForm.country.value = state.currentUser.preferences.location?.country || "US";
    }

    const podcast = state.currentUser?.preferences?.podcast || {
      news: true,
      weather: true,
      schedule: true,
      horoscope: false
    };

    elements.podNews.checked = !!podcast.news;
    elements.newsOptions.classList.toggle("hide", !elements.podNews.checked);
    elements.podWeather.checked = !!podcast.weather;
    elements.podSchedule.checked = !!podcast.schedule;
    elements.podHoroscope.checked = !!podcast.horoscope;

    elements.weatherLocationOptions.classList.toggle("hide", !elements.podWeather.checked);
    elements.zodiacOptions.classList.toggle("hide", !elements.podHoroscope.checked);

    if (state.currentUser?.preferences?.podcast?.zodiac) {
      elements.zodiacSelect.value = state.currentUser.preferences.podcast.zodiac;
    }

    const savedSources = state.currentUser?.preferences?.news?.sources;
    const effectiveSources = savedSources == null ? DEFAULT_NEWS_SOURCES : savedSources;

    Object.entries(elements.newsSourceInputs).forEach(([sourceName, checkbox]) => {
      checkbox.checked = effectiveSources.includes(sourceName);
    });
  });

  elements.prefsForm.addEventListener("submit", async (e) => {
    e.preventDefault();

    try {
      const selectedNewsSources = Object.entries(elements.newsSourceInputs)
        .filter(([, checkbox]) => checkbox.checked)
        .map(([sourceName]) => sourceName);

      if (elements.podNews.checked && selectedNewsSources.length === 0) {
        elements.prefsMsg.textContent = t("prefs.selectNewsRequired", "Please select at least one news source.");
        return;
      }

      //LOCATION VALIDATION
      const city = elements.prefsForm.city.value.trim();
      const stateValue = elements.prefsForm.state.value.trim();
      const country = elements.prefsForm.country.value.trim();

      if (elements.podWeather.checked) {
        if (!city || !country) {
          elements.prefsMsg.textContent = t(
            "prefs.locationRequired",
            "Please enter your city and country to enable weather."
          );
          return;
        }

        if (country === "US" && !stateValue) {
          elements.prefsMsg.textContent = t(
            "prefs.stateRequired",
            "Please select your state to enable weather in the U.S."
          );
          return;
        }
      }

      const prefs = {
        wakeStart: elements.prefsForm.wakeStart.value,
        wakeEnd: elements.prefsForm.wakeEnd.value,
        tone: elements.prefsForm.tone.value,
        explicit: elements.prefsForm.explicit.value,
        podcast: {
          news: elements.podNews.checked,
          weather: elements.podWeather.checked,
          schedule: elements.podSchedule.checked,
          horoscope: elements.podHoroscope.checked,
          zodiac: elements.podHoroscope.checked ? elements.zodiacSelect.value : null
        },
        news: {
          sources: selectedNewsSources
        },
        location: {
          city,
          state: stateValue || null,
          country
        }
      };

      const userID = state.currentUser?.username || loadSession().username;
      if (!userID) {
        elements.prefsMsg.textContent = t("auth.sessionExpired", "Session expired. Please log in again.");
        return;
      }

      const { ok, data } = await updatePreferences(userID, prefs);

      if (ok) {
        elements.prefsMsg.textContent = t("prefs.saved", "Saved ✓");
        await render();
      } else {
        elements.prefsMsg.textContent = data.message || t("prefs.saveFailed", "Save failed");
      }
    } catch (e2) {
      elements.prefsMsg.textContent = t("auth.errorPrefix", "Error: ") + e2.message;
    }
  });

  elements.btnBackToSetup.addEventListener("click", () => {
    setView("setup");
    elements.prefsMsg.textContent = "";
    render();
  });
}
