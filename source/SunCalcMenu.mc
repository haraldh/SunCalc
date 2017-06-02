using Toybox.System as Sys;
using Toybox.WatchUi as Ui;

class SettingsMenuAMPM extends Ui.Menu {
    function initialize(indexAM, indexPM) {
        var showAM = null;
        var showPM = null;

        Menu.initialize();
        Menu.setTitle(Rez.Strings.SettingsMenuTitleAMPM);

        if (indexAM != null) {
            showAM = DISPLAY[indexAM][D_SHOW];
        }
        if (indexPM != null) {
            showPM = DISPLAY[indexPM][D_SHOW];
        }

        if (showAM != null) {
            if (showAM) {
                addItem(Rez.Strings.MenuAMOn, :AM);
            } else {
                addItem(Rez.Strings.MenuAMOff, :AM);
            }

            if (showPM) {
                addItem(Rez.Strings.MenuPMOn, :PM);
            } else {
                addItem(Rez.Strings.MenuPMOff, :PM);
            }
        } else {
            if (showPM) {
                addItem(Rez.Strings.MenuOn, :PM);
            } else {
                addItem(Rez.Strings.MenuOff, :PM);
            }
        }
    }
}

class SettingsMenuAMPMDelegate extends Ui.MenuInputDelegate {
    var mIndexAM = null;
    var mIndexPM = null;

    function initialize(indexAM, indexPM) {
        MenuInputDelegate.initialize();
        mIndexAM = indexAM;
        mIndexPM = indexPM;
    }

    function onMenuItem(item) {
        if (item == :AM) {
            DISPLAY[mIndexAM][D_SHOW] = !DISPLAY[mIndexAM][D_SHOW];
            AB.setProperty(DISPLAY[mIndexAM][D_PROP], DISPLAY[mIndexAM][D_SHOW]);
        } else if (item == :PM) {
            DISPLAY[mIndexPM][D_SHOW] = !DISPLAY[mIndexPM][D_SHOW];
            AB.setProperty(DISPLAY[mIndexPM][D_PROP], DISPLAY[mIndexPM][D_SHOW]);
        }

        Ui.popView(Ui.SLIDE_IMMEDIATE);
        Ui.pushView(new SettingsMenuAMPM(mIndexAM, mIndexPM), new SettingsMenuAMPMDelegate(mIndexAM, mIndexPM), Ui.SLIDE_IMMEDIATE);
        return true;
    }
}

class SettingsMenuDelegate extends Ui.MenuInputDelegate {

    function initialize() {
        MenuInputDelegate.initialize();
    }

    function onMenuItem(item) {
        var indexAM = null;
        var indexPM = null;

        for (var i = 0; i < DISPLAY.size(); i++) {
            if (item.equals(DISPLAY[i][D_MENU])) {
                if (DISPLAY[i][D_AMPM] == :AM) {
                    indexAM = i;
                } else if (DISPLAY[i][D_AMPM] == :PM) {
                    indexPM = i;
                    break;
                }
            }
        }

        Ui.pushView(new SettingsMenuAMPM(indexAM, indexPM),
                    new SettingsMenuAMPMDelegate(indexAM, indexPM), Ui.SLIDE_UP);
    }
}
