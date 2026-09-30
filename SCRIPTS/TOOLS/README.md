# BDConfigTool

Copy this script to the radio SD card under `SCRIPTS/TOOLS/` and run it from the Tools menu.

Example deployment:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\deploy.ps1 -Tool BDConfigTool
```

The script lists its configured widgets, loads their `/WIDGETS/<widget>/BDConfig.lua` files, and lets you edit numeric values from the radio.

## Development Notes

- EdgeTX Tools use the event-driven entry point: return `{ run = run_func, init = init_func }`. Keep UI work in the event handler rather than a standalone draw call.
- Widget configs are addressed from the SD-card root, for example `/WIDGETS/BDCellBatt/BDConfig.lua`; this is not relative to `/SCRIPTS/TOOLS`.
- EdgeTX exposes a reduced `io` library. Use `io.read(file, count)`, `io.write(file, text)`, and `io.close(file)`. File handles do not support `file:read()` / `file:write()`, and `io.output` is unavailable. Use explicit functions such as `string.find(source, ...)`, not `source:find(...)`.
- Saving updates numeric literals in the existing config text so key order and comments are retained. Before replacing a config, the tool writes and verifies a `.bak` copy; it then verifies the new file and attempts a verified rollback if needed.
- Deploy the tool alone with the PowerShell command above. This updates `BDConfigTool.lua` without overwriting widget configs.
- The workspace `WIDGETS/BDCellBatt/BDConfig.lua` currently has `crit = 3.30`. The radio copy may contain a different value. Compare them before deploying the whole widget folder, because that deployment replaces the radio's config with the workspace copy.

## Versioning

The title uses `major.minor`, currently `1.16`.

- Increment the minor number for normal fixes and small changes: `1.16` to `1.17`.
- Increment the major number only for a major overhaul, and reset the minor number: `1.17` to `2.0`.
- Keep both version constants in `BDConfigTool.lua` aligned with the title displayed on the radio.

The last radio-tested tool version reported by the user is v16; values loaded and saved successfully. The next runtime check should confirm v1.16 preserves comments and that a subsequent save leaves the `.bak` intact.
