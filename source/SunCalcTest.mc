// Unit tests. Run with `make test` (or `nix develop -c make test`).
//
// The reference fixtures were pulled from the sunrise-sunset.org API
// (NOAA-style algorithm, times in UTC, "formatted=0"), e.g.:
//   https://api.sunrise-sunset.org/json?lat=70.6632359&lng=23.681726&date=2026-09-19&formatted=0
// Each row is [ anchor, lat, lng, event, expected-epoch-or-null ]. The
// anchor is the API's solar_noon epoch, which pins calculate() to the same
// solar day regardless of longitude/date-line ambiguities. Missing events
// (polar day/night) are encoded by the API as 1970 epochs and stored here
// as null. TOLERANCE covers the refraction-model differences between the
// reference and our implementation (max observed deviation: 199 s).

using Toybox.Lang;
using Toybox.Time as Time;
using Toybox.Position as Pos;

(:test)
module SunCalcTestHelpers {

    const TOLERANCE = 300;

    function makeView(epoch, lat, lng) as SunCalcView {
        // force all rows visible so selection is deterministic
        for (var i = 0; i < DISPLAY.size(); i++) {
            DISPLAY[i][D_SHOW] = true;
        }
        var v = new SunCalcView();
        v.now = new Time.Moment(epoch);
        v.lastLoc = new Pos.Location(
            { :latitude => lat, :longitude => lng, :format => :degrees }
            ).toRadians();
        v.DAY_IN_ADVANCE = 0;
        return v;
    }

    function locOf(lat, lng) {
        return new Pos.Location(
            { :latitude => lat, :longitude => lng, :format => :degrees }
            ).toRadians();
    }

    function near(logger, what, moment, expected) {
        if (moment == null) {
            logger.debug(what + ": expected " + expected + ", got null");
            return false;
        }
        var dev = moment.value().toLong() - expected;
        if (dev < 0) {
            dev = -dev;
        }
        if (dev > TOLERANCE) {
            logger.debug(what + ": expected " + expected + ", got "
                         + moment.value() + " (off by " + dev + "s)");
            return false;
        }
        return true;
    }
}

