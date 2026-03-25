/*
Name: source/Alarm/WakeAlarmManager.mc
Description: Manages wake alarms for the SleepMonitor Connect IQ watch app.
             Handles setting, retrieving, and triggering wake alarms.
Authors: Audrey Pan
Created: February 22, 2026
Last Modified: March 15, 2026
*/

import Toybox.Timer;
import Toybox.Time;
import Toybox.System;
import Toybox.Attention;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Time.Gregorian;

class WakeAlarmManager {

    var _wakeEpoch = null;
    var _alarmTimer = null;
    var _ringTimer = null;
    var _isRinging = false;
    var _alarmShowing = false;
    var _currentView = null;
    var _alarmView = null;
    var _alarmDelegate = null;
    var _podcastReady = false;
    var _podcastPollTimer = null;

    // Instance of the network provider
    private var _podcastProvider;

    function initialize() {
        _podcastProvider = new PodcastProvider();
    }

    function scheduleAlarmAtEpoch(wakeEpoch) {
        if (_alarmTimer != null) {
            _alarmTimer.stop();
            _alarmTimer = null;
        }

        _wakeEpoch = wakeEpoch;
        var nowEpoch = Time.now().value();
        var secondsUntil = wakeEpoch - nowEpoch;

        System.println("WakeAlarmManager: scheduling alarm for epoch " + wakeEpoch);
        System.println("WakeAlarmManager: current epoch " + nowEpoch);
        System.println("WakeAlarmManager: seconds until alarm " + secondsUntil);

        if (secondsUntil <= 0) {
            _fireAlarmUiAndRing();
            return;
        }

        _alarmTimer = new Timer.Timer();
        _alarmTimer.start(method(:_onAlarmTimer), secondsUntil * 1000, false);
    }

    function scheduleAlarmInSeconds(seconds) {
        var nowEpoch = Time.now().value();
        scheduleAlarmAtEpoch(nowEpoch + seconds);
    }

    function _onAlarmTimer() as Void {
        if (_alarmTimer != null) {
            _alarmTimer.stop();
            _alarmTimer = null;
        }

        _fireAlarmUiAndRing();
        getApp().updateUserInfo();

        var wakeTime = SleepMonitorHttpClient.getWakeStart();
        if (wakeTime == null) {
            System.println("WakeAlarmManager: no stored wake start time, defaulting to 07:00");
            wakeTime = "07:00";
        }
  
        scheduleAlarmAtEpoch(getNextDayEpoch(wakeTime));
        return;

    }
        

    function _fireAlarmUiAndRing() {
        _showAlarmUiOnce();
        startRinging();
    }

    function _showAlarmUiOnce() {
        if (_alarmShowing) {
            System.println("WakeAlarmManager: alarm UI already showing");
            return;
        }
        _alarmShowing = true;

        if (_alarmView == null) {
            _alarmView = new AlarmView();
            if (_alarmView has :setManager) {
                _alarmView.setManager(self);
            }
            _alarmDelegate = new AlarmDelegate(_alarmView, self);
        }

        System.println("WakeAlarmManager: pushing AlarmView");
        WatchUi.pushView(_alarmView, _alarmDelegate, WatchUi.SLIDE_UP);
        startPodcastPolling();
    }

    function setAlarmShowing(showing) {
        _alarmShowing = showing;
        if (!showing) {
            _currentView = null;
            stopPodcastPolling();
        }
    }

    function startRinging() {
        if (_isRinging) { return; }

        _isRinging = true;
        _ringOnce();

        _ringTimer = new Timer.Timer();
        _ringTimer.start(method(:_onRingTick), 2000, true);
    }

    function stopRinging() {
        _isRinging = false;

        if (_ringTimer != null) {
            _ringTimer.stop();
            _ringTimer = null;
        }

        stopPodcastPolling();
        _wakeEpoch = null;
    }

    function isRinging() {
        return _isRinging;
    }

    // Returns the scheduled wake epoch (seconds since epoch), or null if not set.
    function getWakeEpoch() {
        return _wakeEpoch;
    }

    function _onRingTick() as Void {
        if (!_isRinging) { return; }
        _ringOnce();
    }

    function _ringOnce() {
        var vibes = [
            new Attention.VibeProfile(100, 400),
            new Attention.VibeProfile(0, 200),
            new Attention.VibeProfile(100, 400)
        ];
        Attention.vibrate(vibes);
        Attention.playTone(Attention.TONE_ALARM);
    }

    // Uses the modular provider
    function sendPodcastLinkToPhone() as Void {
        _podcastProvider.openPodcast();
    }

    function isPodcastReady() {
        return _podcastReady;
    }

    function startPodcastPolling() as Void {
        _podcastReady = false;

        if (_alarmView != null && (_alarmView has :setPodcastReady)) {
            _alarmView.setPodcastReady(false);
        }

        if (_podcastPollTimer == null) {
            _podcastPollTimer = new Timer.Timer();
            _podcastPollTimer.start(method(:_pollPodcastStatus), 15000, true);
        }

        _pollPodcastStatus();
    }

    function stopPodcastPolling() as Void {
        if (_podcastPollTimer != null) {
            _podcastPollTimer.stop();
            _podcastPollTimer = null;
        }
    }

    function _pollPodcastStatus() as Void {
        if (!_alarmShowing) { return; }
        _podcastProvider.checkStatus(method(:_onPodcastUpdate));
    }

    // Callback received from PodcastProvider
    function _onPodcastUpdate(responseCode as Lang.Number, isReady as Boolean) as Void {
        if (isReady) {
            _podcastReady = true;
            stopPodcastPolling();

            if (_alarmView != null && (_alarmView has :setPodcastReady)) {
                _alarmView.setPodcastReady(true);
            }
        }
    }

    static function getNextDayEpoch(timeStr as String) as Lang.Number {
        var hours = timeStr.substring(0, 2).toNumber();
        var minutes = timeStr.substring(3, 5).toNumber();

        var now = Gregorian.info(Time.now(), Time.FORMAT_SHORT);

        var options = {
            :year   => now.year,
            :month  => now.month,
            :day    => now.day + 1,
            :hour   => hours,
            :minute => minutes,
            :second => 0
        };

        var moment = Gregorian.moment(options);
        var tzOffset = System.getClockTime().timeZoneOffset;

        return moment.value() - tzOffset;
    }

    function scheduleAlarmFromSleepPayload(payload as Dictionary) as Void {
        if (payload == null) {
            System.println("WakeAlarmManager: no sleep payload provided");
            return;
        }

        var wakeEpoch = null;
        var recommended = payload.get("recommendedHandoffEpochSec");
        var fallback = payload.get("fallbackHandoffEpochSec");

        if (recommended != null) {
            wakeEpoch = recommended;
            System.println("WakeAlarmManager: using recommended handoff epoch " + wakeEpoch);
        } else if (fallback != null) {
            wakeEpoch = fallback;
            System.println("WakeAlarmManager: using fallback handoff epoch " + wakeEpoch);
        }

        if (wakeEpoch == null) {
            System.println("WakeAlarmManager: no handoff epoch found in payload");
            return;
        }

        scheduleAlarmAtEpoch(wakeEpoch);
    }
}