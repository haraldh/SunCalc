using Toybox.WatchUi as Ui;
using Toybox.Position as Pos;
using Toybox.Lang;
using Toybox.Time as Time;
using Toybox.Math as Math;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;

var DISPLAY as Lang.Array<Lang.Array> = [
    [ "Astr. Dawn", ASTRO_DAWN, NAUTIC_DAWN, :Astro, :AM, "showAstroDawn", null],
    [ "Nautic Dawn", NAUTIC_DAWN, DAWN, :Nautic, :AM, "showNauticDawn", null],
    [ "Blue Hour", DAWN, BLUE_HOUR_AM, :Blue, :AM, "showBlueDawn", null],
    [ "Civil Dawn", DAWN, SUNRISE, :Civil, :AM, "showDawn", null],
    [ "Sunrise", SUNRISE, SUNRISE_END, :Sunrise, :AM, "showSunrise", null],
    [ "Golden Hour", BLUE_HOUR_AM, GOLDEN_HOUR_AM, :Golden, :AM, "showGoldenDawn", null],
    [ "Morning", SUNRISE, NOON, :Noon, :AM, "showMorning", null],
    [ "Afternoon", NOON, SUNSET, :Noon, :PM, "showAfternoon", null],
    [ "Golden Hour", GOLDEN_HOUR_PM, BLUE_HOUR_PM, :Golden, :PM, "showGoldenDusk", null],
    [ "Sunset", SUNSET_START, SUNSET, :Sunrise, :PM, "showSunset", null],
    [ "Civil Dusk", SUNSET, DUSK, :Civil, :PM, "showDusk", null],
    [ "Blue Hour", BLUE_HOUR_PM, DUSK, :Blue, :PM, "showBlueDusk", null],
    [ "Nautic Dusk", DUSK, NAUTIC_DUSK, :Nautic, :PM, "showNauticDusk", null],
    [ "Astr. Dusk", NAUTIC_DUSK, ASTRO_DUSK, :Astro, :PM, "showAstroDusk", null],
    [ "Night", ASTRO_DUSK, ASTRO_DUSK+1, :Night, :PM, "showNight", null]
    ];

var NO_DISPLAY = false;

function shouldShow(i) {
    if (DISPLAY[i][D_SHOW] == null) {
        DISPLAY[i][D_SHOW] = getPropertyDef(DISPLAY[i][D_PROP], true);
    }
    return DISPLAY[i][D_SHOW];
}


class SunCalcView extends Ui.View {

    var sc;
    var listView;
    var now;
    var DAY_IN_ADVANCE;
    var lastLoc;
    var thirdHeight;
    var is24Hour;
    var hasLayout;
    var mDI;

    function initialize() {
        View.initialize();
        sc = new SunCalc();
        listView = false;
        now = Time.now();
        // for testing now = new Time.Moment(1483225200);
        DAY_IN_ADVANCE = 0;
        lastLoc = null;
        mDI = 0;
        thirdHeight = null;
        is24Hour = Sys.getDeviceSettings().is24Hour;
        hasLayout = false;
    }

    //! Load your resources here
    function onLayout(dc) {
        setLayout(Rez.Layouts.MainLayout(dc));
        hasLayout = true;
        thirdHeight = dc.getHeight() / 3;

        var info = Pos.getInfo();
        if (info == null || info.accuracy == Pos.QUALITY_NOT_AVAILABLE) {
            Pos.enableLocationEvents(Pos.LOCATION_ONE_SHOT, method(:setPosition));
            (findDrawableById("what") as Ui.Text).setText("Waiting for GPS");
            (findDrawableById("time_from") as Ui.Text).setText("");
            (findDrawableById("time_to") as Ui.Text).setText("");
        } else {
            setPosition(info);
        }
    }

    function setPosition(info as Pos.Info) as Void {

        if (info == null || info.accuracy == Pos.QUALITY_NOT_AVAILABLE) {
            return;
        }

        var loc = info.position.toRadians();
        self.lastLoc = loc;
        now = Time.now();
        /* For testing
           now = new Time.Moment(1483225200);
           self.lastLoc = new Pos.Location(
            { :latitude => 70.6632359, :longitude => 23.681726, :format => :degrees }
            ).toRadians();
        */

        selectDisplay();
        myUpdate();
    }

