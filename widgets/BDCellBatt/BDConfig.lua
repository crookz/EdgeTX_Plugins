-- BDCellBatt shared thresholds for all models. Volts per cell.
-- Changes apply on the next model load or widget settings change.
return {
  -- armed (under load, with sag). A model's non-zero Warn / Crit option overrides these.
  warn = 3.50,
  crit = 3.30,
  -- disarmed (at rest), used when FC telemetry reports disarmed
  restWarn = 3.70,
  restCrit = 3.50,
}
