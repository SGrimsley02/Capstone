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

    var _alarmEpoch = null;
    var _alarmTimer = null;
    var _ringTimer = null;
    var _isRinging = false;
    var _alarmShowing = false;
    var _currentView = null;
    var _alarmView = null;
    var _alarmDelegate = null;
    var _podcastReady = false;
    var _podcastPollTimer = null;
    var _wakeStartEpoch = null;
    var _wakeEndEpoch = null;

    // Instance of the network provider
    private var _podcastProvider;

    function initialize() {
        _podcastProvider = new PodcastProvider();
    }

    // Schedule alarm based on wake window: generates a sleep payload at wakeStartTime
    function scheduleAlarmFromWakeWindow(wakeStartTime as String, endWakeTime as String) as Void {
        _wakeStartEpoch = timeStrToEpoch(wakeStartTime);
        _wakeEndEpoch = timeStrToEpoch(endWakeTime);

        var nowEpoch = Time.now().value();
        if (_wakeStartEpoch < nowEpoch) {
            System.println("WakeAlarmManager: Scheduling alarm for tomorrow");
            _wakeStartEpoch += 24 * 60 * 60;
            _wakeEndEpoch += 24 * 60 * 60;
        }
        _alarmEpoch = _wakeStartEpoch;
        var secondsUntil = _wakeStartEpoch - nowEpoch;

        if (_alarmTimer != null) {
            _alarmTimer.stop();
            _alarmTimer = null;
        }

        // Schedule timer to compute and set alarm when wakeStartTime arrives
        _alarmTimer = new Timer.Timer();
        _alarmTimer.start(method(:_onWakeWindowTimer), secondsUntil * 1000, false);
    }

    function _onWakeWindowTimer() as Void {
        if (_wakeEndEpoch == null) {
            System.println("WakeAlarmManager: no stored wake end time, defaulting to " + Defaults.DEFAULT_WAKE_END);
            _wakeEndEpoch = Defaults.DEFAULT_WAKE_END;
        }

        if (_alarmTimer != null) {
            _alarmTimer.stop();
            _alarmTimer = null;
        }

        // Get userId from storage
        var userId = SleepMonitorHttpClient.getUserId();
        if (userId == null) {
            System.println("WakeAlarmManager: no user ID found, falling back to endWakeTime");
            _alarmEpoch = _wakeEndEpoch;
            scheduleAlarmAtEpoch(_alarmEpoch);
            return;
        }

        // Build sleep payload to analyze sleep data and get handoff epoch
        var payload = SleepAnalyzer.buildSleepPayload(userId);
        if (payload == null) {
            System.println("WakeAlarmManager: could not build sleep payload, falling back to endWakeTime");
            _alarmEpoch = _wakeEndEpoch;
            scheduleAlarmAtEpoch(_alarmEpoch);
            return;
        }

        // Extract handoff epoch (recommended or fallback)
        var recommended = payload.get("recommendedHandoffEpochSec");
        var fallback = payload.get("fallbackHandoffEpochSec");

        // If both recommended and fallback are missing, fall back to endWakeTime
        var handoffEpoch = (recommended != null) ? recommended : ((fallback != null) ? fallback : _wakeEndEpoch);

        // Use handoff epoch only if it's before endWakeTime, otherwise use endWakeTime
        if (handoffEpoch < _wakeEndEpoch) {
            _alarmEpoch = handoffEpoch;
        } else {
            _alarmEpoch = _wakeEndEpoch;
        }
        scheduleAlarmAtEpoch(_alarmEpoch);
    }

    function scheduleAlarmAtEpoch(wakeEpoch) {
        if (_alarmTimer != null) {
            _alarmTimer.stop();
            _alarmTimer = null;
        }

        _alarmEpoch = wakeEpoch;
        var nowEpoch = Time.now().value();
        var secondsUntil = wakeEpoch - nowEpoch;

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

        var wakeStartTime = SleepMonitorHttpClient.getWakeStart();
        if (wakeStartTime == null) {
            System.println("WakeAlarmManager: no stored wake start time, defaulting to " + Defaults.DEFAULT_WAKE_START);
            wakeStartTime = Defaults.DEFAULT_WAKE_START;
        }
        var wakeEndTime = SleepMonitorHttpClient.getWakeEnd();
        if (wakeEndTime == null) {
            System.println("WakeAlarmManager: no stored wake end time, defaulting to " + Defaults.DEFAULT_WAKE_END);
            wakeEndTime = Defaults.DEFAULT_WAKE_END;
        }
  
        getApp().sendSleepSummary();
        scheduleAlarmFromWakeWindow(wakeStartTime, wakeEndTime);
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
        _alarmEpoch = null;
    }

    function isRinging() {
        return _isRinging;
    }

    // Returns the scheduled wake epoch (seconds since epoch), or null if not set.
    function getWakeEpoch() {
        return _alarmEpoch;
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

    static function timeStrToEpoch(timeStr as String) as Lang.Number {
        if (timeStr == null || timeStr.length() < 5) {
            System.println("WakeAlarmManager: invalid time string, defaulting to " + Defaults.DEFAULT_WAKE_START);
            timeStr = Defaults.DEFAULT_WAKE_START;
        }
        var hours = timeStr.substring(0, 2).toNumber();
        var minutes = timeStr.substring(3, 5).toNumber();

        var options = {
            :hour   => hours,
            :minute => minutes
        };

        var moment = Gregorian.moment(options);
        var tzOffset = System.getClockTime().timeZoneOffset;
        var epoch = moment.value() - tzOffset;

        return epoch;
    }
}