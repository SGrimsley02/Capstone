/*
Name: source/utils/ThemeHelpers.mc
Description: Theme helper functions for the SleepMonitor Connect IQ app.
Authors: Audrey Pan
Created: April 4, 2026
Last Modified: April 4, 2026
*/

import Toybox.Application.Storage;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import StorageKeys;
import Colors;

module ThemeHelpers {

    function getTheme() as String {
        // Using the key from your StorageKeys or a string literal
        var theme = Storage.getValue(StorageKeys.UI_THEME_KEY);

        if (theme == null || !(theme instanceof Lang.String)) {
            return "dark";
        }

        return theme as String;
    }

    function getColor(token as String) as Number {
        var themeName = getTheme();

        // Ensure ThemeRegistry is visible to this module
        var themeMap = ThemeRegistry.THEMES[themeName] as Dictionary?;

        if (themeMap == null) {
            themeMap = ThemeRegistry.THEMES["dark"] as Dictionary;
        }

        var color = themeMap[token];

        // 3. Fallback if a specific token is missing or null
        if (color == null) {
            return Graphics.COLOR_WHITE;
        }

        return color as Number;
    }
}