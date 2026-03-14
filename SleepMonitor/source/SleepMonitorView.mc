/*
Name: source/SleepMonitorView.mc
Description: Home screen view for the REMix watch app.
             Displays the app branding, current time/date, next scheduled alarm,
             and quick-action buttons for music and podcast features.
Authors: Kiara Rose
Created: February 7, 2026
Last Modified: March 13, 2026
*/

import Toybox.Graphics;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.System;
import Toybox.Time;
import Toybox.Time.Gregorian;

class SleepMonitorView extends WatchUi.View {

    // Brand / accent palette
    private const PURPLE_MID  = 0x7B5EA7; // muted purple (arcs, rings)
    private const PURPLE_LITE = 0xB39DDB; // lavender (logo, podcast tint)
    private const PURPLE_DARK = 0x2D1B4E; // deep purple (podcast btn bg)
    private const TEAL_LITE   = 0x4FC3F7; // light blue (alarm text, music tint)
    private const TEAL_DARK   = 0x0D2B3E; // deep teal (music btn bg)
    private const GRAY_MID    = 0x9E9E9E; // mid-gray (date, labels)
    private const GRAY_DARK   = 0x333355; // dark blue-gray (divider)

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
        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();



        // ── "REMix" brand logo or fallback text ───────────────────
        if (_remixLogo != null) {
            // Center the logo horizontally near the top
            var logoW = _remixLogo.getWidth();
            dc.drawBitmap2(cx - logoW / 2, (H * 0.04).toNumber(), _remixLogo, {:tintColor => PURPLE_LITE});
        } else {
            dc.setColor(PURPLE_LITE, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                cx, (H * 0.10).toNumber(),
                Graphics.FONT_TINY,
                "REMix",
                Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        // ── Current time ───────────────────────────────────────────
        var ct   = System.getClockTime();
        var hour = ct.hour;
        var amPm = "";
        var use12h = !System.getDeviceSettings().is24Hour;

        if (use12h) {
            if      (hour == 0)  { hour = 12; amPm = "AM"; }
            else if (hour < 12)  { amPm = "AM"; }
            else if (hour == 12) { amPm = "PM"; }
            else                 { hour -= 12; amPm = "PM"; }
        }

        var timeStr = Lang.format("$1$:$2$", [hour.format("%d"), ct.min.format("%02d")]);

        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx, (H * 0.30).toNumber(),
            Graphics.FONT_NUMBER_MEDIUM,
            timeStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // AM / PM superscript
        if (use12h && amPm.length() > 0) {
            dc.setColor(GRAY_MID, Graphics.COLOR_TRANSPARENT);
            dc.drawText(
                (cx + W * 0.23).toNumber(), (H * 0.27).toNumber(),
                Graphics.FONT_XTINY,
                amPm,
                Graphics.TEXT_JUSTIFY_LEFT | Graphics.TEXT_JUSTIFY_VCENTER
            );
        }

        // ── Date ───────────────────────────────────────────────────
        var info    = Gregorian.info(Time.now(), Time.FORMAT_MEDIUM);
        var dateStr = Lang.format("$1$, $2$ $3$", [info.day_of_week, info.month, info.day]);

        dc.setColor(GRAY_MID, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx, (H * 0.45).toNumber(),
            Graphics.FONT_XTINY,
            dateStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );

        // ── Thin divider ───────────────────────────────────────────
        dc.setColor(GRAY_DARK, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(1);
        dc.drawLine(
            (cx - W * 0.28).toNumber(), (H * 0.52).toNumber(),
            (cx + W * 0.28).toNumber(), (H * 0.52).toNumber()
        );

        // ── Next alarm ─────────────────────────────────────────────
        var alarmStr = _getAlarmString();
        dc.setColor(TEAL_LITE, Graphics.COLOR_TRANSPARENT);
        dc.drawText(
            cx, (H * 0.58).toNumber(),
            Graphics.FONT_XTINY,
            alarmStr,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER
        );
        if (_alarmIcon != null) {
            var iconW = _alarmIcon.getWidth();
            var iconY = (H * 0.58).toNumber() + dc.getFontHeight(Graphics.FONT_XTINY) / 2 + 4;
            dc.drawBitmap2(cx - iconW / 2, iconY, _alarmIcon, {:tintColor => TEAL_LITE});
        }

        // ── Action button circles ──────────────────────────────────
        var btnY   = (H * 0.74).toNumber();
        var leftX  = (cx - W * 0.36).toNumber();
        var rightX = (cx + W * 0.36).toNumber();
        var btnR   = (W * 0.19).toNumber();

        // Podcast button (left)
        dc.setColor(PURPLE_DARK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(leftX, btnY, btnR);
        dc.setColor(PURPLE_MID, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(leftX, btnY, btnR);

        // Music button (right)
        dc.setColor(TEAL_DARK, Graphics.COLOR_TRANSPARENT);
        dc.fillCircle(rightX, btnY, btnR);
        dc.setColor(TEAL_LITE, Graphics.COLOR_TRANSPARENT);
        dc.drawCircle(rightX, btnY, btnR);

        // Icons (centered in each button circle; icons are ~20x20 px)
        if (_podcastIcon != null) {
            dc.drawBitmap2(leftX - 16, btnY - 42, _podcastIcon, {
                :tintColor => PURPLE_LITE,
                });
        }
        if (_musicIcon != null) {
            dc.drawBitmap2(rightX - 36, btnY - 42, _musicIcon, {:tintColor => TEAL_LITE});
        }

        // ── Decorative top arc (brand color) ───────────────────────
        // Arc spans the top of the round face (~10 o'clock → ~2 o'clock)
        dc.setColor(PURPLE_MID, Graphics.COLOR_TRANSPARENT);
        dc.setPenWidth(4);
        dc.drawArc(cx, cy, (W / 2) - 6, Graphics.ARC_COUNTER_CLOCKWISE, 125, 55);
        dc.setPenWidth(1);
    }

    // Returns a human-readable string for the next scheduled alarm.
    private function _getAlarmString() as String {
        var manager = getApp().getWakeAlarmManager();
        if (manager == null) { return "No alarm set"; }

        var epoch = manager.getWakeEpoch();
        if (epoch == null) { return "No alarm set"; }

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

        return Lang.format("Alarm  $1$:$2$$3$", [h.format("%d"), m.format("%02d"), suf]);
    }

    function onHide() as Void { }

}
