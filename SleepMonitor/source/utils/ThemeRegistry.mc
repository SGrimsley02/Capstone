import Toybox.Graphics;
import Colors;

module ThemeRegistry {
    // LIGHT_MODE
    const LIGHT_MODE = {
        "bg"           => Colors.ALICE_BLUE,
        "logo"         => Colors.POWDER_BLUSH,
        "time"         => Colors.STORMY_TEAL,
        "date_am_pm"   => Colors.DARK_CYAN,
        "line"         => Colors.DARK_CYAN,
        "alarm_music"  => Colors.ROSEWOOD,
        "podcast_btn"  => Colors.STORMY_TEAL,
        "podcast_icon" => Colors.POWDER_BLUSH,
        "arc"          => Colors.ALMOND_SILK,
        "music_btn"    => Colors.TANGERINE_DREAM,

        // ALARM SPECFIC
        "alarm_podcast_music" => Colors.TANGERINE_DREAM,
        "alarm_snooze_dismiss" => Colors.ROSEWOOD,
        "alarm_pill_bg" => Colors.ALICE_BLUE,
        "alarm_pill_outline" => Colors.POWDER_BLUSH,
        "alarm_pill_text" => Colors.STORMY_TEAL,
        "alarm_bubble1" => Colors.STORMY_TEAL,
        "alarm_bubble2" => Colors.TANGERINE_DREAM,
        "is_dismissed" => Colors.DARK_CYAN,

        //PLAYBACK VIEW
        "playback_controls" => Colors.ROSEWOOD,
        "playback_song_name" => Colors.STORMY_TEAL,
        "playback_artist_name" => Colors.DARK_CYAN,
        "playback_volume" => Colors.TANGERINE_DREAM,
        "playback_star" => Colors.GOLD,

        //VOLUME VIEW
        "volume" => Colors.STORMY_TEAL,
        "volume_bg" => Colors.GRAY_DARK,
        "volume_percentage" => Colors.ROSEWOOD,

        //RATING VIEW
        "rating_title" => Colors.STORMY_TEAL,
        "rating_hint" => Colors.DARK_CYAN,
        "rating_filled_star" => Colors.GOLD,
        "rating_unfilled_star" => Colors.STAR_GRAY,
        "rating_song_name" => Colors.TANGERINE_DREAM
    };

    // DARK DEFAULT
    const DARK_DEFAULT = {
        "bg"           => Graphics.COLOR_BLACK,
        "logo"         => Colors.PURPLE_LITE,
        "time"         => Graphics.COLOR_WHITE,
        "date_am_pm"   => Colors.GRAY_MID,
        "line"         => Colors.GRAY_DARK,
        "alarm_music"  => Colors.TEAL_LITE,
        "podcast_btn"  => Colors.PURPLE_DARK,
        "podcast_icon" => Colors.PURPLE_LITE,
        "arc"          => Colors.PURPLE_MID,
        "music_btn"    => Colors.TEAL_DARK,

        // ALARM SPECFIC...if var starts with alarm then it's for the alarm view
        "alarm_podcast_music" => Colors.PURPLE_MID,
        "alarm_snooze_dismiss" => Colors.TEAL_LITE,
        "alarm_pill_bg" => Graphics.COLOR_BLACK,
        "alarm_pill_outline" => Colors.PURPLE_LITE,
        "alarm_pill_text" => Graphics.COLOR_WHITE,
        "alarm_bubble1" => Colors.PURPLE_DARK,
        "alarm_bubble2" => Colors.TEAL_DARK,
        "is_dismissed" => Colors.PURPLE_LITE,

        //PLAYBACK VIEW
        "playback_controls" => Colors.TEAL_LITE,
        "playback_song_name" => Graphics.COLOR_WHITE,
        "playback_artist_name" => Colors.GRAY_MID,
        "playback_volume" => Colors.PURPLE_MID,
        "playback_star" => Colors.GOLD,

        //VOLUME VIEW
        "volume" => Colors.TEAL_LITE,
        "volume_bg" => Colors.GRAY_DARK,
        "volume_percentage" => Graphics.COLOR_WHITE,

        //RATING VIEW
        "rating_title" => Graphics.COLOR_WHITE,
        "rating_hint" => Colors.GRAY_MID,
        "rating_filled_star" => Colors.GOLD,
        "rating_unfilled_star" => Colors.STAR_GRAY,
        "rating_song_name" => Graphics.COLOR_WHITE
    };

    const THEMES = {
        "light" => LIGHT_MODE,
        "dark"   => DARK_DEFAULT
    };
}
