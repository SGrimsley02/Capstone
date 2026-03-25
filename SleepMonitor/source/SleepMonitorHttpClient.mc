/*
Name: source/SleepMonitorHttpClient.mc
Description: Networking client for the SleepMonitor Connect IQ watch app.
             Wraps Communications.makeWebRequest() for DEV test calls (GET local, GET public HTTPS,
             POST simulated sleep payload) and updates the UI with status messages.
Authors: Audrey Pan, Lauren D'Souza
Created: February 14, 2026
Last Modified: March 1st, 2026

PLEASE READ:
- CURRENTLY CODE:
  - Provides local HTTP + public HTTPS + POST test paths triggered manually from menu items.
  - Sends simulated/hardcoded sleep data.
- LATER IMPLEMENT:
  - Remove local HTTP test flows and menu items.
  - Add batching/streaming logic (automatic background sends) instead of manual menu-triggered POST.
*/

import Toybox.Application;
import Toybox.Communications;
import Toybox.Lang;
import Toybox.PersistedContent;
import Toybox.SensorHistory;
import Toybox.System;
import Toybox.Time;
import Toybox.WatchUi;

// URL to AWS API Gateway endpoint
const BASE_URL = "https://kyajhve0ek.execute-api.us-east-2.amazonaws.com/dev/";
const USER_ID_KEY = "username";
const WAKE_START_KEY = "wakeStart";
const WAKE_END_KEY = "wakeEnd";

class SleepMonitorHttpClient {

    private var _wakeAlarmManager; // Reference to the alarm manager for potential future use (e.g., triggering podcast status checks)

    function initialize() {
        _wakeAlarmManager = new WakeAlarmManager(); 
        // Purpose: Construct the HTTP client (no state needed currently).
    }

    function sendLocalHttpRequest() as Void {
        // GET request to a local server (mainly useful in simulator/dev).
        // TODO: remove this path and its menu item.
        var url = "http://127.0.0.1:5000/";
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN,
            :context => "LOCAL_HTTP"
        };

        makeRequest(url, null, options);
    }

    function sendPublicHttpsRequest(url as String) as Void {
        // GET request to the ngrok public HTTPS URL (proves HTTPS works).
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :context => "PUBLIC_HTTPS",
            :timeout      => 15,
        };

        makeRequest(url, null, options);
    }

    function sendPostTestRequest() as Void {
        // POST request that sends simulated sleep data to the backend.
        // TODO: replace URL, remove ngrok header
        var url = BASE_URL + "upload";
        var userId = getUserId();
        if (userId == null) {
            System.println("No user ID found in storage. Cannot send sleep summary.");
            return;
        }
        var params = SleepAnalyzer.buildSleepPayload(userId);

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN,
            :context => "SLEEP_POST",
            :headers => {
                // With a Dictionary params + POST, the SDK sends a form-urlencoded body.
                // TODO: if backend expects JSON, change Content-Type and send JSON string instead.
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED,
                "Accept" => "text/plain",
                //remove once backend is set up
                "ngrok-skip-browser-warning" => "true"
            }
        };

        System.println("POST payload: " + params.toString());
        makeRequest(url, params, options);
    }

    function sendSleepSummaryRequest() as Void {
        // POST request that sends a nightly summary for the last sleep window.
        var url = BASE_URL + "sleep-summary";

        var userId = getUserId();
        if (userId == null) {
            System.println("No user ID found in storage. Cannot send sleep summary.");
            return;
        }

        var params = SleepAnalyzer.buildSleepPayload(userId);
        if (params != null && _wakeAlarmManager != null) {
            _wakeAlarmManager.scheduleAlarmFromSleepPayload(params);
        }

        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_POST,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_TEXT_PLAIN,
            :context => "SLEEP_SUMMARY",
            :headers => {
                "Content-Type" => Communications.REQUEST_CONTENT_TYPE_URL_ENCODED,
                "Accept" => "text/plain"
            }
        };

        if (params == null) {
            // TODO replace with proper error handling once we have real sleep data
            params = {
                "eventType" => "sleep_summary",
                "timestamp" => "",
                "username" => "demo",
                "sleepQuality" => 0
            };
            System.println("No applicable sensor history could be extracted for sleep window.");
        }

        System.println("POST sleep summary: " + params.toString());
        makeRequest(url, params, options);
    }

    function getUserInfo() {
        var url = BASE_URL + "user";
        var username = getUserId();
        if (username == null) {
            System.println("No user ID found in storage.");
            return;
        }
        var params = {"username" => username};
        var options = {
            :method => Communications.HTTP_REQUEST_METHOD_GET,
            :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON,
            :context => "USER_INFO",
            :timeout      => 15,
        };
        makeRequest(url, params, options);

    }

    private function makeRequest(
        url as String,
        params as Dictionary or Null,
        options as Dictionary
    ) as Void {
        // shared wrapper around Communications.makeWebRequest() that adds error handling and UI status updates.
        try {
            options[:contentType] = Communications.REQUEST_CONTENT_TYPE_JSON;
            setStatus("Sending " + options[:context].toString());
            System.println("Sending request: " + options[:context] + " -> " + url);
            System.println("About to call makeWebRequest");
            Communications.makeWebRequest(url, params, options, method(:onReceive));
        } catch (ex) {
            // catch setup errors before request completes
            setStatus("Setup failed");
            System.println("Request setup failed: " + ex.toString());
        }
    }

    function onReceive(
        responseCode as Number,
        data as Dictionary or String or PersistedContent.Iterator or Null,
        context as Object
    ) as Void {
        //handle HTTP/web responses and update the on-screen status.
        var label = context.toString();
        if (responseCode == 200 or responseCode == 201) {
            setStatus(label + " ok");
            //response body may come back as Dictionary, String, Iterator, null
            if (data instanceof Dictionary) {
                System.println(label + " success. JSON response: " + data.toString());
                var preferences = data["preferences"];
                var wakeStart = preferences["wakeStart"] as String?;
                var wakeEnd = preferences["wakeEnd"] as String?;
                if (wakeStart != null && wakeEnd != null) {
                    setWakeStart(wakeStart);
                    setWakeEnd(wakeEnd);
                    System.println("Updated wake times from response: " + wakeStart + " - " + wakeEnd);
                }

            } else if (data != null) {
                System.println(label + " success. Body: " + data.toString());
            } else {
                System.println(label + " success with empty body.");
            }
        } else {
            setStatus(label + " err " + responseCode.toString());
            System.println(label + " failed. Response code: " + responseCode.toString());
        }
    }

    private function setStatus(message as String) as Void {
        //store status in-memory and request a UI redraw
        getApp().setHttpStatus(message);
        WatchUi.requestUpdate();
    }

    static function setUserId(userId as String) as Void {
        Application.Storage.setValue(USER_ID_KEY, userId);
    }

    private function getUserId() as String or Null {
        return Application.Storage.getValue(USER_ID_KEY) as String?;
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

        _wakeAlarmManager.scheduleAlarmAtEpoch(wakeEpoch);
    }

    static function setWakeStart(wakeStartTime as String) as Void {
        Application.Storage.setValue(WAKE_START_KEY, wakeStartTime);
    }

    static function getWakeStart() as String or Null {
        return Application.Storage.getValue(WAKE_START_KEY) as String?;
    }

    static function setWakeEnd(wakeEndTime as String) as Void {
        Application.Storage.setValue(WAKE_END_KEY, wakeEndTime);
    }

    static function getWakeEnd() as String or Null {
        return Application.Storage.getValue(WAKE_END_KEY) as String?;
    }
}
