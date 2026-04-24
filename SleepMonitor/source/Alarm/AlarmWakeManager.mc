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
    var _resetAlarm = false; // Flag to indicate whether we need to reset the alarm after dismissing the current one
    var _prefPollPending = true;
    var _podcastPollPending = false;

    // Instance of the network provider
    private var _podcastProvider;

    function initialize() {
        _podcastProvider = new PodcastProvider();
        _podcastPollPending = false;
    }

     // Schedule alarm based on wake window: generates a sleep payload at wakeStartTime
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
            _wakeEndEpoch += 24 * 60 * 60; // Handle case where end time is past midnight (e.g., wakeStart=23:00, wakeEnd=06:00)
        }

        _alarmEpoch = _wakeStartEpoch;
        WatchUi.requestUpdate();

        var secondsUntil = _wakeStartEpoch - nowEpoch;
        System.println("Scheduling analysis for epoch " + _wakeStartEpoch + " in " + secondsUntil + " seconds");

        _clearAlarmTimer();

        // Schedule timer to compute and set alarm when wakeStartTime arrives
        _alarmTimer = new Timer.Timer();
        _alarmTimer.start(method(:_onWakeWindowTimer), secondsUntil * 1000, false);
    }

    function _onWakeWindowTimer() as Void {
        if (_wakeEndEpoch == null) {
            System.println("WakeAlarmManager: no stored wake end time, defaulting to " + Defaults.DEFAULT_WAKE_END);
            _wakeEndEpoch = timeStrToEpoch(Defaults.DEFAULT_WAKE_END);
        }

        _clearAlarmTimer();

        _prefPollPending = false;  // Stop any pending preference polls to avoid conflicts during alarm scheduling
        getApp().getSharedTimerManager().unregisterTask(TimerConstants.ONBOARDING_LONG_PREF_POLL_ID);
        
        // Get userId from storage
        var userId = Storage.getValue(StorageKeys.USER_ID_KEY) as String?;
        if (userId == null) {
            System.println("WakeAlarmManager: no user ID found, falling back to endWakeTime");
            scheduleAlarmAtEpoch(_wakeEndEpoch);
            return;
        }
        // Build sleep payload to analyze sleep data and get handoff epoch
        var payload = SleepAnalyzer.buildSleepPayload(userId);
        if (payload == null) {
            System.println("WakeAlarmManager: could not build sleep payload, falling back to endWakeTime");
            scheduleAlarmAtEpoch(_wakeEndEpoch);
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
    // TODO: delete once alarm is fully tested
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
            TimerConstants.RING_TASK_ID,
            TimerConstants.RING_INTERVAL_SEC,
            method(:_onRingTick)
            );
    }

    function stopRinging() {
        _isRinging = false;
        getApp().getSharedTimerManager().unregisterTask(TimerConstants.RING_TASK_ID);
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

    function finishAlarmSession() as Void {
        stopRinging();
        stopPodcastPolling();

        _podcastReady = false;
        _alarmEpoch = null;
        _resetAlarm = true;

        getApp().updateUserInfo(method(:onReceive));
        _prefPollPending = true; 
        getApp().getSharedTimerManager().registerRepeatingTask(
            TimerConstants.ONBOARDING_LONG_PREF_POLL_ID,
            TimerConstants.ONBOARDING_LONG_PREF_POLL_INTERVAL,
            method(:pollPreferences)
        );
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

        _podcastPollPending = true;

        getApp().getSharedTimerManager().registerRepeatingTask(
            TimerConstants.PODCAST_POLL_TASK_ID,
            TimerConstants.PODCAST_POLL_INTERVAL_SEC,
            method(:_pollPodcastStatus)
        );

        _pollPodcastStatus();
    }

    function stopPodcastPolling() as Void {
        getApp().getSharedTimerManager().unregisterTask(TimerConstants.PODCAST_POLL_TASK_ID);
        _podcastPollPending = false;
    }

    function _pollPodcastStatus() as Void {
        if (!_alarmShowing || !_podcastPollPending) { return; }
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
        if (_prefPollPending == false) {
            return;
        }
        getApp().updateUserInfo(method(:onReceive));
    }

    function onReceive(
        responseCode as Number,
        data as Dictionary?,
        context as Object
    ) as Void {
        //handle HTTP/web responses and update the on-screen status.
        var label = context.toString();
        if (responseCode == 200 or responseCode == 201) {
            getApp().setHttpStatus(label + " ok");
            //response body may come back as Dictionary or null
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
                        _resetAlarm = false;  // reset the flag after handling the change
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