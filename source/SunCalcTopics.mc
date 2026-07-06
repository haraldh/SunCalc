using Toybox.Application as App;
using Toybox.Lang;

// The twilight "topics" the user can choose for the two ring rows and for
// the glance. Each entry is
//   [ title, morning event, evening event, morning label, evening label ]
// The title is shown centered on the ring; the short labels prefix the
// glance countdown ("Sunset 6h 12m"). Indices are stored in the number
// properties ringTop / ringBottom / glanceTopic, so their order is API and
// must match the <listEntry> values in resources/settings.xml.
//
// Annotated (:glance) so the (glance-only) build can see the table too; the
// enum column names come from SunCalcEnum.mc which is also (:glance).
(:glance)
var TOPICS as Lang.Array<Lang.Array> = [
    [ "Sunrise / Sunset", SUNRISE, SUNSET, "Sunrise", "Sunset" ],
    [ "Civil Twilight", DAWN, DUSK, "Dawn", "Dusk" ],
    [ "Nautical Twil.", NAUTIC_DAWN, NAUTIC_DUSK, "N.Dawn", "N.Dusk" ],
    [ "Astro Twilight", ASTRO_DAWN, ASTRO_DUSK, "A.Dawn", "A.Dusk" ],
    [ "Blue Hour", BLUE_HOUR_AM, BLUE_HOUR_PM, "Blue Hr", "Blue Hr" ],
    [ "Golden Hour", GOLDEN_HOUR_AM, GOLDEN_HOUR_PM, "Golden", "Golden" ]
];

// Read a property with a fallback. Safe in the glance process (no Rez/AB
// access) and in unit tests (no app instance) because it goes straight to
// Application.Properties and swallows any lookup failure.
(:glance)
function getConfig(key, def) {
    try {
        var v = App.Properties.getValue(key);
        if (v != null) {
            return v;
        }
    } catch (e) {
    }
    return def;
}

// Validated topic index for a number property.
(:glance)
function topicFor(key, def) {
    var v = getConfig(key, def);
    if (!(v instanceof Lang.Number) || v < 0 || v >= TOPICS.size()) {
        return def;
    }
    return v;
}

// Persist the last good position (radians) so the glance can still show data
// when the device's own cached GPS fix is stale or unavailable - the glance
// only reads Pos.getInfo() and never acquires a fix itself.
function saveLoc(loc) {
    try {
        App.Storage.setValue("lastLat", loc[0]);
        App.Storage.setValue("lastLng", loc[1]);
    } catch (e) {
    }
}

// [lat, lng] in radians from storage, or null if never saved.
(:glance)
function loadStoredLoc() {
    try {
        var lat = App.Storage.getValue("lastLat");
        var lng = App.Storage.getValue("lastLng");
        if (lat != null && lng != null) {
            return [lat, lng];
        }
    } catch (e) {
    }
    return null;
}
