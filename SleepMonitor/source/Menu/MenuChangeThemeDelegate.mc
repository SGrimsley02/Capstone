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

    // Touch Support
    function onTap(evt as WatchUi.ClickEvent) {
        var coords = evt.getCoordinates();
        var tx = coords[0];
        var ty = coords[1];

        // Check Row 0 (Relink)
        if (isInHitbox(tx, ty, _view.rowHitboxes[0])) {
            System.println("Saving Light Theme");
            Storage.setValue(StorageKeys.UI_THEME_KEY, "light");
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return true;
        }

        // Check Row 1 (Theme)
        if (isInHitbox(tx, ty, _view.rowHitboxes[1])) {
            System.println("Saving Dark Theme");
            Storage.setValue(StorageKeys.UI_THEME_KEY, "dark");
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return true;
        }

        // Check Exit Button
        if (isInHitbox(tx, ty, _view.exitHitbox)) {
            WatchUi.popView(WatchUi.SLIDE_DOWN);
            return true;
        }

        return false;
    }

    // Helper to check if tap is within bounds
    private function isInHitbox(tx, ty, hitbox) {
        return (tx >= hitbox[0] && tx <= hitbox[0] + hitbox[2] &&
                ty >= hitbox[1] && ty <= hitbox[1] + hitbox[3]);
    }
}