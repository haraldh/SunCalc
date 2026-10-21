# AGENTS.md

SunCalc is a Garmin Connect IQ widget (Monkey C) that shows sun times:
dawn/dusk (civil, nautical, astronomical), sunrise/sunset, blue and golden
hour, solar noon. Front page is a 24h twilight ring; Enter opens the
period pager; on Connect IQ 4+ devices a glance shows the next sunrise or
sunset. User-facing docs: `docs/USER_GUIDE.md`.

## Architecture

Widget (`type="widget"` in `manifest.xml`); on Connect IQ 4+ devices it
runs as a super app with a glance. No phone connection, no network: all it
needs is a position.

### Source files

- **SunCalc.mc**: the sun algorithm (`SunCalc.calculate(moment, [lat,
  lng] in radians, event)`, a port of the suncalc.js algorithm), returns a
  `Time.Moment` or `null` when the sun never reaches that altitude that
  day (polar day/night). Caches the per-day values (`dec`, `Jnoon`, ...)
  by day and longitude. `momentToString` formats 12/24h with a "+N" day
  offset.
- **SunCalcEnum.mc**: event ids (`ASTRO_DAWN` .. `ASTRO_DUSK`, `NOON` in
  the middle: events before it are morning, after it evening; the
  `TIMES` altitude table in SunCalc.mc mirrors this order), the
  `DISPLAY` row columns (`D_*`) and the topic columns (`T_*`).
- **SunCalcApp.mc**: `SunCalcApp` (initial view = ring, `getGlanceView`
  under `(:hasGlance)`), the global app instance `AB` and
  `getPropertyDef()` for the pager's show/hide properties.
- **SunCalcRingView.mc**: front page. `ringSegments()` turns the
  `RING_BANDS` (astro, nautic, civil, blue hour, sunrise, golden hour) into
  `[dawnFrac, duskFrac]`, `:full` or `null` per band; the view draws the
  24h ring (noon at the top), current-time arc, solar noon/midnight ticks
  and two topic rows. Up/Down scroll days (`dayOffset`), Enter/tap pushes
  the pager. Acquires GPS itself and saves the fix with `saveLoc()`.
- **SunCalcView.mc**: the period pager (`DISPLAY` table: one row per
  period with from/to events, menu id, AM/PM and its `show*` property).
  `selectDisplay()` picks the current period, walking into the next day
  and skipping hidden or non-existent (polar) periods. Menu opens the
  show/hide menu (**SunCalcMenu.mc**).
- **SunCalcTopics.mc**: the `TOPICS` table (pairs of morning/evening
  events used by ring rows and glance; its index order is stored in the
  `ringTop`/`ringBottom`/`glanceTopic` properties and mirrors the
  `listEntry` order in `settings.xml`, so it is API: only append),
  property helpers (`readProperty`, `writeProperty`, `getConfig`,
  `topicFor`) and the saved position (`saveLoc`, `loadStoredLoc`).
- **SunCalcGlance.mc**: `SunCalcGlanceView` (`(:glance :hasGlance)`):
  countdown to the next event of the glance topic, a twilight bar and the
  topic's times. Uses `Pos.getInfo()` or the saved position; never starts
  GPS.
- **SunCalcTest.mc**: unit tests.

### Settings and properties

`resources/settings.xml`: `darkMode`, `ringTop`, `ringBottom`,
`glanceTopic` (indices into `TOPICS`), the `show*` switches of the pager
rows, and the hidden `lastLat`/`lastLng` (radians, 999 = unset) the glance
falls back on. Values from Garmin Connect arrive via
`onSettingsChanged()`.

### Localization

`resources/strings/strings.xml` is English and the fallback;
`resources-<lang>/strings/strings.xml` for deu, fre, spa, ita, dut, por.
A new language needs its folder and an entry in `<iq:languages>` in
`manifest.xml` (`gen-devices.py` keeps that block), or monkeyc ignores
the folder. Strings the glance uses carry `scope="glance"` (the `g*` ids),
in every language file. `AppVersion` is only in the base file and carries
the `x-release-please-version` marker.

## Build and test

The Nix devShell provides the JDK (and on Linux the SDK itself); on macOS
the SDK comes from Garmin's SDK manager (`properties.mk` reads its
`current-sdk.cfg`). The SDK tools need Java, so run everything through
the devShell:

```bash
nix develop -c make build                    # default device (DEVICE in properties.mk)
nix develop -c make build DEVICE=fenix7
nix develop -c make -j buildall              # every device in the manifest
nix develop -c make test DEVICE=epix         # unit tests in the simulator
nix develop -c make run                      # launch in the simulator
nix develop -c make package                  # store package bin/SunCalc.iq
```

`DEVICE`, `SDK_HOME`, `PRIVATE_KEY` (default `~/.id_rsa_garmin.der`) and
`DEPLOY` can be overridden in a gitignored `properties.local.mk`.

The Makefile builds every target in its own `bin/work/<target>/`
directory because monkeyc writes fixed-name scratch files into its output
directory; this is what makes `make -j buildall` safe, do not simplify it.

Expected warnings: `String id 'AppVersion' undefined for language 'dut'`,
the glance entry point note, and on devices without glance "annotation
will be ignored" / "resource scopes are not supported". Keep new code
free of other warnings.

## Devices

`manifest.xml` (products), `monkey.jungle` and the `resources-launcher-*`
icons are generated from the installed device library; never edit them by
hand:

