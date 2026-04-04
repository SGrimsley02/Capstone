/*
Name: source/ThemeMenuDelegate.mc
Description: Menu input delegate for UI theme selection.
Authors: Audrey Pan
Created: April 4, 2026
Last Modified: April 4, 2026
*/

import Toybox.Application.Storage;
import Toybox.System;
import Toybox.WatchUi;
import StorageKeys;
import Toybox.Lang;


class ThemeMenuDelegate extends WatchUi.MenuInputDelegate {

    function initialize() {
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item as Symbol) as Void {
        System.println("Selected theme item: " + item.toString());

        if (item == :themeDark) {
            Storage.setValue(StorageKeys.UI_THEME_KEY, "dark");
        } else if (item == :themeLight) {
            Storage.setValue(StorageKeys.UI_THEME_KEY, "light");
        }

        WatchUi.requestUpdate();
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
    }
}