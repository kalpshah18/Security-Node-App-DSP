function build_security_app(peerIP, port)
% build_security_app('192.168.1.23')  -- peerIP = IP address of the OTHER phone.
if nargin < 1 || contains(peerIP,'<'), error('Pass a real IP: build_security_app(''192.168.1.23'')'); end
if nargin < 2, port = 25000; end
mdl = 'SecurityApp';
here = fileparts(mfilename('fullpath'));
if ~evalin('base','exist(''alertWav'',''var'')'), make_alert_wav(false); end
if bdIsLoaded(mdl), close_system(mdl,0); end
if exist(fullfile(here,[mdl '.slx']),'file'), delete(fullfile(here,[mdl '.slx'])); end
for L = {'androidsensorlib','androidcommunicationlib','androidaudiovideolib','androiduilib'}, load_system(L{1}); end
new_system(mdl); open_system(mdl);
set_param(mdl,'Solver','FixedStepDiscrete','FixedStep','0.05','StopTime','inf');
try, set_param(mdl,'HardwareBoard','Android Device'); catch ME, warning('HardwareBoard: %s',ME.message); end

% best effort: tick "Create 64 bit library as well"
try
    op = get_param(mdl,'ObjectParameters'); f = fieldnames(op); done = false;
    for i = 1:numel(f)
        if ~isempty(regexpi(f{i},'64')) && any(strcmpi(get_param(mdl,f{i}),{'off','0'}))
            set_param(mdl,f{i},'on'); fprintf('64-bit library enabled via %s\n',f{i}); done = true;
        end
    end
    if ~done, fprintf(2,'TICK MANUALLY: Model Settings > Hardware Implementation > App options > Create 64 bit library as well\n'); end
catch, fprintf(2,'TICK MANUALLY: Create 64 bit library as well (App options)\n'); end

% ---- logic block ----
lg = [mdl '/SecurityLogic'];
add_block('simulink/User-Defined Functions/MATLAB Function', lg, 'Position',[520 60 720 520]);
ch = sfroot().find('-isa','Stateflow.EMChart','Path',lg);
ch.Script = fileread(fullfile(here,'SecurityLogic.m'));
% in : 1 role 2 armSw 3 sirenSw 4 light 5 gyro 6 lat 7 lon 8 rx 9 rxLen 10 alertWav
% out: 1 txPacket 2 audioFrame 3 flash 4 info 5 evtLog 6 audioOn
%      7 dispBreach 8 dispLat 9 dispLon 10 dispTime 11 dispLink

% ---- UI sliders (0..1) ----
ui = {'role','armSw','sirenSw'};
for i = 1:3
    b = addB('androiduilib/Slider', mdl, ui{i}, [60 20+70*i 140 60+70*i]);
    setF(b,'min','0'); setF(b,'max','1');
    add_line(mdl,[ui{i} '/1'],sprintf('SecurityLogic/%d',i));
end

% ---- sensors ----
b = addB('androidsensorlib/Light Sensor', mdl,'Light',[220 260 300 300]);
setF(b,'^sample.?time$','0.05'); add_line(mdl,'Light/1','SecurityLogic/4');
b = addB('androidsensorlib/Gyroscope', mdl,'Gyro',[220 340 300 380]);
setF(b,'^sample.?time$','0.05');
add_block('simulink/Signal Routing/Mux',[mdl '/GyroMux'],'Inputs','3','Position',[330 340 335 380]);
for p = 1:3, add_line(mdl,sprintf('Gyro/%d',p),sprintf('GyroMux/%d',p)); end
add_line(mdl,'GyroMux/1','SecurityLogic/5');
b = addB('androidsensorlib/Location Sensor', mdl,'GPS',[220 420 300 480]);
setF(b,'^sample.?time$','0.05');
add_line(mdl,'GPS/1','SecurityLogic/6'); add_line(mdl,'GPS/2','SecurityLogic/7');

