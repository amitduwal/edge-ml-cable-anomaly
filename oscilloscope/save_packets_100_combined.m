%% Combined Acquisition: Tektronix MSO64B + Red Pitaya
clear; clc;

% --- Configuration: Oscilloscope ---
scopeIP = '169.254.198.168';
scopeFile = 'E:\Thesis\thesis_code\data\oscilloscope\100Mbps\air\ethernet_packets_1000_25cm.mat';
numFrames = 1000;
recordLengthScope = 250000; 
sampleRateScope = 1250e6; 
scopeVerticalScale = 0.5;
scopeHorizontalScale = 40e-6;
scopeHorizontalPosition = 30;
scopeTriggerLevel = 1.5;


% --- Configuration: Red Pitaya ---
rpIP = '169.254.149.74';
rpPort = 5000;
rpFile = 'E:\Thesis\thesis_code\data\rp\100Mbps\air\ethernet_packets_1000_25cm.mat';
recordLengthRP = 16384; 
if isfile(rpFile)
    error('File already exists: %s\nAborting to prevent overwrite.', filename);
end
if isfile(scopeFile)
    error('File already exists: %s\nAborting to prevent overwrite.', filename);
end

% --- Preallocate Data ---
packetsScope = zeros(recordLengthScope, numFrames);
packetsRP    = zeros(recordLengthRP, numFrames);

scopemetadata.sample_rate = sampleRateScope;
scopemetadata.trigger_level = scopeTriggerLevel;
scopemetadata.record_length = recordLengthScope;
scopemetadata.num_frames = numFrames;

rpmetadata.record_length = recordLengthRP;
rpmetadata.num_frames = numFrames;
rpmetadata.sample_rate = 125e6; 
rpmetadata.trigger_level = 1.5;

try
    %% 1. Initialize Connections
    fprintf('Connecting to devices...\n');
    scope = visadev(['TCPIP0::', scopeIP, '::inst0::INSTR']);
    scope.Timeout = 40;
    configureTerminator(scope, "LF");
    
    rp = tcpclient(rpIP, rpPort);
    configureTerminator(rp, "CR/LF");

    %% 2. Global Setup: Oscilloscope
    writeline(scope, 'HEADER OFF');
    writeline(scope, 'DATA:SOURCE CH1');
    writeline(scope, 'DATA:ENC SRI'); 
    writeline(scope, 'DATA:WIDTH 2');
    writeline(scope, ['CH1:SCALE ', num2str(scopeVerticalScale)]);
    writeline(scope, 'SELECT:CH2 ON');
    writeline(scope, 'CH2:SCALE 1.0');
    writeline(scope, 'HOR:MODE MAN');
    writeline(scope, ['HOR:MODE:SAMPLERATE ', num2str(sampleRateScope)]);
    writeline(scope, ['HOR:SCALE ', num2str(scopeHorizontalScale)]);
    writeline(scope, ['HOR:POS ', num2str(scopeHorizontalPosition)]);
    writeline(scope, 'TRIG:A:TYPE EDGE');
    writeline(scope, 'TRIG:A:EDGE:SOU CH2');
    writeline(scope, 'TRIG:A:EDGE:SLO RISE');
    writeline(scope, ['TRIG:A:LEV:CH2 ', num2str(scopeTriggerLevel)]);
    writeline(scope, 'TRIG:A:MODE NORMAL');
    
    % yMult = str2double(writeread(scope, 'WFMOUTPRE:YMULT?'));
    % yOff  = str2double(writeread(scope, 'WFMOUTPRE:YOFF?'));
    % yZero = str2double(writeread(scope, 'WFMOUTPRE:YZERO?'));
    % disp([yMult, yOff, yZero])

    %% 3. Global Setup: Red Pitaya
    writeline(rp, 'ACQ:RST');
    writeline(rp, 'ACQ:DEC 1'); 
    writeline(rp, 'ACQ:DATA:FORMAT BIN');
    writeline(rp, 'ACQ:DATA:UNITS VOLTS');
    writeline(rp, 'ACQ:TRIG:LEV 1.5');

    %% 4. Main Acquisition Loop
    for i = 1:numFrames
        fprintf('Frame %d/%d: Arming... ', i, numFrames);
        
        % --- ARM BOTH DEVICES ---
        % Arm Tektronix
        writeline(scope, '*CLS');
        flush(scope);
        writeline(scope, 'ACQ:STOPAFTER SEQUENCE');
        writeline(scope, 'ACQ:STATE RUN');
        
        % Arm Red Pitaya
        writeline(rp, 'ACQ:START');
        writeline(rp, 'ACQ:TRIG CH2_PE'); 
        writeline(rp, 'ACQ:TRIG:DLY 8192');

        % --- WAIT FOR BOTH TO TRIGGER ---
        % Wait for Scope
        while ~contains(writeread(scope, 'ACQ:STATE?'), '0')
            pause(0.01);
        end
        % Wait for Red Pitaya
        while ~contains(writeread(rp, 'ACQ:TRIG:STAT?'), 'TD')
            pause(0.01);
        end
        
        fprintf('Triggered! Downloading... ');

        % --- DOWNLOAD FROM SCOPE ---
        writeline(scope, 'DATA:START 1');
        writeline(scope, ['DATA:STOP ', num2str(recordLengthScope)]);

        % --- Get scaling AFTER acquisition ---
        yMult = str2double(writeread(scope, 'WFMOUTPRE:YMULT?'));
        yOff  = str2double(writeread(scope, 'WFMOUTPRE:YOFF?'));
        yZero = str2double(writeread(scope, 'WFMOUTPRE:YZERO?'));

        write(scope, 'CURVE?');
        rawScope = readbinblock(scope, 'int16');
        packetsScope(:, i) = ((double(rawScope) - yOff) * yMult) + yZero;

        % --- DOWNLOAD FROM RED PITAYA ---
        writeline(rp, 'ACQ:SOUR1:DATA?');
        headerStart = read(rp, 1, "char"); 
        nDigits = str2double(read(rp, 1, "char")); 
        payloadLength = str2double(read(rp, nDigits, "char")); 
        rawDataRP = read(rp, payloadLength / 4, "single");
        rawDataRP = swapbytes(rawDataRP);
        read(rp, 2, "char"); % Clear terminator
        packetsRP(:, i) = double(rawDataRP(1:recordLengthRP));

        fprintf('Done.\n');
    end

    %% 5. Save Data to Separate Files
    % Save Oscilloscope Data
    packets = packetsScope;
    metadata = scopemetadata;
    save(scopeFile, 'packets', 'metadata', '-v7.3');
    
    % Save Red Pitaya Data
    packets = packetsRP;
    metadata = rpmetadata;
    save(rpFile, 'packets', 'metadata', '-v7.3');
    
    fprintf('\nSuccess! Data saved to:\n1. %s\n2. %s\n', scopeFile, rpFile);

catch ME
    fprintf('\nCritical Error: %s\n', ME.message);
end

% Cleanup
clear scope rp;