{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.rethinkdb;
  rethinkdb = cfg.package;
in

{

  ###### interface

  options = {

    services.rethinkdb = {

      enable = lib.mkEnableOption "RethinkDB server";

      #package = lib.mkOption {
      #  default = pkgs.rethinkdb;
      #  description = "Which RethinkDB derivation to use.";
      #};

      user = lib.mkOption {
        default = "rethinkdb";
        description = "User account under which RethinkDB runs.";
      };

      group = lib.mkOption {
        default = "rethinkdb";
        description = "Group which rethinkdb user belongs to.";
      };

      dbpath = lib.mkOption {
        default = "/var/db/rethinkdb";
        description = "Location where RethinkDB stores its data, 1 data directory per instance.";
      };

      pidpath = lib.mkOption {
        default = "/run/rethinkdb";
        description = "Location where each instance's pid file is located.";
      };

      #cfgpath = lib.mkOption {
      #  default = "/etc/rethinkdb/instances.d";
      #  description = "Location where RethinkDB stores it config files, 1 config file per instance.";
      #};

      # TODO: currently not used by our implementation.
      #instances = lib.mkOption {
      #  type = lib.types.attrsOf lib.types.str;
      #  default = {};
      #  description = "List of named RethinkDB instances in our cluster.";
      #};

    };

  };

  ###### implementation
  config = lib.mkIf config.services.rethinkdb.enable {

    environment.systemPackages = [ rethinkdb ];

    systemd.services.rethinkdb = {
      description = "RethinkDB server";

      wantedBy = [ "multi-user.target" ];
      after = [ "network.target" ];

      serviceConfig = {
        # TODO: abstract away 'default', which is a per-instance directory name
        #       allowing end user of this nix module to provide multiple instances,
        #       and associated directory per instance
        ExecStart = "${rethinkdb}/bin/rethinkdb -d ${cfg.dbpath}/default";
        ExecReload = "${pkgs.coreutils}/bin/kill -HUP $MAINPID";
        User = cfg.user;
        Group = cfg.group;
        PIDFile = "${cfg.pidpath}/default.pid";
        PermissionsStartOnly = true;
      };

      preStart = ''
        if ! test -e ${cfg.dbpath}; then
            install -d -m0755 -o ${cfg.user} -g ${cfg.group} ${cfg.dbpath}
            install -d -m0755 -o ${cfg.user} -g ${cfg.group} ${cfg.dbpath}/default
            chown -R ${cfg.user}:${cfg.group} ${cfg.dbpath}
        fi
        if ! test -e "${cfg.pidpath}/default.pid"; then
            install -D -o ${cfg.user} -g ${cfg.group} /dev/null "${cfg.pidpath}/default.pid"
        fi
      '';
    };

    users.users.rethinkdb = lib.mkIf (cfg.user == "rethinkdb") {
      name = "rethinkdb";
      description = "RethinkDB server user";
      isSystemUser = true;
    };

    users.groups = lib.optionalAttrs (cfg.group == "rethinkdb") (
      lib.singleton {
        name = "rethinkdb";
      }
    );

  };

}