% ---- network ----
b = addB('androidcommunicationlib/UDP Receive', mdl,'UDPRx',[220 520 300 580]);
setF(b,'local.*port',num2str(port)); setF(b,'^sample.?time$','0.05'); setF(b,'^dims$','64');
add_line(mdl,'UDPRx/1','SecurityLogic/8'); add_line(mdl,'UDPRx/2','SecurityLogic/9');
b = addB('androidcommunicationlib/UDP Send', mdl,'UDPTx',[900 60 980 110]);
setF(b,'^remoteURL$',['''' peerIP '''']); setF(b,'^remote.*port',num2str(port));
add_line(mdl,'SecurityLogic/1','UDPTx/1');

% ---- alert audio constant ----
add_block('simulink/Sources/Constant',[mdl '/alertWav'],'Value','alertWav(:)', ...
    'VectorParams1D','off','OutDataTypeStr','double','Position',[220 660 300 690]);
add_line(mdl,'alertWav/1','SecurityLogic/10');

% ---- audio output, gated by an Enabled Subsystem (silent stream removed) ----
ss = [mdl '/AudioSS'];
add_block('simulink/Ports & Subsystems/Enabled Subsystem', ss, 'Position',[900 140 1010 220]);
try, delete_line(ss,'In1/1','Out1/1'); catch, end
try, delete_block([ss '/Out1']); catch, end
add_block('simulink/Math Operations/Gain',[ss '/AudGain'],'Gain','32767','Position',[150 30 200 60]);
add_block('simulink/Signal Attributes/Data Type Conversion',[ss '/AudInt16'],'OutDataTypeStr','int16', ...
    'RndMeth','Nearest','SaturateOnIntegerOverflow','on','Position',[240 30 310 60]);
b = [ss '/Audio']; add_block('androidaudiovideolib/Audio Playback', b, 'Position',[350 25 430 65]);
setF(b,'^QueueDuration$','0.5'); setF(b,'^SampleFreq$','8000'); setF(b,'^AudioSamplingFreq$','8000');
try, set_param(b,'SampleTime','-1'); catch, fprintf(2,'SET MANUALLY: Audio SampleTime = -1\n'); end
add_line(ss,'In1/1','AudGain/1'); add_line(ss,'AudGain/1','AudInt16/1'); add_line(ss,'AudInt16/1','Audio/1');
add_line(mdl,'SecurityLogic/2','AudioSS/1');
phS = get_param(ss,'PortHandles'); phL = get_param(lg,'PortHandles');
add_line(mdl, phL.Outport(6), phS.Enable);        % enable = audioOn

% ---- flash: no torch block in library; terminate ----
add_block('simulink/Sinks/Terminator',[mdl '/FlashTerm'],'Position',[900 250 920 270]);
add_line(mdl,'SecurityLogic/3','FlashTerm/1');

% ---- on-phone data displays ----
names  = {'Breach','Lat','Lon','BreachTimeHHMMSS','LinkAlive'};
for i = 1:5
    nm = ['Disp' names{i}];
    b = addB('androiduilib/Data Display', mdl, nm, [1100 40+70*i 1190 80+70*i]);
    setF(b,'^(label|title|name|displayName|text)$',names{i},true);
    add_line(mdl,sprintf('SecurityLogic/%d',6+i),[nm '/1']);
end

% ---- simulation-only displays ----
add_block('simulink/Sinks/Display',[mdl '/InfoDisp'],'Position',[900 420 1000 480]);
add_line(mdl,'SecurityLogic/4','InfoDisp/1');
add_block('simulink/Sinks/Display',[mdl '/LogDisp'],'Position',[900 510 1060 600]);
add_line(mdl,'SecurityLogic/5','LogDisp/1');

save_system(mdl, fullfile(here,[mdl '.slx']));
fprintf('\nSaved SecurityApp.slx (peer %s:%d)\n\n=== VERIFY ===\n',peerIP,port);
dumpP([ss '/Audio']); dumpP([mdl '/UDPTx']); dumpP([mdl '/DispLat']);
end

function b = addB(src, mdl, name, pos)
b = [mdl '/' name]; add_block(src, b, 'Position', pos);
end
function setF(b, pat, val, quiet)
if nargin < 4, quiet = false; end
dp = get_param(b,'DialogParameters');
if isstruct(dp)
    f = fieldnames(dp);
    for i = 1:numel(f)
        if ~isempty(regexpi(f{i},pat,'once'))
            try, set_param(b,f{i},val); return; catch, end
        end
    end
end
if ~quiet, fprintf(2,'  SET MANUALLY on %s: field like "%s" = %s\n', b, pat, val); end
end
function dumpP(b)
fprintf('\n[%s]\n', b);
dp = get_param(b,'DialogParameters');
if ~isstruct(dp), return; end
f = fieldnames(dp);
for i = 1:numel(f)
    try, v = get_param(b,f{i}); catch, v = '?'; end
    if ~ischar(v), v = '<non-text>'; end
    fprintf('  %-22s = %s\n', f{i}, v);
end
end
