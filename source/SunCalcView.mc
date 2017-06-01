using Toybox.WatchUi as Ui;
using Toybox.Position as Position;
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

        var info = Position.getInfo();
        if (info == null || info.accuracy == Position.QUALITY_NOT_AVAILABLE) {
            Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:setPosition));
            findDrawableById("what").setText("Waiting for GPS");
            findDrawableById("time_from").setText("");
            findDrawableById("time_to").setText("");
        } else {
            setPosition(info);
        }
    }

    function setPosition(info) {

        if (info == null || info.accuracy == Position.QUALITY_NOT_AVAILABLE) {
            return;
        }

        now = Time.now();
        var loc = info.position.toRadians();
        self.lastLoc = loc;

        if (!listView) {
            DAY_IN_ADVANCE = 0;
            display_index = 6; // NOON
            var moment = getMoment(display[display_index][2]);
            if (moment.value() > now.value()) {
                display_index = 0;
                moment = getMoment(display[display_index][1]);
                if (moment.value() > now.value()) {
                    displayPrevious();
                }
            }
            moment = getMoment(display[display_index][2]);

            while(moment.value() < now.value()) {
                displayNext();
                moment = getMoment(display[display_index][2]);
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

        findDrawableById("time_from").setText(sc.momentToString(getMoment(display[display_index][1]), is24Hour));
        findDrawableById("time_to").setText(sc.momentToString(getMoment(display[display_index][2]), is24Hour));

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
                Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));
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
        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));

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
                Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));
            }
        } else {
            view.setListView(true);
            Ui.pushView(view, new SunCalcDelegate(view, true), Ui.SLIDE_IMMEDIATE);
        }
        return true;
    }
}
