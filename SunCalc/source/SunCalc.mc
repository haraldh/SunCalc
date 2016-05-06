using Toybox.Math as Math;
using Toybox.Time as Time;

class SunCalc {

	hidden const PI   = Math.PI,
		RAD  = Math.PI / 180.0,
		PI2  = Math.PI * 2.0,
		DAYS = Time.Gregorian.SECONDS_PER_DAY,
		J1970 = 2440588,
		J2000 = 2451545,
		J0 = 0.0009;

	hidden const TIMES = [
		[-0.833 * RAD, "sunrise",       "sunset"      ],
		[  -0.3 * RAD, "sunriseEnd",    "sunsetStart" ],
		[    -6 * RAD, "dawn",          "dusk"        ],
		[   -12 * RAD, "nauticalDawn",  "nauticalDusk"],
		[   -18 * RAD, "nightEnd",      "night"       ],
		[     6 * RAD, "goldenHourEnd", "goldenHour"  ]
		];

	function fromJulian(j) {
		return new Time.Moment((j + 0.5 - J1970) * DAYS);
	}

	// lat and lng in radians
	function calculate(moment, lat, lng) {
		var d = moment.value() / DAYS - 0.5 + J1970 - J2000,
			n = Math.round(d - J0 + lng / PI2),
			ds = J0 - lng / PI2 + n,
			M = 6.240059967 + 0.01720197 * ds,
			sinM = Math.sin(M),
			C = (1.9148 * sinM + 0.02 * Math.sin(2 * M) + 0.0003 * Math.sin(3 * M)) * RAD,
			L = M + C + 1.796593063 + PI,
			sin2L = Math.sin(2 * L),
			dec = Math.asin( 0.397783703 * Math.sin(L) ),
			Jnoon = J2000 + ds + 0.0053 * sinM - 0.0069 * sin2L;


		var result = {
			"solarNoon" => fromJulian(Jnoon),
			"nadir" => fromJulian(Jnoon - 0.5)
		};

		for (var i = 0; i < TIMES.size(); i ++) {
			var time = TIMES[i];
			var x = (Math.sin(time[0]) - Math.sin(lat) * Math.sin(dec)) / (Math.cos(lat) * Math.cos(dec));

			if (x <= 1.0 && x >= -1.0) {
				var ds = J0 + (Math.acos(x) - lng) / PI2 + n;
				var Jset = J2000 + ds + 0.0053 * sinM - 0.0069 * sin2L;
				var Jrise = Jnoon - (Jset - Jnoon);
				result[time[1]] = fromJulian(Jrise);
				result[time[2]] = fromJulian(Jset);
			} else {
				result[time[1]] = null;
				result[time[2]] = null;
			}
		}
		return result;
	}
}
