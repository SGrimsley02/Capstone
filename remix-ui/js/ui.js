const el = (id) => document.getElementById(id);

export function getElements() {
  const viewAuth = el("viewAuth");
  const viewSetup = el("viewSetup");
  const viewPrefs = el("viewPrefs");

  const podNews = el("pod_news");
  const podWeather = el("pod_weather");
  const podSchedule = el("pod_schedule");
  const podHoroscope = el("pod_horoscope");

  const newsSourceInputs = {
    "NY Times": el("news_nytimes"),
    "BBC News": el("news_bbc"),
    "The Guardian": el("news_guardian"),
    "Al Jazeera": el("news_aljazeera"),
    "TechRadar": el("news_techradar"),
    "Time Magazine": el("news_time"),
    "Yahoo Sports": el("news_yahoo"),
    "Not Boring": el("news_notboring")
  };

  return {
    viewAuth,
    viewSetup,
    viewPrefs,
    languageSelect: el("languageSelect"),
    pillState: el("pillState"),
    tabLogin: el("tabLogin"),
    tabSignup: el("tabSignup"),
    formLogin: el("formLogin"),
    formSignup: el("formSignup"),
    authMsg: el("authMsg"),
    signupMsg: el("signupMsg"),
    btnDemoSignup: el("btnDemoSignup"),
    googleStatus: el("googleStatus"),
    spotifyStatus: el("spotifyStatus"),
    btnGoogle: el("btnGoogle"),
    btnSpotify: el("btnSpotify"),
    btnToPrefs: el("btnToPrefs"),
    btnLogout: el("btnLogout"),
    btnResetAll: el("btnResetAll"),
    prefsForm: el("prefsForm"),
    prefsMsg: el("prefsMsg"),
    btnBackToSetup: el("btnBackToSetup"),
    podNews,
    podWeather,
    podSchedule,
    podHoroscope,
    zodiacOptions: el("zodiacOptions"),
    zodiacSelect: el("zodiac"),
    newsOptions: el("newsOptions"),
    newsSourceInputs
  };
}

export function setView(elements, which) {
  elements.viewAuth.classList.toggle("hide", which !== "auth");
  elements.viewSetup.classList.toggle("hide", which !== "setup");
  elements.viewPrefs.classList.toggle("hide", which !== "prefs");
}

export function setTab(elements, which) {
  const login = which === "login";
  elements.tabLogin.classList.toggle("active", login);
  elements.tabSignup.classList.toggle("active", !login);
  elements.formLogin.classList.toggle("hide", !login);
  elements.formSignup.classList.toggle("hide", login);
  elements.authMsg.textContent = "";
  elements.signupMsg.textContent = "";
}

export function renderConnectedState(elements, currentUser, t) {
  const gOK = (currentUser.googleConnected === true) || (currentUser.googleEmail != null);
  const sOK = (currentUser.spotifyConnected === true) || (currentUser.spotifyName != null);

  elements.googleStatus.textContent = gOK ? t("setup.connected", "Connected ✅") : t("setup.notConnected", "Not connected");
  elements.googleStatus.className = gOK ? "ok" : "warn";
  elements.spotifyStatus.textContent = sOK ? t("setup.connected", "Connected ✅") : t("setup.notConnected", "Not connected");
  elements.spotifyStatus.className = sOK ? "ok" : "warn";
  return { gOK, sOK };
}
