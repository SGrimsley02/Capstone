 /*
Name: source/utils/ThemeHelpers.mc
Description: Theme helper functions for the SleepMonitor Connect IQ app.
Authors: Audrey Pan
Created: April 4 , 2026
Last Modified: April 4, 2026
*/  

import Toybox.Application.Storage;
import Toybox.Graphics;
import StorageKeys;
import Colors;
import Toybox.Lang;

module ThemeHelpers {

    function getTheme() as String {
        var theme = Storage.getValue(StorageKeys.UI_THEME_KEY) as String?;
        if (theme == null) {
            return "dark";
        }
        return theme;
    }

    function getColor(colorName as String) as Number {
        var theme = getTheme();

        if (theme == "light") {
            if (colorName == "background") { return Graphics.COLOR_WHITE; }
            if (colorName == "primaryText") { return Graphics.COLOR_BLACK; }
            if (colorName == "secondaryText") { return Colors.GRAY_DARK; }
            if (colorName == "accent") { return Colors.TEAL_DARK; }
            if (colorName == "secondaryAccent") { return Colors.PURPLE_MID; }
        }

        // default dark theme
        if (colorName == "background") { return Graphics.COLOR_BLACK; }
        if (colorName == "primaryText") { return Graphics.COLOR_WHITE; }
        if (colorName == "secondaryText") { return Colors.GRAY_MID; }
        if (colorName == "accent") { return Colors.TEAL_LITE; }
        if (colorName == "secondaryAccent") { return Colors.PURPLE_MID; }

        return Graphics.COLOR_WHITE;
    }
}
