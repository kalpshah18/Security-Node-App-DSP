# Smartphone Intrusion Detection System (Simulink, Android)

Digital Signal Processing Course Assignment 1. Kalp Shah (24110152), IIT Gandhinagar.

Two Android phones form a security system built entirely in Simulink with the
Simulink Support Package for Android Devices.

- **Phone A, Security Node:** stationary (drawer, cabinet). When ARMED, it detects an ambient light increase or gyroscope motion and reports the breach.
- **Phone B, Monitoring Console:** plays an audible alert, shows GPS and breach time, and remotely triggers the siren and ARM/DISARM on Phone A.
- **Interchangeable:** the same app runs on both phones. A `role` slider selects Node (0) or Monitor (1).

Demo video: https://youtu.be/q4VKf8RstJU

## How it works

| Item | Detail |
|------|--------|
| Sample step | 0.05 s fixed (20 Hz sensors, 400-sample audio frames at 8 kHz) |
| Light breach | `E > 1.5 * E0 + 15 lux`, where `E0` is the mean over a 3 s settle window after arming |
| Motion breach | Gyroscope magnitude above 0.35 rad/s for 2 consecutive samples |
| Latching | A breach stays latched until DISARM |
| Transport | UDP, port 25000, 64-byte packets (8 doubles) sent every step |
| Node to Monitor | `[1, state, breached, lat, lon, breachTs, nowTs, reason]` |
| Monitor to Node | `[2, sirenReq, armReq, seq, 0, 0, 0, 0]` |
| Siren | Phase-continuous sine sweep, 600 to 1400 Hz, 1 Hz sweep rate |
| Alert | Recorded WAV (`alert.wav`) looped on the Monitor while a breach is active |
| Audio gating | Audio blocks sit in an Enabled Subsystem, so the speaker stream is off when idle |
| Phone displays | Breach flag, latitude, longitude, breach time (HHMMSS, IST), link status |

State-based packets are sent continuously, so a lost UDP packet is corrected by the next one.

## Repository contents

| File | Purpose |
|------|---------|
| `SecurityLogic.m` | All logic for both roles (MATLAB Function block source) |
| `build_security_app.m` | Generates `SecurityApp.slx` and wires all blocks |
| `make_alert_wav.m` | Creates `alert.wav` and the `alertWav` workspace variable |
| `test_logic_offline.m` | Tests the logic in MATLAB without phones |
| `diagnose_blocks.m` | Lists the Android support package blocks installed |
| `SecurityApp.slx` | Generated Simulink model |
| `alert.wav` | Alert message played on the Monitor |

## Requirements

- MATLAB and Simulink R2026a with Simulink Support Package for Android Devices.
- Two Android phones with USB debugging enabled.
- Both phones on one Wi-Fi network that allows device-to-device traffic. Campus Wi-Fi often blocks this; use a mobile hotspot if packets do not arrive.

## Build and deploy

1. Run `test_logic_offline` in MATLAB. It must print `ALL TESTS PASSED`.
2. Optional: `make_alert_wav(true)` records your own alert message; `make_alert_wav(false)` synthesizes one.
3. Note both phone IPs (Settings, Wi-Fi).
4. **Phone A:**
   - Run `build_security_app('<Phone B IP>')`.
   - Open Model Settings, Hardware Implementation, Target hardware resources, App options. Tick **Create 64 bit library as well**, then Apply.
   - Press Ctrl+D in the model.
   - Connect Phone A by USB, select it in Hardware Settings, and click **Build, Deploy & Start**.
5. **Phone B:** repeat with `build_security_app('<Phone A IP>')`.

`build_security_app` deletes and regenerates `SecurityApp.slx`, so deploy one phone before rebuilding for the other. The USB cable is not needed after installation.

## Test procedure

Set sliders: Phone A `role` = 0; Phone B `role` = 1; all other sliders 0.

1. B `sirenSw` = 1: Phone A's siren sounds. Set to 0: it stops.
2. B `armSw` = 1, wait 5 s. Shine a torch at A's light sensor: B plays the alert and shows breach, GPS and time.
3. B `armSw` = 0: the alert stops.
4. Arm again, then shake A: B alerts again.
5. Swap the `role` sliders and repeat to show interchangeable roles.

## Troubleshooting

| Symptom | Cause and fix |
|---------|---------------|
| `device unauthorized` | Accept the USB debugging prompt on the phone, or revoke USB debugging authorizations and replug |
| `INSTALL_FAILED_NO_MATCHING_ABIS` | The support package builds 32-bit code. Tick **Create 64 bit library as well** for 64-bit-only phones |
| `INSTALL_FAILED_VERIFICATION_FAILURE` | Allow install via USB in Developer options; turn off Play Protect scanning |
| Audio Playback expects `int16` | Handled in the model by a gain of 32767 and an int16 conversion |
| `unknown type name 'time_t'` | Fixed: the wall-clock helper uses `long` |
| Phones do not communicate | Check each phone points at the other's current IP, both are on one network, both apps are in the foreground |
| Latitude and longitude read 0 | No GPS fix yet; test near a window |

## Limitations

- The Android library has no flash or torch block, so the siren has no flash pulse.
- The phone shows the latest breach time only; the 10-event log exists in the model but has no phone display.
- UDP gives no delivery guarantee (mitigated by continuous state packets).
- The breach time display uses a fixed IST offset (`TZ` in `SecurityLogic.m`).
- iOS is not supported: the iOS support package has no ambient light sensor block, to my knowledge.
