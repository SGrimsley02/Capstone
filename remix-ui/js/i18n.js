const LANGUAGE_KEY = "remix_language_v1";
const DEFAULT_LANGUAGE = "en";
const SUPPORTED_LANGUAGES = ["ar", "de", "en", "es", "fr", "hi", "it", "ja", "ko", "nl", "pt", "ru", "th", "vi", "wo", "zh"];

let currentLanguage = DEFAULT_LANGUAGE;
let translations = {};

function deepMerge(base, override) {
  if (override == null) return base;
  const merged = { ...base };

  Object.keys(override).forEach((key) => {
    const baseValue = base[key];
    const overrideValue = override[key];
    if (
      baseValue != null &&
      overrideValue != null &&
      typeof baseValue === "object" &&
      typeof overrideValue === "object" &&
      !Array.isArray(baseValue) &&
      !Array.isArray(overrideValue)
    ) {
      merged[key] = deepMerge(baseValue, overrideValue);
    } else {
      merged[key] = overrideValue;
    }
  });

  return merged;
}

function getNestedValue(obj, key) {
  return key.split(".").reduce((acc, part) => (acc && acc[part] != null ? acc[part] : undefined), obj);
}

async function loadLocale(language) {
  const localePath = new URL(`../locales/${language}.json`, import.meta.url);
  const res = await fetch(localePath);
  if (!res.ok) throw new Error(`Failed to load locale: ${language}`);
  return res.json();
}

async function loadUniversal() {
  const universalPath = new URL(`../locales/universal.json`, import.meta.url);
  const res = await fetch(universalPath);
  if (!res.ok) throw new Error("Failed to load universal locale");
  return res.json();
}

export async function initI18n() {
  const saved = localStorage.getItem(LANGUAGE_KEY);
  const browser = (navigator.language || DEFAULT_LANGUAGE).split("-")[0];
  const preferred = saved || browser;
  const language = SUPPORTED_LANGUAGES.includes(preferred) ? preferred : DEFAULT_LANGUAGE;

  const [universal, defaultStrings, selectedStrings] = await Promise.all([
    loadUniversal(),
    loadLocale(DEFAULT_LANGUAGE),
    language === DEFAULT_LANGUAGE ? Promise.resolve(null) : loadLocale(language)
  ]);

  const merged = deepMerge(universal, defaultStrings);
  currentLanguage = language;
  translations = selectedStrings == null ? merged : deepMerge(merged, selectedStrings);
  localStorage.setItem(LANGUAGE_KEY, currentLanguage);
  document.documentElement.lang = currentLanguage;

  return currentLanguage;
}

export async function setLanguage(language) {
  if (!SUPPORTED_LANGUAGES.includes(language)) return currentLanguage;

  const [universal, defaultStrings, selectedStrings] = await Promise.all([
    loadUniversal(),
    loadLocale(DEFAULT_LANGUAGE),
    language === DEFAULT_LANGUAGE ? Promise.resolve(null) : loadLocale(language)
  ]);

  const merged = deepMerge(universal, defaultStrings);
  currentLanguage = language;
  translations = selectedStrings == null ? merged : deepMerge(merged, selectedStrings);
  localStorage.setItem(LANGUAGE_KEY, currentLanguage);
  document.documentElement.lang = currentLanguage;

  return currentLanguage;
}

export function getLanguage() {
  return currentLanguage;
}

export function t(key, fallback = "") {
  const value = getNestedValue(translations, key);
  return value != null ? value : fallback;
}

export function applyTranslations(root = document) {
  root.querySelectorAll("[data-i18n]").forEach((node) => {
    const key = node.getAttribute("data-i18n");
    node.textContent = t(key, node.textContent);
  });

  root.querySelectorAll("[data-i18n-placeholder]").forEach((node) => {
    const key = node.getAttribute("data-i18n-placeholder");
    node.setAttribute("placeholder", t(key, node.getAttribute("placeholder") || ""));
  });

  root.querySelectorAll("[data-i18n-aria-label]").forEach((node) => {
    const key = node.getAttribute("data-i18n-aria-label");
    node.setAttribute("aria-label", t(key, node.getAttribute("aria-label") || ""));
  });
}
