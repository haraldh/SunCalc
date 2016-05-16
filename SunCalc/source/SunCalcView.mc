using Toybox.WatchUi as Ui;
using Toybox.Position as Position;
using Toybox.Time as Time;
using Toybox.Math as Math;
using Toybox.Graphics as Gfx;

class SunCalcView extends Ui.View {

	var sc;
	var listview;
	var now;
	var DAY_IN_ADVANCE = 0;
	var lastLoc;
	
	const display = [
		[ "Astronomical Dawn", NIGHT_END, NAUTICAL_DAWN ],
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
		[ "Astronomical Dusk", NAUTICAL_DUSK, NIGHT ],
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
    }

    //! Load your resources here
    function onLayout(dc) {
        setLayout(Rez.Layouts.MainLayout(dc));
		findDrawableById("what").setText("Waiting for GPS");
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

		display_index = 6; // NOON
		    	
    	var moment = getMoment(display[display_index][2]);
		if (moment.value() > now.value()) {
			display_index = 0;
		}

    	while(moment.value() < now.value()) {
    		displayNext();
    		moment = getMoment(display[display_index][2]);
		}

        myUpdate();
        return View.onShow();
    }

	function setPosition(info) {
		System.println("setPosition()");
		
    	if (info == null || info.accuracy == Position.QUALITY_NOT_AVAILABLE) {
    		return;
    	}

    	var loc = info.position.toRadians();
		DAY_IN_ADVANCE = 0;
		self.lastLoc = loc;
        myUpdate();
	}

	function displayPrevious()
	{
		display_index--;
		if (display_index < 0) {
			DAY_IN_ADVANCE--;
			display_index = display.size() - 1;
		}
        myUpdate();
	}

	function displayNext()
	{
		display_index++;
		if (display_index >= display.size()) {
			DAY_IN_ADVANCE++;
			display_index = 0;
		}
        myUpdate();
	}

	function waitingForGPS() {
		self.lastLoc = null;
        myUpdate();
	}

	function momentToString(moment) {
   		var tinfo = Time.Gregorian.info(new Time.Moment(moment.value() + 30), Time.FORMAT_SHORT);
		var text = tinfo.hour.format("%02d") + ":" + tinfo.min.format("%02d");
		var days = (moment.value() / Time.Gregorian.SECONDS_PER_DAY).toNumber() - (now.value() / Time.Gregorian.SECONDS_PER_DAY).toNumber();
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
	    return sc.calculate(new Time.Moment(now.value() + day * Time.Gregorian.SECONDS_PER_DAY), lastLoc[0], lastLoc[1], what);
	}

    //! Update the view
    function myUpdate() {
    	var text;
		//dc.setColor(Gfx.COLOR_WHITE, Gfx.COLOR_BLACK);

		if (lastLoc == null) {
			findDrawableById("what").setText("Waiting for GPS");
			//dc.drawText(dc.getWidth()/2, dc.getHeight()*1/3, Gfx.FONT_MEDIUM, "Waiting for GPS", Gfx.TEXT_JUSTIFY_CENTER); 
			return;
		}

		if (listview) {
			findDrawableById("up").setText("^");
			findDrawableById("down").setText("v");
			//dc.drawText(dc.getWidth()/2, dc.getHeight()*1/7, Gfx.FONT_MEDIUM, "^", Gfx.TEXT_JUSTIFY_CENTER); 
			//dc.drawText(dc.getWidth()/2, dc.getHeight()*6/7, Gfx.FONT_MEDIUM, "v", Gfx.TEXT_JUSTIFY_CENTER); 			
		} else {
			findDrawableById("up").setText(">");
			findDrawableById("down").setText(">");
			//dc.drawText(dc.getWidth()/2, dc.getHeight()*6/7, Gfx.FONT_MEDIUM, "->", Gfx.TEXT_JUSTIFY_CENTER); 
		}
		
		findDrawableById("what").setText(display[display_index][0]);
		//dc.drawText(dc.getWidth()/2, dc.getHeight()*2/7, Gfx.FONT_MEDIUM, display[display_index][0], Gfx.TEXT_JUSTIFY_CENTER); 

    	var moment = getMoment(display[display_index][1]);
    	if (moment) {
			System.println("Result for " + display[display_index][0]);
			text = momentToString(moment);

			moment = getMoment(display[display_index][2]);
			if (moment) {
				text = text + " - " + momentToString(moment);
			}

			System.println(text);
		} else {
			text = "--";
		}
		//dc.drawText(dc.getWidth()/2, dc.getHeight()*4/7, Gfx.FONT_MEDIUM, text, Gfx.TEXT_JUSTIFY_CENTER); 
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
		if (k == Ui.KEY_ENTER) {
	    	if (enter) {
		        view.waitingForGPS();
		        Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));
				return true;
			} else {
				view.setListView(true);
				Ui.pushView(view, new SunCalcDelegate(view, true), Ui.SLIDE_IMMEDIATE);
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
		return true;
	}

	function onNextPage() {
    	if (!enter) {
    		return false;
    	}

		view.displayNext();
		return true;
	}

	function onPreviousMode() {
    	if (!enter) {
    		return false;
    	}
		view.displayPrevious();
		return true;
	}

	function onNextMode() {
    	if (!enter) {
    		return false;
    	}
		view.displayNext();
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
//		Sys.exit();
	}
}