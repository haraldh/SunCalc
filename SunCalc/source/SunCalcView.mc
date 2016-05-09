using Toybox.WatchUi as Ui;
using Toybox.Position as Position;
using Toybox.Time as Time;
using Toybox.Math as Math;
using Toybox.Graphics as GFX;

class SunCalcView extends Ui.View {

	var sc;
	var result;
	var listview;
	
	const display = [
		"Night End",
		"Nautical Dawn",
		"Dawn",
		"Sunrise",
		"Sunrise End",
		"Golden Hour End",
		"Golden Hour",
		"Sunset Start",
		"Sunset",
		"Dusk",
		"Nautical Dusk",
		"Night"	];

	var display_index = 0;

    function initialize() {
        View.initialize();
    	sc = new SunCalc();
    	result = null;
    	listview = false;
    }

    //! Load your resources here
    function onLayout(dc) {
        setLayout(Rez.Layouts.MainLayout(dc));
    }
	
    //! Called when this View is brought to the foreground. Restore
    //! the state of this View and prepare it to be shown. This includes
    //! loading resources into memory.
    function onShow() {
    	var info = Position.getInfo();
    	if (info == null || info.accuracy == Position.QUALITY_NOT_AVAILABLE) {
    		return;
    	}
    	var loc = info.position.toRadians();
    	self.result = sc.calculate(Time.now(), loc[0], loc[1]);
    	View.onShow();
    	display_index = 9;
    }

	function setPosition(info) {
    	if (info == null || info.accuracy == Position.QUALITY_NOT_AVAILABLE) {
    		return;
    	}
    	var loc = info.position.toRadians();
    	self.result = sc.calculate(Time.now(), loc[0], loc[1]);
        Ui.requestUpdate();
	}

	function displayPrevious()
	{
		display_index = (display_index - 2 + display.size()) % (display.size() - 1);
        Ui.requestUpdate();
	}

	function displayNext()
	{
		display_index = (display_index + 1) % (display.size() - 1);
        Ui.requestUpdate();
	}

	function waitingForGPS() {
		self.result = null;
        Ui.requestUpdate();
	}
	
    //! Update the view
    function onUpdate(dc) {
        View.onUpdate(dc);
		dc.setColor(GFX.COLOR_WHITE, GFX.COLOR_BLACK);

		if (result == null) {
			dc.drawText(dc.getWidth()/2, dc.getHeight()*1/3, GFX.FONT_MEDIUM, "Waiting for GPS", GFX.TEXT_JUSTIFY_CENTER); 
			return;
		}
		if (listview) {
			dc.drawText(dc.getWidth()/2, dc.getHeight()*1/7, GFX.FONT_MEDIUM, "^", GFX.TEXT_JUSTIFY_CENTER); 
			dc.drawText(dc.getWidth()/2, dc.getHeight()*6/7, GFX.FONT_MEDIUM, "v", GFX.TEXT_JUSTIFY_CENTER); 			
		} else {
			dc.drawText(dc.getWidth()/2, dc.getHeight()*6/7, GFX.FONT_MEDIUM, "->", GFX.TEXT_JUSTIFY_CENTER); 
		}

    	var moment = result[display[display_index]];
    	if (moment) {
	   		var tinfo = Time.Gregorian.info(new Time.Moment(moment.value() + 30), Time.FORMAT_SHORT);
			var text = tinfo.hour.format("%02d") + ":" + tinfo.min.format("%02d");
			dc.drawText(dc.getWidth()/2, dc.getHeight()*2/7, GFX.FONT_MEDIUM, display[display_index], GFX.TEXT_JUSTIFY_CENTER); 
			dc.drawText(dc.getWidth()/2, dc.getHeight()*4/7, GFX.FONT_MEDIUM, text, GFX.TEXT_JUSTIFY_CENTER); 
			System.println(text);
		}
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
    	if (enter) {
	        Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
			view.setListView(false);
			Ui.popView(Ui.SLIDE_IMMEDIATE);
	        return true;
    	}
		return BehaviorDelegate.onBack();
//		Sys.exit();
	}
}