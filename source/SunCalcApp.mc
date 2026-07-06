using Toybox.Application as App;

var AB = null;

function getPropertyDef(key, def) {
    if (AB == null) {
        // no app instance (unit tests)
        return def;
    }
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
    }

    //! Return the initial view of your application here
    function getInitialView() {
        var view = new SunCalcRingView();
        return [ view, new SunCalcRingDelegate(view) ];
    }

    // stripped via excludeAnnotations on devices without Ui.GlanceView
    (:hasGlance)
    function getGlanceView() {
        return [ new SunCalcGlanceView() ];
    }

    function onSettingsChanged() {
        for (var i = 0; i < DISPLAY.size(); i++) {
           DISPLAY[i][D_SHOW] = getPropertyDef(DISPLAY[i][D_PROP], true);
        }
    }
}
