/*
Name: source/Menu/MenuUserView.mc
Description: Custom user menu view for the SleepMonitor Connect IQ watch app.
             Draws the user menu header, scrollable menu rows, and wave footer action.
Authors: Audrey Pan
Created: April 5, 2026
Last Modified: April 9, 2026
*/

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

class MenuUserView extends WatchUi.View {

    private var _linkIcon;
    private var _gearIcon;
    private var _selectedIndex = 0;

    // 0 = Relink Website
    // 1 = Change Theme
    // 2 = Debug Menu
    // 3 = Exit Menu
    var rowHitboxes = [[0,0,0,0], [0,0,0,0], [0,0,0,0]];
    var exitHitbox = [0,0,0,0];

    function initialize() {
        View.initialize();
    }

    function onLayout(dc as Dc) as Void {
        // Fully custom-drawn screen; no layout XML required
    }

    function onShow() as Void {
        WatchUi.requestUpdate();
    }

    function onHide() as Void { }

    function moveSelectionUp() as Void {
        if (_selectedIndex > 0) {
            _selectedIndex -= 1;
            WatchUi.requestUpdate();
        }
    }

    function moveSelectionDown() as Void {
        if (_selectedIndex < 3) {
            _selectedIndex += 1;
            WatchUi.requestUpdate();
        }
    }

    function getSelectedIndex() as Number {
        return _selectedIndex;
    }

    function setSelectedIndex(index as Number) as Void {
        if (index >= 0 && index <= 3) {
            _selectedIndex = index;
            WatchUi.requestUpdate();
        }
    }

    function getExitHitbox() as Array {
        return exitHitbox;
    }

    function onUpdate(dc as Dc) as Void {
        _linkIcon = loadResource(Rez.Drawables.linkIcon);
        _gearIcon = loadResource(Rez.Drawables.settingsIcon);

        var iconColor = ThemeHelpers.getColor("menu_user_icons");
        var W = dc.getWidth();
        var H = dc.getHeight();

        var rowTop = (H * 0.28).toNumber();
        var rowHeight = (H * 0.16).toNumber();

        var labels = ["Relink Website", "Change Theme", "Debug Menu"];
        var icons  = [_linkIcon, _gearIcon, _gearIcon];

        // Small upward slide like the default menu behavior.
        var scrollOffset = 0;
        if (_selectedIndex == 2) {
            scrollOffset = (rowHeight * 0.55).toNumber();
        } else if (_selectedIndex == 3) {
            scrollOffset = (rowHeight * 0.78).toNumber();
        }

        // 1. Base screen background only
        MenuHelpers.drawMenuBackground(dc);

        // Clear hitboxes each frame
        rowHitboxes = [[0,0,0,0], [0,0,0,0], [0,0,0,0]];

        // These define the visible menu band between the header and footer chrome
        var visibleTop = (H * 0.26).toNumber();
        var visibleBottom = (H * 0.73).toNumber();

        // 2. Draw scrolling rows first (behind everything else)
        for (var i = 0; i < labels.size(); i += 1) {
            var y = rowTop + (i * rowHeight) - scrollOffset;

            // Save only the visible/tappable portion
            var visibleY = y;
            var visibleHeight = rowHeight;

            if (visibleY < visibleTop) {
                var hiddenTop = visibleTop - visibleY;
                visibleY = visibleTop;
                visibleHeight -= hiddenTop;
            }

            if ((visibleY + visibleHeight) > visibleBottom) {
                visibleHeight = visibleBottom - visibleY;
            }

            if (visibleHeight > 0) {
                rowHitboxes[i] = [0, visibleY, W, visibleHeight];
            }

            if (_selectedIndex == i) {
                MenuHelpers.drawSelectionHighlightAtY(dc, y);
            }

            MenuHelpers.drawMenuRowAtY(dc, labels[i], icons[i], iconColor, y, true);
        }

        // 3. Footer stays in front of the list
        exitHitbox = [
            (W * 0.20).toNumber(),
            (H * 0.77).toNumber(),
            (W * 0.60).toNumber(),
            (H * 0.16).toNumber()
        ];
        var itemCount = labels.size();
        MenuHelpers.drawFooter(dc, _selectedIndex, itemCount);

        // 4. Top overlay sits in front of the list too
        MenuHelpers.drawHeaderOverlay(dc);

        // 5. Header text/time/date are the topmost layer
        MenuHelpers.drawHeaderText(dc, "USER MENU");
    }
}