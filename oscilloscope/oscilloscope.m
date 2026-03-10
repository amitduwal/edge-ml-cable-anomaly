% ---------------------------------------------------------
% Tektronix MSO64B: 10 Mbps Ethernet Full Packet Capture
% Uses Timeout Trigger to find Interpacket Gaps (IPG)
% ---------------------------------------------------------

% --- Configuration ---
scopeIP = '169.254.198.168';
numFrames = 5;            % Number of packets to catch
sampleRate = 1250e6;       % 100 MS/s (10 samples per bit for 10Mbps)
horizontalScale = 200e-6; % 2ms total time (Max packet is ~1.2ms)
recordLength = 250000;    % Sufficient for 2.5ms of data at 100MS/s

try
    % Connect and Reset
    scope = visadev(['TCPIP0::', scopeIP, '::inst0::INSTR']);
    scope.Timeout = 60;
    configureTerminator(scope,"LF");
    flush(scope);
    
    writeline(scope, 'HEADER OFF');
    writeline(scope, 'DATA:SOURCE CH1');
    writeline(scope, 'DATA:ENC SRI'); % Signed Integer
    writeline(scope, 'DATA:WIDTH 2');

    % --- Horizontal & Acquisition Setup ---
    writeline(scope, 'HOR:MODE MAN');
    writeline(scope, ['HOR:MODE:SAMPLERATE ', num2str(sampleRate)]);
    writeline(scope, ['HOR:RECORDLENGTH ', num2str(recordLength)]);
    writeline(scope, ['HOR:SCALE ', num2str(horizontalScale)]);

    % --- 10Mbps Ethernet Specific Triggering ---
    % 10BASE-T idle is 0V. We look for a 5us "quiet" period.
    writeline(scope, 'TRIG:A:TYPE TIMEOUT');
    writeline(scope, 'TRIG:A:TIMEOUT:SOU CH1');
    writeline(scope, 'TRIG:A:TIMEOUT:POLARITY EITHER');
    writeline(scope, 'TRIG:A:TIMEOUT:TIME 5e-6'); 
    writeline(scope, 'TRIG:A:LEV 0.8'); % Trigger at 800mV to avoid noise

    % Holdoff: Wait 1.5ms before allowing another trigger 
    % (Ensures we don't trigger on the end of the same packet)
    writeline(scope, 'TRIG:A:HOLDOFF:MODE TIME');
    writeline(scope, 'TRIG:A:HOLDOFF:TIME 1.5e-3');

    % --- FastFrame Setup ---
    writeline(scope, 'HOR:FASTFRAME:STATE ON');
    writeline(scope, ['HOR:FASTFRAME:COUNT ', num2str(numFrames)]);

    % --- Start Acquisition ---
    writeline(scope, 'ACQ:STOPAFTER SEQUENCE');
    writeline(scope, 'ACQ:STATE RUN');
    fprintf("Waiting for %d Ethernet packets (10Mbps)...\n", numFrames);
    
    % Wait until the scope finishes acquiring all frames
    while ~strcmp(writeread(scope, 'ACQ:STATE?'), '0')
        pause(0.5);
    end

    % --- Scaling & Timing Parameters ---
    yMult = str2double(writeread(scope,'WFMOUTPRE:YMULT?'));
    yOff  = str2double(writeread(scope,'WFMOUTPRE:YOFF?'));
    yZero = str2double(writeread(scope,'WFMOUTPRE:YZERO?'));
    xIncr = str2double(writeread(scope,'WFMOUTPRE:XINCR?'));

    % --- Download & Plot ---
    figure(1); clf;
    colors = lines(numFrames);
    
    for i = 1:numFrames
        writeline(scope, ['DATA:FRAMESTART ', num2str(i)]);
        writeline(scope, ['DATA:FRAMESTOP ', num2str(i)]);
        writeline(scope, 'DATA:START 1');
        writeline(scope, ['DATA:STOP ', num2str(recordLength)]);
        
        write(scope, 'CURVE?', 'string');
        raw = readbinblock(scope, 'int16');
        
        % Conversion
        volt = ((double(raw) - yOff) * yMult) + yZero;
        timeAxis = (0:length(volt)-1) * xIncr;
        
        subplot(numFrames, 1, i);
        plot(timeAxis * 1e3, volt, 'Color', colors(i,:));
        ylabel(['Pkt ', num2str(i), ' (V)']);
        grid on;
    end
    xlabel('Time (ms)');
    sgtitle('10Mbps Ethernet Packet Captures');

catch ME
    fprintf("Error: %s\n", ME.message);
end

% Cleanup
writeline(scope, 'HOR:FASTFRAME:STATE OFF');
clear scope;