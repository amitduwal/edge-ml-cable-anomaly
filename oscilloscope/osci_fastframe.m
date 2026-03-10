% --- MATLAB FastFrame Data Acquisition Script ---

% 1. Connection Setup
scopeIP = '169.254.198.168'; % Define the IP address of the oscilloscope
try
    scope = visadev(['TCPIP0::', scopeIP, '::inst0::INSTR']);
    fprintf(scopeIP)
catch
    % If the resource is busy, find and delete all existing visadev objects
    oldObjs = visadevlist;
    if ~isempty(oldObjs)
        delete(visadev(oldObjs.ResourceName{1}));
    end
    scope = visadev(['TCPIP0::', scopeIP, '::inst0::INSTR']);
end
scope.Timeout = 50; % Set high timeout (120s) to allow for large data transfers
configureTerminator(scope,"LF"); % Set the message terminator to Line Feed

% 2. Acquisition Parameters
recordLength = 100000; % Define number of points per frame (e.g., 100k)
numFrames    = 50;       % Define total number of frames to capture
allFrames    = zeros(recordLength, numFrames); % Pre-allocate matrix for speed

try
    writeline(scope, '*CLS');       % Clear Status: Resets error queue and hardware registers
    flush(scope); % Clear any old data remaining in the MATLAB input buffer
    
    % 3. Configure Waveform Formatting
    writeline(scope, 'HEADER OFF'); % Disable headers in query responses for easier parsing
    writeline(scope, 'DATA:SOURCE CH1'); % Set the source channel to Channel 1
    writeline(scope, 'DATA:ENC SRI'); % Set encoding to Signed Binary, Little Endian (Fastest)
    writeline(scope, 'DATA:WIDTH 2'); % Set data width to 2 bytes (16-bit)
    writeline(scope, 'DATA:START 1'); % Set start point for data transfer
    writeline(scope, ['DATA:STOP ', num2str(recordLength)]); % Set stop point for data transfer
     % 5. Scaling Preamble (Required to convert raw bits to Volts)
    yMult = str2double(writeread(scope, 'WFMOUTPRE:YMULT?')); % Get Vertical Scale Factor
    yOff  = str2double(writeread(scope, 'WFMOUTPRE:YOFF?'));  % Get Vertical Position Offset
    yZero = str2double(writeread(scope, 'WFMOUTPRE:YZERO?')); % Get Vertical Zero Offset
    
    
    % 4. Enable and Configure FastFrame
    writeline(scope, 'HOR:FASTFRAME:STATE ON'); % Turn on FastFrame mode
    writeline(scope, ['HOR:FASTFRAME:COUNT ', num2str(numFrames)]); % Set number of frames to capture
    writeline(scope, ['HOR:RECORDLENGTH ', num2str(recordLength)]); % Ensure record length matches
    
   
    % 6. Start Acquisition
    fprintf("Capturing %d frames... please wait.\n", numFrames);
    writeline(scope, 'ACQUIRE:STOPAFTER SEQUENCE'); % Set scope to stop after one sequence
    writeline(scope, 'ACQUIRE:STATE RUN'); % Start the trigger system
    
    % 7. Synchronization (The Fix for Timeouts)
    % *OPC? blocks the script until the scope hardware confirms acquisition is 100% finished
    % writeread(scope, '*OPC?'); 
    
    % 8. Data Retrieval Loop
    for f = 1:numFrames
        fprintf("Downloading frame %d of %d\n", f, numFrames);
        
        % Tell the scope which specific frame to point to for the CURVE? query
        writeline(scope, ['DATA:FRAMESTART ', num2str(f)]); 
        writeline(scope, ['DATA:FRAMESTOP ', num2str(f)]);
        
        % Request binary waveform data
        writeline(scope, 'CURVE?'); 
        raw = readbinblock(scope, 'int16'); % Read the block as 16-bit integers
        
        % Convert raw ADC counts to actual Voltage values
        volts = ((double(raw) - yOff) * yMult) + yZero;
        allFrames(:, f) = volts; % Store the frame in our matrix
    end
    
    % 9. Visualization
    figure; % Open a new plot window
    plot(allFrames(:)); % Plot only the first frame for clarity
    title(['FastFrame Capture - Frame 1 of ', num2str(numFrames)]);
    xlabel('Samples');
    ylabel('Voltage (V)');
    grid on; % Enable grid lines

catch ME
    % If any error occurs, display it in the command window
    fprintf("Error encountered: %s\n", ME.message);
end

% 10. Clean Up (Crucial for preventing future timeouts)
writeline(scope, 'HOR:FASTFRAME:STATE OFF'); % Turn off FastFrame to return to normal mode
writeline(scope, 'ACQUIRE:STATE RUN');       % Set scope back to continuous run if desired
delete(scope); % Close the VISA connection
clear scope;   % Remove the object from the workspace
fprintf("Operation complete. Connection closed.\n");