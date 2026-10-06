function [txPacket, audioFrame, flash, info, evtLog, audioOn, dispBreach, dispLat, dispLon, dispTime, dispLink] = SecurityLogic( ...
        role, armSw, sirenSw, light, gyro, lat, lon, rx, rxLen, alertWav)
%#codegen
% Single logic block for BOTH roles. role: 0 = Security Node, 1 = Monitoring Console.
% Step time must be 0.05 s (400 audio samples @ 8 kHz per step).
%
% Packet format (8 doubles = 64 bytes, UDP):
%   Node    -> Monitor : [1, state, breached, lat, lon, breachTs, nowTs, reason]
%   Monitor -> Node    : [2, sirenReq, armReq, seq, 0, 0, 0, 0]
%   state: 0 DISARMED, 1 ARMED.  reason: 1 light, 2 motion.
% Packets are sent every step (state-based => tolerant to UDP loss).
coder.extrinsic('now');

FS = 8000; N = 400;
SETTLE = 60;        % steps (3 s) to place phone in enclosure after arming
LIGHT_DELTA = 15;   % lux above 1.5*baseline that counts as breach
GYRO_THR = 0.35;    % rad/s
ALIVE = 40;         % steps (2 s) without peer packet => link down

persistent k state prevState breached breachTs reason baseline settleCnt gyroHit
persistent prevArmSw prevRemArm sirenReq lastMonRx lastNodeRx
persistent alertIdx sirenPhase sirenN logMat lastSeenBTs seq
persistent rState rBreached rLat rLon rBTs rReason
if isempty(k)
    k = 0; state = 0; prevState = 0; breached = 0; breachTs = 0; reason = 0;
    baseline = 0; settleCnt = 0; gyroHit = 0;
    prevArmSw = double(armSw > 0.5); prevRemArm = -1; sirenReq = 0;
    lastMonRx = -1e6; lastNodeRx = -1e6;
    alertIdx = 1; sirenPhase = 0; sirenN = 0;
    logMat = zeros(10,4); lastSeenBTs = -1; seq = 0;
    rState = 0; rBreached = 0; rLat = 0; rLon = 0; rBTs = 0; rReason = 0;
end
k = k + 1;
armSw = double(armSw > 0.5);      % sliders -> clean 0/1
sirenSw = double(sirenSw > 0.5);
nowTs = wallclock();

lightD = double(light);
g = double(gyro(:));
latD = double(lat); lonD = double(lon);

% ---- parse received packet ----
v = zeros(8,1);
rxOk = double(rxLen) >= 1 && numel(rx) >= 64;   % works for length or status port
if rxOk
    v = typecast(uint8(rx(1:64)), 'double');
    v = v(:);
end

audioFrame = zeros(N,1);
flash = 0;
v_out = zeros(8,1);
dLink = 0; dSiren = 0; audioOn = 0;

if role < 0.5
    %% ================= SECURITY NODE =================
    if rxOk && v(1) == 2
        lastMonRx = k; sirenReq = v(2);
        remArm = v(3);
        if remArm ~= prevRemArm
            state = double(remArm > 0.5); prevRemArm = remArm;
        end
    end
    if double(armSw) ~= prevArmSw
        state = double(armSw > 0.5); prevArmSw = double(armSw);
    end
    alive = (k - lastMonRx) < ALIVE;
    if ~alive, sirenReq = 0; end

    if state == 1 && prevState == 0        % just armed
        settleCnt = 0; baseline = 0; breached = 0; reason = 0; gyroHit = 0;
    end
    if state == 0, breached = 0; reason = 0; end
    prevState = state;

    if state == 1
        if settleCnt < SETTLE
            baseline = baseline + lightD / SETTLE;
            settleCnt = settleCnt + 1;
        elseif breached == 0
            lightHit = lightD > baseline * 1.5 + LIGHT_DELTA;
            if sqrt(sum(g.^2)) > GYRO_THR, gyroHit = gyroHit + 1; else, gyroHit = 0; end
            motionHit = gyroHit >= 2;
            if lightHit || motionHit
                breached = 1; breachTs = nowTs;
                reason = 1; if motionHit, reason = 2; end
                logMat = [breachTs, latD, lonD, reason; logMat(1:9,:)];
            end
        end
    end

    sirenOn = alive && sirenReq > 0.5;
    dSiren = double(sirenOn);
    audioOn = double(sirenOn);
    if sirenOn
        for n = 1:N
            f = 1000 + 400*sin(2*pi*(sirenN/FS));
            sirenPhase = mod(sirenPhase + 2*pi*f/FS, 2*pi);
            sirenN = sirenN + 1;
            audioFrame(n) = 0.9*sin(sirenPhase);
        end
        flash = double(mod(k,5) < 3);       % ~4 Hz pulse
    end

    v_out = [1; state; breached; latD; lonD; breachTs; nowTs; reason];
    dState = state; dBreached = breached; dLat = latD; dLon = lonD;
    dBTs = breachTs; dReason = reason; dLink = double(alive);
else
    %% ================= MONITORING CONSOLE =================
    if rxOk && v(1) == 1
        lastNodeRx = k;
        rState = v(2); rBreached = v(3); rLat = v(4); rLon = v(5);
        rBTs = v(6); rReason = v(8);
        if rBreached > 0.5 && rBTs ~= lastSeenBTs
            lastSeenBTs = rBTs;
            logMat = [rBTs, rLat, rLon, rReason; logMat(1:9,:)];
        end
    end
    nodeAlive = (k - lastNodeRx) < ALIVE;
    if rBreached > 0.5 && nodeAlive
        audioOn = 1;
        La = numel(alertWav);
        for n = 1:N
            audioFrame(n) = double(alertWav(alertIdx));
            alertIdx = alertIdx + 1; if alertIdx > La, alertIdx = 1; end
        end
    end
    seq = seq + 1;
    v_out = [2; double(sirenSw); double(armSw); seq; 0; 0; 0; 0];
    dState = rState; dBreached = double(rBreached > 0.5 && nodeAlive);
    dLat = rLat; dLon = rLon; dBTs = rBTs; dReason = rReason;
    dLink = double(nodeAlive); dSiren = double(sirenSw);
end

txPacket = typecast(v_out, 'uint8');
info = [dState; dBreached; dLat; dLon; dBTs; nowTs; dSiren; dLink; dReason; double(role)];
evtLog = logMat;
dispBreach = double(dBreached);
dispLat = double(dLat);
dispLon = double(dLon);
dispTime = toHHMMSS(dBTs);      % breach time of day as HHMMSS (IST)
dispLink = double(dLink);
end

function h = toHHMMSS(ts)
TZ = 19800;   % IST = UTC+5:30 in seconds; edit for other zones
h = 0;
if ts > 0
    sod = mod(floor(ts + TZ), 86400);
    hh = floor(sod/3600); mm = floor(mod(sod,3600)/60); ss = mod(sod,60);
    h = hh*10000 + mm*100 + ss;
end
end

function t = wallclock()
% Seconds since Unix epoch. libc time() on device, MATLAB clock in simulation.
t = 0;
if coder.target('rtw')
    coder.cinclude('<time.h>');
    t0 = coder.opaque('long', '0');     % time_t is 'long' on Android; avoids needing time_t in the header
    t1 = coder.opaque('long', '0');
    t1 = coder.ceval('time', coder.opaque('long*', 'NULL'));
    t = coder.ceval('difftime', t1, t0);
else
    t = (now - 719529) * 86400;
end
end
