/*
Name: source/utils/ThemeHelpers.mc
Description: Theme helper functions for the SleepMonitor Connect IQ app.
Authors: Audrey Pan
Created: April 4, 2026
Last Modified: April 4, 2026
*/  

import Toybox.Application.Storage;
import Toybox.Graphics;
import StorageKeys;
import Colors;
import Toybox.Lang;
import Toybox.System;

module ThemeHelpers {

    function getTheme() as String {
        var theme = Storage.getValue(StorageKeys.UI_THEME_KEY) as String?;
        System.println("ThemeHelpers.getTheme raw value: " + theme);

        if (theme == null) {
            System.println("ThemeHelpers.getTheme using default: dark");
            return "dark";
        }

        System.println("ThemeHelpers.getTheme returning: " + theme);
        return theme;
    }

    function getColor(colorName as String) as Number {
        var theme = getTheme();

        if (theme.equals("light")) {
        // UPDATED FOR CONTRAST ON A LIGHT BACKGROUND
            if (colorName.equals("background")) { return Colors.ALICE_BLUE; } // Alice Blue
            if (colorName.equals("primaryText")) { return Colors.STORMY_TEAL; } // Stormy teal
            if (colorName.equals("secondaryText")) { return Colors.DARK_CYAN; } // Dark Cyan
            if (colorName.equals("date")) { return Colors.DARK_CYAN; } // Dark Cyan
            if (colorName.equals("accent")) { return Colors.ROSEWOOD; } // Rosewood
            if (colorName.equals("secondaryAccent")) { return Colors.ALMOND_SILK; } // Almond Silk
            if (colorName.equals("3rdAccent")) { return Colors.POWDER_BLUSH; } // Powder Blush
            if (colorName.equals("4thAccent")) { return Colors.STORMY_TEAL; } // Stormy teal
            if (colorName.equals("5thAccent")) { return Colors.TANGERINE_DREAM; } // Tangerine Dream
        }

        // default dark theme
        if (colorName.equals("background")) { return Graphics.COLOR_BLACK; }
        if (colorName.equals("primaryText")) { return Graphics.COLOR_WHITE; }
        if (colorName.equals("secondaryText")) { return Colors.GRAY_MID; }
        if (colorName.equals("date")) { return Colors.GRAY_DARK; }
        if (colorName.equals("accent")) { return Colors.TEAL_LITE; }
        if (colorName.equals("secondaryAccent")) { return Colors.PURPLE_MID; }
        if (colorName.equals("3rdAccent")) { return Colors.PURPLE_LITE; }
        if (colorName.equals("4thAccent")) { return Colors.PURPLE_DARK; }
        if (colorName.equals("5thAccent")) { return Colors.TEAL_DARK; }

        System.println("ThemeHelpers.getColor fallback hit for token: " + colorName);
        return Graphics.COLOR_WHITE;
    }
}