clear; clc;

% Red Pitaya IP and port
IP = '169.254.149.74';
port = 5000;

% Create TCP connection to Red Pitaya
rp = tcpclient(IP, port);
configureTerminator(rp,"CR/LF");

% Reset acquisition system
writeline(rp,'ACQ:RST');

% Set decimation (sampling rate divider)
writeline(rp,'ACQ:DEC 1');

% Output data format
writeline(rp,'ACQ:DATA:FORMAT ASCII');

% Data units in volts
writeline(rp,'ACQ:DATA:UNITS VOLTS');

% Set trigger level to -0.25 V
writeline(rp,'ACQ:TRIG:LEV -0.25');

% Trigger on Channel 1 negative edge
writeline(rp,'ACQ:TRIG CH1_NE');

% Start acquisition
writeline(rp,'ACQ:START');

% Wait until trigger occurs
triggered = false;
while ~triggered
    status = writeread(rp,'ACQ:TRIG:STAT?');
    if contains(status,'TD')   % Trigger detected
        triggered = true;
    end
end

pause(0.1)

% Request data from Channel 1
data = writeread(rp,'ACQ:SOUR1:DATA?');

% Clean returned data
data = erase(data,{'{','}'});
signal = str2double(split(data,','));

% Plot captured signal
plot(signal)
grid on
title('Red Pitaya CH1 Triggered Signal (-0.25 V)')

clear rp