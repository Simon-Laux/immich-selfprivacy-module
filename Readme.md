# immich Module for Self Privacy

## Installation

Since this is a not an official module, you need to add it first
to the inputs of your SP instance.

Login to your server via ssh and open the inputs file:
```sh
nano /etc/nixos/sp-modules/flake.nix
```

Add this to the end of your file, but before `outputs = _: { };`:
```nix
# Your own modules:
  inputs.immich.url = "git+https://github.com/Simon-Laux/immich-selfprivacy-module";
```

Then run this command to make it appear in the selfprivacy app:
```sh
nix flake update --override-input selfprivacy-nixos-config git+https://git.selfprivacy.org/SelfPrivacy/selfprivacy-nixos-config.git?ref=flakes
```

Now you just need to activate the module in the SP app and navigate to the page to setup immich.

### Thanks

Thanks to immich, Self Privacy and Nix Contributors for making nice Software.

Also thanks to SelfPrivacy for making a guide for creating new modules: <https://selfprivacy.org/docs/theory/selfprivacy_modules/>.
