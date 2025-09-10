{
  description = "Immich as Selfprivacy Module";

  outputs = { self }: {
    nixosModules.default = import ./module.nix;
    configPathsNeeded =
      builtins.fromJSON (builtins.readFile ./config-paths-needed.json);
      # docs are under https://selfprivacy.org/docs/theory/selfprivacy_modules/#flake-metadata
    meta = {lib, ...}: {
      spModuleSchemaVersion = 1;
      id = "immich";
      name = "immich";
      description = "immich is a self-hosted photo and video management solution";
      svgIcon = builtins.readFile ./icon.svg;
      showUrl = true;
      isMovable = true;
      isRequired = false;

      # TODO: test if it would work or if sth is missing in files
      canBeBackedUp = true;
      backupDescription = "Configuration and Media";

      # Systemd services that API checks and manipulates
      systemdServices = [
        "immich-server.service"
        "immich-machine-learning.service"
      ];

      user = "immich";
      group = "immich";

      sso = {
        userGroup = "sp.immich.users";
        adminGroup = "sp.immich.admins";
      };

      # Folders that have to be moved or backed up
      # Ownership is implied by the user/group defined above
      folders = [
        "/var/lib/immich" # media location
      ];

      # Same as above, but if you need to overwrite ownership
      ownedFolders = [];

      # PostgreSQL databases to back up
      postgreDatabases = ["immich"];
      license = [
        lib.licenses.agpl3Only
        lib.licenses.cc-by-40 # geonames
      ];
      homepage = "https://immich.app";
      sourcePage = "https://github.com/immich-app/immich";

      # What is our support level for this service?
      # Supported values:
      # - normal
      # - deprecated
      # - experimental
      # - community
      supportLevel = "community";
    };
  };
}
