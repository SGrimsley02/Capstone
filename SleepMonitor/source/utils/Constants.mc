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
    const SLEEP_SCORE_KEY = "sleep_score";
}

module Defaults {
    const DEFAULT_WAKE_START = "07:00";
    const DEFAULT_WAKE_END = "09:00";
}

module TimerConstants {
    const ESC_HOLD_SEC = 1;
    const ESC_HOLD_TASK_ID = "sleep_monitor_esc_hold";

    const RING_TASK_ID = "wake_alarm_ring";
    const RING_INTERVAL_SEC = 2;

    const PODCAST_POLL_TASK_ID = "wake_alarm_podcast_poll";
    const PODCAST_POLL_INTERVAL_SEC = 15;

    const SNOOZE_TASK_ID = "alarm_snooze_countdown";
    const SNOOZE_DURATION_SEC = 600;
    const SNOOZE_TICK_INTERVAL_SEC = 1;

    const PLAYBACK_POLL_TASK_ID = "playback_poll";
    const PLAYBACK_POLL_INTERVAL_SEC = 10;

    const PLAYBACK_REFRESH_TASK_ID = "playback_refresh";
    const PLAYBACK_REFRESH_DELAY_SEC = 2;

    const ONBOARDING_USERNAME_POLL_TASK_ID = "onboarding_username_poll";
    const ONBOARDING_USERNAME_POLL_INTERVAL_SEC = 30;
    const ONBOARDING_USERNAME_MAX_POLLS = 20;

    const ONBOARDING_INITIAL_PREF_POLL_ID = "onboarding_initial_pref_poll";
    const ONBOARDING_INITIAL_PREF_POLL_INTERVAL = 10 * 60; // 10 minutes
    const ONBOARDING_LONG_PREF_POLL_ID = "onboarding_long_pref_poll";
    const ONBOARDING_LONG_PREF_POLL_INTERVAL = 2 * 60 * 60; // 2 hours
}
