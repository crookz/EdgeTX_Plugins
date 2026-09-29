# BDCellBatt

A compact per-cell battery voltage widget for EdgeTX colour radios, with voice alerts that know the difference between a pack under load and a pack at rest.

## Design philosophy

- **Per-cell voltage first.** The number that matters is volts per cell, not pack voltage. It reads the same on a 4S and a 6S quad, so the thresholds are the same too. Pack voltage and cell count are shown as secondary detail when there is room.
- **Readable at a glance.** The widget picks the largest font that fits its zone, so it works in anything from a top-bar slot to a full-screen tile without overlapping text. Colour (normal / yellow / red / grey) tells you the state before you read the number.
- **Alerts should be trustworthy, not noisy.** An alert you learn to ignore is worse than none. Alerts need the voltage to stay below a threshold for 2 seconds, so a punch-out doesn't trigger them. They only escalate: a warning you've heard won't replay as the pack recovers after landing. They stay silent until a real pack has been seen, so a quad powered from USB on the bench doesn't nag.
- **Under load and at rest are different.** A pack that sags to 3.3V under throttle is fine. A pack sitting at 3.3V on the bench is not. The widget reads the arm state from the flight controller and uses stricter thresholds when disarmed.
- **Set once, use everywhere.** Thresholds live in one shared file (`BDConfig.lua`) used by every model. Per-model options exist only as overrides.
- **Zero setup by default.** The voltage sensor, cell count and arm state are all detected automatically. Where detection isn't possible, the widget falls back to its safest behaviour, which is how it behaved before the feature existed.

## Features

### Display
- Large per-cell voltage (e.g. `3.82V`), in the biggest font that fits the zone.
- Secondary line with cell count and pack voltage (e.g. `4S 15.28V`), shown only when there is space.
- Battery icon on the left, filled from empty (Crit) to full (4.20V LiPo / 4.35V LiHV).
- Colour coding:

  | Colour | Meaning |
  |---|---|
  | Your chosen colour | Above Warn |
  | Yellow | At or below Warn |
  | Red | At or below Crit |
  | Grey | Telemetry link down (last reading kept) |

### Cell count detection
- With **Cells** set to 0, the cell count is worked out from the pack voltage when telemetry connects.
- If telemetry briefly reports a low value at link-up, the widget corrects the count upwards once the real voltage arrives, so it doesn't lock in too few cells.
- The count is detected again after every link drop, so swapping packs between flights just works.

### Voice and haptic alerts
- **Warn:** plays `lowbat.wav` and speaks the cell voltage, once.
- **Crit:** plays `clobat.wav`, speaks the cell voltage and vibrates. While armed it repeats every 10 seconds. While disarmed it plays once.
- **Below Crit:** each time the cell voltage drops into a lower 0.1V band (e.g. 3.2x → 3.1x → 3.0x), the new voltage is spoken once. This works armed or disarmed and restarts the 10-second repeat timer, so the callouts don't overlap.
- The voltage must stay below a threshold for 2 seconds before an alert fires, which filters out momentary sag.
- The alert level only goes up until the link drops. Once you've heard a warning, it won't replay as voltage recovers after landing.
- **No false alerts on USB power:** alerts are enabled only after a reading above the armed Crit level has been seen since the link came up. A flight controller on USB with no pack never reaches that, so it stays silent. It still displays whatever it reads.

### Armed / disarmed thresholds
The widget reads the arm state from flight controller telemetry and picks its thresholds to match:

| Link | Sensor | Disarmed when |
|---|---|---|
| CRSF (ExpressLRS, Crossfire) with Betaflight | `FM` | Flight mode ends in `*` (e.g. `ACRO*`) |
| FrSky SmartPort / F.Port with Betaflight or INAV | `Tmp1` | Ones digit is 1–3 (4–7 means armed) |
| Anything else | – | Never: treated as armed |

- **Armed** uses the under-load thresholds (default 3.50V / 3.30V).
- **Disarmed** uses the at-rest thresholds (default 3.70V / 3.50V). This catches a used pack plugged in on the bench, or a pack that was flown too low.
- When the arm state can't be read, the widget assumes armed. The worst case is then a missed bench warning, never false alerts mid-flight.

## Settings

### Widget options (per model)

| Option | Default | Range | Description |
|---|---|---|---|
| Source | blank | any source | Pack voltage sensor. Blank finds `RxBt` automatically. |
| Cells | 0 | 0–12 | Cell count. 0 = detect automatically. |
| LiHV | off | on / off | Off = LiPo (4.20V full). On = LiHV (4.35V full). Affects the icon's fill level and cell detection. |
| Warn | 0 | 0–400 (×0.01V) | Armed warning level per cell, e.g. 350 = 3.50V. 0 = use `BDConfig.lua`. |
| Crit | 0 | 0–380 (×0.01V) | Armed critical level per cell, e.g. 330 = 3.30V. 0 = use `BDConfig.lua`. |
| Color | white | any colour | Text and icon colour when the voltage is above Warn. |
| Alerts | on | on / off | Voice and haptic alerts. The display works either way. |

Warn and Crit override the **armed** thresholds only. The at-rest thresholds always come from `BDConfig.lua`.

> Models set up before `BDConfig.lua` existed still have their old Warn / Crit values (e.g. 350 / 330), which count as overrides. Set them to 0 to use the shared file.

### Shared config: `BDConfig.lua`

Lives in the widget folder (`/WIDGETS/BDCellBatt/BDConfig.lua`) and applies to every model. All values are volts per cell.

```lua
return {
  -- armed (under load, with sag). A model's non-zero Warn / Crit option overrides these.
  warn = 3.50,
  crit = 3.30,
  -- disarmed (at rest), used when FC telemetry reports disarmed
  restWarn = 3.70,
  restCrit = 3.50,
}
```

| Key | Default | Used when |
|---|---|---|
| `warn` | 3.50 | Armed, or arm state unknown |
| `crit` | 3.30 | Armed, or arm state unknown. Also the level a reading must exceed before alerts are enabled. |
| `restWarn` | 3.70 | Disarmed |
| `restCrit` | 3.50 | Disarmed |

- Any missing key falls back to the default above. If the file is missing or has an error, all four defaults are used.
- Changes take effect on the next model load or widget settings change.
- `deploy.ps1` copies the whole widget folder to the radio, so it overwrites `BDConfig.lua` on the SD card. Edit the copy in this repo and deploy it, rather than editing it on the radio.

## Install

Copy the `BDCellBatt` folder to `/WIDGETS/` on the radio's SD card (or run `.\deploy.ps1 BDCellBatt`). Then add the widget to a screen or the top bar.

For arm-state detection, make sure the `FM` (CRSF) or `Tmp1` (FrSky) sensor has been discovered on the model's telemetry page.
