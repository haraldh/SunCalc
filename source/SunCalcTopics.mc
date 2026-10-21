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

// Application.Properties needs API 2.4. Older devices (none of them has a
// glance) go through the app instance AB instead, like getPropertyDef();
// a missing symbol is not an exception, so this must be a `has` check.
(:glance)
function readProperty(key) {
    if (App has :Properties) {
        return App.Properties.getValue(key);
    }
    return AB != null ? AB.getProperty(key) : null;
}

function writeProperty(key, value) {
    if (App has :Properties) {
        App.Properties.setValue(key, value);
        return;
    }
    if (AB != null) {
        AB.setProperty(key, value);
    }
}

// Read a property with a fallback. Safe in the glance process (no Rez/AB
// access) and in unit tests (no app instance) because it goes straight to
// the properties and swallows any lookup failure.
(:glance)
function getConfig(key, def) {
    try {
        var v = readProperty(key);
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
//
// Uses Properties, not Storage: the glance process can read Properties (see
// getConfig) but Application.Storage is not available there and crashes it.
// lastLat/lastLng are declared in settings.xml with an out-of-range sentinel
// default so an unset value is distinguishable from a real fix.
function saveLoc(loc as Lang.Array) {
    try {
        writeProperty("lastLat", loc[0]);
        writeProperty("lastLng", loc[1]);
    } catch (e) {
    }
}

// [lat, lng] in radians from the last saved fix, or null if none.
(:glance)
function loadStoredLoc() {
    try {
        var lat = readProperty("lastLat");
        var lng = readProperty("lastLng");
        // valid latitude in radians is within +/- pi/2; the sentinel is 999
        if (lat != null && lng != null && lat >= -2.0 && lat <= 2.0) {
            return [lat, lng];
        }
    } catch (e) {
    }
    return null;
}