(:test)
function testReferenceFixtures(logger) {
    var fixtures = [
        [ 1768473279, 70.6632359d, 23.681726d, ASTRO_DAWN, 1768453031 ], // hammerfest 2026-01-15
        [ 1768473279, 70.6632359d, 23.681726d, NAUTIC_DAWN, 1768457721 ], // hammerfest 2026-01-15
        [ 1768473279, 70.6632359d, 23.681726d, DAWN, 1768463550 ], // hammerfest 2026-01-15
        [ 1768473279, 70.6632359d, 23.681726d, SUNRISE, null ], // hammerfest 2026-01-15 (polar night)
        [ 1768473279, 70.6632359d, 23.681726d, NOON, 1768473279 ], // hammerfest 2026-01-15
        [ 1768473279, 70.6632359d, 23.681726d, SUNSET, null ], // hammerfest 2026-01-15 (polar night)
        [ 1768473279, 70.6632359d, 23.681726d, DUSK, 1768483008 ], // hammerfest 2026-01-15
        [ 1768473279, 70.6632359d, 23.681726d, NAUTIC_DUSK, 1768488837 ], // hammerfest 2026-01-15
        [ 1768473279, 70.6632359d, 23.681726d, ASTRO_DUSK, 1768493527 ], // hammerfest 2026-01-15
        [ 1782037625, 70.6632359d, 23.681726d, ASTRO_DAWN, null ], // hammerfest 2026-06-21 (midnight sun)
        [ 1782037625, 70.6632359d, 23.681726d, NAUTIC_DAWN, null ], // hammerfest 2026-06-21
        [ 1782037625, 70.6632359d, 23.681726d, DAWN, null ], // hammerfest 2026-06-21
        [ 1782037625, 70.6632359d, 23.681726d, SUNRISE, null ], // hammerfest 2026-06-21
        [ 1782037625, 70.6632359d, 23.681726d, NOON, 1782037625 ], // hammerfest 2026-06-21
        [ 1782037625, 70.6632359d, 23.681726d, SUNSET, null ], // hammerfest 2026-06-21
        [ 1782037625, 70.6632359d, 23.681726d, DUSK, null ], // hammerfest 2026-06-21
        [ 1782037625, 70.6632359d, 23.681726d, NAUTIC_DUSK, null ], // hammerfest 2026-06-21
        [ 1782037625, 70.6632359d, 23.681726d, ASTRO_DUSK, null ], // hammerfest 2026-06-21
        [ 1789813144, 70.6632359d, 23.681726d, ASTRO_DAWN, null ], // hammerfest 2026-09-19 (twilight boundary)
        [ 1789813144, 70.6632359d, 23.681726d, NAUTIC_DAWN, 1789780937 ], // hammerfest 2026-09-19
        [ 1789813144, 70.6632359d, 23.681726d, DAWN, 1789786113 ], // hammerfest 2026-09-19
        [ 1789813144, 70.6632359d, 23.681726d, SUNRISE, 1789789794 ], // hammerfest 2026-09-19
        [ 1789813144, 70.6632359d, 23.681726d, NOON, 1789813144 ], // hammerfest 2026-09-19
        [ 1789813144, 70.6632359d, 23.681726d, SUNSET, 1789836494 ], // hammerfest 2026-09-19
        [ 1789813144, 70.6632359d, 23.681726d, DUSK, 1789840175 ], // hammerfest 2026-09-19
        [ 1789813144, 70.6632359d, 23.681726d, NAUTIC_DUSK, 1789845350 ], // hammerfest 2026-09-19
        [ 1789813144, 70.6632359d, 23.681726d, ASTRO_DUSK, null ], // hammerfest 2026-09-19
        [ 1782003302, -77.85d, 166.67d, ASTRO_DAWN, 1781987560 ], // mcmurdo 2026-06-21 (antarctic winter)
        [ 1782003302, -77.85d, 166.67d, NAUTIC_DAWN, 1781998386 ], // mcmurdo 2026-06-21
        [ 1782003302, -77.85d, 166.67d, DAWN, null ], // mcmurdo 2026-06-21
        [ 1782003302, -77.85d, 166.67d, SUNRISE, null ], // mcmurdo 2026-06-21
        [ 1782003302, -77.85d, 166.67d, NOON, 1782003302 ], // mcmurdo 2026-06-21
        [ 1782003302, -77.85d, 166.67d, SUNSET, null ], // mcmurdo 2026-06-21
        [ 1782003302, -77.85d, 166.67d, DUSK, null ], // mcmurdo 2026-06-21
        [ 1782003302, -77.85d, 166.67d, NAUTIC_DUSK, 1782008219 ], // mcmurdo 2026-06-21
        [ 1782003302, -77.85d, 166.67d, ASTRO_DUSK, 1782019045 ], // mcmurdo 2026-06-21
        [ 1797814269, -77.85d, 166.67d, ASTRO_DAWN, null ], // mcmurdo 2026-12-21 (antarctic midnight sun)
        [ 1797814269, -77.85d, 166.67d, NAUTIC_DAWN, null ], // mcmurdo 2026-12-21
        [ 1797814269, -77.85d, 166.67d, DAWN, null ], // mcmurdo 2026-12-21
        [ 1797814269, -77.85d, 166.67d, SUNRISE, null ], // mcmurdo 2026-12-21
        [ 1797814269, -77.85d, 166.67d, NOON, 1797814269 ], // mcmurdo 2026-12-21
        [ 1797814269, -77.85d, 166.67d, SUNSET, null ], // mcmurdo 2026-12-21
        [ 1797814269, -77.85d, 166.67d, DUSK, null ], // mcmurdo 2026-12-21
        [ 1797814269, -77.85d, 166.67d, NAUTIC_DUSK, null ], // mcmurdo 2026-12-21
        [ 1797814269, -77.85d, 166.67d, ASTRO_DUSK, null ], // mcmurdo 2026-12-21
        [ 1774005625, 48.101d, 11.7598d, ASTRO_DAWN, 1773977426 ], // munich 2026-03-20 (equinox)
        [ 1774005625, 48.101d, 11.7598d, NAUTIC_DAWN, 1773979687 ], // munich 2026-03-20
        [ 1774005625, 48.101d, 11.7598d, DAWN, 1773981879 ], // munich 2026-03-20
        [ 1774005625, 48.101d, 11.7598d, SUNRISE, 1773983644 ], // munich 2026-03-20
        [ 1774005625, 48.101d, 11.7598d, NOON, 1774005625 ], // munich 2026-03-20
        [ 1774005625, 48.101d, 11.7598d, SUNSET, 1774027606 ], // munich 2026-03-20
        [ 1774005625, 48.101d, 11.7598d, DUSK, 1774029371 ], // munich 2026-03-20
        [ 1774005625, 48.101d, 11.7598d, NAUTIC_DUSK, 1774031563 ], // munich 2026-03-20
        [ 1774005625, 48.101d, 11.7598d, ASTRO_DUSK, 1774033824 ], // munich 2026-03-20
        [ 1782040486, 48.101d, 11.7598d, ASTRO_DAWN, 1781999466 ], // munich 2026-06-21 (summer solstice)
        [ 1782040486, 48.101d, 11.7598d, NAUTIC_DAWN, 1782005607 ], // munich 2026-06-21
        [ 1782040486, 48.101d, 11.7598d, DAWN, 1782009089 ], // munich 2026-06-21
        [ 1782040486, 48.101d, 11.7598d, SUNRISE, 1782011458 ], // munich 2026-06-21
        [ 1782040486, 48.101d, 11.7598d, NOON, 1782040486 ], // munich 2026-06-21
        [ 1782040486, 48.101d, 11.7598d, SUNSET, 1782069515 ], // munich 2026-06-21
        [ 1782040486, 48.101d, 11.7598d, DUSK, 1782071884 ], // munich 2026-06-21
        [ 1782040486, 48.101d, 11.7598d, NAUTIC_DUSK, 1782075366 ], // munich 2026-06-21
        [ 1782040486, 48.101d, 11.7598d, ASTRO_DUSK, 1782081507 ], // munich 2026-06-21
        [ 1797851460, 48.101d, 11.7598d, ASTRO_DAWN, 1797829569 ], // munich 2026-12-21 (winter solstice)
        [ 1797851460, 48.101d, 11.7598d, NAUTIC_DAWN, 1797831844 ], // munich 2026-12-21
        [ 1797851460, 48.101d, 11.7598d, DAWN, 1797834231 ], // munich 2026-12-21
        [ 1797851460, 48.101d, 11.7598d, SUNRISE, 1797836304 ], // munich 2026-12-21
        [ 1797851460, 48.101d, 11.7598d, NOON, 1797851460 ], // munich 2026-12-21
        [ 1797851460, 48.101d, 11.7598d, SUNSET, 1797866616 ], // munich 2026-12-21
        [ 1797851460, 48.101d, 11.7598d, DUSK, 1797868689 ], // munich 2026-12-21
        [ 1797851460, 48.101d, 11.7598d, NAUTIC_DUSK, 1797871076 ], // munich 2026-12-21
        [ 1797851460, 48.101d, 11.7598d, ASTRO_DUSK, 1797873352 ], // munich 2026-12-21
        [ 1787311149, 60.0d, 11.0d, ASTRO_DAWN, null ], // 60N 2026-08-21 (no astro twilight)
        [ 1787311149, 60.0d, 11.0d, NAUTIC_DAWN, 1787276938 ], // 60N 2026-08-21
        [ 1787311149, 60.0d, 11.0d, DAWN, 1787281000 ], // 60N 2026-08-21
        [ 1787311149, 60.0d, 11.0d, SUNRISE, 1787283772 ], // 60N 2026-08-21
        [ 1787311149, 60.0d, 11.0d, NOON, 1787311149 ], // 60N 2026-08-21
        [ 1787311149, 60.0d, 11.0d, SUNSET, 1787338526 ], // 60N 2026-08-21
        [ 1787311149, 60.0d, 11.0d, DUSK, 1787341299 ], // 60N 2026-08-21
        [ 1787311149, 60.0d, 11.0d, NAUTIC_DUSK, 1787345360 ], // 60N 2026-08-21
        [ 1787311149, 60.0d, 11.0d, ASTRO_DUSK, null ], // 60N 2026-08-21
        [ 1774027275, -0.1807d, -78.4678d, ASTRO_DAWN, 1774001355 ], // quito 2026-03-20 (equator)
        [ 1774027275, -0.1807d, -78.4678d, NAUTIC_DAWN, 1774002795 ], // quito 2026-03-20
        [ 1774027275, -0.1807d, -78.4678d, DAWN, 1774004235 ], // quito 2026-03-20
        [ 1774027275, -0.1807d, -78.4678d, SUNRISE, 1774005411 ], // quito 2026-03-20
        [ 1774027275, -0.1807d, -78.4678d, NOON, 1774027275 ], // quito 2026-03-20
        [ 1774027275, -0.1807d, -78.4678d, SUNSET, 1774049139 ], // quito 2026-03-20
        [ 1774027275, -0.1807d, -78.4678d, DUSK, 1774050315 ], // quito 2026-03-20
        [ 1774027275, -0.1807d, -78.4678d, NAUTIC_DUSK, 1774051755 ], // quito 2026-03-20
        [ 1774027275, -0.1807d, -78.4678d, ASTRO_DUSK, 1774053195 ], // quito 2026-03-20
        [ 1782059704, -54.8019d, -68.303d, ASTRO_DAWN, 1782038520 ], // ushuaia 2026-06-21 (southern winter)
        [ 1782059704, -54.8019d, -68.303d, NAUTIC_DAWN, 1782041174 ], // ushuaia 2026-06-21
        [ 1782059704, -54.8019d, -68.303d, DAWN, 1782044017 ], // ushuaia 2026-06-21
        [ 1782059704, -54.8019d, -68.303d, SUNRISE, 1782046585 ], // ushuaia 2026-06-21
        [ 1782059704, -54.8019d, -68.303d, NOON, 1782059704 ], // ushuaia 2026-06-21
        [ 1782059704, -54.8019d, -68.303d, SUNSET, 1782072824 ], // ushuaia 2026-06-21
        [ 1782059704, -54.8019d, -68.303d, DUSK, 1782075391 ], // ushuaia 2026-06-21
        [ 1782059704, -54.8019d, -68.303d, NAUTIC_DUSK, 1782078235 ], // ushuaia 2026-06-21
        [ 1782059704, -54.8019d, -68.303d, ASTRO_DUSK, 1782080889 ], // ushuaia 2026-06-21
        [ 1774618154, 64.371607d, -20.975488d, ASTRO_DAWN, 1774583456 ], // iceland 2026-03-27 (issue #4)
        [ 1774618154, 64.371607d, -20.975488d, NAUTIC_DAWN, 1774588031 ], // iceland 2026-03-27
        [ 1774618154, 64.371607d, -20.975488d, DAWN, 1774591760 ], // iceland 2026-03-27
        [ 1774618154, 64.371607d, -20.975488d, SUNRISE, 1774594706 ], // iceland 2026-03-27
        [ 1774618154, 64.371607d, -20.975488d, NOON, 1774618154 ], // iceland 2026-03-27
        [ 1774618154, 64.371607d, -20.975488d, SUNSET, 1774641602 ], // iceland 2026-03-27
        [ 1774618154, 64.371607d, -20.975488d, DUSK, 1774644547 ], // iceland 2026-03-27
        [ 1774618154, 64.371607d, -20.975488d, NAUTIC_DUSK, 1774648277 ], // iceland 2026-03-27
        [ 1774618154, 64.371607d, -20.975488d, ASTRO_DUSK, 1774652852 ], // iceland 2026-03-27
        [ 1782048344, 64.371607d, -20.975488d, ASTRO_DAWN, null ], // iceland 2026-06-21 (sun stays above -6 deg)
        [ 1782048344, 64.371607d, -20.975488d, NAUTIC_DAWN, null ], // iceland 2026-06-21
        [ 1782048344, 64.371607d, -20.975488d, DAWN, null ], // iceland 2026-06-21
        [ 1782048344, 64.371607d, -20.975488d, SUNRISE, 1782009900 ], // iceland 2026-06-21
        [ 1782048344, 64.371607d, -20.975488d, NOON, 1782048344 ], // iceland 2026-06-21
        [ 1782048344, 64.371607d, -20.975488d, SUNSET, 1782086788 ], // iceland 2026-06-21 (after midnight UTC)
        [ 1782048344, 64.371607d, -20.975488d, DUSK, null ], // iceland 2026-06-21
        [ 1782048344, 64.371607d, -20.975488d, NAUTIC_DUSK, null ], // iceland 2026-06-21
        [ 1782048344, 64.371607d, -20.975488d, ASTRO_DUSK, null ], // iceland 2026-06-21
        [ 1797859319, 64.371607d, -20.975488d, ASTRO_DAWN, 1797839441 ], // iceland 2026-12-21 (winter)
        [ 1797859319, 64.371607d, -20.975488d, NAUTIC_DAWN, 1797843075 ], // iceland 2026-12-21
        [ 1797859319, 64.371607d, -20.975488d, DAWN, 1797847273 ], // iceland 2026-12-21
        [ 1797859319, 64.371607d, -20.975488d, SUNRISE, 1797852119 ], // iceland 2026-12-21
        [ 1797859319, 64.371607d, -20.975488d, NOON, 1797859319 ], // iceland 2026-12-21
        [ 1797859319, 64.371607d, -20.975488d, SUNSET, 1797866520 ], // iceland 2026-12-21
        [ 1797859319, 64.371607d, -20.975488d, DUSK, 1797871366 ], // iceland 2026-12-21
        [ 1797859319, 64.371607d, -20.975488d, NAUTIC_DUSK, 1797875564 ], // iceland 2026-12-21
        [ 1797859319, 64.371607d, -20.975488d, ASTRO_DUSK, 1797879197 ] // iceland 2026-12-21
    ] as Lang.Array<Lang.Array>;

    var sc = new SunCalc();
    var ok = true;
    for (var i = 0; i < fixtures.size(); i++) {
        var f = fixtures[i];
        var loc = new Pos.Location(
            { :latitude => f[1], :longitude => f[2], :format => :degrees }
            ).toRadians();
        var moment = sc.calculate(new Time.Moment(f[0]), loc, f[3]);
        if (f[4] == null) {
            if (moment != null) {
                logger.debug("fixture " + i + ": expected null, got " + moment.value());
                ok = false;
            }
        } else if (!SunCalcTestHelpers.near(logger, "fixture " + i, moment, f[4])) {
            ok = false;
        }
    }
    return ok;
}

