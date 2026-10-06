function make_alert_wav(useMic)
% make_alert_wav(true)  : records 3 s from PC microphone (say "Intruder alert, breach detected")
% make_alert_wav(false) : synthesizes a two-tone alert (default)
% Creates alert.wav and base-workspace variable alertWav (8 kHz, column, [-1,1]).
if nargin < 1, useMic = false; end
Fs = 8000;
if useMic
    r = audiorecorder(Fs,16,1);
    disp('Recording 3 s...'); recordblocking(r,3);
    y = getaudiodata(r,'double');
else
    t = (0:Fs*2-1)'/Fs;
    y = 0.8*sign(sin(2*pi*3*t)) .* sin(2*pi*(800 + 400*(sin(2*pi*3*t)>0)).*t);
end
y = y(:); y = 0.9*y/max(abs(y)+eps);
audiowrite('alert.wav', y, Fs);
assignin('base','alertWav',y);
fprintf('alertWav: %d samples\n', numel(y));
end
