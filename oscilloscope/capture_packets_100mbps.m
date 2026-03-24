% -------------------------------
% Tektronix MSO64B Packet Capture for 100Mbps
% Capture 5 Ethernet packets using FastFrame
% Trigger level = -0.5 V
% -------------------------------

% IP address of the oscilloscope
scopeIP = '169.254.198.168';

% Create VISA connection using Ethernet (TCPIP)
scope = visadev(['TCPIP0::', scopeIP, '::inst0::INSTR']);

% Increase timeout because waveform transfers can take time
scope.Timeout = 60;

% Configure communication line termination to LF (Tektronix standard)
configureTerminator(scope,"LF");

% Number of packets (frames) to capture
numFrames = 5;

% Number of samples stored per packet
recordLength = 250000;

sampleRate = 1250e6; 
horizontalScale = 40e-6;
horizontalPosition = 30;
triggerLevel = 0.4;
verticalScale = 0.25;

% -------------------------------
% MAT FILE SETUP
% -------------------------------
filename = 'ethernet_packets.mat';

% Initialize data structure
packets = zeros(recordLength, numFrames);  % preallocate for speed
metadata.sample_rate = sampleRate;
metadata.trigger_level = triggerLevel;
metadata.record_length = recordLength;
metadata.num_frames = numFrames;

try

    % Clear any unread data in the scope buffer
    flush(scope);

    % Disable header text in responses (faster data transfers)
    writeline(scope,'HEADER OFF');

    % Select waveform source channel
    writeline(scope,'DATA:SOURCE CH1');

    % Set waveform encoding to Signed Integer (fastest binary format)
    writeline(scope,'DATA:ENC SRI');

    % Set waveform width to 2 bytes (16-bit data)
    writeline(scope,'DATA:WIDTH 2');

    % Set vertical scale of Channel 1 to 500 mV/div
    writeline(scope, ['CH1:SCALE ', num2str(verticalScale)]);

    % --- Horizontal & Acquisition Setup ---
    writeline(scope, 'HOR:MODE MAN');
    writeline(scope, ['HOR:MODE:SAMPLERATE ', num2str(sampleRate)]);
    writeline(scope, ['HOR:SCALE ', num2str(horizontalScale)]);

    writeline(scope, ['HOR:POS ', num2str(horizontalPosition)]);


    % -------------------------------
    % FASTFRAME CONFIGURATION
    % -------------------------------

    % Enable FastFrame segmented acquisition
    writeline(scope,'HOR:FASTFRAME:STATE ON');

    % Define number of segments (each segment captures one trigger event)
    writeline(scope,['HOR:FASTFRAME:COUNT ',num2str(numFrames)]);

    % Define number of samples stored in each segment
    writeline(scope,['HOR:RECORDLENGTH ',num2str(recordLength)]);

    % -------------------------------
    % TRIGGER CONFIGURATION
    % -------------------------------

    % Set trigger type to edge trigger
    writeline(scope,'TRIG:A:TYPE EDGE');

    % Trigger source is channel 2
    writeline(scope,'TRIG:A:EDGE:SOU CH2');

    % Trigger on falling edge (packet start often dips negative)
    writeline(scope,'TRIG:A:EDGE:SLO RISE');

    % Ensure CH2 is set up for the trigger
    writeline(scope, 'CH2:PRObe:GAIN 1.0'); % Ensure no attenuation mismatch
    writeline(scope, 'CH2:COUPling DC');
    writeline(scope, 'TRIG:A:MODE NORMAL') % CRITICAL: Do not use AUTO


    % Set trigger voltage level to 0.5 V
    writeline(scope,['TRIG:A:LEV:CH2 ', num2str(triggerLevel)]);

    % -------------------------------
    % START ACQUISITION
    % -------------------------------

    % Stop acquisition after the required number of triggers
    writeline(scope,'ACQ:STOPAFTER SEQUENCE');

    % Start acquisition
    writeline(scope,'ACQ:STATE RUN');

    % Inform user
    fprintf("Waiting for %d Ethernet packets...\n",numFrames);

    % Wait a few seconds for packets to arrive
    pause(3);

    % -------------------------------
    % READ SCALING PARAMETERS
    % -------------------------------

    % YMULT converts ADC counts to volts
    yMult = str2double(writeread(scope,'WFMOUTPRE:YMULT?'));

    % YOFF is the ADC offset
    yOff  = str2double(writeread(scope,'WFMOUTPRE:YOFF?'));

    % YZERO is voltage reference offset
    yZero = str2double(writeread(scope,'WFMOUTPRE:YZERO?'));

    % -------------------------------
    % PLOT INITIALIZATION
    % -------------------------------

    figure(1);     % Create figure window
    clf;           % Clear previous plots
    hold on;       % Allow multiple packet plots

    % -------------------------------
    % DOWNLOAD EACH PACKET FRAME
    % -------------------------------

    for i = 1:numFrames

        % Select which FastFrame segment to read
        writeline(scope,['DATA:FRAMESTART ',num2str(i)]);
        writeline(scope,['DATA:FRAMESTOP ',num2str(i)]);

        % Define data region inside the frame
        writeline(scope,'DATA:START 1');
        writeline(scope,['DATA:STOP ',num2str(recordLength)]);

        % Request waveform data from scope
        write(scope,'CURVE?','string');

        % Read binary block data (16-bit integers)
        raw = readbinblock(scope,'int16');

        % Convert ADC values to voltage using scaling parameters
        volt = ((double(raw) - yOff) * yMult) + yZero;

        % Plot captured packet waveform
        plot(volt);

    end

    % -------------------------------
    % PLOT SETTINGS
    % -------------------------------

    title('Captured Ethernet Packets (Trigger -0.5V)');
    ylabel('Voltage (V)');
    xlabel('Sample Number');
    grid on;

catch ME

    % Display any communication or acquisition errors
    fprintf("Error: %s\n",ME.message);

end
writeline(scope, 'HOR:FASTFRAME:STATE OFF'); % Turn off FastFrame to return to normal mode
% Close connection and release VISA object
clear scope;