// Issues #7 and #4: a position given as Floats (the saved-position
// fallback stores lastLat/lastLng as float properties, and callers of the
// library pass plain Floats) must give the same times as Doubles. With
// Floats the Julian dates (~2.46e6) lost everything below 0.25 days, so
// every event collapsed onto the same 6-hour step.
(:test)
function testFloatPositionMatchesDouble(logger) {
    var places = [
        [ 1774005625, 48.101d, 11.7598d ], // munich 2026-03-20
        [ 1774618154, 64.371607d, -20.975488d ], // iceland 2026-03-27
        [ 1774027275, -0.1807d, -78.4678d ] // quito 2026-03-20
    ] as Lang.Array<Lang.Array>;
    var ok = true;
    for (var p = 0; p < places.size(); p++) {
        var dbl = SunCalcTestHelpers.locOf(places[p][1], places[p][2]);
        var flt = [ dbl[0].toFloat(), dbl[1].toFloat() ];
        var anchor = new Time.Moment(places[p][0]);
        var prev = null;
        for (var what = ASTRO_DAWN; what <= ASTRO_DUSK; what++) {
            if (what == GOLDEN_HOUR_PM || what == GOLDEN_HOUR_AM) {
                continue;
            }
            var expected = new SunCalc().calculate(anchor, dbl, what);
            var got = new SunCalc().calculate(anchor, flt, what);
            if (!SunCalcTestHelpers.near(logger, "place " + p + " event " + what,
                                         got, expected.value().toLong())) {
                ok = false;
            } else if (prev != null && got.value() <= prev) {
                logger.debug("place " + p + " event " + what + " not after the previous one");
                ok = false;
            }
            if (got != null) {
                prev = got.value();
            }
        }
    }
    return ok;
}

