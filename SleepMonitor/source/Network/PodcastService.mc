/*
Name: source/Network/PodcastService.mc
Description: Implements the PodcastProvider class responsible for communicating with
             the AWS Lambda backend to check podcast status and trigger playback.
             This modular design keeps the API logic separate from the alarm management.
Authors: Audrey Pan
Created: March 2, 2026
Last Modified: April 5, 2026
*/

import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Application;
import StorageKeys;

class PodcastProvider {
    private var _notifyBaseUrl = "https://fopzwr25foju62tnwa3hqyk6su0utwkh.lambda-url.us-east-2.on.aws/";
    private var _statusCallback;

    function initialize() {
        System.println("PodcastProvider initialized.");
    }

    private function _getStoredUsername() as String or Null {
        var stored = Application.Storage.getValue(StorageKeys.USER_ID_KEY);
        if (stored == null) {
            System.println("PodcastProvider: no stored user ID found.");
            return null;
        }

        var username = stored.toString();
        if (username.length() == 0) {
            System.println("PodcastProvider: stored user ID is empty.");
            return null;
        }

        return username;
    }

    // Requests the status of the podcast.
    // Callback must accept (responseCode as Number, isReady as Boolean)
    function checkStatus(callback) as Void {
        var username = _getStoredUsername();
        _statusCallback = callback;

        if (username == null) {
            System.println("PodcastProvider: cannot check podcast status without a valid user ID.");
            if (_statusCallback != null) {
                _statusCallback.invoke(-1, false);
            }
            return;
        }

        var url = _notifyBaseUrl + "?action=status&userId=" + username;

        try {
            Communications.makeWebRequest(
                url,
                null,
                {
                    :method => Communications.HTTP_REQUEST_METHOD_GET,
                    :responseType => Communications.HTTP_RESPONSE_CONTENT_TYPE_JSON
                },
                method(:_onPodcastStatusResponse)
            );
        } catch (ex) {
            System.println("pollPodcastStatus FAILED: " + ex.toString());
            if (_statusCallback != null) {
                _statusCallback.invoke(-1, false);
            }
        }
    }

    // Opens the generated podcast on the user's phone via browser.
    function openPodcast() as Void {
        var username = _getStoredUsername();
        if (username == null) {
            System.println("PodcastProvider: cannot open podcast without a valid user ID.");
            return;
        }

        var url = _notifyBaseUrl + "?action=open&userId=" + username;

        try {
            System.println("Attempting openWebPage: " + url);
            Communications.openWebPage(url, null, null);
            System.println("openWebPage call completed.");
        } catch (ex) {
            System.println("openWebPage FAILED: " + ex.toString());
        }
    }

    private function _isReadyStatusString(bodyStr as String) as Boolean {
        // Exact match
        if (bodyStr.equals("READY")) {
            return true;
        }
        // JSON-style response
        if (bodyStr.find("\"status\":\"READY\"") != null) {
            return true;
        }
        return false;
    }

    function _onPodcastStatusResponse(
        responseCode as Lang.Number,
        data as Lang.Dictionary or Lang.String or Null
    ) as Void {
        var isReady = false;

        if (responseCode == 200 && data != null) {
            if (data instanceof Lang.Dictionary) {
                var dict = data as Lang.Dictionary;
                var statusVal = dict.get("status");

                if (statusVal != null && statusVal.toString().equals("READY")) {
                    isReady = true;
                    System.println("Podcast READY (dict match)");
                } else {
                    System.println("Podcast NOT ready (dict): " + dict.toString());
                }
            } else {
                var bodyStr = data.toString();

                if (_isReadyStatusString(bodyStr)) {
                    isReady = true;
                    System.println("Podcast READY (string match)");
                } else {
                    System.println("Podcast NOT ready (string): " + bodyStr);
                }
            }
        } else {
            System.println("podcast status bad response: " + responseCode);
        }

        if (_statusCallback != null) {
            _statusCallback.invoke(responseCode, isReady);
        }
    }
}