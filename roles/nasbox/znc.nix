{...}: {
  services.znc = {
    enable = true;
    mutable = false; # Overwrite configuration set by ZNC from the web and chat interfaces.
    useLegacyConfig = false; # Turn off services.znc.confOptions and their defaults.
    openFirewall = true; # ZNC uses TCP port 5000 by default.
    config = {
      LoadModule = ["adminlog" "webadmin"];
      User.joe = {
        Admin = true;
        Pass.password = {
          Method = "sha256";
          Hash = "8fefbaab1771fc2a6267332f6834c376c8c206ba8b5fff88b1c1eadb19e7a24f";
          Salt = "XcDtD4q(JY3/m!lQxfeX";
        };
      };
    };
  };
}
