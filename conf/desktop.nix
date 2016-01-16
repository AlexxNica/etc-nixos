{ config, pkgs, expr, buildVM, ... }:

let
  iconTheme = pkgs.stdenv.mkDerivation {
    name = "breeze-icons";
    buildCommand = ''
      # Copy base icons
      mkdir -p $out/share
      cp -r ${pkgs.pkgsi686Linux.kde5.breeze}/share/icons $out/share/icons
      chmod +w -R $out/share/icons

      # Add some additional icons
      for file in $(find ${pkgs.gnome3.adwaita-icon-theme}/share/icons/Adwaita/scalable/status -name "*wireless*"); do
        for dir in $out/share/icons/breeze/status/*; do
          target=''${file/%-symbolic.svg/.svg}
          echo "$file:$dir:$target"
          cp -v $file $dir/''${target##*/}
        done
      done
    '';
  };
  qtTheme = pkgs.stdenv.mkDerivation {
    name = "breeze-style";
    buildCommand = ''
      cp -r --no-preserve=all ${pkgs.kde5.breeze} $out
      chmod +w -R $out/share/icons
      rm -r $out/share/icons
    '';
  };
  themeEnv = ''
    # GTK2 theme
    export GTK_PATH=$GTK_PATH:${pkgs.gtk-engine-murrine}/lib/gtk-2.0
    export GTK2_RC_FILES=${pkgs.writeText "iconrc" ''gtk-icon-theme-name="breeze"''}:${pkgs.orion}/share/themes/orion/gtk-2.0/gtkrc:$GTK2_RC_FILES

    # GTK3 theme
    export GTK_DATA_PREFIX=${pkgs.orion}
    export GTK_THEME="orion"

    # SVG loader for pixbuf (needed for svg icon themes)
    export GDK_PIXBUF_MODULE_FILE=$(echo ${pkgs.librsvg}/lib/gdk-pixbuf-2.0/*/loaders.cache)
  '';

in {

imports = [];

# Required for our screen-lock-on-suspend functionality
services.logind.extraConfig = ''
  LidSwitchIgnoreInhibited=False
  HandleLidSwitch=suspend
  HoldoffTimeoutSec=10
'';

# Enable the X11 windowing system.
services.xserver = {
  enable = true;
  layout = "de";
  synaptics.enable = true;
  synaptics.accelFactor = "0.01";
  synaptics.twoFingerScroll = true;
  synaptics.additionalOptions = ''
    Option "VertScrollDelta" "-112"
    Option "HorizScrollDelta" "-112"
    Option "TapButton2" "3"
    Option "TapButton3" "2"
  '';
  xkbOptions = "ctrl:nocaps";

  displayManager.sddm.enable = true;
  displayManager.sddm.autoLogin = {
    enable = true;
    user = "benno";
    relogin = true;
  };
  displayManager.desktopManagerHandlesLidAndPower = false;
  desktopManager.session =
    [ { name = "custom";
        start = ''
          # Setup desktop
          ${themeEnv}

          # Lock
          ${expr.lock}/bin/lock
          ${expr.lock-suspend}/bin/lock-on-suspend &

          ${pkgs.feh}/bin/feh --bg-fill ${/data/pics/wallpapers/unsplash/autumn.jpg}
          ${pkgs.haskellPackages.xmobar}/bin/xmobar --alpha 200 &
          ${pkgs.stalonetray}/bin/stalonetray --slot-size 22 --icon-size 20 --geometry 9x1-0 --icon-gravity NE --grow-gravity E -c /dev/null --kludges fix_window_pos,force_icons_size,use_icons_hints --transparent --tint-level 200 &> /dev/null &
          ${pkgs.xlibs.xrdb}/bin/xrdb -load ${./Xresources}

          # Autostart
          ${pkgs.lib.optionalString (!buildVM) ''
            ${pkgs.rxvt_unicode}/bin/urxvt -title "IRC bennofs" -e ${pkgs.weechat}/bin/weechat &
            ${pkgs.skype}/bin/skype &
            ${pkgs.hipchat}/bin/hipchat &
          ''}
          ${pkgs.rxvt_unicode}/bin/urxvtd &
          ${pkgs.gvolicon}/bin/gvolicon &> /dev/null &
          ${pkgs.unclutter}/bin/unclutter -idle 3 &
          ${pkgs.pythonPackages.udiskie}/bin/udiskie --tray &
          ${pkgs.wpa_supplicant_gui}/bin/wpa_gui -q -t &
          ${pkgs.dunst}/bin/dunst -key 'mod4+less' -history_key 'mod4+shift+less' -all_key ' ' -cto 4 -nto 2 -lto 1 -config ${./dunstrc} &
          syndaemon -i 1 -R -K -t -d

          ${pkgs.lib.optionalString buildVM '' ${pkgs.rxvt_unicode}/bin/urxvt '' }
        '';
    } ];
  desktopManager.default = "custom";
  desktopManager.xterm.enable = false;

  windowManager.default = "xmonad";
  windowManager.xmonad.enable = true;
  windowManager.xmonad.enableContribAndExtras = true;

  wacom.enable = true;
};

environment.extraInit = ''
  ${themeEnv}

  # LS colors
  eval `${pkgs.coreutils}/bin/dircolors "${./dircolors}"`

  # Remove Qt configuration (can cause programs to SEGV)
  rm -f ~/.config/Trolltech.conf
'';

# QT4/5 theme
environment.etc."xdg/Trolltech.conf" = {
  text = ''
    [Qt]
    style=Breeze
  '';
  mode = "444";
};

environment.systemPackages = with pkgs; [
  # Qt theme
  qtTheme # 32 bit, to handle 32 bit apps (skype)

  # Icons
  iconTheme
  hicolor_icon_theme
];

# Make applications find files in <prefix>/share
environment.pathsToLink = [ "/share" ];

}
