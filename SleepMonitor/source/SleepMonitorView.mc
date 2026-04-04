/*
Name: source/SleepMonitorView.mc
Description: Home screen view for the REMix watch app.
             Displays the app branding, current time/date, next scheduled alarm,
             and quick-action buttons for music and podcast features.
Authors: Kiara Rose
Created: February 7, 2026
Last Modified: March 15, 2026
*/

import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;
import ThemeHelpers;

class SleepMonitorView extends WatchUi.View {

    private var _musicIcon;
    private var _podcastIcon;
    private var _remixLogo;
    private var _alarmIcon;

    function initialize() {
        View.initialize();
        _musicIcon    = loadResource(Rez.Drawables.musicIcon);
        _podcastIcon  = loadResource(Rez.Drawables.podcastIcon);
        _remixLogo    = loadResource(Rez.Drawables.remixLogo);
        _alarmIcon    = loadResource(Rez.Drawables.alarmIcon);
    }

    function onLayout(dc as Dc) as Void {
        setLayout(Rez.Layouts.MainLayout(dc));
    }

    function onShow() as Void {
        WatchUi.requestUpdate();
    }

    function onUpdate(dc as Dc) as Void {
        var W  = dc.getWidth();
        var H  = dc.getHeight();
        var cx = W / 2;
        var cy = H / 2;

        // ── Background ─────────────────────────────────────────────
        var bgColor = ThemeHelpers.getColor("background");
        dc.setColor(bgColor, bgColor);
        dc.clear();



        // ── "REMix" brand logo or fallback text ───────────────────
        UIHelpers.drawBranding(dc, cx, H, _remixLogo);

        // ── Current time ───────────────────────────────────────────
        UIHelpers.drawClock(dc, cx, (H * 0.30).toNumber(), Graphics.FONT_NUMBER_MEDIUM);

        // ── Date ───────────────────────────────────────────────────
        var info    = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateStr = Lang.format("$1$, $2$ $3$", [info.day_of_week, info.month, info.day]);

        dc.setColor(ThemeHelpers.getColor("secondaryText"), Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx, (H * 0.45).toNumber(),
            Graphics.FONT_XTINY,
            dateStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // ── Thin divider ───────────────────────────────────────────
        dc.setColor(ThemeHelpers.getColor("date"), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(
            (cx - W * 0.28).toNumber(), (H * 0.52).toNumber(),
            (cx + W * 0.28).toNumber(), (H * 0.52).toNumber()
        );

        // ── Next alarm ─────────────────────────────────────────────
        var alarmStr = _getAlarmString();
        dc.setColor(ThemeHelpers.getColor("accent"), Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx, (H * 0.58).toNumber(),
            Graphics.FONT_XTINY,
            alarmStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        if (_alarmIcon != null) {
            var iconW = _alarmIcon.getWidth();
            var iconY = (H * 0.58).toNumber() + dc.getFontHeight(Graphics.FONT_XTINY) / 2 + 4;
            dc.drawBitmap2(cx - iconW / 2, iconY, _alarmIcon, {:tintColor => ThemeHelpers.getColor("accent")});
        }

        // ── Action button circles ──────────────────────────────────
        var btnY   = (H * 0.74).toNumber();
        var leftX  = (cx - W * 0.36).toNumber();
        var rightX = (cx + W * 0.36).toNumber();
        var btnR   = (W * 0.19).toNumber();

        // Podcast button (left)
        dc.setColor(ThemeHelpers.getColor("4thAccent"), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(leftX, btnY, btnR);
        dc.setColor(ThemeHelpers.getColor("secondaryAccent"), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(leftX, btnY, btnR);

        // Music button (right)
        dc.setColor(ThemeHelpers.getColor("5thAccent"), Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(rightX, btnY, btnR);
        dc.setColor(ThemeHelpers.getColor("accent"), Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(rightX, btnY, btnR);

        // Icons (centered in each button circle; icons are ~20x20 px)
        if (_podcastIcon != null) {
            dc.drawBitmap2(leftX - 16, btnY - 42, _podcastIcon, {
                :tintColor => ThemeHelpers.getColor("3rdAccent"),
                });
        }
        if (_musicIcon != null) {
            dc.drawBitmap2(rightX - 36, btnY - 42, _musicIcon, {:tintColor => ThemeHelpers.getColor("accent")});
        }

        // ── Decorative top arc (brand color) ───────────────────────
        // Arc spans the top of the round face (~10 o'clock → ~2 o'clock)
        dc.setColor(ThemeHelpers.getColor("secondaryAccent"), Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        dc.drawArc(cx, cy, (W / 2) - 6, Graphics.ARC_COUNTER_CLOCKWISE, 125, 55);
        dc.setPenWidth(1);
    }

    // Returns a human-readable string for the next scheduled alarm.
    private function _getAlarmString() as String {
        var manager = getApp().getWakeAlarmManager();
        if (manager == null) { return WatchUi.loadResource(Rez.Strings.NoAlarmSet); }

        var epoch = manager.getWakeEpoch();
        if (epoch == null) { return WatchUi.loadResource(Rez.Strings.NoAlarmSet); }

        var info = Gregorian.info(new Time.Moment(epoch), Time.FORMAT_SHORT);
        var h    = info.hour;
        var m    = info.min;
        var suf  = "";

        if (!System.getDeviceSettings().is24Hour) {
            if      (h == 0)  { h = 12; suf = " AM"; }
            else if (h < 12)  { suf = " AM"; }
            else if (h == 12) { suf = " PM"; }
            else              { h -= 12; suf = " PM"; }
        }

        return Lang.format("$1$  $2$:$3$$4$", [WatchUi.loadResource(Rez.Strings.AlarmSet), h.format("%d"), m.format("%02d"), suf]);
    }

    function onHide() as Void { }

}