// Issue #6: Time.Moment must be built from a Number. The simulator keeps a
// Float otherwise and loses seconds at epoch magnitudes.
(:test)
function testFromJulianIsNumber(logger) {
    var sc = new SunCalc();
    var m = sc.fromJulian(2461120.0123d);
    if (!(m.value() instanceof Lang.Number)) {
        logger.debug("fromJulian value is not a Number: " + m.value());
        return false;
    }
    // 2461120.0123 JD = 2026-03-20 12:17:42 UTC
    return SunCalcTestHelpers.near(logger, "fromJulian", m, 1774009062);
}

// The glance falls back to the saved position, which round-trips through
// float properties: its times must match the live fix.
(:test)
function testStoredLocationTimes(logger) {
    var loc = SunCalcTestHelpers.locOf(64.371607d, -20.975488d);
    saveLoc(loc);
    var stored = loadStoredLoc();
    if (stored == null) {
        logger.debug("stored location not loaded");
        return false;
    }
    var anchor = new Time.Moment(1774618154);
    return SunCalcTestHelpers.near(logger, "stored sunrise",
                                   new SunCalc().calculate(anchor, stored, SUNRISE), 1774594706)
        && SunCalcTestHelpers.near(logger, "stored sunset",
                                   new SunCalc().calculate(anchor, stored, SUNSET), 1774641602);
}

