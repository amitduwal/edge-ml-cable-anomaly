%% Tektronix MSO64B - Fixed Buffer Size Transfer
clear; clc;

scopeIP = '169.254.198.168';
numFrames = 10;
recordLength = 250000; 
sampleRate = 1250e6; 
horizontalScale = 40e-6;
horizontalPosition = 30;
triggerLevel = 1.5;
verticalScale = 0.5;
filename = 'E:\Thesis\thesis_code\data\oscilloscope\fixed_buffer_test.mat';

try
    scope = visadev(['TCPIP0::', scopeIP, '::inst0::INSTR']);
    scope.Timeout = 40; % High timeout for large transfers
    configureTerminator(scope, "LF");
    
    % Initial Setup
    writeline(scope, 'HEADER OFF');
    writeline(scope, 'DATA:SOURCE CH1');
    writeline(scope, 'DATA:ENC SRI'); 
    writeline(scope, 'DATA:WIDTH 2');
    % writeline(scope, ['HOR:RECORDLENGTH ', num2str(recordLength)]);


     % Set vertical scale of Channel 1 to 500 mV/div
    writeline(scope, ['CH1:SCALE ', num2str(verticalScale)]);
    writeline(scope,'SELECT:CH2 ON');
    writeline(scope,'CH2:SCALE 1.0'); % Set a reasonable scale for the pulse


    % --- Horizontal & Acquisition Setup ---
    writeline(scope, 'HOR:MODE MAN');
    writeline(scope, ['HOR:MODE:SAMPLERATE ', num2str(sampleRate)]);
    writeline(scope, ['HOR:SCALE ', num2str(horizontalScale)]);
    writeline(scope, ['HOR:POS ', num2str(horizontalPosition)]);

    writeline(scope,'TRIG:A:EDGE:SOU CH2');

    % Set trigger type to edge trigger
    writeline(scope,'TRIG:A:TYPE EDGE');

    % Trigger on falling edge (packet start often dips negative)
    writeline(scope,'TRIG:A:EDGE:SLO RISE');

    % Set trigger voltage level to -0.5 V
    writeline(scope,['TRIG:A:LEV:CH2 ', num2str(triggerLevel)]);

    writeline(scope,'TRIG:A:MODE NORMAL');     % avoid auto-trigger

    % Get scaling
    % yMult = str2double(writeread(scope, 'WFMOUTPRE:YMULT?'));
    % yOff  = str2double(writeread(scope, 'WFMOUTPRE:YOFF?'));
    % yZero = str2double(writeread(scope, 'WFMOUTPRE:YZERO?'));

    packets = zeros(recordLength, numFrames);
    i = 1;
    while i <= numFrames
        writeline(scope, '*CLS');
        flush(scope);
        
        % Arm
        writeline(scope, 'ACQ:STOPAFTER SEQUENCE');
        writeline(scope, 'ACQ:STATE RUN');
        
        fprintf('Frame %d/%d: Waiting... ', i, numFrames);

        % Wait for Trigger
        while ~contains(writeread(scope, 'ACQ:STATE?'), '0')
            pause(0.05);
        end
        
        % --- RE-ASSERT CONSTRAINTS INSIDE LOOP ---
        writeline(scope, 'DATA:START 1');
        writeline(scope, ['DATA:STOP ', num2str(recordLength)]);

        % --- Get scaling AFTER acquisition ---
        yMult = str2double(writeread(scope, 'WFMOUTPRE:YMULT?'));
        yOff  = str2double(writeread(scope, 'WFMOUTPRE:YOFF?'));
        yZero = str2double(writeread(scope, 'WFMOUTPRE:YZERO?'));
        
        % Request Data
        write(scope, 'CURVE?');
        raw = readbinblock(scope, 'int16');
        
        % Check if the received data matches the expected size
        receivedLength = length(raw);
        if receivedLength == recordLength
            packets(:, i) = ((double(raw) - yOff) * yMult) + yZero;
            fprintf('Success (Rec: %d).\n', receivedLength);
            i = i + 1; % Move to next frame
        else
            fprintf('Size Mismatch! Expected %d, got %d. Retrying...\n', recordLength, receivedLength);
            % Do not increment i; loop will retry this frame
            pause(0.5); 
        end
        
        writeread(scope, '*OPC?'); 
    end

    save(filename, 'packets', '-v7.3');

catch ME
    fprintf('\nGlobal Error: %s\n', ME.message);
end

clear scope;