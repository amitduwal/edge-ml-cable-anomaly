%% Red Pitaya 5-Packet Capture Loop
clear; clc;

% Connection Settings
IP = '169.254.149.74';
port = 5000;
numFrames = 5;
bufferSize = 16384; % Red Pitaya standard buffer length

% Preallocate storage: rows = samples, columns = packets
packetsRP = zeros(bufferSize, numFrames);

try
    % Create TCP connection
    rp = tcpclient(IP, port);
    configureTerminator(rp, "CR/LF");

    % Global Configuration
    writeline(rp, 'ACQ:RST');
    writeline(rp, 'ACQ:DEC 1');
    writeline(rp, 'ACQ:DATA:FORMAT ASCII');
    writeline(rp, 'ACQ:DATA:UNITS VOLTS');
    writeline(rp, 'ACQ:TRIG:LEV -0.25');

    fprintf('Starting capture of %d packets...\n', numFrames);

    for i = 1:numFrames
        % Start acquisition for this frame
        writeline(rp, 'ACQ:START');
        
        % Set trigger source (must be done AFTER ACQ:START)
        writeline(rp, 'ACQ:TRIG CH1_NE');
        writeline(rp, 'ACQ:TRIG:DLY 4096');

        % Polling for trigger
        triggered = false;
        while ~triggered
            status = writeread(rp, 'ACQ:TRIG:STAT?');
            if contains(status, 'TD') % Trigger Detected/Triggered
                triggered = true;
            end
        end

        % Small pause to ensure buffer is filled post-trigger
        pause(0.05);

        % Request and parse data
        rawData = writeread(rp, 'ACQ:SOUR1:DATA?');
        cleanData = erase(rawData, {'{', '}'});
        packetsRP(:, i) = str2double(split(cleanData, ','));
        
        fprintf('Packet %d captured and stored.\n', i);
    end

    % Visualization of all packets
    figure;
    plot(packetsRP);
    title('Red Pitaya: 5 Captured Ethernet Packets');
    xlabel('Samples');
    ylabel('Voltage (V)');
    grid on;

catch ME
    fprintf('Error occurred: %s\n', ME.message);
end

% Clean up
clear rp;