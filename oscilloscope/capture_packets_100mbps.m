% -------------------------------
% Tektronix MSO64B Single Packet Capture
% Capture 1 Ethernet packet (No FastFrame)
% -------------------------------

% IP address of the oscilloscope
scopeIP = '169.254.198.168';
scope = visadev(['TCPIP0::', scopeIP, '::inst0::INSTR']);
scope.Timeout = 20; % Reduced timeout for single capture
configureTerminator(scope,"LF");

% Acquisition Parameters
recordLength = 250000;
sampleRate = 125e7;        % 1.25 GS/s
horizontalScale = 40e-6;
triggerLevel = 1.5;       % Updated to -0.5V as per your requirement
verticalScale = 0.25;

try
    flush(scope);
    writeline(scope,'HEADER OFF');
    writeline(scope,'DATA:SOURCE CH1');
    writeline(scope,'DATA:ENC SRI'); % Signed Integer
    writeline(scope,'DATA:WIDTH 2'); % 16-bit

    % --- Vertical & Horizontal Setup ---
    writeline(scope, ['CH1:SCALE ', num2str(verticalScale)]);
    writeline(scope, 'HOR:MODE MAN');
    writeline(scope, ['HOR:MODE:SAMPLERATE ', num2str(sampleRate)]);
    writeline(scope, ['HOR:RECORDLENGTH ', num2str(recordLength)]);
    writeline(scope, ['HOR:SCALE ', num2str(horizontalScale)]);

    % --- FastFrame: ENSURE OFF ---
    writeline(scope,'HOR:FASTFRAME:STATE OFF');

    % --- Trigger Configuration ---
    writeline(scope,'TRIG:A:TYPE EDGE');
    writeline(scope,'TRIG:A:EDGE:SOU CH2');
    writeline(scope,'TRIG:A:EDGE:SLO RISE'); % Falling edge for -0.5V trigger
    writeline(scope,'TRIG:A:MODE NORMAL');
    writeline(scope,['TRIG:A:LEV:CH2 ', num2str(triggerLevel)]);

    % --- Start Acquisition ---
    % ACQ:STOPAFTER SEQUENCE ensures it stops after exactly one trigger event
    writeline(scope,'ACQ:STOPAFTER SEQUENCE');
    writeline(scope,'ACQ:STATE RUN');

    fprintf("Waiting for a single trigger on CH2...\n");
    
    % Wait until the scope has finished capturing (STB check is better, but this works)
    busy = "1";
    while busy == "1"
        busy = writeread(scope, "BUSY?");
        pause(0.1);
    end

    % --- Read Scaling Parameters ---
    yMult = str2double(writeread(scope,'WFMOUTPRE:YMULT?'));
    yOff  = str2double(writeread(scope,'WFMOUTPRE:YOFF?'));
    yZero = str2double(writeread(scope,'WFMOUTPRE:YZERO?'));

    % --- Download Waveform ---
    writeline(scope,'DATA:START 1');
    writeline(scope,['DATA:STOP ', num2str(recordLength)]);
    
    write(scope,'CURVE?');
    raw = readbinblock(scope,'int16');

    % Convert to Voltage
    volt = ((double(raw) - yOff) * yMult) + yZero;

    % --- Plotting ---
    figure(1); clf;
    plot(volt);
    title(['Captured Ethernet Packet (Trigger ', num2str(triggerLevel), 'V)']);
    ylabel('Voltage (V)');
    xlabel('Sample Number');
    grid on;

catch ME
    fprintf("Error: %s\n", ME.message);
end

clear scope;