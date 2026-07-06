using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Time as Time;
using Toybox.Position as Pos;
using Toybox.System as Sys;
using Toybox.Math as Math;
using Toybox.Lang;

// Glance shown in the carousel on CIQ >= 3.2 devices, styled after the
// native Garmin sunrise/sunset glance: a countdown to the next event, a
// horizontal 24h twilight bar with the current-time marker, and today's
// sunrise/sunset times underneath.
//
// :glance marks the code for the glance context (which only loads
// annotated code); :hasGlance is stripped via excludeAnnotations in
// monkey.jungle on devices whose SDK has no Ui.GlanceView symbol.
(:glance :hasGlance)
class SunCalcGlanceView extends Ui.GlanceView {

    // horizontal bar bands, outer (lower sun) first so inner overpaints:
    // [ dawn event, dusk event, altitude threshold (rad), color ]
    hidden const RAD = Math.PI / 180.0;

    function initialize() {
        GlanceView.initialize();
    }

    // next occurrence of an event from now: today, else tomorrow
    hidden function nextEvent(sc, now, loc, what) {
        var m = sc.calculate(now, loc, what);
        if (m == null || m.value() < now.value()) {
            m = sc.calculate(new Time.Moment(now.value() + Time.Gregorian.SECONDS_PER_DAY), loc, what);
            if (m != null && m.value() < now.value()) {
                return null;
            }
        }
        return m;
    }

    // fraction of the local day [0..1) for a moment
    hidden function dayFrac(m) {
        var t = Time.Gregorian.info(m, Time.FORMAT_SHORT);
        return (t.hour * 3600 + t.min * 60 + t.sec) / 86400.0;
    }

    // fill the bar from day-fraction f0 to f1 (wrapping past midnight)
    hidden function fillBar(dc, f0, f1, color, bx, bw, by, bh) {
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        if (f0 <= f1) {
            dc.fillRectangle(bx + f0 * bw, by, (f1 - f0) * bw, bh);
        } else {
            dc.fillRectangle(bx, by, f1 * bw, bh);
            dc.fillRectangle(bx + f0 * bw, by, (1.0 - f0) * bw, bh);
        }
    }

    hidden function drawSun(dc, cx, cy, rad, color) {
        dc.setColor(color, Gfx.COLOR_TRANSPARENT);
        dc.fillCircle(cx, cy, rad);
        dc.setPenWidth(1);
        for (var i = 0; i < 8; i++) {
            var a = i * Math.PI / 4.0;
            dc.drawLine(cx + (rad + 1) * Math.cos(a), cy + (rad + 1) * Math.sin(a),
                        cx + (rad + 3) * Math.cos(a), cy + (rad + 3) * Math.sin(a));
        }
    }

