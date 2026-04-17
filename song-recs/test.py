"""
Test file for MusicAPI

Test suite for MusicAPI class.

Run all tests:
    python -m pytest test_music_api.py -v

Run a specific test:
    python -m pytest test_music_api.py::TestSpotify::test_create_playlist -v

Run with coverage:
    python -m pytest test_music_api.py -v --tb=short

last updated: 4.17.26
by: Reeny
"""

import pytest
from unittest.mock import patch, MagicMock
from MusicAPI import MusicAPI


CLIENT_ID     = "fake_client_id"
CLIENT_SECRET = "fake_client_secret"
FAKE_TOKEN    = "fake_access_token"
PLAYLIST_ID   = "playlist_abc123"
TRACK_URI     = "spotify:track:4iV5W9uYEdYUVa79Axb7Rh"
TRACK_ID      = "4iV5W9uYEdYUVa79Axb7Rh"


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def make_mock_response(json_data: dict, status_code: int = 200) -> MagicMock:
    mock = MagicMock()
    mock.status_code = status_code
    mock.json.return_value = json_data
    mock.raise_for_status = MagicMock()
    return mock


def make_track_item(name="Test Track", artist="Test Artist"):
    return {
        "track": {
            "name": name,
            "artists": [{"name": artist}],
            "uri": TRACK_URI,
            "id": TRACK_ID,
        }
    }


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def api():
    """Return a fresh MusicAPI instance with a pre-cached token."""
    instance = MusicAPI(CLIENT_ID, CLIENT_SECRET)
    instance.spotify_token = FAKE_TOKEN
    return instance


# ---------------------------------------------------------------------------
# Auth
# ---------------------------------------------------------------------------

class TestAuth:
    def test_get_spotify_token_success(self):
        api = MusicAPI(CLIENT_ID, CLIENT_SECRET)
        mock_resp = make_mock_response({"access_token": FAKE_TOKEN})
        with patch("requests.post", return_value=mock_resp) as mock_post:
            token = api._get_spotify_token()
            assert token == FAKE_TOKEN
            assert api.spotify_token == FAKE_TOKEN
            mock_post.assert_called_once()

    def test_get_headers_triggers_auth_when_no_token(self):
        api = MusicAPI(CLIENT_ID, CLIENT_SECRET)
        mock_resp = make_mock_response({"access_token": FAKE_TOKEN})
        with patch("requests.post", return_value=mock_resp):
            headers = api._get_headers()
            assert headers["Authorization"] == f"Bearer {FAKE_TOKEN}"

    def test_get_headers_uses_cached_token(self, api):
        with patch("requests.post") as mock_post:
            headers = api._get_headers()
            assert headers["Authorization"] == f"Bearer {FAKE_TOKEN}"
            mock_post.assert_not_called()


# ---------------------------------------------------------------------------
# Spotify — Playlists
# ---------------------------------------------------------------------------

