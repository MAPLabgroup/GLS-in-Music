%% WAFrequency_PeakPower_Analysis.m
% Computes Weighted Average Frequency (Log2-Scaled) and Peak Power (dB/Bel)
% for each 1.2-second chunk of every .wav file in a user-selected folder.
% Outputs:
%   1) WAFrequency_Log2Scaled_PeakPowerB_MasterData.xlsx
%   2) WAFrequency_Log2Scaled_PeakPowerB_GridCATData.xlsx
%   3) WAFrequency_Log2Scaled_PeakPowerB_FullGrids/ folder of .png files

clear; clc; close all;
set(0,'DefaultAxesFontName','Arial')
%% -------------------------------------------------------------------------
% 1. USER INPUT: Select folder containing .wav files
% -------------------------------------------------------------------------
folderPath = uigetdir(pwd, 'Select folder containing .wav files');
if folderPath == 0
    error('No folder selected. Script aborted.');
end

%% -------------------------------------------------------------------------
% 2. GET .wav FILES IN NATURAL NUMERICAL ORDER
% -------------------------------------------------------------------------
wavFiles = dir(fullfile(folderPath, '*.wav'));
if isempty(wavFiles)
    error('No .wav files found in the selected folder.');
end

% Extract leading integers from filenames for natural sort
fileNames = {wavFiles.name};
numericKeys = zeros(1, numel(fileNames));
for k = 1:numel(fileNames)
    tokens = regexp(fileNames{k}, '(\d+)', 'tokens');
    if ~isempty(tokens)
        numericKeys(k) = str2double(tokens{1}{1});
    else
        numericKeys(k) = Inf; % Non-numeric names go last
    end
end
[~, sortIdx] = sort(numericKeys);
wavFiles = wavFiles(sortIdx);

%% -------------------------------------------------------------------------
% 3. PARAMETERS
% -------------------------------------------------------------------------
chunkDuration = 1.2; % seconds

%% -------------------------------------------------------------------------
% 4. INITIALIZE STORAGE
% -------------------------------------------------------------------------
masterData   = {};   % rows for MasterData excel
gridCATData  = {};   % rows for GridCATData excel

% Output folder for PNG grids
gridFolder = fullfile(folderPath, 'WAFrequency_Log2Scaled_PeakPowerB_FullGrids');
if ~exist(gridFolder, 'dir')
    mkdir(gridFolder);
end

