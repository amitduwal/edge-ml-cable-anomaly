% -------------------------------
% Tektronix MSO64B Normal Capture (One-by-One)
% -------------------------------

% IP address of the oscilloscope
scopeIP = '169.254.198.168';
scope = visadev(['TCPIP0::', scopeIP, '::inst0::INSTR']);
scope.Timeout = 60;
configureTerminator(scope,"LF");

% Capture Settings
numFrames = 1000;
recordLength = 250000;
sampleRate = 1250e6; 
triggerLevel = 1.5;
verticalScale = 0.5;

filename = 'E:\Thesis\thesis_code\data\oscilloscope\ethernet_packets_normal.mat';

% Preallocate
packets = zeros(recordLength, numFrames);
metadata.sample_rate = sampleRate;

try
    flush(scope);
    writeline(scope,'HEADER OFF');
    writeline(scope,'DATA:SOURCE CH1');
    writeline(scope,'DATA:ENC SRI');
    writeline(scope,'DATA:WIDTH 2');

    % --- Horizontal & Vertical Setup ---
    writeline(scope, ['CH1:SCALE ', num2str(verticalScale)]);
    writeline(scope, 'HOR:MODE MAN');
    writeline(scope, ['HOR:RECORDLENGTH ', num2str(recordLength)]);
    writeline(scope, ['HOR:MODE:SAMPLERATE ', num2str(sampleRate)]);

    % --- Trigger Setup ---
    writeline(scope,'TRIG:A:EDGE:SOU CH2');
    writeline(scope,'TRIG:A:TYPE EDGE');
    writeline(scope,'TRIG:A:EDGE:SLO RISE');
    writeline(scope,['TRIG:A:LEV:CH2 ', num2str(triggerLevel)]);

    % Ensure FastFrame is OFF
    writeline(scope,'HOR:FASTFRAME:STATE OFF');

    % Read scaling parameters once (assuming they don't change during the loop)
    % We need to trigger once or be in a ready state to get valid preamble
    yMult = str2double(writeread(scope,'WFMOUTPRE:YMULT?'));
    yOff  = str2double(writeread(scope,'WFMOUTPRE:YOFF?'));
    yZero = str2double(writeread(scope,'WFMOUTPRE:YZERO?'));

    for i = 1:numFrames
        fprintf("Capturing and downloading packet %d of %d...\n", i, numFrames);
        
        % Set to stop after one trigger
        writeline(scope, 'ACQ:STOPAFTER SEQUENCE');
        writeline(scope, 'ACQ:STATE RUN');
        
        % CRITICAL: Wait for the scope to actually finish the capture
        % The script will pause here until a trigger happens.
        fprintf("Waiting for trigger...\n");
        opcResponse = writeread(scope, '*OPC?'); 
        
        % Only after *OPC? returns '1' do we ask for the data
        writeline(scope, 'CURVE?');
        raw = readbinblock(scope, 'int16');
        packets(:,i) = ((double(raw) - yOff) * yMult) + yZero;
        pause(0.2)
    end

    save(filename,'packets','metadata','-v7.3');
    fprintf("Data saved to %s\n", filename);

catch ME
    fprintf("Error: %s\n",ME.message);
end

clear scope;