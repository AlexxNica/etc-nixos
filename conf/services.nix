{ config, pkgs, ... }:

let
  expr = import ../expr { inherit pkgs; };
in {

imports = [];

services = {

  # The locate service for finding files in the nix-store quickly.
  locate.enable = true;

  # Enable CUPS to print documents.
  printing.enable = true;

  # Add drivers to CUPS
  printing.drivers = [ expr.mfcj430w-driver ];

  # Avahi is used for finding other devices on the network.
  avahi.enable = true;
  avahi.nssmdns = true;

  # Enable dnsmasq (required to merge VPN nameservers)
  dnsmasq = {
    enable = true;
    extraConfig = ''
      bind-interfaces
      interface=lo
      no-negcache
      all-servers
      dnssec
      trust-anchor=.,19036,8,2,49AAC11D7B6F6446702E54A1607371607A1A41855200FD2CE1CDDE32F24E8FB5
    '';
  };

  # HackingLab openvpn config
  openvpn.servers.hacking-lab = {
    config = ''
      ${builtins.readFile ./hacking-lab.ovpn};
      ca ${./hacking-lab-vpn.crt}
    '';
    updateResolvConf = true;
    autoStart = false;
  };

};

# Use libvirtd for managing virtual machines.
# This only enables the service, but does not add users to the libvirt group.
virtualisation.libvirtd.enable = true;

# Libvirtd needs to start after data is mounted, because the storage pool lives
# on /data.
systemd.services.libvirtd = {
  after = ["data.mount"];
  requires = ["data.mount"];
};

# Enable docker for container management.
# This only enables the service, but does not add users to the docker group.
virtualisation.docker.enable = true;

# We need to choose a storage driver for docker.
# "overlay" is currently actively developed and will eventually become the default, so use it.
virtualisation.docker.storageDriver = "overlay";

networking.firewall = {
  # Pings are very useful for network troubleshooting.
  allowPing = true;

  allowedTCPPorts = [
    3000        # hydra
  ];

  # We want to route packets coming from VMs, so we need to disable the
  # reverse path test for the libvirt bridge interfaces.
  checkReversePath = false;

  # Setup a restricted reverse path test that doesn't apply to libvirt's bridge interfaces.
  extraCommands = ''
    ip46tables -A PREROUTING -t raw ! -i virbr+ -m rpfilter --invert -j DROP
  '';

  # When stopping the firewall, remove the restricted reverse path test again.
  extraStopCommands = ''
    ip46tables -D PREROUTING -t raw ! -i virbr+ -m rpfilter --invert -j DROP
  '';
};

# Configure additional DNS servers
networking.extraResolvconfConf =
  let
    extraNameServers = [
      # Google IPv6 DNS servers
      "2001:4860:4860::8888"
      "2001:4860:4860::8844"
      # ipv6.lt NAT64 DNS server
      #"2001:778::37"
    ];
  in ''
    name_servers="$name_servers''${name_servers:+ }${toString extraNameServers}"
  '';
}