// Regression for the TIMES[-1] crash: on the last day before astronomical
// twilight returns, the "Night" row has no astro dusk (from == null) but
// the next morning has an astro dawn (to != null). The mirror formula
// yielded index -1 and crashed with an out-of-bounds array access.
(:test)
function testNightRowPolarBoundaryNoCrash(logger) {
    // Hammerfest, 2026-09-19 20:20 UTC
    var v = SunCalcTestHelpers.makeView(1789849200, 70.6632359d, 23.681726d);
    v.selectDisplay();
    if (v.mDI != 14 || v.DAY_IN_ADVANCE != 0) {
        logger.debug("expected Night (14/day 0), got " + v.mDI + "/day " + v.DAY_IN_ADVANCE);
        return false;
    }
    var ft = v.getFromTo(); // crashed before the fix
    if (ft[0] != null) {
        logger.debug("expected open start (--:--), got " + ft[0].value());
        return false;
    }
    return SunCalcTestHelpers.near(logger, "night end", ft[1], 1789858058);
}

// Same boundary situation at 60N in late August (no astronomical twilight
// season): the walk must continue into the next day instead of taking the
// former unconditional "no sunset" branch.
(:test)
function testBrightNightBoundaryNoCrash(logger) {
    // 60N 11E, 2026-08-21 21:30 UTC
    var v = SunCalcTestHelpers.makeView(1787347800, 60.0d, 11.0d);
    v.selectDisplay();
    if (v.mDI != 14 || v.DAY_IN_ADVANCE != 0) {
        logger.debug("expected Night (14/day 0), got " + v.mDI + "/day " + v.DAY_IN_ADVANCE);
        return false;
    }
    var ft = v.getFromTo();
    if (ft[0] != null) {
        logger.debug("expected open start (--:--), got " + ft[0].value());
        return false;
    }
    return SunCalcTestHelpers.near(logger, "night end", ft[1], 1787355776);
}