```bash
nix shell nixpkgs#librsvg -c python3 tools/gen-devices.py
```

Run it after updating the SDK/devices in the SDK manager, then build the
new devices and check a few in the simulator. Views draw themselves
relative to the screen size, so a new device needs no layout resources.
Devices without glance get `excludeAnnotations = hasGlance`. Every device
keeps exactly one of `:color` / `:mono` (1-bit screens: Instinct 2/2S/2X/
3 Solar/Crossover/E, Descent G1), which picks the ring drawing
(`monoScreen()`); since a device entry replaces
`base.excludeAnnotations`, the generator repeats it per device.
Watches with a subscreen (`WatchUi.getSubscreen()`) show the sun icon and
the day in the subscreen and keep the ring out of it.

## Pitfalls

- API 1.x devices (epix, fēnix 3, Forerunner 230/235/630/920XT, ...): no
  `Application.Properties` (2.4), no `Array.add()` (1.3). A missing symbol
  is a fatal "Symbol Not Found", not an exception: guard with `has`, not
  `try`. `readProperty`/`writeProperty` in `SunCalcTopics.mc` handle it.
- `SunCalc.calculate()` must work in Double precision: Julian dates are
  ~2.46e6, a Float only resolves 0.25 days there. It widens its input;
  keep it that way.
- Glance process: only `(:glance)` code runs; strings it uses need
  `scope="glance"`; no `Application.Storage` (use Properties); never
  initialize module globals from `Rez` (the glance loads them and
  crashes); 32 kB memory limit.
- Every language listed in the manifest's `<iq:languages>` needs
  `AppName` in its strings file: Garmin Express does not fall back to the
  base language.

## Tests

Unit tests live in `source/SunCalcTest.mc` (`(:test)`). Reference times
come from the sunrise-sunset.org API (see the file header); one test per
place, because a single large table exceeds the object limit of the
oldest devices.

CI (`.github/workflows/build.yml`, image `ghcr.io/matco/connectiq-tester`)
runs the tests on one device per special case: `epix` (API 1.2.1, no
glance, rectangular), `fr235` (semi-round), `instinct2` (monochrome,
subscreen), `marqadventurer` (the maintainer's watch), `fenix8pro47mm`
(AMOLED). Add a device there when a new kind of special case appears
instead of testing everything. The image lags behind the SDK;
`.github/scripts/prune-unknown-devices.sh` drops devices it does not know
yet, so the CI package is not the store package. Each device gets 90 s
and one retry in a freshly started simulator, because the simulator hangs
after some device switches (fenix8pro47mm after marqadventurer, every
run); a device that fails twice fails the job.

Simulator on macOS: one device at a time, `pkill -f
"monkeydo|MonkeyDoDeux"` before each run, rebuild before running. The
SDK 9.3.0 simulator sometimes stumbles when the device changes: it hangs
on the Connect IQ loading triangle, or an API 1.x device (epix) right
after a current one crashes with "Could not find symbol 'initResources'"
and a stack in the other device's build directory. Run the same device a
second time before suspecting the app. Set Settings → Set
Position and Set GPS Quality, otherwise the views wait for GPS. Screen
captures for the store: File → Save Screen Capture.

Test calculation and glance changes on a real watch (MARQ Adventurer) before
a release.

## Releasing

1. Commits follow Conventional Commits. release-please opens a
   "chore(master): release x.y.z" PR; merging it tags `vX.Y.Z` and bumps
   `AppVersion` in `resources/strings/strings.xml`.
2. Build the store package locally with the real key: `nix develop -c
   make package` (the CI artifact is signed with a throwaway key and may
   lack the newest devices). SunCalc is signed with its own key,
   `~/.id_rsa_garmin.der_suncalc`, not the default `~/.id_rsa_garmin.der`
   (that one is gimporter's): set `PRIVATE_KEY` in `properties.local.mk`.
   The store rejects a package signed with any other key ("Signature
   check has failed").
3. Upload `bin/SunCalc.iq` in the Connect IQ developer dashboard
   (https://apps.garmin.com/developer/dashboard).
4. Store versions are named "V<major>" (V14 was the last before
   release-please); use "V<x.y.z>" from now on. "What's new": only what users of the last published version notice, in
   user language, not internal fixes or refactors. Keep the history of
   earlier versions below the new entry, in the existing format
   (`V14:` / `* more devices`). Description, screenshots and device icons
   are edited under the app's details ("Edit Details"):
   - screenshots (max. 5, JPG < 150 kB): simulator window with the device
     frame, cropped on white, 800 px high; set Settings → Set Position
     (e.g. Munich) and Set GPS Quality first
   - hero image (1440×720, < 2 MB): icon, name and tagline on a twilight
     gradient next to two framed screenshots
   - cover image (500×500) and device icons (128×128, 64-colour and
     24-bit), rendered from `SunCalc-icon.svg` with transparent corners
   The current assets are not in the repo; keep the cover image's file
   input apart from the first screenshot's when automating the form.

## Where users report problems

Check both now and then, and always before a release:

- GitHub issues: https://github.com/haraldh/SunCalc/issues
- Connect IQ store reviews:
  https://apps.garmin.com/apps/87b86650-a443-43ea-9dcb-29e4051a5722

Answer in the reporter's language. Replies are public: show the text to
the maintainer before posting, and do not close issues without approval.
