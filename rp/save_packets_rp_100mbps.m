%% Red Pitaya 5-Packet Capture & .mat Export
clear; clc;

% --- Configuration ---
IP = '169.254.149.74';
port = 5000;
numFrames = 10;
recordLengthRP = 16384; % Red Pitaya fixed buffer size
sampleRateRP = 125e6;   % Standard RP sampling rate (125 MHz)
filename = 'E:\Thesis\thesis_code\data\rp\rp_ethernet_packets_test_100.mat';
triggerLevel = 1.5;

% --- Preallocate Data Structure ---
packetsRP = zeros(recordLengthRP, numFrames);
metadataRP.sample_rate = sampleRateRP;
metadataRP.record_length = recordLengthRP;
metadataRP.num_frames = numFrames;
metadataRP.timestamp = datetime('now');
metadataRP.source = 'Red Pitaya STEMlab 125-14';
metadataRP.trigger_level = triggerLevel;

try
    % Create TCP connection
    rp = tcpclient(IP, port);
    configureTerminator(rp, "CR/LF");

    % Global Hardware Setup
    writeline(rp, 'ACQ:RST');
    writeline(rp, 'ACQ:DEC 1'); % 125MS/s
    writeline(rp, 'ACQ:DATA:FORMAT BIN');
    writeline(rp, 'ACQ:DATA:UNITS VOLTS');
    writeline(rp, 'ACQ:TRIG:LEV 1.5');

    fprintf('Starting capture of %d packets...\n', numFrames);

    for i = 1:numFrames
        % Arm the trigger
        writeline(rp, 'ACQ:START');
        writeline(rp, 'ACQ:TRIG CH2_PE'); % Trigger on negative edge
        writeline(rp, 'ACQ:TRIG:DLY 8192'); % Set trigger to middle of buffer

        % Wait for trigger (Polling)
        triggered = false;
        while ~triggered
            status = writeread(rp, 'ACQ:TRIG:STAT?');
            if contains(status, 'TD')
                triggered = true;
            end
        end

        % Small delay to ensure the buffer completes the post-trigger fill
        pause(0.01);
        
        % Request Data
        writeline(rp, 'ACQ:SOUR1:DATA?');
        
        % --- Parse IEEE 488.2 Binary Header ---
        % Header format: #<n><length><data><terminator>
        % e.g., #565536...
        
        headerStart = read(rp, 1, "char"); % Should be '#'
        if ~strcmp(headerStart, '#')
            error('Invalid header received: %s', headerStart);
        end
        
        nDigits = str2double(read(rp, 1, "char")); % Number of digits in length
        payloadLength = str2double(read(rp, nDigits, "char")); % Total bytes
        
        % Read the data (Volts are sent as 4-byte 'single' floats)
        % We divide payloadLength by 4 to get the number of elements
        rawData = read(rp, payloadLength / 4, "single");
        rawData = swapbytes(rawData);
        
        % Read the trailing terminator (CR/LF) to clear the buffer
        read(rp, 2, "char"); 

        % Store data
        packetsRP(:, i) = double(rawData(1:recordLengthRP));
        
        fprintf('Frame %d/%d captured via Binary.\n', i, numFrames);
    end

    % --- Save to .mat File ---
    % Mapping to your existing variable naming convention
    packets = packetsRP; 
    metadata = metadataRP;
    
    save(filename, 'packets', 'metadata', '-v7.3');
    fprintf('Success! Data saved to: %s\n', filename);

catch ME
    fprintf('Critical Error: %s\n', ME.message);
end

% Close connection
clear rp;