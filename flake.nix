{
  description = "Garmin ConnectIQ (MonkeyC) development environment for SunCalc";

  inputs.nixpkgs.url = "https://flakehub.com/f/NixOS/nixpkgs/0.1";
  # Pinned older nixpkgs for the headless simulator sandbox only: the
  # ConnectIQ simulator links libwebkit2gtk-4.0.so.37 / libsoup-2.4, an ABI
  # that has been dropped from current nixpkgs. 24.05 still ships it.
  inputs.nixpkgs-2405.url = "github:NixOS/nixpkgs/nixos-24.05";

  outputs = inputs:
    let
      lib = inputs.nixpkgs.lib;

      # monkey-run: our own steam-run-equivalent FHS sandbox, carrying exactly
      # the GTK/webkit/GL libraries the x86_64 ConnectIQ simulator needs. All
      # libs come from one nixpkgs generation so sonames (libgcrypt vs
      # libgpg-error, etc.) stay mutually consistent — the mismatch that a
      # mixed host + steam-run stack runs into. Software Mesa (llvmpipe) +
      # lavapipe give it GL without a GPU. x86_64-linux only.
      monkeyRunFor = system:
        let
          p = import inputs.nixpkgs-2405 {
            inherit system;
            config.permittedInsecurePackages = [ "libsoup-2.74.3" ];
          };
        in
        p.buildFHSEnv {
          name = "monkey-run";
          targetPkgs = pkgs: with pkgs; [
            # freetype linked -Bsymbolic: the simulator statically embeds an
            # old freetype and EXPORTS 73 of its symbols (TT_New_Context et
            # al.), which interpose the shared libfreetype's internal calls
            # and crash it (SIGSEGV in TT_Load_Context) as soon as its GTK UI
            # measures text under X11. -Bsymbolic binds libfreetype's
            # intra-library calls locally, immune to the interposition.
            (freetype.overrideAttrs (o: { NIX_LDFLAGS = "-Bsymbolic"; }))
            glib gtk3 atk pango cairo gdk-pixbuf libpng fontconfig
            expat zlib libxkbcommon libsecret libusb1 libjpeg8
            stdenv.cc.cc.lib systemd
            xorg.libX11 xorg.libXext xorg.libXxf86vm xorg.libSM xorg.libICE
            webkitgtk libsoup            # 4.0 ABI + soup 2.4
            libglvnd mesa                # software GL (llvmpipe)
            xorg.xorgserver imagemagick xdotool xorg.xwininfo twm
            glib-networking
            dejavu_fonts
          ];
          runScript = "bash";
        };

      sdkVersion = "9.2.0";
      sdkRelease = "connectiq-sdk-lin-${sdkVersion}-2026-06-09-92a1605b2";

      supportedSystems = [ "x86_64-linux" "aarch64-linux" "x86_64-darwin" "aarch64-darwin" ];
      forEachSupportedSystem = f: lib.genAttrs supportedSystems (system: f {
        pkgs = import inputs.nixpkgs { inherit system; };
        inherit system;
      });

      # The Linux SDK: monkeyc & friends are Java, launched via bash scripts.
      # The simulator binaries are x86_64 ELF and won't run from the store on
      # NixOS anyway (use `make run` with an SDK-manager install for that);
      # this package is the compile/package toolchain.
      #
      # Note: monkeyc computes MB_HOME from $0 and regenerates
      # bin/default.jungle there on every run, so it cannot run directly from
      # the read-only store — the devShell exposes it through a writable
      # symlink shadow instead (see shellHook). That is also why the scripts
      # get their java calls patched to absolute paths rather than being
      # wrapped with wrapProgram (a wrapper would re-anchor $0 in the store).
      connectiqSdkFor = pkgs: pkgs.stdenvNoCC.mkDerivation {
        pname = "connectiq-sdk";
        version = sdkVersion;

        src = pkgs.fetchzip {
          url = "https://developer.garmin.com/downloads/connect-iq/sdks/${sdkRelease}.zip";
          stripRoot = false;
          hash = "sha256-SIiEE71WhEcg67JmT4iuKYfe/gbBVi35I1XPd/3xKlo=";
        };

        dontConfigure = true;
        dontBuild = true;

        installPhase = ''
          runHook preInstall
          mkdir -p $out
          cp -r . $out
          runHook postInstall
        '';

        postFixup = ''
          # Some scripts (e.g. monkeym) ship without the executable bit
          for f in $out/bin/*; do
            if [ -f "$f" ] && grep -Iq '^#!' "$f"; then
              chmod +x "$f"
              sed -i 's|^\([[:space:]]*\)java |\1${pkgs.jdk}/bin/java |' "$f"
            fi
          done
          patchShebangs $out/bin
        '';
      };
    in
    {
      packages = forEachSupportedSystem ({ pkgs, system }:
        lib.optionalAttrs (lib.hasSuffix "linux" system) (rec {
          connectiq-sdk = connectiqSdkFor pkgs;
          default = connectiq-sdk;
        }
        // lib.optionalAttrs (system == "x86_64-linux") {
          monkey-run = monkeyRunFor system;
        }));

      devShells = forEachSupportedSystem ({ pkgs, system }:
        let
          linux = lib.hasSuffix "linux" system;
          sdk = connectiqSdkFor pkgs;
          # `make simcheck` driver: boots the compiled .prg in the headless
          # simulator via the monkey-run sandbox. x86_64-linux only.
          simcheck = pkgs.writeShellApplication {
            name = "ciq-simcheck";
            text = ''
              : "''${SDK_HOME:?run via 'nix develop -c make simcheck'}"
              exec ${monkeyRunFor system}/bin/monkey-run -c \
                "SDK_HOME='$SDK_HOME' bash ${./nix/ciq-sim-run.sh} $*"
            '';
          };
        in
        {
          default = pkgs.mkShell ({
            packages = [ pkgs.jdk ]
              ++ lib.optionals (system == "x86_64-linux") [ simcheck ];
          }
          # On darwin the SDK comes from the SDK manager; properties.mk
          # falls back to its current-sdk.cfg when SDK_HOME is unset.
          // lib.optionalAttrs linux {
            # monkeyc insists on writing bin/default.jungle next to its jar,
            # so give it a writable symlink shadow of the store SDK, keyed by
            # store hash so SDK updates get a fresh shadow.
            shellHook = ''
              sdk_shadow="''${XDG_CACHE_HOME:-$HOME/.cache}/SunCalc/$(basename ${sdk})"
              if [ ! -d "$sdk_shadow" ]; then
                mkdir -p "$sdk_shadow"
                cp -rs ${sdk}/. "$sdk_shadow/"
                chmod -R u+w "$sdk_shadow"
                # monkeybrains resolves its jar's canonical path and writes
                # default.jungle next to the real file, so jars must be
                # real copies, not symlinks into the store
                for jar in "$sdk_shadow"/bin/*.jar; do
                  cp --remove-destination "$(readlink -f "$jar")" "$jar"
                done
              fi
              export SDK_HOME="$sdk_shadow"
            '';
          });
        });
    };
}
