'''
This program handles recommending songs to users based on their ratings.
Implements the SongRecommender class, interacting with MusicAPI and database
to get user data and update playlists.
- createInitialPlaylists: creates initial playlists for the user based on their top and saved songs
- updateAllPlaylists: updates all playlists for the user based on their latest ratings

Last updated: 4.17.26
By: Kiara
'''

from MusicAPI import MusicAPI

class SongRecommender:
    def __init__(self, userId: str, userSecret: str, remixUsername: str):
        '''
        Initialize the SongRecommender with the MusicAPI.
        Input:
        userId[str] = the Spotify client ID for the user
        userSecret[str] = the Spotify client secret for the user
        remixUsername[str] = the REMix username for the user
        '''
        self.music_api = MusicAPI(spotify_client_id=userId, spotify_client_secret=userSecret)
        self.username = remixUsername
        self.user_podcasts = self.createInitialPlaylists()

    # ===============================
    # Playlist Management Functions
    # ===============================

    def createInitialPlaylists(self) -> dict:
        '''
        Create initial playlists for the user.
        Good, Average, Bad sleep playlists depending on how well they slept.
        Initial songs recommended based on their top and saved songs.

        Output:
        playlist_ids[dict] = a dictionary containing the playlist IDs for the user
        '''

        playlist_ids = {
            "goodSleep": self.music_api.create_playlist(name="REMix: Good Sleep", public=False, description=""),
            "averageSleep": self.music_api.create_playlist(name="REMix: Average Sleep", public=False, description=""),
            "badSleep": self.music_api.create_playlist(name="REMix: Bad Sleep", public=False, description="")
        }

        # Initialize user's playlists with songs based on their top songs and saved songs
        top_songs = self.music_api.get_user_top_tracks(time_range="medium_term", limit=50)
        saved_songs = self.music_api.get_user_saved_tracks(limit=50)
        seeds = [song["uri"] for song in top_songs + saved_songs]

        # Good sleep -> energetic
        # Neutral sleep -> lofi, calm
        # Bad sleep -> slow, instrumental

        good_sleep_songs = self.music_api.get_recommendations(
            size=20,
            seeds=seeds,
            danceability=0.8,
            energy=0.8,
            valence=0.8,
            popularity=80,
            mode=1,
            featureWeight=4.0
        )
        average_sleep_songs = self.music_api.get_recommendations(
            size=20,
            seeds=seeds,
            danceability=0.4,
            acousticness=0.8,
            energy=0.5,
            instrumentalness=0.2,
            liveness=0.4,
            popularity=70,
            featureWeight=2.5
        )
        bad_sleep_songs = self.music_api.get_recommendations(
            size=20,
            seeds=seeds,
            danceability=0.2,
            acousticness=0.9,
            energy=0.2,
            instrumentalness=0.6,
            liveness=0.4,
            mode=0,
            valence=0.4,
            popularity=70,
            featureWeight=4.0
        )
        self.addSongsToPlaylist(playlist_ids["goodSleep"], [song["uri"] for song in good_sleep_songs])
        self.addSongsToPlaylist(playlist_ids["averageSleep"], [song["uri"] for song in average_sleep_songs])
        self.addSongsToPlaylist(playlist_ids["badSleep"], [song["uri"] for song in bad_sleep_songs])

        # TODO: Store playlist IDs in database for the user

        return playlist_ids

    def updateAllPlaylists(self) -> None:
        '''
        Update all playlists for the user based on their latest ratings.
        '''

        for sleep_quality in ("good", "average", "bad"): # Yes I'm too lazy to hard code all three
            new_recommendations = self.recommendSongs(sleep_quality)
            # NOTE: Remove will come here in either implementation choice
            # removed_songs = self.getNegativeSeeds(sleep_quality) # If only remove poorly rated songs
            # self.removeSongsFromPlaylist(self.user_podcasts[sleep_quality])
            self.addSongsToPlaylist(self.user_podcasts[sleep_quality], new_recommendations)

    # ===============================
    # Helper Functions
    # ===============================

    def getPositiveSeeds(self, sleep_quality: str) -> list:
        '''
        Get positive seed songs for the user from the db ratings based on their sleep quality.

        Input:
        sleep_quality[str] = the user's sleep quality

        Output:
        positive_seeds[list] = a list of song URIs with ratings >=4 for the given sleep quality
        '''
        # TODO: Query DB
        pass

    def getNegativeSeeds(self, sleep_quality: str) -> list:
        '''
        Get negative seed songs for the user from the db ratings based on their sleep quality.

        Input:
        sleep_quality[str] = the user's sleep quality

        Output:
        negative_seeds[list] = a list of song URIs with ratings < 4 for the given sleep quality
        '''
        # TODO: Query DB
        pass


    def recommendSongs(self, sleep_quality: str) -> list: # TODO: refactor to take positive and negative seeds
        '''
        Get recommended songs for the user based on their sleep quality.
        '''
        positive_seeds = self.getPositiveSeeds(sleep_quality)
        negative_seeds = self.getNegativeSeeds(sleep_quality)

        # If we don't have enough positive seeds, grab from existing playlist to fill in gaps
        if len(positive_seeds) < 5:
            previous_songs =self.music_api.get_playlist_item(playlist_id=self.user_podcasts[sleep_quality], limit=10)
            positive_seeds += [song["uri"] for song in previous_songs if song["uri"] not in positive_seeds and song["uri"] not in negative_seeds]

        # Not using feature params here, want to allow for drift over time to fit user's preferences
        new_recommendations = self.music_api.get_recommendations(
            size=20,                        # TODO: Number depends if we're adding or replacing songs
            seeds=positive_seeds,
            negativeSeeds=negative_seeds
        )

        return [song["uri"] for song in new_recommendations]

    def addSongsToPlaylist(self, playlist_id: str, song_ids: list) -> None:
        '''
        Add songs to the user's playlist.

        Input:
        playlist_id[str] = the Spotify playlist ID to add songs to
        song_ids[list] = a list of Spotify song URIs to add to the playlist
        '''
        self.music_api.add_tracks_to_playlist(playlist_id=playlist_id, track_ids=song_ids)

    def removeSongsFromPlaylist(self, playlist_id: str, song_ids: list) -> None:
        '''
        Remove songs from the user's playlist.

        Input:
        playlist_id[str] = the Spotify playlist ID to remove songs from
        song_ids[list] = a list of Spotify song URIs to remove from the playlist
        '''
        # TODO: Implementation question, do we want playlists to grow forever or new weekly?
        # If forever, this will remove poorly rated songs. If weekly, this will empty the playlist
        # For now leaving this as a placeholder, and I'll ask at sprint meeting. Replace weekly is my vote though
        self.music_api.remove_tracks_from_playlist(playlist_id=playlist_id, track_ids=song_ids)