// Regression for the "Morning is never displayed" bug: any late morning
// used to trip the "no sunrise" heuristic and reset the display to
// "Nautic Dawn" with stale times.
(:test)
function testMorningIsDisplayed(logger) {
    // Munich, 2026-06-26 06:40 UTC (mid-morning)
    var v = SunCalcTestHelpers.makeView(1782456000, 48.1010d, 11.7598d);
    v.selectDisplay();
    if (v.mDI != 6 || v.DAY_IN_ADVANCE != 0) {
        logger.debug("expected Morning (6/day 0), got " + v.mDI + "/day " + v.DAY_IN_ADVANCE);
        return false;
    }
    var ft = v.getFromTo();
    return SunCalcTestHelpers.near(logger, "sunrise", ft[0], 1782443666)
        && SunCalcTestHelpers.near(logger, "noon", ft[1], 1782472549);
}

// Real polar night: the "no sunrise" branch must still fire and fall back
// to the first displayable row after midnight.
(:test)
function testPolarNightSelection(logger) {
    // Hammerfest, 2026-01-15 10:00 UTC (sun never rises)
    var v = SunCalcTestHelpers.makeView(1768471200, 70.6632359d, 23.681726d);
    v.selectDisplay();
    if (v.mDI != 1 || v.DAY_IN_ADVANCE != 0) {
        logger.debug("expected Nautic Dawn (1/day 0), got " + v.mDI + "/day " + v.DAY_IN_ADVANCE);
        return false;
    }
    var ft = v.getFromTo();
    return SunCalcTestHelpers.near(logger, "nautic dawn", ft[0], 1768457781)
        && SunCalcTestHelpers.near(logger, "dawn", ft[1], 1768463640);
}

