# immich Module for SelfPrivacy

## Installation

Since this is a not an official module, you need to add it first
to the inputs of your SelfPrivacy instance.

```sh
nano /etc/nixos/flake.nix
```

Add this to the end of the `inputs = {` block:
```nix
  # Your own modules:
  sp-module-immich = {
    url = "git+https://github.com/Simon-Laux/immich-selfprivacy-module";
  };
```

Then run this command to make it appear in the SelfPrivacy app:
```sh
nix flake update --override-input selfprivacy-nixos-config git+https://git.selfprivacy.org/SelfPrivacy/selfprivacy-nixos-config.git?ref=flakes
```

Now you just need to activate the module in the SP app.
Once it is set up you are able to login via SSO.

The main admin account is created in the background, but it is a random, inaccessible dummy account that just needed to exist for SSO to work. You can get an accessible admin account by logging in with an SP account with immich admin privileges via SSO.

### Note on backups from before immich 2.x

Older installs of this module ran immich 1.138 with the pgvecto.rs (`vectors`) postgres extension, which is no longer available in NixOS 26.05.
On the first start after updating, the module drops the stale extension from the database (see `immich-drop-pgvectors.service`), so new backups are fine.
Database backups taken *before* that still contain `CREATE EXTENSION vectors` and cannot be restored as-is on the new system.

### How to delete to start fresh
WARNING: know what you are doing! this deletes all your images.

- disable immich module in the SP app and wait until it is done
- remove immich object from /etc/nixos/userdata.json
- delete the immich folder from /volumes/sda1/immich/ or /volumes/sdb/immich (or whatever you set as data folder)
- delete immich db with `dropdb -U postgres immich`

### Thanks

Thanks to immich, SelfPrivacy and Nix Contributors for making nice software.

Also thanks to SelfPrivacy for making a guide for creating new modules: <https://selfprivacy.org/docs/theory/selfprivacy_modules/>.
