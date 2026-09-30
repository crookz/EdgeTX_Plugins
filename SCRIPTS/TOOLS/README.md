# BDConfigTool

Copy this script to the radio SD card under `SCRIPTS/TOOLS/` and run it from the Tools menu.

Example deployment:

```powershell
./deploy.ps1 -Tool BDConfigTool
```

The script scans `/WIDGETS/*/BDConfig.lua`, groups values by widget, and lets you edit the shared config values directly from the radio.
