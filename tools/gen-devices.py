#!/usr/bin/env python3
"""Regenerate device support from the installed ConnectIQ device library.

Scans ~/Library/Application Support/Garmin/ConnectIQ/Devices (or
~/.Garmin/ConnectIQ/Devices on Linux) for all wearable devices that can run
a widget (natively, or as a super app on CIQ >= 4) and rewrites:

  - manifest.xml            <iq:products> list
  - monkey.jungle           per-device launcher icon resourcePath +
                            excludeAnnotations=hasGlance for devices
                            without glance support
  - resources-<family>/     layout.xml + drawables.xml scaled from the
                            round-240x240 template (only if missing)
  - resources-launcher-*/   launcher_icon.png rendered from
                            SunCalc-icon.svg (requires rsvg-convert,
                            e.g. `nix shell nixpkgs#librsvg`)

Run after installing a new SDK / device updates:
  nix shell nixpkgs#librsvg -c python3 tools/gen-devices.py
"""
import glob, json, os, re, subprocess, sys

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HANDHELD = re.compile(r"^(edge|gpsmap|montana|oregon|rino|etrex|echomap)")

def devices_dir():
    for p in ("~/Library/Application Support/Garmin/ConnectIQ/Devices",
              "~/.Garmin/ConnectIQ/Devices"):
        p = os.path.expanduser(p)
        if os.path.isdir(p):
            return p
    sys.exit("no ConnectIQ device library found - install an SDK via the SDK manager")

def scan():
    wear = []
    for f in sorted(glob.glob(os.path.join(devices_dir(), "*", "compiler.json"))):
        j = json.load(open(f))
        types = {a["type"] for a in j.get("appTypes", [])}
        d = j["deviceId"]
        if HANDHELD.match(d) or not ({"widget", "watchApp"} & types):
            continue
        li = j.get("launcherIcon", {})
        wear.append(dict(id=d, fam=j.get("deviceFamily"),
                         launcher=f'{li.get("width")}x{li.get("height")}',
                         glance="glance" in types))
    return wear

def r(v):
    return int(round(v))

def gen_family(fam):
    shape, dims = fam.split("-")
    W, H = map(int, dims.split("x"))
    sx, sy = W / 240.0, H / 240.0
    # 1-bit displays dither gray away
    bar_color = "Gfx.COLOR_BLACK" if shape == "semioctagon" else "Gfx.COLOR_DK_GRAY"
    d = os.path.join(REPO, f"resources-{fam}")
    os.makedirs(os.path.join(d, "drawables"), exist_ok=True)
    os.makedirs(os.path.join(d, "layouts"), exist_ok=True)
    cx = W // 2
    aw, ah, top = r(11 * sx), r(10 * sy), r(5 * sy)
    bot = H - top
    ax, ay = r(115 * sx), r(15 * sy)
    with open(os.path.join(d, "drawables", "drawables.xml"), "w") as f:
        f.write(f'''<drawables>
		<drawable-list id="Arrow_updown">
			<shape type="polygon" points="[[{cx},{top}], [{cx-aw},{top+ah}], [{cx+aw},{top+ah}]]" color="Gfx.COLOR_BLACK" />
			<shape type="polygon" points="[[{cx},{bot}], [{cx-aw},{bot-ah}], [{cx+aw},{bot-ah}]]" color="Gfx.COLOR_BLACK" />
		</drawable-list>
		<drawable-list id="Arrow_right">
			<shape type="polygon" points="[[{ax},{ay}], [{ax},{ay+r(20*sy)}], [{ax+r(10*sx)},{ay+r(10*sy)}]]" color="Gfx.COLOR_BLACK" />
		</drawable-list>

	    <drawable-list id="gray_horizontal_up_bar">
	    	<shape type="rectangle" color="{bar_color}" x="0" y="{r(45*sy)}" width="fill" height="2" />
	    </drawable-list>
	    <drawable-list id="gray_horizontal_down_bar">
	    	<shape type="rectangle" color="{bar_color}" x="0" y="{r(195*sy)}" width="fill" height="2" />
	    </drawable-list>
	    <drawable-list id="white_background">
	        <shape type="rectangle" color="Gfx.COLOR_WHITE" x="0" y="0" width="fill" height="fill" />
	    </drawable-list>
</drawables>
''')
    with open(os.path.join(d, "layouts", "layout.xml"), "w") as f:
        f.write(f'''<layout id="MainLayout">
	<drawable id="white_background" />
	<drawable id="gray_horizontal_up_bar" />
	<drawable id="gray_horizontal_down_bar" />

	<label id="what"      x="center" y="{r(50*sy)}"  font="Gfx.FONT_LARGE" color="Gfx.COLOR_BLACK" justification="Gfx.TEXT_JUSTIFY_CENTER" />
	<label id="time_from" x="center" y="{r(100*sy)}" font="Gfx.FONT_MEDIUM" color="Gfx.COLOR_BLACK" justification="Gfx.TEXT_JUSTIFY_CENTER" />
	<label text="@Strings.dash"       x="center" y="{r(120*sy)}" font="Gfx.FONT_MEDIUM" color="Gfx.COLOR_BLACK" justification="Gfx.TEXT_JUSTIFY_CENTER" />
	<label id="time_to"   x="center" y="{r(140*sy)}" font="Gfx.FONT_MEDIUM" color="Gfx.COLOR_BLACK" justification="Gfx.TEXT_JUSTIFY_CENTER" />
</layout>
''')

