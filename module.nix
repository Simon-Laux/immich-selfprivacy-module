{patchedImmich }:{ config, lib, pkgs, ... }:
let
  # Just for convinience, this module's config values
  sp = config.selfprivacy;
  cfg = sp.modules.immich;

  oauthClientID = "immich";
  auth-passthru = config.selfprivacy.passthru.auth;
  # oauth2-provider-name = auth-passthru.oauth2-provider-name;
  redirectUris = [
    # https://immich.app/docs/administration/oauth/#prerequisites
    "app.immich:///oauth-callback"
    "https://${cfg.subdomain}.${sp.domain}/auth/login"
    "https://${cfg.subdomain}.${sp.domain}/user-settings"
  ];
  oauthDiscoveryURL = auth-passthru.oauth2-discovery-url oauthClientID;

  # SelfPrivacy uses SP Module ID to identify the group!
  adminsGroup = "sp.immich.admins";
  usersGroup = "sp.immich.users";

  # INFO: immich is the default user & group that is created by the immich nixos service
  # if we change this we may need to create the user and group in this file instead
  linuxUserOfService = "immich";
  linuxGroupOfService = "immich";

  # serviceAccountTokenFP = auth-passthru.mkServiceAccountTokenFP linuxGroupOfService;
  oauthClientSecretFP = auth-passthru.mkOAuth2ClientSecretFP linuxGroupOfService;
