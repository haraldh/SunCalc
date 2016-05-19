using Toybox.Application as App;

class SunCalcApp extends App.AppBase {

	var view;

	function initialize() {
		AppBase.initialize();
	}

	//! onStart() is called on application start up
	function onStart() {
		Position.enableLocationEvents(Position.LOCATION_ONE_SHOT, method(:onPosition));
	}

	//! onStop() is called when your application is exiting
	function onStop() {
		Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
	}

	function onPosition(info) {
		if (view) {
			view.setPosition(info);
		}
	}

	//! Return the initial view of your application here
	function getInitialView() {
		view = new SunCalcView();
		return [ view, new SunCalcDelegate(view, false) ];
	}

}
