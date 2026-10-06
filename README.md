# Simulink Security Node / Monitoring Console (Android)

Files
- SecurityLogic.m        all logic, both roles (MATLAB Function block source)
- make_alert_wav.m       creates alertWav (recorded or synthesized alert message)
- build_security_app.m   generates SecurityApp.slx and wires blocks
- test_logic_offline.m   logic test without phones

Steps
1. Both phones + PC on same Wi-Fi. Note both phone IPs.
2. MATLAB: cd to this folder; run `test_logic_offline` (must print ALL TESTS PASSED).
3. `make_alert_wav(true)` to record your own message (optional).
4. `build_security_app('<IP of Phone B>')`; read console for MISSING / SET MANUALLY lines; fix in GUI.
5. Hardware tab > Hardware Settings: Android Device, select Phone A. Build, Deploy & Start.
6. `build_security_app('<IP of Phone A>')`; deploy to Phone B the same way.
7. Roles at runtime: role switch 0 = Node, 1 = Monitor. Swap switches to swap roles.
