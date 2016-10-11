using Toybox.Application as App;

class SunCalcApp extends App.AppBase {

	function onStart() {
		return false;
	}

	function onStop() {
		return false;
	}

	//! Return the initial view of your application here
	function getInitialView() {
		var view;
		view = new SunCalcView();
		return [ view, new SunCalcDelegate(view, false) ];
	}

}
