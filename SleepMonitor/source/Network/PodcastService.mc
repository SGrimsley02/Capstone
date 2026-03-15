/*
Name: source/Network/PodcastService.mc
Description: Implements the PodcastProvider class responsible for communicating with 
             the AWS Lambda backend to check podcast status and trigger playback.
             This modular design keeps the API logic separate from the alarm management.
Authors: Audrey Pan
Created: March 2, 2026
Last Modified: March 2, 2026
*/

import Toybox.Communications;
import Toybox.Lang;
import Toybox.System;
import Toybox.Application;

class PodcastProvider {
    private var _username;
    private var _notifyBaseUrl = "https://fopzwr25foju62tnwa3hqyk6su0utwkh.lambda-url.us-east-2.on.aws/";
    private var _statusCallback;

    function initialize() { 
        var stored = Application.Storage.getValue("user_id");
        _username = stored != null ? stored.toString() : "test_user42"; //Fall back to defaul username if not yet set
        System.println("PodcastProvider user_id: " + _username);
    }

    // Requests the status of the podcast.
    // Callback must accept (responseCode as Number, isReady as Boolean)
    function checkStatus(callback) as Void {
        var url = _notifyBaseUrl + "?action=status&userId=" + _username;
        _statusCallback = callback;

        try {
            // Fix: Casting literals to the specific Enum types required by the PolyType
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
        }
    }

    // Opens the generated podcast on the user's phone via browser.
    function openPodcast() as Void {
        var url = _notifyBaseUrl + "?action=open&userId=" + _username;
        try {
            System.println("Attempting openWebPage: " + url);
            Communications.openWebPage(url, null, null);
            System.println("openWebPage call completed.");
        } catch (ex) {
            System.println("openWebPage FAILED: " + ex.toString());
        }
    }

    function _onPodcastStatusResponse(responseCode as Lang.Number, data as Lang.Dictionary or Lang.String or Null) as Void {
        var isReady = false;

        if (responseCode == 200 && data != null) {
            if (data instanceof Lang.Dictionary) {
                var dict = data as Lang.Dictionary;

                var statusVal = dict.get("status");

                // USE .equals() and .toString() to bridge the Symbol/String gap
                if (statusVal != null && statusVal.toString().equals("READY")) {
                    isReady = true;
                    System.println("Podcast READY (dict match)");
                } else {
                    System.println("Podcast NOT ready (dict): " + dict.toString());
                }
            } else {
                // Fallback for raw string data
                var bodyStr = data.toString();
                if (bodyStr.find("READY") != null) {
                    isReady = true;
                    System.println("Podcast READY (string match)");
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