in
{
  # Here go the options you expose to the user.
  options.selfprivacy.modules.immich = {
    # This is required and must always be named "enable"
    enable = (lib.mkOption {
      default = false;
      type = lib.types.bool;
      description = "Enable the service";
    }) // {
      meta = {
        type = "enable";
      };
    };
    # This is required if your service stores data on disk
    location = (lib.mkOption {
      type = lib.types.str;
      description = "Service location";
    }) // {
      meta = {
        type = "location";
      };
    };
    # This is required if your service needs a subdomain
    subdomain = (lib.mkOption {
      default = "photo";
      type = lib.types.strMatching "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
      description = "Subdomain";
    }) // {
      meta = {
        widget = "subdomain";
        type = "string";
        regex = "[A-Za-z0-9][A-Za-z0-9\-]{0,61}[A-Za-z0-9]";
        weight = 0;
      };
    };
    # Other options, that user sees directly.
    # Refer to Module options reference to learn more.

    # TODO services.immich.machine-learning.enable
    machineLearningEnable = (lib.mkOption {
      default = true;
      type = lib.types.bool;
      description = "Enable Machine Learning Features";
    }) // {
      meta = {
        type = "bool";
        weight = 1;
      };
    };
    # TODO check relevant settings on services.immich.settings
    # TODO services.immich.accelerationDevices
    # defaultStorageClaim = (lib.mkOption {
    #   default = 2;
    #   type = lib.types.int;
    #   description = "How much Storage Quota users have by default in GiB. Set to 0 for unlimited";
    # }) // {
    #   meta = {
    #     type = "int";
    #     weight = 2;
    #     minValue = 0;
    #   };
    # };

    # Why do we need this?
    # ====================
    # Problem:
    #  immich normally makes the first registered user admin,
    #  which is a potential problem on a publicly accessible setup like self-privacy,
    #  since some bot may beat you to the punch and snatch the admin account before you do it.
    #  This also is not acceptable for unattended installations, because it leaves a big security hole.
    #
    # Solution:
    #  So our solution is to block the API for creating the new admin account
    #  and create it automatically on startup if it does not exist yet.
    #
    #  The account we create is a dummy account that has a random username and credentials.
    #  To get an actual usable account, you should log in with a Self Privacy account that has admin privileges for immich.
    OnlyAllowSSOLogin = (lib.mkOption {
      default = true;
      type = lib.types.bool;
      description = "Only allow SSO login and automatically create an admin account. If that doesn't work, then you may need to change this option temporarely to create an admin account.";
    }) // {
      meta = {
        type = "bool";
        weight = 1;
      };
    };
  };
  # All your changes to the system must go to this config attrset.
  # It MUST use lib.mkIf with an enable option.
  # This makes sure your module only makes changes to the system
  # if the module is enabled.
  config = lib.mkIf cfg.enable {
    # If your service stores data on disk, you have to mount a folder
    # for this. useBinds is always true on modern SelfPrivacy installations
    # but we keep this mkIf to keep migration flow possible.
    fileSystems = lib.mkIf sp.useBinds {
      "/var/lib/immich" = {
        device = "/volumes/${cfg.location}/immich";
        # Make sure that your service does not start before folder mounts
        options = [
          "bind"
          "x-systemd.required-by=immich-server.service"
          "x-systemd.required-by=immich-machine-learning.service"
          "x-systemd.before=immich-server.service"
          "x-systemd.before=immich-machine-learning.service"
        ];
      };
    };
    # Your service configuration, varies heavily.
    # Refer to NixOS Options search.
    # You can use defined options here.
    services.immich = {
      enable = true;
      machine-learning.enable = cfg.machineLearningEnable;
      settings.server.externalDomain = "https://${cfg.subdomain}.${sp.domain}";
      user = linuxUserOfService;
      group = linuxGroupOfService;
    };
    systemd = {
      services = {
        immich-server.serviceConfig.Slice = lib.mkForce "immich.slice";
        immich-machine-learning.serviceConfig.Slice = lib.mkForce "immich.slice";

        immich-auto-register-admin = lib.mkIf cfg.OnlyAllowSSOLogin {
          description = "Startup script that auto-registers the first user admin account once the website is up";
          after = [ "immich-server.service" ];
          requires = [ "immich-server.service" ];
          wantedBy = [ "multi-user.target" ];
          Slice = "immich.slice";
          path = [ pkgs.curl pkgs.bash ];
          script = ''
            while true; do
              response=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:2283/)
              if [ "$response" = "200" ]; then
                admin_email="admin@immich.selfprivacy.local"
                admin_password=$(head /dev/urandom | tr -dc A-Za-z0-9 | head -c42)
                admin_name="Admin$(head /dev/urandom | tr -dc A-Za-z | head -c8)"
                sleep 3
                curl -X POST -H "Content-Type: application/json" \
                  -d "{\"email\":\"$admin_email\",\"password\":\"$admin_password\",\"name\":\"$admin_name\"}" \
                  http://localhost:2283/api/auth/admin-sign-up
                echo "Request to register admin account was made. (it returns an error when it already exists, which can be ignored)"
                break
              fi
              sleep 3
              echo "still waiting for immich to be up (debug: $response)"
            done
          '';
          serviceConfig = {
            Type = "simple";
            Restart = "no";
            RemainAfterExit = false;
          };
        };

      };
      # Define the slice itself
      slices.immich = {
        description = "Immich (self-hosted photo and video backup solution) slice (on selfprivacy)";
      };
    };
    # You can define a reverse proxy for your service like this
    services.nginx.virtualHosts."${cfg.subdomain}.${sp.domain}" = {
      useACMEHost = sp.domain;
      forceSSL = true;
      extraConfig = ''
        add_header Strict-Transport-Security $hsts_header;
        add_header 'Referrer-Policy' 'origin-when-cross-origin';
        add_header X-Frame-Options SAMEORIGIN;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";

        # FIXME is it needed?
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
      '';
      # longest specific match matters
      locations = {
        "/" = {
          proxyPass = "http://localhost:2283";
          proxyWebsockets = true;
        };

      } // (if cfg.OnlyAllowSSOLogin then {
          # Thanks to immich's PWA service worker magic,
          # this page opens anyway somehow,
          # so not much point in blocking it
          # "/auth/register" = {
          #  return = "403";
          # };

          "/api/auth/admin-sign-up"= {
            return = "403";
          };
        }
        else {}
      );
    };

  # SSO
    assertions = [
      {
        assertion = sp.sso.enable;
        message = "This module needs SSO. Please update your SP instance to enable it.";
      }
    ];

    # disable password login, in hope that this solves the first signup becomes admin problem
    services.immich.settings.passwordLogin.enabled = false;

    services.immich.settings.oauth = {
      enabled = true;
      autoRegister = true;
      # https://immich.app/docs/administration/oauth/#auto-launch
      autoLaunch = cfg.OnlyAllowSSOLogin;
      buttonText = "Login with Kanidm";

      clientId = "immich";
      # this needs patched immich, which we do at the end of this file
      clientSecret = oauthClientSecretFP;
      scope = "openid email profile";

      issuerUrl = oauthDiscoveryURL; # TODO is this correct?

      # https://immich.app/docs/administration/oauth/#mobile-redirect-uri
      mobileOverrideEnabled = false;
      # mobileRedirectUri: "";

      signingAlgorithm = "ES256";
      # profileSigningAlgorithm = "none";

      # Default quota for user without storage quota claim (empty for unlimited quota)
      # (in GiB)
      defaultStorageQuota = 2 ;#cfg.defaultStorageClaim;

      # Claim mapping for the user's role. (should return "user" or "admin")
      roleClaim = "groups";
      storageLabelClaim = "preferred_username";

      # TODO: custom claims from UI? does SP support that?
      # storageQuotaClaim = "immich_quota";
    };

    selfprivacy.auth.clients."${oauthClientID}" = {
      inherit adminsGroup usersGroup;
      imageFile = ./icon.svg;
      displayName = "immich";
      subdomain = cfg.subdomain;
      isTokenNeeded = true;

      # When redirecting from the Kanidm Apps Listing page, some linked applications may need to land on a specific page to trigger oauth2/oidc interactions.
      # https://mynixos.com/nixpkgs/option/services.kanidm.provision.systems.oauth2.%3Cname%3E.originLanding
      originLanding = "https://${cfg.subdomain}.${sp.domain}/auth/login?autoLaunch=1";

      originUrl = redirectUris;

      clientSystemdUnits = [ "immich.service" ];

      enablePkce = true;
      linuxUserOfClient = linuxUserOfService;
      linuxGroupOfClient = linuxGroupOfService;

      scopeMaps.${usersGroup} = [
        "email"
        "openid"
        "profile"
      ];

      claimMaps.groups = {
        joinType = "array";
        valuesByGroup.${adminsGroup} = [ "admin" ];
      };
    };

    services.immich.package = patchedImmich.packages.${pkgs.system}.default;
  };
}
