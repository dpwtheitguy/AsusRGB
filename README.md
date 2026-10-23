# AsusRGB

An easier way to install ASUS keyboard lighting controls on
**Pop!_OS 24.04 and Ubuntu 24.04**.

AsusRGB installs **ROG Control Center**, the graphical app from the
[ASUS Linux project](https://github.com/OpenGamingCollective/asusctl).
Use it to change supported keyboard lighting colors and effects.

## Install

1. Open [Releases](https://github.com/dpwtheitguy/AsusRGB/releases).
2. Expand **Assets** and download the file ending in `.deb`.
3. Open Terminal and run:

```bash
cd ~/Downloads
sudo apt install ./asusrgb_*.deb
sudo systemctl restart asusd
AsusRGB
```

Download only the version you want to install into that folder.

If there is no `.deb` available yet, the build has not finished
successfully. Check [Actions](https://github.com/dpwtheitguy/AsusRGB/actions).

## Open it later

Find **ROG Control Center** in your applications menu, or run:

```bash
AsusRGB
```

## What works?

This package targets 64-bit Intel/AMD computers using Wayland.
Keyboard lighting support depends on your ASUS laptop model.

The initial target is the **ROG Strix G16 G614JIR**.
Full package and RGB testing is still in progress.

Pop!_OS power management is left unchanged. Start with the lighting
controls; ASUS power-profile controls may conflict with Pop's settings.

## Updates

Download the newer `.deb` and install it the same way.
Updates are not automatic.

## Remove

```bash
sudo apt remove asusrgb
```

## Having trouble?

Please open an [issue](https://github.com/dpwtheitguy/AsusRGB/issues)
with your laptop model, OS version, and the error message.

## Credits

The ASUS control software is made by the ASUS Linux /
Open Gaming Collective contributors.

AsusRGB provides community packaging. It is not an official ASUS product.