class TestSpotify:
    def test_create_playlist_returns_id(self, api):
        mock_resp = make_mock_response({"id": PLAYLIST_ID}, status_code=201)
        with patch("requests.post", return_value=mock_resp):
            result = api.create_playlist("My Playlist", description="A test playlist")
            assert result == PLAYLIST_ID

    def test_create_playlist_propagates_exception(self, api):
        with patch("requests.post", side_effect=Exception("Network error")):
            with pytest.raises(Exception, match="Network error"):
                api.create_playlist("Bad Playlist")

    # ---- update_playlist_items ----
    # NOTE: current implementation uses requests.get instead of requests.post —
    # the test below documents the existing behaviour and will need updating once
    # the HTTP verb is corrected to POST.
    def test_update_playlist_items_success(self, api):
        mock_resp = make_mock_response({}, status_code=201)
        with patch("requests.put", return_value=mock_resp):
            result = api.update_playlist_items(PLAYLIST_ID, [TRACK_URI])
            assert result is True

    def test_update_playlist_items_failure_status(self, api):
        mock_resp = make_mock_response({}, status_code=400)
        with patch("requests.put", return_value=mock_resp):
            result = api.update_playlist_items(PLAYLIST_ID, [TRACK_URI])
            assert result is False

    def test_update_playlist_items_with_position(self, api):
        mock_resp = make_mock_response({}, status_code=201)
        with patch("requests.put", return_value=mock_resp) as mock_get:
            api.update_playlist_items(PLAYLIST_ID, [TRACK_URI], position=0)
            _, kwargs = mock_get.call_args
            assert kwargs["data"]["position"] == 0

    # ---- get_playlist_item ----
    def test_get_playlist_item_returns_parsed_tracks(self, api):
        payload = {"items": [make_track_item("Song A", "Artist A"),
                              make_track_item("Song B", "Artist B")]}
        mock_resp = make_mock_response(payload)
        with patch("requests.get", return_value=mock_resp):
            tracks = api.get_playlist_item(PLAYLIST_ID)
            assert len(tracks) == 2
            assert tracks[0]["title"] == "Song A"
            assert tracks[1]["artist"] == "Artist B"
            assert "uri" in tracks[0] and "id" in tracks[0]

    def test_get_playlist_item_skips_null_tracks(self, api):
        payload = {"items": [{"track": None}, make_track_item()]}
        mock_resp = make_mock_response(payload)
        with patch("requests.get", return_value=mock_resp):
            tracks = api.get_playlist_item(PLAYLIST_ID)
            assert len(tracks) == 1

    # ---- remove_playlist_item ----
    def test_remove_playlist_item_success(self, api):
        mock_resp = make_mock_response({}, status_code=200)
        with patch("requests.delete", return_value=mock_resp):
            result = api.remove_playlist_item(PLAYLIST_ID, [TRACK_URI])
            assert result is True

    def test_remove_playlist_item_sends_correct_body(self, api):
        mock_resp = make_mock_response({}, status_code=200)
        with patch("requests.delete", return_value=mock_resp) as mock_del:
            api.remove_playlist_item(PLAYLIST_ID, [TRACK_URI])
            _, kwargs = mock_del.call_args
            assert kwargs["data"] == {"tracks": [{"uri": TRACK_URI}]}


# ---------------------------------------------------------------------------
# Spotify — User Data
# ---------------------------------------------------------------------------

class TestSpotifyUser:
    def test_get_user_saved_tracks(self, api):
        payload = {"items": [make_track_item("Liked Song", "Some Artist")]}
        mock_resp = make_mock_response(payload)
        with patch("requests.get", return_value=mock_resp):
            tracks = api.get_user_saved_tracks(limit=1)
            assert len(tracks) == 1
            assert tracks[0]["title"] == "Liked Song"

    def test_get_user_top_tracks_default_time_range(self, api):
        payload = {"items": [{"name": "Top Track", "artists": [{"name": "Star"}],
                               "uri": TRACK_URI, "id": TRACK_ID}]}
        mock_resp = make_mock_response(payload)
        with patch("requests.get", return_value=mock_resp) as mock_get:
            tracks = api.get_user_top_tracks()
            assert tracks[0]["title"] == "Top Track"
            _, kwargs = mock_get.call_args
            assert kwargs["data"]["time_range"] == "medium_term"

    def test_get_user_top_tracks_short_term(self, api):
        mock_resp = make_mock_response({"items": []})
        with patch("requests.get", return_value=mock_resp) as mock_get:
            api.get_user_top_tracks(time_range="short_term")
            _, kwargs = mock_get.call_args
            assert kwargs["data"]["time_range"] == "short_term"

    def test_get_user_artists_returns_artists(self, api):
        payload = {"artists": {"items": [
            {"name": "Band", "id": "artist1", "uri": "spotify:artist:1", "genres": ["rock"]}
        ]}}
        mock_resp = make_mock_response(payload)
        with patch("requests.get", return_value=mock_resp):
            artists = api.get_user_artists()
            assert artists[0]["name"] == "Band"
            assert "rock" in artists[0]["genres"]

    def test_get_user_artists_pagination_after(self, api):
        mock_resp = make_mock_response({"artists": {"items": []}})
        with patch("requests.get", return_value=mock_resp) as mock_get:
            api.get_user_artists(after="artist_cursor_xyz")
            _, kwargs = mock_get.call_args
            assert kwargs["data"]["after"] == "artist_cursor_xyz"


