using Toybox.WatchUi as Ui;
using Toybox.Position as Position;
using Toybox.Time as Time;
using Toybox.Math as Math;

class SunCalcView extends Ui.View {

    function initialize() {
        View.initialize();
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
    	var loc = info.position.toDegrees();
    	System.println(loc[0] + ", " + loc[1]);
    	var sc = new SunCalc();
    	var now = Time.now();
   		var tinfo = Time.Gregorian.info(now, Time.FORMAT_SHORT);
   		System.println(tinfo.year + "." + tinfo.month + "." + tinfo.day);
    	var result = sc.calculate(now, 48.1016736 * Math.PI / 180.0, 11.7564513 * Math.PI / 180.0);
    	var keys = result.keys();
    	for (var i=0; i < keys.size(); i++) {
    		var moment = result[keys[i]];
    		if (moment != null) {
	    		var tinfo = Time.Gregorian.info(moment, Time.FORMAT_SHORT);
    			System.println(keys[i]);
    			System.println(tinfo.year + "." + tinfo.month + "." + tinfo.day + " " + tinfo.hour + ":" + tinfo.min + ":" + tinfo.sec);
    		}
    	}
    }

    //! Update the view
    function onUpdate(dc) {
        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
    }

    //! Called when this View is removed from the screen. Save the
    //! state of this View here. This includes freeing resources from
    //! memory.
    function onHide() {
    }

}
