{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=9cb344e96d5b6918e94e1bca2d9f3ea1e9615545";
    rawPatch = {
      url = "https://github.com/immich-app/immich/compare/v1.138.0...Simon-Laux:immich:feat-allow-to-load-client-secret-from-file.patch";
      flake = false;
    };
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, rawPatch, flake-utils }: flake-utils.lib.eachDefaultSystem (system:
    let
      pkgs = nixpkgs.legacyPackages.${system};
      modified_patch = pkgs.stdenv.mkDerivation {
        name = "modified-immich-patch";
        # Fetch the original patch file
        src = rawPatch;
        # don't unpack
        unpackPhase = "true";
        # Use buildInputs to have substituteInPlace available
        nativeBuildInputs = [ pkgs.gnused ];

        # The build phase rewrites the patch paths and outputs the modified patch
        buildPhase = ''
          cp $src modified.patch

          substituteInPlace modified.patch \
            --replace "a/server/src/" "a/src/" \
            --replace "b/server/src/" "b/src/"

          mkdir -p $out
          cp modified.patch $out/
        '';
      };
    in
    {
      packages.default = pkgs.immich.overrideAttrs (previousAttrs: {
        # patch of immich 1.138 (what's currently referenced by self privacy nixpkgs)
        # that also allows file path as clientSecret config.
        # If this works, then I'll make a cleaner pr to immich ton introduce this properly

        # we can not patch source directly because it is defined as let variable in the package.
        # https://github.com/NixOS/nixpkgs/blob/d179d77c139e0a3f5c416477f7747e9d6b7ec315/pkgs/by-name/im/immich/package.nix#L107

        # src = pkgs.fetchFromGitHub {
        #     owner = "Simon-Laux";
        #     repo = "immich";
        #     rev = "feat-allow-to-load-client-secret-from-file";
        #     hash = "sha256-L30KfiP++Tqc6qUkviIkHuo/ndV7+LiNlu1F4aUyw24=";
        #   };

        # so we need to apply it as a patch, note that we can not change the webinterface this way,
        # because it is built before, for that we'd need to patch nixpackages to change the src let variable in the package.nix file
        # https://github.com/NixOS/nixpkgs/blob/d179d77c139e0a3f5c416477f7747e9d6b7ec315/pkgs/by-name/im/immich/package.nix#L107
        #
        # also the patch needs to be modified, because for some reason, that I haven't figgured out yet, the source directory changed to be inside of the server directory
        patches = (if (builtins.hasAttr "patches" previousAttrs) then previousAttrs.patches else []) ++ ["${modified_patch}/modified.patch"];
      });
    }
  );
}