%% -------------------------------------------------------------------------
% 5. PROCESS EACH .wav FILE
% -------------------------------------------------------------------------
for stimIdx = 1:numel(wavFiles)
    filePath = fullfile(folderPath, wavFiles(stimIdx).name);
    [audioData, fs] = audioread(filePath);

    % If stereo, convert to mono by averaging channels
    if size(audioData, 2) > 1
        audioData = mean(audioData, 2);
    end

    totalSamples  = length(audioData);
    chunkSamples  = round(chunkDuration * fs);

    % Determine chunk boundaries
    chunkStarts = 1 : chunkSamples : totalSamples;
    numChunks   = numel(chunkStarts);

    % Storage for this stimulus (for grid plotting)
    stimLog2Freq  = zeros(numChunks, 1);
    stimPeakPowerB = zeros(numChunks, 1);
    stimAngles    = zeros(numChunks, 1);
    stimChunkDur  = zeros(numChunks, 1);

    prevPoint = [0, 0]; % previous point for angle calculation

    for chunkIdx = 1:numChunks
        startSample = chunkStarts(chunkIdx);
        endSample   = min(startSample + chunkSamples - 1, totalSamples);
        chunk       = audioData(startSample:endSample);
        N           = length(chunk);
        actualDur   = N / fs;
        stimChunkDur(chunkIdx) = actualDur;

        % --- FFT (remove DC component, index 1) ---
        X   = fft(chunk, N);
        X(1) = 0;  % zero out DC

        % Positive frequencies only (indices 2 to floor(N/2)+1)
        if mod(N,2) == 0
            posIdx = 2 : N/2 + 1;
        else
            posIdx = 2 : (N+1)/2;
        end

        freqAxis = (posIdx - 1) * (fs / N);  % Hz values for positive freqs
        Xpos     = X(posIdx);

        % Power spectrum (magnitude squared, Parseval-consistent)
        powerSpectrum = (abs(Xpos).^2) / N;

        % --- Weighted Average Frequency (Hz) ---
        totalPower = sum(powerSpectrum);
        if totalPower == 0
            waf_hz = 0;
        else
            weights   = powerSpectrum / totalPower;  % normalize
            waf_hz    = sum(freqAxis(:) .* weights(:));
        end

        % Log2-scaled WAFrequency
        if waf_hz > 0
            waf_log2 = log2(waf_hz);
        else
            waf_log2 = 0;
        end

        % --- Peak Power in dB (Parseval Theorem / PSD max) ---
        % Peak power = max of power spectrum; express in dB re 1 (normalized)
        peakPower_linear = max(powerSpectrum);
        if peakPower_linear > 0
            peakPower_dB = 10 * log10(peakPower_linear);
        else
            peakPower_dB = -Inf;
        end

        % Convert dB to Bel (divide by 10)
        peakPower_B = peakPower_dB / 10;

        % Store for plotting
        stimLog2Freq(chunkIdx)   = waf_log2;
        stimPeakPowerB(chunkIdx) = peakPower_B;

        % --- Angle calculation ---
        currentPoint = [waf_log2, peakPower_B];
        dx = currentPoint(1) - prevPoint(1);
        dy = currentPoint(2) - prevPoint(2);
        angleRad = atan2(dy, dx);       % atan2 gives CCW from east
        angleDeg = rad2deg(angleRad);
        if angleDeg < 0
            angleDeg = angleDeg + 360;  % map to [0, 360)
        end
        angleDeg = round(angleDeg, 2);  % round to hundredths
        stimAngles(chunkIdx) = angleDeg;

        % Update previous point
        prevPoint = currentPoint;

        % --- Append to masterData ---
        masterData(end+1, :) = { ...
            stimIdx, ...          % Stimuli Number
            chunkIdx, ...         % Event Number
            waf_hz, ...           % Weighted Average Frequency (Hz)
            waf_log2, ...         % Log2Scaled WAFrequency
            peakPower_dB, ...     % PeakPower (dB)
            peakPower_B, ...      % PeakPower (B)
            angleDeg ...          % Angle
        };

        % --- Append to gridCATData ---
        eventType = sprintf('Music%dOn', stimIdx);
        gridCATData(end+1, :) = { ...
            eventType, ...   % EventType
            '', ...          % Event Onset (s) — left blank for user input
            actualDur, ...   % Event Duration (s)
            angleDeg ...     % Angle
        };
    end

    %% -----------------------------------------------------------------------
    % 6. GENERATE GRID PLOT FOR THIS STIMULUS
    % -----------------------------------------------------------------------
    fig = figure('Visible', 'off');
    hold on;

    % Connect points in sequential order
    plot(stimLog2Freq, stimPeakPowerB, '-k', 'LineWidth', 1.2);

    % Plot points and label with chunk number
    for chunkIdx = 1:numChunks
        plot(stimLog2Freq(chunkIdx), stimPeakPowerB(chunkIdx), 'o', ...
            'MarkerSize', 6, 'MarkerFaceColor', [0.2 0.4 0.8], ...
            'MarkerEdgeColor', 'k');
        text(stimLog2Freq(chunkIdx), stimPeakPowerB(chunkIdx), ...
            sprintf('  %d', chunkIdx), ...
            'FontSize', 9, 'VerticalAlignment', 'bottom');
    end

    xlabel('WAFrequency(Log2Scaled)', 'FontSize', 22);
    ylabel('PeakPower(Bel)', 'FontSize', 22);
    title(sprintf('1A - Individual Grid: Stimulus %d', stimIdx), ...
        'FontSize', 30);
    axis auto;
    grid on;
    hold off;

    % Save PNG
    pngName = sprintf('WAFrequency_Log2Scaled_PeakPowerB_Grid_Stimuli%d.png', stimIdx);
    pngPath = fullfile(gridFolder, pngName);
    exportgraphics(fig, pngPath, 'Resolution', 150);
    close(fig);

    fprintf('Processed stimulus %d (%s): %d chunks\n', stimIdx, wavFiles(stimIdx).name, numChunks);
end

%% -------------------------------------------------------------------------
% 7. WRITE MASTER DATA EXCEL
% -------------------------------------------------------------------------
masterHeaders = {'Stimuli Number', 'Event Number', ...
    'Weighted Average Frequency (Hz)', 'Log2Scaled WAFrequency', ...
    'PeakPower (dB)', 'PeakPower (B)', 'Angle'};

masterTable = cell2table(masterData, 'VariableNames', masterHeaders);
masterExcelPath = fullfile(folderPath, ...
    'WAFrequency_Log2Scaled_PeakPowerB_MasterData.xlsx');
writetable(masterTable, masterExcelPath, 'Sheet', 1);
fprintf('\nMaster data saved to:\n  %s\n', masterExcelPath);

%% -------------------------------------------------------------------------
% 8. WRITE GRIDCAT DATA EXCEL
% -------------------------------------------------------------------------
gridCATHeaders = {'EventType', 'Event Onset (s)', 'Event Duration (s)', 'Angle'};
gridCATTable = cell2table(gridCATData, 'VariableNames', gridCATHeaders);
gridCATExcelPath = fullfile(folderPath, ...
    'WAFrequency_Log2Scaled_PeakPowerB_GridCATData.xlsx');
writetable(gridCATTable, gridCATExcelPath, 'Sheet', 1);
fprintf('GridCAT data saved to:\n  %s\n', gridCATExcelPath);

%% -------------------------------------------------------------------------
% 9. DONE
% -------------------------------------------------------------------------
fprintf('\nAll outputs saved to:\n  %s\n', folderPath);
fprintf('PNG grids saved in:\n  %s\n', gridFolder);
fprintf('\nProcessing complete.\n');
