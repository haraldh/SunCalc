# SunCalc
The SunCalc widget calculates all useful times for the sun, like sunset, sunrise, dusk, dawn, blue hour, golden hour.

The widget is available in the Garmin Connect IQ store:
https://apps.garmin.com/en-US/apps/87b86650-a443-43ea-9dcb-29e4051a5722

On Connect IQ 4+ devices (fēnix 7 and newer) the widget runs as a super
app with a glance showing the next sunrise/sunset.

See the **[User Guide](docs/USER_GUIDE.md)** for how to use it, with screenshots.

## Development

With [Nix](https://nixos.org) and [direnv](https://direnv.net) the dev
environment (JDK, and on Linux the ConnectIQ SDK itself) comes up
automatically; otherwise install the SDK via Garmin's SDK manager.

    make build              # default device (see properties.mk)
    make -j buildall        # all supported devices
    make test               # unit tests in the simulator
    make run                # launch in the simulator

Device support (the manifest product list, the monkey.jungle, and
per-device launcher icons) is generated from the installed device library.
The views draw themselves in code, so no per-screen-size layout resources
are needed:

    nix shell nixpkgs#librsvg -c python3 tools/gen-devices.py
