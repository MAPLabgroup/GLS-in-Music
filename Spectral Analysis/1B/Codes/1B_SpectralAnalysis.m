%% WAFrequency_Log2Scaled_RMSPowerB Analysis Script
% Computes Weighted Average Frequency and RMS Power from .wav files
% Outputs: Two Excel files and PNG grid plots per stimulus
set(0,'DefaultAxesFontName','Arial')
%% --- USER INPUT ---
folderPath = uigetdir('', 'Select folder containing .wav files');
if folderPath == 0
    error('No folder selected. Script aborted.');
end

%% --- PARAMETERS ---
chunkDuration = 1.2; % seconds per chunk

%% --- GET AND SORT WAV FILES (Natural Numerical Order) ---
wavFiles = dir(fullfile(folderPath, '*.wav'));

% Extract numeric values from filenames for natural sort
fileNames = {wavFiles.name};
numericVals = zeros(1, length(fileNames));
for i = 1:length(fileNames)
    tokens = regexp(fileNames{i}, '\d+', 'match');
    if ~isempty(tokens)
        numericVals(i) = str2double(tokens{1});
    else
        numericVals(i) = i; % fallback
    end
end
[~, sortIdx] = sort(numericVals);
wavFiles = wavFiles(sortIdx);

nStimuli = length(wavFiles);
if nStimuli == 0
    error('No .wav files found in the selected folder.');
end

%% --- INITIALIZE OUTPUT TABLES ---
% Master Data table
masterData = table('Size', [0, 8], ...
    'VariableTypes', {'double','double','double','double','double','double','double','double'}, ...
    'VariableNames', {'StimuliNumber','EventNumber','WeightedAvgFreq_Hz', ...
                      'Log2Scaled_WAFrequency','RMSPower_dB','RMSPower_B', ...
                      'Angle','ChunkDuration_s'});

% GridCAT Data table
gridCATData = table('Size', [0, 4], ...
    'VariableTypes', {'string','double','double','double'}, ...
    'VariableNames', {'EventType','EventOnset_s','EventDuration_s','Angle'});

%% --- OUTPUT FOLDER FOR PLOTS ---
plotFolder = fullfile(folderPath, 'WAFrequency_Log2Scaled_RMSPowerB_FullGrids');
if ~exist(plotFolder, 'dir')
    mkdir(plotFolder);
end

