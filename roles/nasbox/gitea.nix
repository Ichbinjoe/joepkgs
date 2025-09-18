{config, ...}: {
  userDBs = ["gitea"];

  dn42Expose.gitea = {
    port = config.services.gitea.settings.server.HTTP_PORT;
    addr = "fde7:76fd:7444:eeee::108";
  };

  services.gitea = {
    enable = true;
    stateDir = "/zpool/gitea";

    database = {
      type = "postgres";
      socket = "/var/run/postgresql";
    };

    settings = {
      server = {
        DOMAIN = "git.joe.dn42";
        HTTP_PORT = 3001;
        HTTP_ADDR = "::1";
        ROOT_URL = "http://git.joe.dn42/";
      };
    };
  };
}
