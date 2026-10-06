% Verifies SecurityLogic in plain MATLAB (no phone). Run: test_logic_offline
make_alert_wav(false); alert = evalin('base','alertWav');
rx0 = zeros(64,1,'uint8'); pkt = @(v) typecast(double(v(:)),'uint8');
dec = @(tx) typecast(tx,'double');

% --- NODE ---
clear SecurityLogic
armCmd = pkt([2;0;1;1;0;0;0;0]);
for i=1:70, [tx,~,~,info] = SecurityLogic(0,0,0,20,[0;0;0],19.1,72.8,armCmd,64,alert); end
assert(info(1)==1 && info(2)==0, 'node should be armed, no breach');
[tx,~,~,info,lg] = SecurityLogic(0,0,0,250,[0;0;0],19.1,72.8,armCmd,64,alert); %#ok<ASGLU>
v = dec(tx); assert(v(1)==1 && v(3)==1 && v(8)==1, 'light breach not reported');
fprintf('Node light breach: OK  ts=%s\n', datestr(v(6)/86400+datenum(1970,1,1)));
sirenCmd = pkt([2;1;1;2;0;0;0;0]);
[~,aud,fl] = SecurityLogic(0,0,0,250,[0;0;0],19.1,72.8,sirenCmd,64,alert);
assert(any(aud~=0), 'siren silent'); fprintf('Siren: OK, flash=%d\n',fl);
disCmd = pkt([2;0;0;3;0;0;0;0]);
[tx,~,~,info] = SecurityLogic(0,0,0,20,[0;0;0],19.1,72.8,disCmd,64,alert);
assert(info(1)==0 && info(2)==0); fprintf('Remote disarm: OK\n');

% motion test
clear SecurityLogic
for i=1:70, SecurityLogic(0,0,0,20,[0;0;0],0,0,armCmd,64,alert); end
for i=1:3, [tx,~,~,info] = SecurityLogic(0,0,0,20,[1;0;0],0,0,armCmd,64,alert); end
v = dec(tx); assert(v(3)==1 && v(8)==2); fprintf('Node motion breach: OK\n');

% --- MONITOR ---
clear SecurityLogic
nodePkt = pkt([1;1;1;19.1;72.8;1.7e9;1.7e9;1]);
for i=1:3, [tx,aud,~,info,lg] = SecurityLogic(1,0,1,0,[0;0;0],0,0,nodePkt,64,alert); end
assert(info(2)==1 && any(aud~=0), 'monitor did not alert');
v = dec(tx); assert(v(1)==2 && v(2)==1);
assert(lg(1,1)==1.7e9 && lg(1,4)==1); fprintf('Monitor alert + log + cmd tx: OK\n');
disp('ALL TESTS PASSED');
