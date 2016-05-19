using Toybox.WatchUi as Ui;
using Toybox.Position as Position;
using Toybox.Time as Time;
using Toybox.Math as Math;
using Toybox.Graphics as Gfx;
using Toybox.System as Sys;

class SunCalcView extends Ui.View {

	var sc;
	var listview;
	var now;
	var DAY_IN_ADVANCE;
	var lastLoc;
	var halfheight;
	var is24Hour;

	const display = [
		[ "Astr. Dawn", NIGHT_END, NAUTICAL_DAWN ],
		[ "Nautical Dawn", NAUTICAL_DAWN, DAWN ],
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
		[ "Nautical Dusk", DUSK, NAUTICAL_DUSK ],
		[ "Astr. Dusk", NAUTICAL_DUSK, NIGHT ],
		[ "Night", NIGHT, NIGHT+1 ]
		];

	var display_index;

	function initialize() {
		View.initialize();
		sc = new SunCalc();
		listview = false;
		now = Time.now();
		DAY_IN_ADVANCE = 0;
		lastLoc = null;
		display_index = 0;
		halfheight = null;
		is24Hour = Sys.getDeviceSettings().is24Hour();
	}

	//! Load your resources here
	function onLayout(dc) {
		setLayout(Rez.Layouts.MainLayout(dc));
		findDrawableById("what").setText("Waiting for GPS");
		halfheight = dc.getHeight() / 2;
	}

	//! Called when this View is brought to the foreground. Restore
	//! the state of this View and prepare it to be shown. This includes
	//! loading resources into memory.
	function onShow() {
		var info = Position.getInfo();
		if (info == null || info.accuracy == Position.QUALITY_NOT_AVAILABLE) {
			return;
		}
		setPosition(info);

		return View.onShow();
	}

	function setPosition(info) {

		if (info == null || info.accuracy == Position.QUALITY_NOT_AVAILABLE) {
			return;
		}

		now = Time.now();
		var loc = info.position.toRadians();
		self.lastLoc = loc;

		if (listview == 0) {
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
		self.lastLoc = null;
		myUpdate();
	}

	function momentToString(moment) {
   		var tinfo = Time.Gregorian.info(new Time.Moment(moment.value() + 30), Time.FORMAT_SHORT);
		var text;
		if (is24Hour) {
			text = tinfo.hour.format("%02d") + ":" + tinfo.min.format("%02d");
		} else {
			hour = tinfo.hour % 12;
			if (hour == 0) {
				hour = 12;
			}
			text = hour.format("%02d") + ":" + tinfo.min.format("%02d");
			// wtf... get used to 24 hour format...
			if (tinfo.hour < 12 || tinfo.hour == 24) {
				text = text + " AM";
			} else {
				text = text + " PM";
			}
		}

		var days = (moment.value() / Time.Gregorian.SECONDS_PER_DAY).toNumber()
			- (now.value() / Time.Gregorian.SECONDS_PER_DAY).toNumber();

		if (days > 0) {
			text = text + " +" + days;
		}
		if (days < 0) {
			text = text + " " + days;
		}
		return text;
	}

	function getMoment(what) {
		var day = DAY_IN_ADVANCE;
		if (what > NIGHT) {
			day++;
			what = NIGHT_END;
		}
		now = Time.now();
		return sc.calculate(new Time.Moment(now.value() + day * Time.Gregorian.SECONDS_PER_DAY), lastLoc[0], lastLoc[1], what);
	}

	function onUpdate(dc) {
		Ui.View.onUpdate(dc);

		if (listview) {
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

		if (lastLoc == null) {
			findDrawableById("what").setText("Waiting for GPS");
			findDrawableById("time").setText("");
			Ui.requestUpdate();
			return;
		}

		findDrawableById("what").setText(display[display_index][0]);

		var moment = getMoment(display[display_index][1]);
		if (moment) {
			text = momentToString(moment);

			moment = getMoment(display[display_index][2]);
			if (moment) {
				text = text + " - " + momentToString(moment);
			}

		} else {
			text = "----";
		}
		findDrawableById("time").setText(text);
		Ui.requestUpdate();
	}

	function setListView(b) {
		listview = b;
	}
}

class SunCalcDelegate extends Ui.BehaviorDelegate {
	var view;
	var enter;

	function initialize(v, e) {
		BehaviorDelegate.initialize();
		view = v;
		enter = e;
		var info = Position.getInfo();
		if (info == null || info.accuracy == Position.QUALITY_NOT_AVAILABLE) {
			Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));
		}
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
			if (view.halfheight == null) {
				return BehaviorDelegate.onTap(event);
			}

			var coordinate = event.getCoordinates();
			var event_x = coordinate[0];
			var event_y = coordinate[1];
			if (event_y > view.halfheight) {
				onNextPage();
			} else {
				onPreviousPage();
			}
		} else {
			view.setListView(true);
			Ui.pushView(view, new SunCalcDelegate(view, true), Ui.SLIDE_IMMEDIATE);
		}
		return true;
	}
}
