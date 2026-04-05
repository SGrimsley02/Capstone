/*
Name: source/utils/Constants.mc
Description: Constants used across the SleepMonitor Connect IQ app, including storage keys and other shared values.
Authors: Kiara Rose
Created: March 24, 2026
Last Modified: March 24, 2026
*/
module StorageKeys {
    const USER_ID_KEY = "username";
    const WAKE_START_KEY = "wakeStart";
    const WAKE_END_KEY = "wakeEnd";
    const HAS_ONBOARDED_KEY = "hasOnboarded";
    const PODCAST_URL_KEY = "podcast_url";
    const UI_THEME_KEY = "ui_theme";
}

module Defaults {
    const DEFAULT_WAKE_START = "07:00";
    const DEFAULT_WAKE_END = "09:00";
    const SHORT_PREF_INT = 60 * 1000; // 5 minutes in milliseconds
    const LONG_PREF_INT =  60 * 1000; // 2 hours in milliseconds
}
