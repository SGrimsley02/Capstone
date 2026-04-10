/*
Name: source/Menu/MenuUserDelegate.mc
Description: Input delegate for the custom user menu.
Authors: Audrey Pan
Created: April 5, 2026
Last Modified: April 9, 2026
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
            return _activateSelection(_view.getSelectedIndex());

        } else if (key == WatchUi.KEY_ESC) {
            System.println("Closing user menu.");
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
            _view.setSelectedIndex(0);
            return _activateSelection(0);
        }

        // Check Row 1 (Theme)
        if (isInHitbox(tx, ty, _view.rowHitboxes[1])) {
            _view.setSelectedIndex(1);
            return _activateSelection(1);
        }

        // Check Row 2 (Debug Menu)
        if (isInHitbox(tx, ty, _view.rowHitboxes[2])) {
            _view.setSelectedIndex(2);
            return _activateSelection(2);
        }

        // Check Exit Button
        if (isInHitbox(tx, ty, _view.exitHitbox)) {
            _view.setSelectedIndex(3);
            return _activateSelection(3);
        }

        return false;
    }

    function _activateSelection(selected) {
        if (selected == 0) {
            System.println("Starting relink flow.");
            getApp().startRelinkFlow();
            return true;

        } else if (selected == 1) {
            System.println("Opening custom settings menu.");
            var themeView = new MenuChangeThemeView();
            WatchUi.pushView(themeView, new MenuChangeThemeBehaviorDelegate(themeView), WatchUi.SLIDE_UP);
            return true;

        } else if (selected == 2) {
            System.println("Opening debug menu.");
            WatchUi.pushView(new Rez.Menus.DebugMenu(), new DebugMenuDelegate(), WatchUi.SLIDE_UP);
            return true;

        } else if (selected == 3) {
            System.println("Closing user menu.");
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