using Toybox.WatchUi as Ui;
using Toybox.Position as Pos;
using Toybox.Time as Time;
using Toybox.Math as Math;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;

var DISPLAY = [
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
            findDrawableById("what").setText("Waiting for GPS");
            findDrawableById("time_from").setText("");
            findDrawableById("time_to").setText("");
        } else {
            setPosition(info);
        }
    }

    function setPosition(info) {

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
            Sys.println("displayNext()");
            if (!displayNext()) {
                break;
            }
            moment = getMoment(DISPLAY[mDI][D_TO]);

            if (mDI == 6) {
                Sys.println("No sunrise:");
                // The sun didn't rise today
                // Display anything to show after midnight
                DAY_IN_ADVANCE = 0;
                mDI = 0;
                displayNext();
                break;
            }

            if (DAY_IN_ADVANCE > 0) {
                Sys.println("No sunset:");
                // The sun does go down today or did not rise.
                // Display anything to show after afternoon
                DAY_IN_ADVANCE = 0;
                mDI = 7;
                displayNext();
                break;
            }
        }
        myUpdate();
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

    function getMoment(what) {
        var day = DAY_IN_ADVANCE;
        if (what > ASTRO_DUSK) {
            day++;
            what = ASTRO_DAWN;
        }
        now = Time.now();
        // for testing now = new Time.Moment(1483225200);
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
        var text;
        if (!hasLayout) {
            return;
        }
        if (lastLoc == null) {
            findDrawableById("what").setText(Rez.Strings.WaitingForGPS);
            findDrawableById("time_from").setText("");
            findDrawableById("time_to").setText("");
            Ui.requestUpdate();
            return;
        }

        if (NO_DISPLAY) {
            findDrawableById("what").setText("");
            findDrawableById("time_from").setText(Rez.Strings.NothingToDisplay);
            findDrawableById("time_to").setText(Rez.Strings.PressMenu);
            Ui.requestUpdate();
            return;
        }

        findDrawableById("what").setText(DISPLAY[mDI][D_TITLE]);
        var from = getMoment(DISPLAY[mDI][D_FROM]);
        var to = getMoment(DISPLAY[mDI][D_TO]);

        if (from == null && to != null) {
            // test if this started the day before
            var what = (2 * NOON - DISPLAY[mDI][D_TO]) % NUM_RESULTS;
            var day = DAY_IN_ADVANCE - 1;
            from = sc.calculate(new Time.Moment(now.value() + day * Time.Gregorian.SECONDS_PER_DAY), lastLoc, what);
        } else if (to == null && from != null) {
            // test if this ends the day after
            var what = (2 * NOON - DISPLAY[mDI][D_FROM]) % NUM_RESULTS;
            var day = DAY_IN_ADVANCE + 1;
            to = sc.calculate(new Time.Moment(now.value() + day * Time.Gregorian.SECONDS_PER_DAY), lastLoc, what);
        }

        findDrawableById("time_from").setText(sc.momentToString(from, is24Hour));
        findDrawableById("time_to").setText(sc.momentToString(to, is24Hour));

        Ui.requestUpdate();
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

    function onPosition(info) {
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
            var event_x = coordinate[0];
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
