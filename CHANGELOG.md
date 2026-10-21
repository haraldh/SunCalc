# Changelog

## [14.1.0](https://github.com/haraldh/SunCalc/compare/v14.0.0...v14.1.0) (2026-10-21)


### Features

* add Nix flake development environment ([e1ccf4d](https://github.com/haraldh/SunCalc/commit/e1ccf4dde25da2c464eda73f40d37da788bb48cf))
* configurable ring/glance topics and a dark/light theme ([1b6978b](https://github.com/haraldh/SunCalc/commit/1b6978b50c58ba90fc15a64f358193a1f65e1a14))
* distinct gold and reddish bands on the twilight ring ([80ba79e](https://github.com/haraldh/SunCalc/commit/80ba79e5d0afe390a9def822dde3cf51e1282cdf))
* Garmin-style 24h twilight ring as the front page ([5633a3d](https://github.com/haraldh/SunCalc/commit/5633a3d7af91bf28cca79c73ef842e535b65ffd2))
* localize into German, French, Spanish, Italian, Dutch, Portuguese ([95dbd3d](https://github.com/haraldh/SunCalc/commit/95dbd3da9a678e06b49b0e8695795312d739a9c4))
* localize the glance labels via scope="glance" ([a1db092](https://github.com/haraldh/SunCalc/commit/a1db09293389aa89e939d05c3c3184b091ef2566))
* native-style glance band and solar noon/midnight markers ([da455fa](https://github.com/haraldh/SunCalc/commit/da455faafb0e780b8e5d6775980098b57e5fd57c))
* scroll days in the ring view with up/down ([dd0cfca](https://github.com/haraldh/SunCalc/commit/dd0cfcae10136ba6777f5c753625e157fd4d94de))
* support all current wearables (136 devices) and add a glance ([e261c59](https://github.com/haraldh/SunCalc/commit/e261c59baa5a6178ab7a17c9b48ef00f18d34016))
* support fēnix 9, MARQ 3, Enduro 4 and Approach S72 ([2291fe6](https://github.com/haraldh/SunCalc/commit/2291fe69742770af83e254e6b664ddc87c2ae92b))


### Bug Fixes

* correct times for positions passed as Floats ([b4ab997](https://github.com/haraldh/SunCalc/commit/b4ab997aec2a242e3d45e648ea47c9a7875c9ad7))
* don't crash on API 1.x devices ([2cfab89](https://github.com/haraldh/SunCalc/commit/2cfab89fd5098a2530e2cd8768e3ca3e611d27a8))
* fit the ring text into the ring on wide screens ([db3c09e](https://github.com/haraldh/SunCalc/commit/db3c09ef3e272ddd2f9f190ffdd2c3960fbef4c5)), closes [#8](https://github.com/haraldh/SunCalc/issues/8)
* glance falls back to the last saved position ([cd91e3a](https://github.com/haraldh/SunCalc/commit/cd91e3a0526589bf861c83195751c50907d8903d))
* keep the glance out of the Rez and Storage APIs it can't use ([492eb64](https://github.com/haraldh/SunCalc/commit/492eb64bd724edcb592e3d67f810bc2cc606cce6))
* make sources pass the monkeyc type checker ([f3f640a](https://github.com/haraldh/SunCalc/commit/f3f640a89d63597bdfa29545a1d5ee63d1d4995f))
* make the ring readable on the Instinct ([d9f9a4e](https://github.com/haraldh/SunCalc/commit/d9f9a4e48cbe6d69b82c8b5296aabe73a4534e1e)), closes [#9](https://github.com/haraldh/SunCalc/issues/9)
* polar-latitude crash and display-selection bugs, add test suite ([f848024](https://github.com/haraldh/SunCalc/commit/f84802400cf5bd06d0caa6238bc6ec592d8fcc88))
* reliable GPS acquisition on the ring view, reddish golden hour ([3f474ec](https://github.com/haraldh/SunCalc/commit/3f474ec67dfaf023b817786e5b4028db5ace3668))
* repeat AppName per language; type the position helpers ([d87a407](https://github.com/haraldh/SunCalc/commit/d87a4074f2a6e14589adb5e048e16d5432d57e01))