# ---------------------------------------------------------------------------
# ReccoBeats
# ---------------------------------------------------------------------------

class TestReccoBeats:
    RECO_RESPONSE = {
        "content": [
            {"title": "Rec Track 1", "artists": [{"name": "Rec Artist 1"}], "id": "rec_id_1"},
            {"title": "Rec Track 2", "artists": [{"name": "Rec Artist 2"}], "id": "rec_id_2"},
        ]
    }

    def test_get_recommendations_basic(self, api):
        mock_resp = make_mock_response(self.RECO_RESPONSE)
        with patch("requests.request", return_value=mock_resp):
            recs = api.get_recommendations(size=2, seeds=[TRACK_ID],
                                           negative_seeds=None, acousticness=None,
                                           danceability=None, energy=None,
                                           instrumentalness=None, key=None,
                                           liveness=None, loudness=None,
                                           mode=None, speechiness=None,
                                           tempo=None, valence=None,
                                           popularity=None, featureWeight=None)
            assert len(recs) == 2
            assert recs[0]["title"] == "Rec Track 1"
            assert recs[1]["artist"] == "Rec Artist 2"

    def test_get_recommendations_with_optional_params(self, api):
        mock_resp = make_mock_response(self.RECO_RESPONSE)
        with patch("requests.request", return_value=mock_resp) as mock_req:
            api.get_recommendations(size=5, seeds=[TRACK_ID],
                                    negative_seeds=None, acousticness=0.8,
                                    danceability=0.7, energy=0.6,
                                    instrumentalness=None, key=None,
                                    liveness=None, loudness=None,
                                    mode=None, speechiness=None,
                                    tempo=120.0, valence=None,
                                    popularity=80, featureWeight=3.0)
            _, kwargs = mock_req.call_args
            sent = kwargs["data"]
            assert sent["acousticness"] == 0.8
            assert sent["tempo"] == 120.0
            assert sent["popularity"] == 80
            assert "instrumentalness" not in sent  # None values excluded

    def test_get_recommendations_invalid_size(self, api):
        with pytest.raises(ValueError, match="size must be between 1 and 100"):
            api.get_recommendations(size=0, seeds=[TRACK_ID],
                                    negative_seeds=None, acousticness=None,
                                    danceability=None, energy=None,
                                    instrumentalness=None, key=None,
                                    liveness=None, loudness=None,
                                    mode=None, speechiness=None,
                                    tempo=None, valence=None,
                                    popularity=None, featureWeight=None)

    def test_get_recommendations_empty_seeds(self, api):
        with pytest.raises(ValueError, match="seeds must contain at least one"):
            api.get_recommendations(size=5, seeds=[],
                                    negative_seeds=None, acousticness=None,
                                    danceability=None, energy=None,
                                    instrumentalness=None, key=None,
                                    liveness=None, loudness=None,
                                    mode=None, speechiness=None,
                                    tempo=None, valence=None,
                                    popularity=None, featureWeight=None)

    def test_get_audio_features(self, api):
        payload = {"content": [
            {"id": TRACK_ID, "acousticness": 0.5, "danceability": 0.8,
             "energy": 0.7, "key": 5, "tempo": 130.0, "valence": 0.6}
        ]}
        mock_resp = make_mock_response(payload)
        with patch("requests.request", return_value=mock_resp):
            features = api.get_audio_features([TRACK_ID])
            assert len(features) == 1
            assert features[0]["tempo"] == 130.0
            assert features[0]["danceability"] == 0.8

    def test_get_audio_features_empty_response(self, api):
        mock_resp = make_mock_response({"content": []})
        with patch("requests.request", return_value=mock_resp):
            features = api.get_audio_features([TRACK_ID])
            assert features == []