def gen_launcher(size):
    d = os.path.join(REPO, f"resources-launcher-{size}")
    os.makedirs(os.path.join(d, "drawables"), exist_ok=True)
    xml = os.path.join(d, "drawables", "launcher_icon.xml")
    if not os.path.exists(xml):
        with open(xml, "w") as f:
            f.write('<drawables>\n    <bitmap id="LauncherIcon" filename="launcher_icon.png" />\n</drawables>\n')
    w, h = map(int, size.split("x"))
    m = min(w, h)
    subprocess.run(["rsvg-convert", "-w", str(m), "-h", str(m),
                    "--page-width", str(w), "--page-height", str(h),
                    "--left", str((w - m) // 2), "--top", str((h - m) // 2),
                    os.path.join(REPO, "SunCalc-icon.svg"),
                    "-o", os.path.join(d, "drawables", "launcher_icon.png")],
                   check=True)

def main():
    wear = scan()
    print(f"{len(wear)} wearable devices")

    for fam in sorted({w["fam"] for w in wear}):
        if not os.path.isdir(os.path.join(REPO, f"resources-{fam}")):
            gen_family(fam)
            print(f"new family {fam}")
    for size in sorted({w["launcher"] for w in wear}):
        gen_launcher(size)

    products = "\n".join(f'      <iq:product id="{w["id"]}"/>'
                         for w in sorted(wear, key=lambda x: x["id"]))
    mf = os.path.join(REPO, "manifest.xml")
    m = open(mf).read()
    m = re.sub(r"(<iq:products>\n).*?(\n    </iq:products>)",
               r"\1" + products + r"\2", m, flags=re.S)
    open(mf, "w").write(m)

    lines = ["# Generated by tools/gen-devices.py - do not edit by hand",
             "project.manifest = manifest.xml",
             "base.sourcePath = source", ""]
    for w in sorted(wear, key=lambda x: x["id"]):
        lines.append(f'{w["id"]}.resourcePath = resources-launcher-{w["launcher"]};$({w["id"]}.resourcePath)')
    lines.append("")
    lines.append("# no Ui.GlanceView on these devices - strip the glance code")
    for w in sorted(wear, key=lambda x: x["id"]):
        if not w["glance"]:
            lines.append(f'{w["id"]}.excludeAnnotations = hasGlance')
    open(os.path.join(REPO, "monkey.jungle"), "w").write("\n".join(lines) + "\n")
    nog = sum(1 for w in wear if not w["glance"])
    print(f"manifest: {len(wear)} products; jungle: {len(wear)} launcher mappings, {nog} glance exclusions")

if __name__ == "__main__":
    main()
