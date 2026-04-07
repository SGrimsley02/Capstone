/*
Name: source/Menu/MenuChangeThemeDelegate.mc
Description: Input delegate for the custom theme menu.
Authors: Audrey Pan
Created: April 7, 2026
Last Modified: April 7, 2026
*/


import Toybox.Application.Storage;
import Toybox.System;
import Toybox.WatchUi;

class MenuChangeThemeBehaviorDelegate extends WatchUi.BehaviorDelegate {

    private var _view;

    function initialize(view) {
        BehaviorDelegate.initialize();
        _view = view;
    }

    function onKey(evt) {
        var key = evt.getKey();

        if (key == WatchUi.KEY_UP) {
            _view.moveSelectionUp();
            return true;
        } else if (key == WatchUi.KEY_DOWN) {
            _view.moveSelectionDown();
            return true;
        } else if (key == WatchUi.KEY_ENTER) {
            var selected = _view.getSelectedIndex();

            if (selected == 0) {
                System.println("Saving Light Theme");
                Storage.setValue(StorageKeys.UI_THEME_KEY, "light");
                WatchUi.popView(WatchUi.SLIDE_DOWN);
                return true;
            } else if (selected == 1) {
                System.println("Saving Dark Theme");
                Storage.setValue(StorageKeys.UI_THEME_KEY, "dark");
                WatchUi.popView(WatchUi.SLIDE_DOWN);
                return true;
            } else if (selected == 2) {
                WatchUi.popView(WatchUi.SLIDE_DOWN);
                return true;
            }
        } else if (key == WatchUi.KEY_ESC) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return true;
        }
        return false;
    }
}