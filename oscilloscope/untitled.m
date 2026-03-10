% --- Configuration ---
ipAddress = '169.254.198.168';
resourceStr = ['TCPIP0::' ipAddress '::inst0::INSTR'];

try
    scope = visadev(resourceStr);
    scope.Timeout = 30; % Increased for large records
    
    % 1. Sync MATLAB with the Scope's actual record length
    % This ensures you get ALL samples currently on the screen
    writeline(scope, 'HEADER OFF');
    recordLength = str2double(query(scope, 'HORIZONTAL:RECORDLENGTH?'));
    writeline(scope, ['DATA:START 1; STOP ' num2str(recordLength)]);
    writeline(scope, 'DATA:SOURCE CH1');
    writeline(scope, 'DATA:ENCDG RIBINARY'); 
    writeline(scope, 'DATA:WIDTH 2'); % Using 16-bit for full MSO64B precision

    fprintf('Recording %d samples per trigger. Press Ctrl+C to stop.\n', recordLength);

    iteration = 1;
    while true
        % 2. Get Scaling Factors
        yMult = str2double(query(scope, 'WFMOUTPRE:YMULT?'));
        yOff = str2double(query(scope, 'WFMOUTPRE:YOFF?'));
        yZero = str2double(query(scope, 'WFMOUTPRE:YZERO?'));
        tScale = str2double(query(scope, 'WFMOUTPRE:XINCR?')); % Time per sample

        % 3. Transfer Data
        writeline(scope, 'CURVE?');
        rawBinaryData = readbinblock(scope, 'int16'); % Read as 16-bit integers

        % 4. Convert to Voltage
        voltage = ((double(rawBinaryData) - yOff) * yMult) + yZero;
        
        % 5. Save to MAT-file
        % Saving each capture as its own variable or file
        saveName = sprintf('Capture_%04d.mat', iteration);
        save(saveName, 'voltage', 'tScale', 'iteration');

        fprintf('Saved %s (%d samples)\n', saveName, length(voltage));
        iteration = iteration + 1;
        
        % Brief pause to allow the scope to re-trigger
        pause(0.1); 
    end

catch ME
    fprintf('\nLogging stopped: %s\n', ME.message);
    if exist('scope', 'var'), clear scope; end
end