    // Walk the DISPLAY table to the period that should be shown for
    // self.now / self.lastLoc, setting mDI and DAY_IN_ADVANCE.
    // Factored out of setPosition() so unit tests can drive it.
    function selectDisplay() as Void {
        DAY_IN_ADVANCE = 0;
        mDI = 0; // morning

        var moment = getMoment(NOON);

        if (now.value() > moment.value()) {
            mDI = 7;
        }
        displayPrevious();
        displayNext();

        moment = getMoment(DISPLAY[mDI][D_TO]);

        while((moment == null) || ( now.value() > moment.value() )) {
            if (!displayNext()) {
                break;
            }
            moment = getMoment(DISPLAY[mDI][D_TO]);

            // Reaching "Morning" means all earlier periods ended or don't
            // exist. Only treat that as polar night if there really is no
            // sunrise that day; otherwise "Morning" is simply the current
            // period (any late morning at any latitude).
            if (mDI == 6 && getMoment(SUNRISE) == null) {
                Sys.println("No sunrise:");
                // The sun didn't rise today
                // Display anything to show after midnight
                DAY_IN_ADVANCE = 0;
                mDI = 0;
                displayNext();
                break;
            }

            // Wrapping into the next day is only a "no sunset" (polar day /
            // polar night PM) situation if that day has no sunset. At high
            // latitudes in summer the walk legitimately continues into the
            // next day (e.g. "Astr. Dawn +1" when there is no astronomical
            // dusk but the sun still sets).
            if (DAY_IN_ADVANCE > 0 && getMoment(SUNSET) == null) {
                Sys.println("No sunset:");
                // The sun does go down today or did not rise.
                // Display anything to show after afternoon
                DAY_IN_ADVANCE = 0;
                mDI = 7;
                displayNext();
                break;
            }

            // Safety stop: nothing displayable within a full day ahead
            // (e.g. only "Night" enabled during the season without
            // astronomical twilight). Without this the walk would advance
            // day by day indefinitely.
            if (DAY_IN_ADVANCE > 1) {
                DAY_IN_ADVANCE = 0;
                mDI = 7;
                displayNext();
                break;
            }
        }
    }

    function displayPrevious()
    {
        var started = mDI;
        while (true) {
            mDI--;
            if (mDI < 0) {
                DAY_IN_ADVANCE--;
                mDI = DISPLAY.size() - 1;
            }
            if (shouldShow(mDI)) {
                NO_DISPLAY = false;
                return true;
            }
            if (mDI == started) {
                break;
            }
        }
        NO_DISPLAY = true;
        return false;
    }

    function displayNext()
    {
        var started = mDI;
        while (true) {
            mDI++;
            if (mDI >= DISPLAY.size()) {
                DAY_IN_ADVANCE++;
                mDI = 0;
            }
            if (shouldShow(mDI)) {
                NO_DISPLAY = false;
                return true;
            }
            if (mDI == started) {
                break;
            }
        }
        NO_DISPLAY = true;
        return false;
    }

    function waitingForGPS() {
        lastLoc = null;
        myUpdate();
    }

    // Uses self.now as time base so the walk in selectDisplay() stays
    // anchored to one instant (and unit tests can inject a fixed time);
    // setPosition() and myUpdate() refresh self.now.
    function getMoment(what) {
        var day = DAY_IN_ADVANCE;
        if (what > ASTRO_DUSK) {
            day++;
            what = ASTRO_DAWN;
        }
        return sc.calculate(new Time.Moment(now.value() + day * Time.Gregorian.SECONDS_PER_DAY), lastLoc, what);
    }

    function onUpdate(dc) {
        Ui.View.onUpdate(dc);

        if (listView) {
            var arrow = new Rez.Drawables.Arrow_updown();
            arrow.draw(dc);
        } else {
            var arrow = new Rez.Drawables.Arrow_right();
            arrow.draw(dc);
        }
    }

    //! Update the view
    function myUpdate() {
        if (!hasLayout) {
            return;
        }
        now = Time.now();
        if (lastLoc == null) {
            (findDrawableById("what") as Ui.Text).setText(Rez.Strings.WaitingForGPS);
            (findDrawableById("time_from") as Ui.Text).setText("");
            (findDrawableById("time_to") as Ui.Text).setText("");
            Ui.requestUpdate();
            return;
        }

        if (NO_DISPLAY) {
            (findDrawableById("what") as Ui.Text).setText("");
            (findDrawableById("time_from") as Ui.Text).setText(Rez.Strings.NothingToDisplay);
            (findDrawableById("time_to") as Ui.Text).setText(Rez.Strings.PressMenu);
            Ui.requestUpdate();
            return;
        }

        (findDrawableById("what") as Ui.Text).setText(DISPLAY[mDI][D_TITLE]);
        var fromTo = getFromTo();

        (findDrawableById("time_from") as Ui.Text).setText(sc.momentToString(fromTo[0], is24Hour));
        (findDrawableById("time_to") as Ui.Text).setText(sc.momentToString(fromTo[1], is24Hour));

        Ui.requestUpdate();
    }

