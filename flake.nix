{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    systems.url = "github:nix-systems/default-linux";
    hyprcursor.url = "github:spikespaz/hyprcursor/patch-1";
  };

  outputs = { self, nixpkgs, systems, hyprcursor }:
    let
      inherit (nixpkgs) lib;
      eachSystem = lib.genAttrs (import systems);
      pkgsFor = eachSystem (system:
        import nixpkgs {
          localSystem.system = system;
          overlays = [ self.overlays.default ];
        });

      mkDate = longDate:
        (lib.concatStringsSep "-" [
          (builtins.substring 0 4 longDate)
          (builtins.substring 4 2 longDate)
          (builtins.substring 6 2 longDate)
        ]);
      date = (mkDate (self.lastModifiedDate or "19700101")) + "_"
        + (self.shortRev or "dirty");

      mkHyprcursorTheme = pkgs:
        args@{ pname, themeName, version, src, meta ? { }, manifest ? {
          General = {
            name = themeName;
            description = meta.description or self.name;
            inherit version;
            cursors_directory = "hyprcursors";
          };
        }, ... }:
        let
          ownArgs = lib.attrNames (lib.functionArgs mkHyprcursorTheme);
          args' = removeAttrs args ownArgs;
          toml = pkgs.formats.toml { };
        in pkgs.stdenv.mkDerivation (self:
          {
            inherit pname version src;

            passthru.manifest = manifest;

            nativeBuildInputs = [
              pkgs.xcur2png # why, I am using patch-1
              hyprcursor.packages.x86_64-linux.hyprcursor
            ];

            buildPhase = ''
              set -x
              srcname="$(basename $src)"
              hyprcursor-util --extract $src -o .
              rm ./extracted_$srcname/manifest.hl
              cp ${
                toml.generate "${self.pname}-manifest.toml"
                self.passthru.manifest
              } ./extracted_$srcname/manifest.toml
              mkdir "${self.pname}"
              hyprcursor-util --create ./extracted_$srcname -o .
            '';

            installPhase = ''
              mkdir -p "$out/share/icons/"
              cp -r "./theme_${self.passthru.manifest.General.name}" \
                "$out/share/icons/${self.pname}"
            '';
          } // args');
    in {
      packages = eachSystem (system: {
        inherit (pkgsFor.${system})
          quintom-ink-hyprcursor-theme quintom-snow-hyprcursor-theme;
      });

      overlays = {
        default = with self.overlays;
          lib.composeManyExtensions [
            self.inputs.hyprcursor.overlays.default
            quintom-ink-hyprcursor-theme
            quintom-snow-hyprcursor-theme
          ];

        quintom-ink-hyprcursor-theme = pkgs: pkgs0: {
          quintom-ink-hyprcursor-theme = mkHyprcursorTheme pkgs {
            pname = "quintom-ink-hyprcursor";
            themeName = "Quintom Ink";
            version = date;
            src = ./. + "/Quintom_Ink Cursors/Quintom_Ink";
            meta.description = "Quintom Ink Hyprcursor Theme";
          };
        };

        quintom-snow-hyprcursor-theme = pkgs: pkgs0: {
          quintom-snow-hyprcursor-theme = mkHyprcursorTheme pkgs {
            pname = "quintom-snow-hyprcursor";
            themeName = "Quintom Snow";
            version = date;
            src = ./. + "Quintom_Snow Cursors/Quintom_Snow";
            meta.description = "Quintom Snow Hyprcursor Theme";
          };
        };
      };

      formatter = eachSystem (system: pkgsFor.${system}.nixfmt-classic);
    };
}
