/*
Name: source/Menu/MenuUserDelegate.mc
Description: Input delegate for the custom user menu.
Authors: Audrey Pan
Created: April 5, 2026
Last Modified: April 5, 2026
*/

import Toybox.System;
import Toybox.WatchUi;

class MenuUserDelegate extends WatchUi.BehaviorDelegate {

    private var _view;

    function initialize(view) {
        WatchUi.BehaviorDelegate.initialize();
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
                System.println("Starting relink flow.");
                getApp().startRelinkFlow();
                return true;
            } else if (selected == 1) {
                System.println("Opening settings menu.");
                WatchUi.pushView(new Rez.Menus.UiCustomizationMenu(), new ThemeMenuDelegate(), WatchUi.SLIDE_UP);
                return true;
            } else if (selected == 2) {
                System.println("Closing user menu.");
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