    // Start/end moments of the currently selected period, extending a
    // one-sided period into the mirrored event of the neighboring day.
    // Factored out of myUpdate() so unit tests can drive it.
    function getFromTo() as Lang.Array<Time.Moment?> {
        var from = getMoment(DISPLAY[mDI][D_FROM]);
        var to = getMoment(DISPLAY[mDI][D_TO]);

        if (from == null && to != null) {
            // test if this started the day before
            var what = 2 * NOON - DISPLAY[mDI][D_TO];
            // For the "Night" row (D_TO == ASTRO_DUSK + 1) the mirrored
            // event is today's ASTRO_DUSK again, i.e. the very moment that
            // is null - and the raw formula would yield -1 and crash with
            // an out-of-bounds TIMES[] access. Leave "from" open instead.
            if (what >= 0) {
                var day = DAY_IN_ADVANCE - 1;
                from = sc.calculate(new Time.Moment(now.value() + day * Time.Gregorian.SECONDS_PER_DAY), lastLoc, what);
            }
        } else if (to == null && from != null) {
            // test if this ends the day after
            var what = 2 * NOON - DISPLAY[mDI][D_FROM];
            var day = DAY_IN_ADVANCE + 1;
            to = sc.calculate(new Time.Moment(now.value() + day * Time.Gregorian.SECONDS_PER_DAY), lastLoc, what);
        }
        return [from, to];
    }

    function setListView(b) {
        listView = b;
    }
}

class SunCalcDelegate extends Ui.BehaviorDelegate {
    var view;
    var enter;

    function initialize(v, e) {
        BehaviorDelegate.initialize();
        view = v;
        enter = e;
    }

    function onKey(key) {
        var k = key.getKey();
        if (k == Ui.KEY_ENTER || k == Ui.KEY_START || k == Ui.KEY_RIGHT) {
            if (enter) {
                view.waitingForGPS();
                Pos.enableLocationEvents(Pos.LOCATION_ONE_SHOT, method(:onPosition));
                return true;
            } else {
                view.setListView(true);
                Ui.pushView(view, new SunCalcDelegate(view, true), Ui.SLIDE_IMMEDIATE);
                return true;
            }
        }
        return BehaviorDelegate.onKey(key);
    }

    function onMenu() {
        Ui.pushView(new Rez.Menus.SettingsMenu(), new SettingsMenuDelegate(), Ui.SLIDE_UP);
        return true;
    }

    function onPosition(info as Pos.Info) as Void {
        if (view) {
            view.setPosition(info);
        }
    }

    function onPreviousPage() {
        if (!enter) {
            return false;
        }
        view.displayPrevious();
        view.myUpdate();
        return true;
    }

    function onNextPage() {
        if (!enter) {
            return false;
        }

        view.displayNext();
        view.myUpdate();
        return true;
    }

    function onPreviousMode() {
        if (!enter) {
            return false;
        }
        view.displayPrevious();
        view.myUpdate();
        return true;
    }

    function onNextMode() {
        if (!enter) {
            return false;
        }
        view.displayNext();
        view.myUpdate();
        return true;
    }

    function onBack() {
        Pos.enableLocationEvents(Pos.LOCATION_DISABLE, method(:onPosition));

        if (enter) {
            view.setListView(false);
            Ui.popView(Ui.SLIDE_IMMEDIATE);
            return true;
        }

        return BehaviorDelegate.onBack();
    }

    function onTap(event) {
        if (enter) {
            if (view.thirdHeight == null) {
                return BehaviorDelegate.onTap(event);
            }

            var coordinate = event.getCoordinates();
            var event_y = coordinate[1];
            if (event_y <= view.thirdHeight) {
                onPreviousPage();
            } else if (event_y >= (view.thirdHeight * 2)) {
                onNextPage();
            } else {
                view.waitingForGPS();
                Pos.enableLocationEvents(Pos.LOCATION_ONE_SHOT, method(:onPosition));
            }
        } else {
            view.setListView(true);
            Ui.pushView(view, new SunCalcDelegate(view, true), Ui.SLIDE_IMMEDIATE);
        }
        return true;
    }
}
