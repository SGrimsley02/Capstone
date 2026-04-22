/*
Name: source/Alarm/WakeAlarmManager.mc
Description: Manages wake alarms for the SleepMonitor Connect IQ watch app.
             Handles setting, retrieving, and triggering wake alarms.
Authors: Audrey Pan
Created: February 22, 2026
Last Modified: April 22, 2026
*/

import Toybox.Timer;
import Toybox.Time;
import Toybox.System;
import Toybox.Attention;
import Toybox.WatchUi;
import Toybox.Lang;
import Toybox.Time.Gregorian;
import Toybox.Application.Storage;
import StorageKeys;

class WakeAlarmManager {

    private const RING_TASK_ID = "wake_alarm_ring";
    private const PODCAST_POLL_TASK_ID = "wake_alarm_podcast_poll";

    var _alarmEpoch = null;
    var _alarmTimer = null;
    var _isRinging = false;
    var _alarmShowing = false;
    var _currentView = null;
    var _alarmView = null;
    var _alarmDelegate = null;
    var _podcastReady = false;
    var _wakeStartEpoch = null;
    var _wakeEndEpoch = null;
    var _resetAlarm = false;

    private var _podcastProvider;

    function initialize() {
        _podcastProvider = new PodcastProvider();
    }

    function scheduleAlarmFromWakeWindow(wakeStartTime as String?, endWakeTime as String?) as Void {
        if (wakeStartTime == null) {
            System.println("WakeAlarmManager: no stored wake start time, defaulting to " + Defaults.DEFAULT_WAKE_START);
            wakeStartTime = Defaults.DEFAULT_WAKE_START;
        }
        _wakeStartEpoch = timeStrToEpoch(wakeStartTime);

        if (endWakeTime == null) {
            System.println("WakeAlarmManager: no stored wake end time, defaulting to " + Defaults.DEFAULT_WAKE_END);
            endWakeTime = Defaults.DEFAULT_WAKE_END;
        }
        _wakeEndEpoch = timeStrToEpoch(endWakeTime);

        var nowEpoch = Time.now().value();
        if (_wakeStartEpoch < nowEpoch) {
            _wakeStartEpoch += 24 * 60 * 60;
            _wakeEndEpoch += 24 * 60 * 60;
        }
        if (_wakeEndEpoch < _wakeStartEpoch) {
            _wakeEndEpoch += 24 * 60 * 60;
        }

        _alarmEpoch = _wakeStartEpoch;
        WatchUi.requestUpdate();

        var secondsUntil = _wakeStartEpoch - nowEpoch;
        System.println("Scheduling analysis for epoch " + _wakeStartEpoch + " in " + secondsUntil + " seconds");

        _clearAlarmTimer();

        _alarmTimer = new Timer.Timer();
        _alarmTimer.start(method(:_onWakeWindowTimer), secondsUntil * 1000, false);
    }

    function _onWakeWindowTimer() as Void {
        if (_wakeEndEpoch == null) {
            System.println("WakeAlarmManager: no stored wake end time, defaulting to " + Defaults.DEFAULT_WAKE_END);
            _wakeEndEpoch = timeStrToEpoch(Defaults.DEFAULT_WAKE_END);
        }

        _clearAlarmTimer();

        getApp().userInfoTimer.stop();

        var userId = Storage.getValue(StorageKeys.USER_ID_KEY) as String?;
        if (userId == null) {
            System.println("WakeAlarmManager: no user ID found, falling back to endWakeTime");
            scheduleAlarmAtEpoch(_wakeEndEpoch);
            return;
        }

        var payload = SleepAnalyzer.buildSleepPayload(userId);
        if (payload == null) {
            System.println("WakeAlarmManager: could not build sleep payload, falling back to endWakeTime");
            scheduleAlarmAtEpoch(_wakeEndEpoch);
            return;
        }

        var recommended = payload.get("recommendedHandoffEpochSec");
        var fallback = payload.get("fallbackHandoffEpochSec");

        var handoffEpoch = (recommended != null) ? recommended : ((fallback != null) ? fallback : _wakeEndEpoch);

        if (handoffEpoch < _wakeEndEpoch) {
            _alarmEpoch = handoffEpoch;
        } else {
            _alarmEpoch = _wakeEndEpoch;
        }

        scheduleAlarmAtEpoch(_alarmEpoch);
    }

