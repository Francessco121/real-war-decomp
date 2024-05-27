# DDrawCompat Settings for Real War
Real War runs poorly on modern versions of Windows. Most of these issues can be solved by disabling hardware acceleration in the game, but other problems like with high refresh rate monitors cannot be fixed so easily.

Thankfully, the [DDrawCompat](https://github.com/narzoul/DDrawCompat) project can be used to run Real War on modern Windows nearly perfectly. Drop in DDrawCompat's `ddraw.dll` next to the game's executable and then create the following `DDrawCompat.ini` file:
```ini
# Fix alt-tab crash (the game does not restore DX resources correctly 
# after tabbing back in)
AltTabFix=keepvidmem(0)

# DDrawCompat overlay locks the game up, disable it
ConfigHotKey=none 

# Game crashes at high resolutions
DesktopResolution=1280x720

# Optionally uncomment for a more "native" upscale feel (game will look 
# more pixelated with this commented out but it also won't change your
# monitor resolution)
# DisplayResolution=app

# Game runs too fast without a cap (this works better than setting 
# the refresh rate to 60) (this fix is not perfect)
FpsLimiter=msgloop(60)
```

See [DDrawCompat's configuration wiki page](https://github.com/narzoul/DDrawCompat/wiki/Configuration) for more information.
