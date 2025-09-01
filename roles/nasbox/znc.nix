{...}: {
  dn42Expose.znc = {
    port = 5001;
    addr = "fde7:76fd:7444:eeee::107";
    allowlist = "fde7:76fd:7444::/48";
  };

  services.znc = {
    enable = true;
    mutable = false; # Overwrite configuration set by ZNC from the web and chat interfaces.
    useLegacyConfig = false; # Turn off services.znc.confOptions and their defaults.
    config = {
      LoadModule = ["adminlog" "webadmin"];
      Listener = {
        httplistener = {
          AllowIRC = false;
          AllowWeb = true;
          Host = "::1";
          IPv4 = false;
          IPv6 = true;
          Port = 5001;
          SSL = false;
        };
        listener1 = {
          AllowIRC = true;
          AllowWeb = false;
          Host = "fde7:76fd:7444:eeee::107";
          IPv4 = false;
          IPv6 = true;
          Port = 6667;
          SSL = false;
        };
      };

      User.joe = {
        Admin = true;
        # Allow = "fde7:76fd:7444::/48";
        Timezone = "US/Pacific";
        Pass.password = {
          Method = "sha256";
          Hash = "8fefbaab1771fc2a6267332f6834c376c8c206ba8b5fff88b1c1eadb19e7a24f";
          Salt = "XcDtD4q(JY3/m!lQxfeX";
        };

        Network.hackint = {
          Server = "irc.hackint.dn42 +6697";
          Nick = "ichbinjoe";
          AltNick = "ichbinjoe_";
          QuitMsg = "Bye - irc@ibj.io";
          LoadModule = [
            "keepnick"
            "sasl"
            "simple_away"
          ];
          TrustAllCerts = true;
          TrustPKI = false;
          TrustedServerFingerprint = "db:49:3a:31:93:9f:36:e3:90:f3:fc:f4:95:77:fb:78:ce:9e:34:ab:e7:ce:49:52:77:e2:0e:05:35:47:2e:51";

          Chan = let
            acBuf = n: {AutoClearChanBuffer = true; Buffer = n; };
          in {
            "#dn42" = acBuf 1000;
            "#dn42-peering" = acBuf 100;
            "##dn42" = acBuf 100;
            "#dn42-social" = acBuf 1000;
          };
        };

        Network.dn42 = {
          Server = "irc.dn42 +6697";
          Nick = "ichbinjoe";
          AltNick = "ichbinjoe_";
          QuitMsg = "Bye - irc@ibj.io";
          LoadModule = [
            "keepnick"
            "sasl"
            "simple_away"
          ];
        };
      };
    };
  };
}