    function scheduleAlarmAtEpoch(wakeEpoch) {
        _clearAlarmTimer();

        _alarmEpoch = wakeEpoch;
        WatchUi.requestUpdate();

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

    (:debug)
    function scheduleAlarmInSeconds(seconds) {
        var nowEpoch = Time.now().value();
        scheduleAlarmAtEpoch(nowEpoch + seconds);
    }

    function _onAlarmTimer() as Void {
        _clearAlarmTimer();

        _fireAlarmUiAndRing();
        getApp().sendSleepSummary();
        return;
    }

    function _fireAlarmUiAndRing() {
        _showAlarmUiOnce();

        if (!_podcastReady) {
            startPodcastPolling();
        }

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

        getApp().getSharedTimerManager().registerRepeatingTask(
            RING_TASK_ID,
            2,
            method(:_onRingTick)
        );
    }

    function stopRinging() {
        _isRinging = false;
        getApp().getSharedTimerManager().unregisterTask(RING_TASK_ID);
    }

    function isRinging() {
        return _isRinging;
    }

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

    function finishAlarmSession() as Void {
        stopRinging();
        stopPodcastPolling();

        _podcastReady = false;
        _alarmEpoch = null;
        _resetAlarm = true;

        getApp().updateUserInfo(method(:onReceive));
        getApp().userInfoTimer.start(method(:pollPreferences), Defaults.LONG_PREF_INT, true);
    }

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

        getApp().getSharedTimerManager().registerRepeatingTask(
            PODCAST_POLL_TASK_ID,
            15,
            method(:_pollPodcastStatus)
        );

        _pollPodcastStatus();
    }

    function stopPodcastPolling() as Void {
        getApp().getSharedTimerManager().unregisterTask(PODCAST_POLL_TASK_ID);
    }

    function _pollPodcastStatus() as Void {
        if (!_alarmShowing) { return; }
        _podcastProvider.checkStatus(method(:_onPodcastUpdate));
    }

    function _onPodcastUpdate(responseCode as Lang.Number, isReady as Boolean) as Void {
        if (isReady) {
            _podcastReady = true;
            stopPodcastPolling();

            if (_alarmView != null && (_alarmView has :setPodcastReady)) {
                _alarmView.setPodcastReady(true);
            }
        }
    }

    function pollPreferences() as Void {
        getApp().updateUserInfo(method(:onReceive));
    }

    function onReceive(
        responseCode as Number,
        data as Dictionary?,
        context as Object
    ) as Void {
        var label = context.toString();
        if (responseCode == 200 or responseCode == 201) {
            getApp().setHttpStatus(label + " ok");
            if (data instanceof Dictionary) {
                System.println(label + " success. JSON response: " + data.toString());
                var preferences = data["preferences"] as Dictionary?;
                if (preferences != null) {
                    var oldWakeStart = Storage.getValue(StorageKeys.WAKE_START_KEY) as String?;
                    var oldWakeEnd = Storage.getValue(StorageKeys.WAKE_END_KEY) as String?;

                    var wakeStart = preferences["wakeStart"] as String?;
                    if (wakeStart != null && !wakeStart.equals(oldWakeStart)) {
                        Storage.setValue(StorageKeys.WAKE_START_KEY, wakeStart);
                        System.println("Updated wake start time: " + wakeStart);
                    }

                    var wakeEnd = preferences["wakeEnd"] as String?;
                    if (wakeEnd != null && !wakeEnd.equals(oldWakeEnd)) {
                        Storage.setValue(StorageKeys.WAKE_END_KEY, wakeEnd);
                        System.println("Updated wake end time: " + wakeEnd);
                    }

                    if ((wakeStart != null && !wakeStart.equals(oldWakeStart)) || (wakeEnd != null && !wakeEnd.equals(oldWakeEnd)) || _resetAlarm) {
                        scheduleAlarmFromWakeWindow(wakeStart, wakeEnd);
                        _resetAlarm = false;
                    }
                }

            } else {
                System.println(label + " success with empty body.");
            }
        } else {
            getApp().setHttpStatus(label + " err " + responseCode.toString());
            System.println(label + " failed. Response code: " + responseCode.toString());
        }
    }

    function _clearAlarmTimer() as Void {
        if (_alarmTimer != null) {
            _alarmTimer.stop();
            _alarmTimer = null;
        }
    }

    static function timeStrToEpoch(timeStr as String) as Lang.Number {
        if (timeStr == null || timeStr.length() < 5) {
            throw new Lang.InvalidValueException("Time string must be in format HH:MM. Received: " + timeStr);
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