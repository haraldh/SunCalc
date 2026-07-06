using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Time as Time;
using Toybox.Position as Pos;
using Toybox.System as Sys;

// Glance shown in the carousel on CIQ >= 3.2 devices: the next sunrise or
// sunset (whichever comes first) for the last known position.
//
// :glance marks the code for the glance context (which only loads
// annotated code); :hasGlance is stripped via excludeAnnotations in
// monkey.jungle on devices whose SDK has no Ui.GlanceView symbol.
(:glance :hasGlance)
class SunCalcGlanceView extends Ui.GlanceView {

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

    function onUpdate(dc) {
        dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_TRANSPARENT);
        dc.clear();
        var font = (Gfx has :FONT_GLANCE) ? Gfx.FONT_GLANCE : Gfx.FONT_TINY;
        var h = dc.getHeight();

        var text = "--:--";
        var info = Pos.getInfo();
        if (info != null && info.position != null
            && info.accuracy != Pos.QUALITY_NOT_AVAILABLE) {
            var sc = new SunCalc();
            var loc = info.position.toRadians();
            var now = Time.now();
            var is24 = Sys.getDeviceSettings().is24Hour;
            var rise = nextEvent(sc, now, loc, SUNRISE);
            var set = nextEvent(sc, now, loc, SUNSET);
            if (rise != null && (set == null || rise.value() < set.value())) {
                text = "Rise " + sc.momentToString(rise, is24);
            } else if (set != null) {
                text = "Set " + sc.momentToString(set, is24);
            }
        }

        dc.drawText(0, h / 4, font, "SUNCALC",
                    Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
        dc.drawText(0, (h * 3) / 4, font, text,
                    Gfx.TEXT_JUSTIFY_LEFT | Gfx.TEXT_JUSTIFY_VCENTER);
    }
}
