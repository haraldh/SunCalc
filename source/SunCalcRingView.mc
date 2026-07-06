using Toybox.WatchUi as Ui;
using Toybox.Position as Pos;
using Toybox.Time as Time;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;
using Toybox.Math as Math;
using Toybox.Lang;

// Twilight bands for the 24h ring, innermost last. Each entry:
// [ dawn event, dusk event, altitude threshold (rad), color ]
// The threshold decides between "all day" and "never" when both
// crossings are missing (polar day/night).
// Twilight/day bands for the 24h ring, drawn outermost-altitude first so
// each successive (higher-sun) band overpaints the middle, leaving one
// visible rim per band. Three distinct warm tiers near the horizon:
//   blue hour..sunrise   -> reddish  (the actual sunrise/sunset glow)
//   sunrise..golden end  -> gold     (golden hour)
//   above +6 deg         -> pale day
var RING_BANDS as Lang.Array<Lang.Array> = [
    [ ASTRO_DAWN, ASTRO_DUSK, -18.0 * 0.017453293, 0x0000AA ],
    [ NAUTIC_DAWN, NAUTIC_DUSK, -12.0 * 0.017453293, 0x0055AA ],
    [ DAWN, DUSK, -6.0 * 0.017453293, 0x55AAFF ],
    [ BLUE_HOUR_AM, BLUE_HOUR_PM, -4.0 * 0.017453293, 0xFF5500 ],
    [ SUNRISE, SUNSET, -0.833 * 0.017453293, 0xFFAA00 ],
    [ GOLDEN_HOUR_AM, GOLDEN_HOUR_PM, 6.0 * 0.017453293, 0xFFDD44 ]
];

var RING_NIGHT = 0x000055;

// fraction of the local day [0..1) for a moment
function ringDayFrac(moment) {
    var t = Time.Gregorian.info(moment, Time.FORMAT_SHORT);
    return (t.hour * 3600 + t.min * 60 + t.sec) / 86400.0;
}

// Compute the ring segments for the local day around `now`.
// Returns one entry per RING_BANDS band:
//   null           - the sun never reaches this altitude (stay night/outer)
//   :full          - the sun never drops below it (band fills the ring)
//   [ dawnFrac, duskFrac ]
// Factored out of the view so unit tests can drive it.
function ringSegments(sc, now, loc as Lang.Array<Lang.Double>) as Lang.Array {
    sc.calculate(now, loc, NOON); // ensure declination cache for noonAlt
    var lat = loc[0];
    var noonAlt = Math.PI / 2.0 - (lat - sc.dec).abs();
    var segs = [] as Lang.Array;
    for (var i = 0; i < RING_BANDS.size(); i++) {
        var band = RING_BANDS[i] as Lang.Array;
        var dawn = sc.calculate(now, loc, band[0]);
        var dusk = sc.calculate(now, loc, band[1]);
        if (dawn != null && dusk != null) {
            segs.add([ringDayFrac(dawn), ringDayFrac(dusk)]);
        } else {
            segs.add(noonAlt > band[2] ? :full : null);
        }
    }
    return segs;
}

// Front page: Garmin-style 24h ring (midnight at the bottom) with
// color-coded twilight bands, today's sunrise/sunset and civil twilight.
// Everything is drawn relative to the dc size, so no per-resolution
// resources are needed. Enter/tap opens the classic period pager.
class SunCalcRingView extends Ui.View {

    var sc;
    var now;
    var lastLoc;
    var is24Hour;
    var fgColor; // foreground, follows the dark/light theme

    function initialize() {
        View.initialize();
        sc = new SunCalc();
        now = Time.now();
        lastLoc = null;
        is24Hour = Sys.getDeviceSettings().is24Hour;
        fgColor = Gfx.COLOR_WHITE;
    }

