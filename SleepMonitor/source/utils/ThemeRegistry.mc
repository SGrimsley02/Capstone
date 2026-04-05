import Toybox.Graphics;
import Colors;

module ThemeRegistry {
    // DESERT MIST (Your 9-color palette)
    const DESERT_MIST = {
        "bg"           => Colors.ALICE_BLUE,
        "logo"         => Colors.POWDER_BLUSH,
        "time"         => Colors.STORMY_TEAL,
        "date_am_pm"   => Colors.DARK_CYAN,
        "line"         => Colors.DARK_CYAN,
        "alarm_music"  => Colors.ROSEWOOD,
        "podcast_btn"  => Colors.STORMY_TEAL,
        "podcast_icon" => Colors.POWDER_BLUSH,
        "arc"          => Colors.ALMOND_SILK,
        "music_btn"    => Colors.TANGERINE_DREAM
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
        "music_btn"    => Colors.TEAL_DARK
    };

    const THEMES = {
        "light" => DESERT_MIST,
        "dark"   => DARK_DEFAULT
    };
}
