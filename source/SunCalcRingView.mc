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

// 1-bit screens (Instinct, Descent G1) cannot tell the band colours apart:
// there the ring shows the sun's height as band width instead, from a
// hairline at night to the full ring width while the sun is up. Exactly
// one of these survives per device (excludeAnnotations in monkey.jungle).
(:color)
function monoScreen() {
    return false;
}

(:mono)
function monoScreen() {
    return true;
}

// band width on 1-bit screens, in sixths of the ring width, per RING_BANDS
var RING_MONO_SIXTHS as Lang.Array<Lang.Number> = [ 1, 2, 3, 4, 6, 6 ];

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
    // preallocated: Array.add() needs API 1.3 (epix has 1.2)
    var segs = new [RING_BANDS.size()] as Lang.Array;
    for (var i = 0; i < RING_BANDS.size(); i++) {
        var band = RING_BANDS[i] as Lang.Array;
        var dawn = sc.calculate(now, loc, band[0]);
        var dusk = sc.calculate(now, loc, band[1]);
        if (dawn != null && dusk != null) {
            segs[i] = [ringDayFrac(dawn), ringDayFrac(dusk)];
        } else {
            segs[i] = noonAlt > band[2] ? :full : null;
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
    var ref;        // moment the ring is drawn for (now + dayOffset days)
    var dayOffset;  // 0 = today; up/down step it
    var lastLoc;
    var is24Hour;
    var fgColor; // foreground, follows the dark/light theme
    // layout of the current frame (see layout()): sun icon centre and
    // radius in pixels, text rows in percent of the height
    var sunX, sunY, sunR;
    var subX = 0, subY = 0, subR = 0; // subscreen circle, subR 0 = none
    var rows as Lang.Array<Lang.Number> = [ 42, 51, 63, 71 ];

    function initialize() {
        View.initialize();
        sc = new SunCalc();
        now = Time.now();
        ref = now;
        dayOffset = 0;
        lastLoc = null;
        is24Hour = Sys.getDeviceSettings().is24Hour;
        fgColor = Gfx.COLOR_WHITE;
    }

    function nextDay() {
        dayOffset++;
        Ui.requestUpdate();
    }

    function prevDay() {
        dayOffset--;
        Ui.requestUpdate();
    }

    // Acquire the position every time the view appears (also when
    // returning from the pager). getInfo() returns the last known fix
    // synchronously; only when that is unavailable do we wait for the
    // async one-shot callback. Registering the one-shot in onLayout()
    // alone is unreliable - if it never delivers, the view is stuck on
    // "Waiting for GPS".
    function onShow() {
        dayOffset = 0; // always reappear on today
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
        var mono = monoScreen();

        if (mono) {
            // night: a hairline along the outer edge
            dc.setPenWidth(1);
            dc.setColor(fgColor, Gfx.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, r + pen / 2);
        } else {
            dc.setPenWidth(pen);
            dc.setColor(RING_NIGHT, Gfx.COLOR_TRANSPARENT);
            dc.drawCircle(cx, cy, r);
        }

        var segs = ringSegments(sc, ref, lastLoc);
        for (var i = 0; i < segs.size(); i++) {
            var seg = segs[i];
            if (seg == null) {
                break; // darker than this everywhere; inner bands too
            }
            var band = RING_BANDS[i] as Lang.Array;
            var br = r;
            if (mono) {
                // all bands share the outer edge and grow inwards
                var bw = (pen * RING_MONO_SIXTHS[i]) / 6;
                if (bw < 1) {
                    bw = 1;
                }
                br = r + pen / 2 - bw / 2;
                dc.setPenWidth(bw);
                dc.setColor(fgColor, Gfx.COLOR_TRANSPARENT);
            } else {
                dc.setColor(band[3] as Lang.Number, Gfx.COLOR_TRANSPARENT);
            }
            if (seg == :full) {
                dc.drawCircle(cx, cy, br);
            } else {
                var pair = seg as Lang.Array;
                dc.drawArc(cx, cy, br, Gfx.ARC_CLOCKWISE,
                           fracToDeg(pair[0]), fracToDeg(pair[1]));
            }
        }

        // solar noon (black, on the lit side) and solar midnight (light, on
        // the night side) as radial ticks across the band, for orientation
        var noon = sc.calculate(ref, lastLoc, NOON);
        if (noon != null) {
            var noonF = ringDayFrac(noon);
            var midF = noonF + 0.5;
            if (midF >= 1.0) { midF -= 1.0; }
            dc.setPenWidth(2);
            drawTick(dc, cx, cy, fracToDeg(noonF), r - pen / 2, r + pen / 2,
                     mono && !getConfig("darkMode", true) ? Gfx.COLOR_WHITE : Gfx.COLOR_BLACK);
            if (!mono) {
                drawTick(dc, cx, cy, fracToDeg(midF), r - pen / 2, r + pen / 2, Gfx.COLOR_LT_GRAY);
            }
        }

        // current time marker - only meaningful on today
        if (dayOffset == 0) {
            var nowDeg = fracToDeg(ringDayFrac(now));
            if (mono) {
                // red is invisible on 1-bit screens: a tick inside the ring
                dc.setPenWidth(3);
                drawTick(dc, cx, cy, nowDeg, r - pen / 2 - pen / 2, r - pen / 2 - 1, fgColor);
            } else {
                dc.setPenWidth(pen + 4);
                dc.setColor(Gfx.COLOR_RED, Gfx.COLOR_TRANSPARENT);
                dc.drawArc(cx, cy, r, Gfx.ARC_CLOCKWISE, nowDeg + 2, nowDeg - 2);
            }
        }

        // hour marks inside the ring; each one is left out where it would
        // run into the sun icon or the times (small and wide screens)
        dc.setPenWidth(1);
        dc.setColor(fgColor, Gfx.COLOR_TRANSPARENT);
        var font = Gfx.FONT_XTINY;
        var fh = dc.getFontHeight(font);
        var ri = r - pen / 2 - fh / 2 - 2;
        if (mono) {
            ri -= pen / 2; // keep clear of the now tick
        }
        var timeW = dc.getTextWidthInPixels(is24Hour ? "00:00" : "00:00 AM", Gfx.FONT_MEDIUM);
        var labelW = dc.getTextWidthInPixels("06", font);
        var sideFree = cx - ri + labelW / 2 + 2 < (w * 32) / 100 - timeW / 2;
        var topFree = sunX != cx || cy - ri + fh / 2 < sunY - sunR - 6;
        var bottomFree = cy + ri - fh / 2
            > (h * rows[3]) / 100 + dc.getFontHeight(Gfx.FONT_SMALL) / 2;
        var labels = [ "12", "18", "24", "06" ]; // top, right, bottom, left
        for (var i = 0; i < 4; i++) {
            if ((i == 0 && !topFree) || (i % 2 == 1 && !sideFree)
                || (i == 2 && !bottomFree)) {
                continue;
            }
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
        ref = (dayOffset == 0)
            ? now
            : new Time.Moment(now.value() + dayOffset * Time.Gregorian.SECONDS_PER_DAY);
        var headY = layout(w, h);
        drawRing(dc, w, h);
        if (subR > 0) {
            // the ring passes under the subscreen lens: keep the lens for
            // the sun and the heading only
            dc.setColor(dark ? Gfx.COLOR_BLACK : Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
            dc.fillCircle(subX, subY, subR);
        }
        drawSun(dc, sunX, sunY, sunR);

        // "Today" on the current day, otherwise the day's date (DD.MM.)
        var head;
        if (dayOffset == 0) {
            head = Ui.loadResource(Rez.Strings.Today);
        } else {
            var di = Time.Gregorian.info(ref, Time.FORMAT_SHORT);
            head = di.day.format("%02d") + "." + di.month.format("%02d") + ".";
        }
        dc.setColor(fgColor, Gfx.COLOR_TRANSPARENT);
        dc.drawText(sunX, headY, Gfx.FONT_XTINY, head,
                    Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);

        // two user-selectable topic rows (defaults: Sunrise/Sunset, Civil)
        drawRow(dc, w, rows[0], rows[1], Gfx.FONT_MEDIUM, topicFor("ringTop", 0));
        drawRow(dc, w, rows[2], rows[3], Gfx.FONT_SMALL, topicFor("ringBottom", 1));
    }

    // Place the sun icon, the day heading and the text rows; returns the
    // heading's y. On watches with a subscreen (Instinct) the sun and the
    // heading go into the subscreen and the rows move down, out of its way.
    hidden function layout(w, h) {
        var sub = null;
        if (Ui has :getSubscreen) {
            sub = Ui.getSubscreen();
        }
        if (sub != null) {
            subX = sub.x + sub.width / 2;
            subY = sub.y + sub.height / 2;
            subR = sub.width / 2 + 1;
            sunX = subX;
            sunY = sub.y + (sub.height * 33) / 100;
            sunR = sub.width / 12 + 1;
            rows = [ 46, 55, 68, 77 ];
            return sub.y + (sub.height * 68) / 100;
        }
        subR = 0;
        sunX = w / 2;
        sunY = (h * 23) / 100;
        sunR = w / 40 + 2;
        rows = [ 42, 51, 63, 71 ];
        return (h * 32) / 100;
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
        var am = sc.calculate(ref, lastLoc, t[T_AM]);
        var pm = sc.calculate(ref, lastLoc, t[T_PM]);
        dc.drawText((w * 32) / 100, (h * yTime) / 100, font,
                    sc.momentToString(am, is24Hour, false),
                    Gfx.TEXT_JUSTIFY_CENTER | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText((w * 68) / 100, (h * yTime) / 100, font,
                    sc.momentToString(pm, is24Hour, false),
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
        } else if (k == Ui.KEY_DOWN) {
            view.nextDay();
            return true;
        } else if (k == Ui.KEY_UP) {
            view.prevDay();
            return true;
        }
        return BehaviorDelegate.onKey(key);
    }

    // up/down (buttons or swipe) step the day; down = next, up = previous
    function onNextPage() {
        view.nextDay();
        return true;
    }

    function onPreviousPage() {
        view.prevDay();
        return true;
    }

    function onTap(event) {
        return openPager();
    }

    function onMenu() {
        Ui.pushView(new Rez.Menus.SettingsMenu(), new SettingsMenuDelegate(), Ui.SLIDE_UP);
        return true;
    }
}