    // Acquire the position every time the view appears (also when
    // returning from the pager). getInfo() returns the last known fix
    // synchronously; only when that is unavailable do we wait for the
    // async one-shot callback. Registering the one-shot in onLayout()
    // alone is unreliable - if it never delivers, the view is stuck on
    // "Waiting for GPS".
    function onShow() {
        var info = Pos.getInfo();
        if (info != null && info.position != null
            && info.accuracy != Pos.QUALITY_NOT_AVAILABLE) {
            setPosition(info);
        } else {
            Pos.enableLocationEvents(Pos.LOCATION_ONE_SHOT, method(:setPosition));
        }
    }

    function setPosition(info as Pos.Info) as Void {
        if (info == null || info.position == null
            || info.accuracy == Pos.QUALITY_NOT_AVAILABLE) {
            return;
        }
        lastLoc = info.position.toRadians();
        saveLoc(lastLoc);
        Ui.requestUpdate();
    }

    // time-of-day fraction -> drawArc degrees (0 = 3 o'clock, CCW
    // positive); midnight at the bottom, time runs clockwise
    hidden function fracToDeg(frac) {
        var deg = 270.0 - frac * 360.0;
        return deg < 0.0 ? deg + 360.0 : deg;
    }

    hidden function drawRing(dc, w, h) {
        var cx = w / 2;
        var cy = h / 2;
        var pen = w / 14;
        var r = (w < h ? w : h) / 2 - pen / 2 - 1;

        dc.setPenWidth(pen);
        dc.setColor(RING_NIGHT, Gfx.COLOR_TRANSPARENT);
        dc.drawCircle(cx, cy, r);

        var segs = ringSegments(sc, now, lastLoc);
        for (var i = 0; i < segs.size(); i++) {
            var seg = segs[i];
            if (seg == null) {
                break; // darker than this everywhere; inner bands too
            }
            var band = RING_BANDS[i] as Lang.Array;
            dc.setColor(band[3] as Lang.Number, Gfx.COLOR_TRANSPARENT);
            if (seg == :full) {
                dc.drawCircle(cx, cy, r);
            } else {
                var pair = seg as Lang.Array;
                dc.drawArc(cx, cy, r, Gfx.ARC_CLOCKWISE,
                           fracToDeg(pair[0]), fracToDeg(pair[1]));
            }
        }

        // solar noon (black, on the lit side) and solar midnight (light, on
        // the night side) as radial ticks across the band, for orientation
        var noon = sc.calculate(now, lastLoc, NOON);
        if (noon != null) {
            var noonF = ringDayFrac(noon);
            var midF = noonF + 0.5;
            if (midF >= 1.0) { midF -= 1.0; }
            dc.setPenWidth(2);
            drawTick(dc, cx, cy, fracToDeg(noonF), r - pen / 2, r + pen / 2, Gfx.COLOR_BLACK);
            drawTick(dc, cx, cy, fracToDeg(midF), r - pen / 2, r + pen / 2, Gfx.COLOR_LT_GRAY);
        }

        // current time marker
        dc.setPenWidth(pen + 4);
        dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
        var nowDeg = fracToDeg(ringDayFrac(now));
        dc.drawArc(cx, cy, r, Gfx.ARC_CLOCKWISE, nowDeg + 2, nowDeg - 2);

        // hour marks inside the ring
        dc.setPenWidth(1);
        dc.setColor(fgColor, Gfx.COLOR_TRANSPARENT);
        var font = Gfx.FONT_XTINY;
        var ri = r - pen / 2 - dc.getFontHeight(font) / 2 - 2;
        var labels = [ "12", "18", "24", "06" ]; // top, right, bottom, left
        for (var i = 0; i < 4; i++) {
            var a = (90 - i * 90) * Math.PI / 180.0;
            dc.drawText(cx + ri * Math.cos(a), cy - ri * Math.sin(a),
                        font, labels[i],
                        Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        }
    }

    // radial tick from radius ri to ro at drawArc-convention degrees
    hidden function drawTick(dc, cx, cy, deg, ri, ro, color) {
        var a = deg * Math.PI / 180.0;
        var ca = Math.cos(a);
        var sa = Math.sin(a);
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.drawLine(cx + ri * ca, cy - ri * sa, cx + ro * ca, cy - ro * sa);
    }

    hidden function drawSun(dc, cx, cy, rad) {
        dc.setColor(0xFFAA00, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, rad);
        dc.setPenWidth(2);
        for (var i = 0; i < 8; i++) {
            var a = i * Math.PI / 4.0;
            dc.drawLine(cx + (rad + 3) * Math.cos(a), cy + (rad + 3) * Math.sin(a),
                        cx + (rad + 6) * Math.cos(a), cy + (rad + 6) * Math.sin(a));
        }
    }

    function onUpdate(dc) {
        var w = dc.getWidth();
        var h = dc.getHeight();
        var dark = getConfig("darkMode", true);
        fgColor = dark ? Gfx.COLOR_WHITE : Gfx.COLOR_BLACK;
        dc.setColor(fgColor, dark ? Gfx.COLOR_BLACK : Gfx.COLOR_WHITE);
        dc.clear();

        if (lastLoc == null) {
            dc.drawText(w / 2, h / 2, Gfx.FONT_MEDIUM, Ui.loadResource(Rez.Strings.WaitingForGPS),
                        Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
            return;
        }

        now = Time.now();
        drawRing(dc, w, h);
        drawSun(dc, w / 2, (h * 23) / 100, w / 40 + 2);

        dc.setColor(fgColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * 32) / 100, Gfx.FONT_XTINY,
                    Ui.loadResource(Rez.Strings.Today),
                    Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // two user-selectable topic rows (defaults: Sunrise/Sunset, Civil)
        drawRow(dc, w, 42, 51, Gfx.FONT_MEDIUM, topicFor("ringTop", 0));
        drawRow(dc, w, 63, 71, Gfx.FONT_SMALL, topicFor("ringBottom", 1));
    }

    // one ring text row: centered topic title with the morning / evening
    // times of that topic beneath it. yTitle / yTime are percent of height.
    hidden function drawRow(dc, w, yTitle, yTime, font, topicIdx) {
        var t = TOPICS[topicIdx] as Lang.Array;
        var h = dc.getHeight();
        // Built here, not at module scope: a global initialized with
        // Rez.Strings crashes the glance process (no Rez there) at load.
        var titleRes = [ Rez.Strings.topicSun, Rez.Strings.topicCivil,
                         Rez.Strings.topicNautic, Rez.Strings.topicAstro,
                         Rez.Strings.topicBlue, Rez.Strings.topicGolden ];
        dc.setColor(fgColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(w / 2, (h * yTitle) / 100, Gfx.FONT_XTINY,
                    Ui.loadResource(titleRes[topicIdx]),
                    Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        var am = sc.calculate(now, lastLoc, t[T_AM]);
        var pm = sc.calculate(now, lastLoc, t[T_PM]);
        dc.drawText((w * 32) / 100, (h * yTime) / 100, font,
                    sc.momentToString(am, is24Hour),
                    Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText((w * 68) / 100, (h * yTime) / 100, font,
                    sc.momentToString(pm, is24Hour),
                    Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
    }
}

class SunCalcRingDelegate extends Ui.BehaviorDelegate {
    var view;

    function initialize(v) {
        BehaviorDelegate.initialize();
        view = v;
    }

    hidden function openPager() {
        var v = new SunCalcView();
        v.setListView(true);
        Ui.pushView(v, new SunCalcDelegate(v, true), Ui.SLIDE_LEFT);
        return true;
    }

    function onSelect() {
        return openPager();
    }

    function onKey(key) {
        var k = key.getKey();
        if (k == Ui.KEY_ENTER || k == Ui.KEY_START || k == Ui.KEY_RIGHT) {
            return openPager();
        }
        return BehaviorDelegate.onKey(key);
    }

    function onTap(event) {
        return openPager();
    }

    function onMenu() {
        Ui.pushView(new Rez.Menus.SettingsMenu(), new SettingsMenuDelegate(), Ui.SLIDE_UP);
        return true;
    }
}