// Midnight sun: selection must terminate without any valid twilight events.
(:test)
function testPolarDaySelection(logger) {
    // Hammerfest, 2026-06-21 10:00 UTC (sun never sets)
    var v = SunCalcTestHelpers.makeView(1782036000, 70.6632359d, 23.681726d);
    v.selectDisplay();
    if (v.mDI != 1 || v.DAY_IN_ADVANCE != 0) {
        logger.debug("expected row 1/day 0, got " + v.mDI + "/day " + v.DAY_IN_ADVANCE);
        return false;
    }
    var ft = v.getFromTo();
    if (ft[0] != null || ft[1] != null) {
        logger.debug("expected --:-- / --:--");
        return false;
    }
    return true;
}

// only exists on glance-capable devices (stripped elsewhere with the
// rest of the :hasGlance code)
(:test :hasGlance)
function testGlanceViewLoads(logger) {
    var g = new SunCalcGlanceView();
    return g != null;
}

// Ring segments: [astro, nautic, civil, day], each an [dawn,dusk] pair,
// :full (never below the threshold) or null (never above).
(:test)
function testRingSegments(logger) {
    var sc = new SunCalc();

    // Munich mid-summer morning: every band has real crossings
    var segs = ringSegments(sc, new Time.Moment(1782456000), SunCalcTestHelpers.locOf(48.1010d, 11.7598d));
    for (var i = 0; i < 6; i++) {
        if (!(segs[i] instanceof Lang.Array)) {
            logger.debug("munich band " + i + " not a pair");
            return false;
        }
    }

    // Hammerfest midnight sun: the sun grazes to about +4 deg at its low
    // point, so every band up to the golden-hour threshold is :full and
    // only the +6 deg golden-hour band has real crossings
    segs = ringSegments(sc, new Time.Moment(1782036000), SunCalcTestHelpers.locOf(70.6632359d, 23.681726d));
    for (var i = 0; i < 5; i++) {
        if (segs[i] != :full) {
            logger.debug("hammerfest jun band " + i + " != :full");
            return false;
        }
    }
    if (!(segs[5] instanceof Lang.Array)) {
        logger.debug("hammerfest jun golden band not a pair");
        return false;
    }

    // Hammerfest polar night: the sun peaks near -2 deg, so it crosses the
    // twilight/blue-hour thresholds (bands 0-3) but never rises (sunrise
    // and golden-hour bands null)
    segs = ringSegments(sc, new Time.Moment(1768471200), SunCalcTestHelpers.locOf(70.6632359d, 23.681726d));
    if (segs[4] != null || segs[5] != null) {
        logger.debug("hammerfest jan: sunrise/golden bands should be null");
        return false;
    }
    for (var i = 0; i < 4; i++) {
        if (!(segs[i] instanceof Lang.Array)) {
            logger.debug("hammerfest jan band " + i + " not a pair");
            return false;
        }
    }

    // McMurdo antarctic winter: only astronomical and nautical twilight
    segs = ringSegments(sc, new Time.Moment(1782003302), SunCalcTestHelpers.locOf(-77.85d, 166.67d));
    return segs[0] instanceof Lang.Array && segs[1] instanceof Lang.Array
        && segs[2] == null && segs[3] == null && segs[4] == null && segs[5] == null;
}

// The TOPICS table is API (indices are stored in properties and mirror the
// settings.xml listEntry values), so verify its shape and the morning/evening
// ordering, plus that topicFor() bounds-checks bad indices.
(:test)
function testTopics(logger) {
    for (var i = 0; i < TOPICS.size(); i++) {
        var t = TOPICS[i];
        if (t.size() != 5) {
            logger.debug("topic " + i + " wrong column count");
            return false;
        }
        // morning event is before noon, evening event is after noon
        if (!(t[T_AM] < NOON && t[T_PM] > NOON)) {
            logger.debug("topic " + i + " am/pm not around noon");
            return false;
        }
    }

    // topicFor falls back to the default for an out-of-range or unset value
    if (topicFor("no.such.property", 3) != 3) {
        logger.debug("topicFor did not fall back to default");
        return false;
    }
    return true;
}

(:test)
function testMomentToStringNull(logger) {
    var sc = new SunCalc();
    return sc.momentToString(null, true, true).equals("--:--");
}
