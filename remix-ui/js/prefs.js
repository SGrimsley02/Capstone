import { ALL_NEWS_SOURCES } from "./config.js";
import { updatePreferences } from "./api.js";
import { loadSession } from "./storage.js";

export function bindPreferenceToggles(elements) {
  elements.podHoroscope.addEventListener("change", () => {
    elements.zodiacOptions.classList.toggle("hide", !elements.podHoroscope.checked);
  });

  elements.podNews.addEventListener("change", () => {
    elements.newsOptions.classList.toggle("hide", !elements.podNews.checked);
  });
}

export function bindPreferencesHandlers({ elements, state, render, setView }) {
  elements.btnToPrefs.addEventListener("click", () => {
    setView("prefs");
    elements.prefsMsg.textContent = "";

    if (state.currentUser?.preferences) {
      elements.prefsForm.wakeStart.value = state.currentUser.preferences.wakeStart || "07:00";
      elements.prefsForm.wakeEnd.value = state.currentUser.preferences.wakeEnd || "07:30";
      elements.prefsForm.tone.value = state.currentUser.preferences.tone || "tone1";
      elements.prefsForm.explicit.value = state.currentUser.preferences.explicit || "filter";
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

    elements.zodiacOptions.classList.toggle("hide", !elements.podHoroscope.checked);

    if (state.currentUser?.preferences?.podcast?.zodiac) {
      elements.zodiacSelect.value = state.currentUser.preferences.podcast.zodiac;
    }

    const savedSources = state.currentUser?.preferences?.news?.sources;
    const effectiveSources = savedSources == null ? ALL_NEWS_SOURCES : savedSources;

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
        elements.prefsMsg.textContent = "Please select at least one news source.";
        return;
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
        }
      };

      const userID = state.currentUser?.username || loadSession().username;
      if (!userID) {
        elements.prefsMsg.textContent = "Session expired. Please log in again.";
        return;
      }

      const { ok, data } = await updatePreferences(userID, prefs);

      if (ok) {
        elements.prefsMsg.textContent = "Saved ✓";
        await render();
      } else {
        elements.prefsMsg.textContent = data.message || "Save failed";
      }
    } catch (e2) {
      elements.prefsMsg.textContent = "Error: " + e2.message;
    }
  });

  elements.btnBackToSetup.addEventListener("click", () => {
    setView("setup");
    elements.prefsMsg.textContent = "";
    render();
  });
}
