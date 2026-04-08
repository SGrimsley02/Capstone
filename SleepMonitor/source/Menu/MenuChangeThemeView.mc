/*
Name: source/Menu/MenuChangeThemeView.mc
Description: Custom user menu view for the SleepMonitor Connect IQ watch app.
             Draws the user menu header, menu rows, and wave footer action.
Authors: Audrey Pan
Created: April 5, 2026
Last Modified: April 7, 2026
*/

import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import Toybox.WatchUi;
import Toybox.Math;

class MenuChangeThemeView extends WatchUi.View {

    private var _sunIcon;
    private var _moonIcon;

    private var _selectedIndex = 0;
    var rowHitboxes = [[0,0,0,0], [0,0,0,0]];
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
        if (_selectedIndex < 2) {
            _selectedIndex += 1;
            WatchUi.requestUpdate();
        }
    }

    function getSelectedIndex() as Number {
        return _selectedIndex;
    }



    function onUpdate(dc as Dc) as Void {
        _sunIcon = loadResource(Rez.Drawables.sunIcon);
        _moonIcon = loadResource(Rez.Drawables.moonIcon);

        var sunColor  = ThemeHelpers.getColor("menu_theme_sun"); // Bright Orange/Yellow
        var moonColor = ThemeHelpers.getColor("menu_theme_moon"); // Soft Indigo/Blue
        var W = dc.getWidth();
        var H = dc.getHeight();
        var row1Top = (H * 0.28).toNumber();
        var rowHeight = (H * 0.16).toNumber();


        // 1. Draw the scaffolding (Background, Title, Date/Time, Header Line)
        MenuHelpers.drawHeader(dc, "THEME");

        // Save hitboxes for the two menu rows
        rowHitboxes[0] = [0, row1Top, W, rowHeight];
        rowHitboxes[1] = [0, row1Top + rowHeight, W, rowHeight];

        // Save hitbox for Exit (Bottom area)
        exitHitbox = [(W * 0.2).toNumber(), (H * 0.75).toNumber(), (W * 0.6).toNumber(), (H * 0.2).toNumber()];

        // 2. Draw the highlight behind the selected row
        MenuHelpers.drawSelectionHighlight(dc, _selectedIndex);

        // 3. Draw the rows
        MenuHelpers.drawMenuRow(dc, 0, "Light Mode", _sunIcon, sunColor);
        MenuHelpers.drawMenuRow(dc, 1, "Dark Mode", _moonIcon, moonColor);

        // 4. Draw the waves and the Exit button
        MenuHelpers.drawFooter(dc, _selectedIndex);
    }
}