    function onUpdate(dc) {
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.clear();
        var font = (Gfx has :FONT_GLANCE) ? Gfx.FONT_GLANCE : Gfx.FONT_TINY;
        var w = dc.getWidth();
        var h = dc.getHeight();

        // Note: the glance process cannot access the Rez resource module,
        // so all labels here are literals.
        //
        // The glance never acquires a fix itself; it uses the live cached fix
        // if there is one, else the last position the full widget saved. That
        // keeps it populated even when the device's GPS cache is stale.
        var info = Pos.getInfo();
        var loc = null;
        if (info != null && info.position != null
            && info.accuracy != Pos.QUALITY_NOT_AVAILABLE) {
            loc = info.position.toRadians();
        } else {
            loc = loadStoredLoc();
        }
        if (loc == null) {
            dc.drawText(0, h / 2, font, "Waiting for GPS",
                        Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
            return;
        }

        var sc = new SunCalc();
        var now = Time.now();
        var is24 = Sys.getDeviceSettings().is24Hour;

        // ---- header: countdown to the chosen topic's next event ----
        var topic = TOPICS[topicFor("glanceTopic", 0)] as Lang.Array;
        var rise = nextEvent(sc, now, loc, topic[T_AM]);
        var set = nextEvent(sc, now, loc, topic[T_PM]);
        var next = null;
        var label = topic[T_PM_LABEL] as Lang.String;
        if (rise != null && (set == null || rise.value() < set.value())) {
            next = rise;
            label = topic[T_AM_LABEL] as Lang.String;
        } else if (set != null) {
            next = set;
        }

        var head;
        if (next != null) {
            var delta = (next.value() - now.value()).toNumber();
            var hh = delta / 3600;
            var mm = (delta % 3600) / 60;
            head = label + " " + hh + "h " + mm + "m";
        } else {
            head = "Twilight";
        }
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(0, (h * 15) / 100, font, head,
                    Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);

        // ---- twilight bar ----
        var barY = (h * 45) / 100;
        var barH = (h * 22) / 100;
        var iconR = barH / 2;
        var iconX = iconR + 2;
        var barX = iconX + iconR + 4;
        var barW = w - barX - 2;

        // today's events for the silhouette (calculate() from `now`)
        sc.calculate(now, loc, NOON);
        var lat = loc[0];
        var noonAlt = Math.PI / 2.0 - (lat - sc.dec).abs();

        // base = night; bands mirror the ring's warm/blue tiers exactly
        fillBar(dc, 0.0, 1.0, 0x000055, barX, barW, barY, barH);
        var bands = [
            [ ASTRO_DAWN, ASTRO_DUSK, -18.0 * RAD, 0x0000AA ],
            [ NAUTIC_DAWN, NAUTIC_DUSK, -12.0 * RAD, 0x0055AA ],
            [ DAWN, DUSK, -6.0 * RAD, 0x55AAFF ],
            [ BLUE_HOUR_AM, BLUE_HOUR_PM, -4.0 * RAD, 0xFF5500 ],
            [ SUNRISE, SUNSET, -0.833 * RAD, 0xFFAA00 ],
            [ GOLDEN_HOUR_AM, GOLDEN_HOUR_PM, 6.0 * RAD, 0xFFDD44 ]
        ];
        for (var i = 0; i < bands.size(); i++) {
            var band = bands[i];
            var d0 = sc.calculate(now, loc, band[0]);
            var d1 = sc.calculate(now, loc, band[1]);
            if (d0 != null && d1 != null) {
                fillBar(dc, dayFrac(d0), dayFrac(d1), band[3] as Lang.Number,
                        barX, barW, barY, barH);
            } else if (noonAlt > band[2]) {
                fillBar(dc, 0.0, 1.0, band[3] as Lang.Number, barX, barW, barY, barH);
            }
        }

        // solar noon (on the gold) and solar midnight (12h opposite, on the
        // night) as thin black ticks for orientation
        var noon = sc.calculate(now, loc, NOON);
        if (noon != null) {
            var noonF = dayFrac(noon);
            var midF = noonF + 0.5;
            if (midF >= 1.0) { midF -= 1.0; }
            dc.setPenWidth(1);
            // noon sits on the gold -> black reads best; midnight sits on the
            // dark night -> a light tick reads best
            var nnx = barX + noonF * barW;
            dc.setColor(Gfx.COLOR_BLACK, Gfx.COLOR_TRANSPARENT);
            dc.drawLine(nnx, barY, nnx, barY + barH);
            var mdx = barX + midF * barW;
            dc.setColor(Gfx.COLOR_LT_GRAY, Gfx.COLOR_TRANSPARENT);
            dc.drawLine(mdx, barY, mdx, barY + barH);
        }

        // current-time marker
        var mx = barX + dayFrac(now) * barW;
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.setPenWidth(2);
        dc.drawLine(mx, barY - 2, mx, barY + barH + 2);

        drawSun(dc, iconX, barY + barH / 2, iconR - 2, 0xFFAA00);

        // ---- the topic's morning / evening times under the bar ----
        var tRise = sc.calculate(now, loc, topic[T_AM]);
        var tSet = sc.calculate(now, loc, topic[T_PM]);
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.drawText(barX, (h * 84) / 100, font, sc.momentToString(tRise, is24),
                    Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(w - 1, (h * 84) / 100, font, sc.momentToString(tSet, is24),
                    Gfx.TEXT_JUSTIFY_RIGHT | Gfx.TEXT_JUSTIFY_VCENTER);
    }
}
