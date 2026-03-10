% --- Setup Connection ---
scopeIP = '169.254.198.168'; % Check scope IP
scope = visadev(['TCPIP0::', scopeIP, '::inst0::INSTR']);
scope.Timeout = 30;

configureTerminator(scope,"LF");

try

    flush(scope);

    % --- Configure Data Transfer ---
    writeline(scope,'HEADER OFF');
    writeline(scope,'DATA:SOURCE CH1');
    writeline(scope,'DATA:START 1');
    writeline(scope,'DATA:STOP 1250000');
    writeline(scope,'DATA:ENC SRI');
    writeline(scope,'DATA:WIDTH 2');

    % --- Get Scaling Parameters ---
    yMult = str2double(writeread(scope,'WFMOUTPRE:YMULT?'));
    yOff  = str2double(writeread(scope,'WFMOUTPRE:YOFF?'));
    yZero = str2double(writeread(scope,'WFMOUTPRE:YZERO?'));

    % --- Request Waveform ---
    fprintf('Requesting 1.25M points from MSO64B...\n');

    write(scope,'CURVE?','string');
    rawData = readbinblock(scope,'int16');

    % --- Convert to Voltage ---
    voltages = ((double(rawData) - yOff) * yMult) + yZero;

    % --- Plot ---
    figure(1);
    clf;
    plot(voltages);
    title('Ethernet Waveform from MSO64B');
    ylabel('Amplitude (V)');
    grid on;
    drawnow;

catch ME
    fprintf('Error: %s\n',ME.message);
end

clear scope;