%% --- PROCESS EACH STIMULUS ---
for stimIdx = 1:nStimuli
    wavPath = fullfile(folderPath, wavFiles(stimIdx).name);
    [audioData, fs] = audioread(wavPath);
    
    % Convert stereo to mono if needed
    if size(audioData, 2) > 1
        audioData = mean(audioData, 2);
    end
    
    totalSamples = length(audioData);
    chunkSamples = round(chunkDuration * fs);
    
    % Determine chunk boundaries
    chunkStarts = 1 : chunkSamples : totalSamples;
    nChunks = length(chunkStarts);
    
    % Storage for this stimulus
    waf_hz    = zeros(nChunks, 1);
    waf_log2  = zeros(nChunks, 1);
    rms_dB    = zeros(nChunks, 1);
    rms_B     = zeros(nChunks, 1);
    chunkDurs = zeros(nChunks, 1);
    angles    = zeros(nChunks, 1);
    
    prevPoint = [0, 0]; % Origin for first chunk angle reference
    
    for chunkIdx = 1:nChunks
        startSamp = chunkStarts(chunkIdx);
        endSamp   = min(startSamp + chunkSamples - 1, totalSamples);
        chunk     = audioData(startSamp:endSamp);
        N         = length(chunk);
        chunkDurs(chunkIdx) = N / fs;
        
        %% --- WEIGHTED AVERAGE FREQUENCY (WAF) ---
        % FFT
        X = fft(chunk, N);
        
        % Use only positive frequencies (excluding DC: index 2 to N/2+1)
        if mod(N, 2) == 0
            posIdx = 2 : N/2 + 1;
        else
            posIdx = 2 : (N+1)/2;
        end
        
        freqRes   = fs / N;
        freqs_pos = (posIdx - 1) * freqRes; % Hz values for positive freqs
        
        % Power spectrum (magnitude squared) for positive freqs
        powerSpec = abs(X(posIdx)).^2;
        
        % Weighted average frequency (normalized weights from power spectrum)
        totalPower = sum(powerSpec);
        if totalPower == 0
            waf_hz(chunkIdx) = 0;
        else
            waf_hz(chunkIdx) = sum(freqs_pos(:) .* powerSpec(:)) / totalPower;
        end
        
        % Log2 scaling
        if waf_hz(chunkIdx) > 0
            waf_log2(chunkIdx) = log2(waf_hz(chunkIdx));
        else
            waf_log2(chunkIdx) = 0;
        end
        
        %% --- RMS POWER (dB and B) ---
        % RMS power in frequency domain via Parseval's Theorem / PSD assumption
        % Sum of squared magnitudes of all FFT components (full spectrum), normalized by N
        rms_linear = sqrt(sum(abs(X).^2) / N^2);
        
        % Convert to dB (power: 20*log10 for amplitude RMS)
        if rms_linear > 0
            rms_dB(chunkIdx) = 20 * log10(rms_linear);
        else
            rms_dB(chunkIdx) = -Inf;
        end
        
        % Convert dB to Bel (divide by 10)
        rms_B(chunkIdx) = rms_dB(chunkIdx) / 10;
        
        %% --- ANGLE CALCULATION ---
        % Current point: (Log2Scaled WAF, RMS Power B)
        currPoint = [waf_log2(chunkIdx), rms_B(chunkIdx)];
        
        dx = currPoint(1) - prevPoint(1);
        dy = currPoint(2) - prevPoint(2);
        
        % atan2 returns angle in radians; convert to degrees
        % atan2(dy, dx) gives angle from east, counterclockwise positive
        angleRad = atan2(dy, dx);
        angleDeg = rad2deg(angleRad);
        
        % Normalize to [0, 360)
        if angleDeg < 0
            angleDeg = angleDeg + 360;
        end
        
        % Round to nearest hundredth
        angles(chunkIdx) = round(angleDeg, 2);
        
        % Update previous point
        prevPoint = currPoint;
    end
    
    %% --- APPEND TO MASTER TABLE ---
    for chunkIdx = 1:nChunks
        newRow = {stimIdx, chunkIdx, waf_hz(chunkIdx), waf_log2(chunkIdx), ...
                  rms_dB(chunkIdx), rms_B(chunkIdx), angles(chunkIdx), chunkDurs(chunkIdx)};
        masterData(end+1, :) = newRow;
    end
    
    %% --- APPEND TO GRIDCAT TABLE ---
    eventType = sprintf('Music%dOn', stimIdx);
    for chunkIdx = 1:nChunks
        newRow = {eventType, NaN, chunkDurs(chunkIdx), angles(chunkIdx)};
        gridCATData(end+1, :) = newRow;
    end
    
    %% --- GENERATE GRID PLOT ---
    fig = figure('Visible', 'off');
    plot(waf_log2, rms_B, '-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'b');
    hold on;
    
    % Label each point with chunk number
    for chunkIdx = 1:nChunks
        text(waf_log2(chunkIdx), rms_B(chunkIdx), sprintf('  %d', chunkIdx), ...
            'FontSize', 9, 'VerticalAlignment', 'bottom');
    end
    
    xlabel('WAFrequency(Log2Scaled)', 'FontSize', 22);
    ylabel('RMSPower(Bel)', 'FontSize', 22);
    title(sprintf('1B - Individual Grid: Stimulus %d', stimIdx), 'FontSize', 30);
    grid on;
    axis auto;
    hold off;
    
    % Save plot
    plotFileName = sprintf('WAFrequency_Log2Scaled_RMSPowerB_Grid_Stimuli%d.png', stimIdx);
    saveas(fig, fullfile(plotFolder, plotFileName));
    close(fig);
    
    fprintf('Processed Stimulus %d/%d: %s\n', stimIdx, nStimuli, wavFiles(stimIdx).name);
end

%% --- WRITE EXCEL OUTPUTS ---

% 1) Master Data Excel
masterOutPath = fullfile(folderPath, 'WAFrequency_Log2Scaled_RMSPowerB_MasterData.xlsx');

% Reorder columns to match spec (remove ChunkDuration from main cols, keep it)
masterExport = masterData(:, {'StimuliNumber','EventNumber','WeightedAvgFreq_Hz', ...
    'Log2Scaled_WAFrequency','RMSPower_dB','RMSPower_B','Angle','ChunkDuration_s'});

% Rename for display
masterExport.Properties.VariableNames = {'Stimuli Number', 'Event Number', ...
    'Weighted Average Frequency (Hz)', 'Log2Scaled WAFrequency', ...
    'RMSPower (dB)', 'RMSPower (B)', 'Angle', 'Chunk Duration (s)'};

writetable(masterExport, masterOutPath, 'Sheet', 1);
fprintf('Master Data Excel saved: %s\n', masterOutPath);

% 2) GridCAT Data Excel
gridCATOutPath = fullfile(folderPath, 'WAFrequency_Log2Scaled_RMSPowerB_GridCATData.xlsx');

gridCATExport = gridCATData;
gridCATExport.Properties.VariableNames = {'EventType', 'Event Onset (s)', ...
    'Event Duration (s)', 'Angle'};

% Replace NaN onset with empty (write as blank)
writetable(gridCATExport, gridCATOutPath, 'Sheet', 1);
fprintf('GridCAT Data Excel saved: %s\n', gridCATOutPath);

fprintf('\n=== Processing Complete ===\n');
fprintf('Plots saved to: %s\n', plotFolder);
