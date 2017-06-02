using Toybox.WatchUi as Ui;
using Toybox.Position as Pos;
using Toybox.Time as Time;
using Toybox.Math as Math;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;

class SunCalcView extends Ui.View {

    var sc;
    var listView;
    var now;
    var DAY_IN_ADVANCE;
    var lastLoc;
    var thirdHeight;
    var is24Hour;
    var hasLayout;

    const display = [
        [ "Astr. Dawn", ASTRO_DAWN, NAUTIC_DAWN ],
        [ "Nautic Dawn", NAUTIC_DAWN, DAWN ],
        [ "Blue Hour", DAWN, BLUE_HOUR_AM ],
        [ "Civil Dawn", DAWN, SUNRISE ],
        [ "Sunrise", SUNRISE, SUNRISE_END ],
        [ "Golden Hour", BLUE_HOUR_AM, GOLDEN_HOUR_AM ],
        [ "Morning", SUNRISE, NOON ],
        [ "Afternoon", NOON, SUNSET ],
        [ "Golden Hour", GOLDEN_HOUR_PM, BLUE_HOUR_PM ],
        [ "Sunset", SUNSET_START, SUNSET ],
        [ "Civil Dusk", SUNSET, DUSK ],
        [ "Blue Hour", BLUE_HOUR_PM, DUSK ],
        [ "Nautic Dusk", DUSK, NAUTIC_DUSK ],
        [ "Astr. Dusk", NAUTIC_DUSK, ASTRO_DUSK ],
        [ "Night", ASTRO_DUSK, ASTRO_DUSK+1 ]
        ];

    var display_index;

    function initialize() {
        View.initialize();
        sc = new SunCalc();
        listView = false;
        now = Time.now();
        // for testing now = new Time.Moment(1483225200);
        DAY_IN_ADVANCE = 0;
        lastLoc = null;
        display_index = 0;
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
        display_index = 0; // NOON
        var moment = getMoment(NOON);

        if (now.value() > moment.value()) {
            display_index = 7;
        }

        moment = getMoment(display[display_index][2]);

        while((moment == null) || now.value() > moment.value() ) {
            displayNext();
            moment = getMoment(display[display_index][2]);
            if (display_index == 6) {
                // The sun didn't rise today
                // Display Morning
                break;
            }
            if (DAY_IN_ADVANCE > 0) {
                // The sun does go down today or did not rise.
                // Display Afternoon
                display_index = 7;
                DAY_IN_ADVANCE = 0;
                break;
            }
        }

        myUpdate();
    }

    function displayPrevious()
    {
        display_index--;
        if (display_index < 0) {
            DAY_IN_ADVANCE--;
            display_index = display.size() - 1;
        }
    }

    function displayNext()
    {
        display_index++;
        if (display_index >= display.size()) {
            DAY_IN_ADVANCE++;
            display_index = 0;
        }
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
            findDrawableById("what").setText("Waiting for GPS");
            findDrawableById("time_from").setText("");
            findDrawableById("time_to").setText("");
            Ui.requestUpdate();
            return;
        }
        findDrawableById("what").setText(display[display_index][0]);
        var from = getMoment(display[display_index][1]);
        var to = getMoment(display[display_index][2]);

        if (from == null && to != null) {
            // test if this started the day before
            var what = (2 * NOON - display[display_index][2]) % NUM_RESULTS;
            var day = DAY_IN_ADVANCE - 1;
            from = sc.calculate(new Time.Moment(now.value() + day * Time.Gregorian.SECONDS_PER_DAY), lastLoc, what);
        } else if (to == null && from != null) {
            // test if this ends the day after
            var what = (2 * NOON - display[display_index][1]) % NUM_RESULTS;
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
