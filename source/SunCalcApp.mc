using Toybox.Application as App;

var AB = null;

function getPropertyDef(key, def) {
    var val = AB.getProperty(key);
    if (val == null) {
        return def;
    } else {
        return val;
    }
}

class SunCalcApp extends App.AppBase {
    function initialize() {
        AppBase.initialize();
        AB = self;
        for (var i = 0; i < DISPLAY.size(); i++) {
            DISPLAY[i][D_SHOW] = getPropertyDef(DISPLAY[i][D_PROP], true);
        }
    }

    //! Return the initial view of your application here
    function getInitialView() {
        var view;
        view = new SunCalcView();
        return [ view, new SunCalcDelegate(view, false) ];
    }

}
