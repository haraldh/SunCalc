# AGENTS.md

SunCalc is a Garmin Connect IQ widget (Monkey C) that shows sun times:
dawn/dusk (civil, nautical, astronomical), sunrise/sunset, blue and golden
hour, solar noon. Front page is a 24h twilight ring; Enter opens the
period pager; on Connect IQ 4+ devices a glance shows the next sunrise or
sunset. User-facing docs: `docs/USER_GUIDE.md`.

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
Devices without glance get `excludeAnnotations = hasGlance`.

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
yet, so the CI package is not the store package.

Simulator on macOS: one device at a time, `pkill -f
"monkeydo|MonkeyDoDeux"` before each run, rebuild before running. The
`fenix847mm` profile hangs in the SDK 9.3.0 simulator. Set Settings → Set
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
   lack the newest devices).
3. Upload `bin/SunCalc.iq` in the Connect IQ developer dashboard
   (https://apps.garmin.com/developer/dashboard).
4. "What's new": only what users of the last published version notice, in
   user language, not internal fixes or refactors. Keep the history of
   earlier versions below the new entry. Description, screenshots and
   device icons are edited under the app's details.

## Where users report problems

Check both now and then, and always before a release:

- GitHub issues: https://github.com/haraldh/SunCalc/issues
- Connect IQ store reviews:
  https://apps.garmin.com/en-US/apps/87b86650-a443-43ea-9dcb-29e4051a5722

Answer in the reporter's language. Replies are public: show the text to
the maintainer before posting, and do not close issues without approval.
