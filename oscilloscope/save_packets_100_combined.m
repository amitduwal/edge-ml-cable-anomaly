%% Tektronix MSO64B - Robust Immediate Download (Fixed + CH1/CH2 setup)
clear; clc;

scopeIP = '169.254.198.168';
numFrames = 10;
recordLength = 250000;
filename = 'E:\Thesis\thesis_code\data\oscilloscope\debug_test.mat';

try
    scope = visadev(['TCPIP0::', scopeIP, '::inst0::INSTR']);
    scope.Timeout = 30;
    configureTerminator(scope, "LF");

    % -------------------------------
    % CONFIGURATION (IMPORTANT)
    % -------------------------------
    writeline(scope, '*RST');
    writeline(scope, '*CLS');

    % Acquisition channel
    writeline(scope, 'DATA:SOURCE CH1');

    % Trigger on CH2
    writeline(scope, 'TRIG:A:EDGE:SOURCE CH2');

    % Data format (CRITICAL)
    writeline(scope, 'DATA:WIDTH 2');        % int16
    writeline(scope, 'DATA:ENC RIBINARY');   % signed

    % Set record length
    writeline(scope, ['HOR:RECORDLENGTH ', num2str(recordLength)]);

    pause(0.5); % allow scope to settle

    % Get scaling AFTER setting source
    yMult = str2double(writeread(scope, 'WFMOUTPRE:YMULT?'));
    yOff  = str2double(writeread(scope, 'WFMOUTPRE:YOFF?'));
    yZero = str2double(writeread(scope, 'WFMOUTPRE:YZERO?'));

    packets = zeros(recordLength, numFrames);

    for i = 1:numFrames

        writeline(scope, '*CLS');
        flush(scope);

        % Arm acquisition
        writeline(scope, 'ACQ:STOPAFTER SEQUENCE');
        writeline(scope, 'ACQ:STATE RUN');

        fprintf('Frame %d/%d: Waiting... ', i, numFrames);

        % -------------------------------
        % SAFE WAIT LOOP (with timeout)
        % -------------------------------
        tStart = tic;
        timeoutSec = 10;

        while true
            state = str2double(writeread(scope, 'ACQ:STATE?'));

            if state == 0
                break;
            end

            if toc(tStart) > timeoutSec
                warning('Timeout waiting for trigger. Retrying...');
                writeline(scope, 'ACQ:STATE STOP');
                continue;
            end

            pause(0.05);
        end

        % -------------------------------
        % DATA TRANSFER
        % -------------------------------
        writeline(scope, 'DATA:START 1');
        writeline(scope, ['DATA:STOP ', num2str(recordLength)]);

        write(scope, 'CURVE?');

        try
            raw = readbinblock(scope, 'int16');
            packets(:, i) = ((double(raw) - yOff) * yMult) + yZero;
            fprintf('Success.\n');

        catch binME
            fprintf('Transfer Error: %s. Retrying frame...\n', binME.message);
            flush(scope);
            i = i - 1; % retry same frame
            continue;
        end

        % Ensure operation complete
        writeread(scope, '*OPC?');
    end

    save(filename, 'packets', '-v7.3');

catch ME
    fprintf('\nGlobal Error: %s\n', ME.message);
end

clear scope;