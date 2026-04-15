%% DomFrequency_Log2Scaled_RMSPowerB Analysis Script
% Parametrizes, computes, and produces outputs for dominant frequency
% and RMS power from .wav files divided into 1.2-second chunks.

clear; clc; close all;
set(0,'DefaultAxesFontName','Arial')
%% --- USER INPUT ---
folderPath = uigetdir(pwd, 'Select folder containing .wav files');
if folderPath == 0
    error('No folder selected. Exiting.');
end

%% --- NATURAL SORT HELPER ---
% Get all .wav files and sort in natural numerical order
wavFiles = dir(fullfile(folderPath, '*.wav'));
fileNames = {wavFiles.name};

% Extract leading numbers for natural sort
numericKeys = zeros(1, numel(fileNames));
for i = 1:numel(fileNames)
    tokens = regexp(fileNames{i}, '(\d+)', 'tokens');
    if ~isempty(tokens)
        numericKeys(i) = str2double(tokens{1}{1});
    else
        numericKeys(i) = Inf;
    end
end
[~, sortIdx] = sort(numericKeys);
wavFiles = wavFiles(sortIdx);

if isempty(wavFiles)
    error('No .wav files found in the selected folder.');
end

%% --- PARAMETERS ---
chunkDuration = 1.2; % seconds

%% --- STORAGE ---
masterData   = {};  % rows for MasterData excel
gridCATData  = {};  % rows for GridCATData excel

% Output folder for PNGs
pngFolder = fullfile(folderPath, 'DomFrequency_Log2Scaled_RMSPowerB_FullGrids');
if ~exist(pngFolder, 'dir')
    mkdir(pngFolder);
end

%% --- MAIN PROCESSING LOOP ---
for stimIdx = 1:numel(wavFiles)
    filePath = fullfile(folderPath, wavFiles(stimIdx).name);
    [audioData, fs] = audioread(filePath);

    % Convert to mono if stereo
    if size(audioData, 2) > 1
        audioData = mean(audioData, 2);
    end

    totalSamples   = length(audioData);
    chunkSamples   = round(chunkDuration * fs);
    numChunks      = ceil(totalSamples / chunkSamples);

    % Per-stimulus storage for grid plotting
    log2Freq_all  = zeros(1, numChunks);
    rmsPowerB_all = zeros(1, numChunks);
    angle_all     = zeros(1, numChunks);
    chunkDur_all  = zeros(1, numChunks);

    prevPoint = [0, 0];  % origin for first chunk angle reference

    for chunkIdx = 1:numChunks
        startSample = (chunkIdx - 1) * chunkSamples + 1;
        endSample   = min(chunkIdx * chunkSamples, totalSamples);
        chunk       = audioData(startSample:endSample);

        actualChunkDur = length(chunk) / fs;
        N = length(chunk);

        % --- FFT (exclude DC component) ---
        Y = fft(chunk);
        Y(1) = 0;  % zero out DC component

        % Positive frequencies only
        halfN     = floor(N/2) + 1;
        posFreqs  = (0:halfN-1) * (fs / N);
        posMag    = abs(Y(1:halfN));

        % Dominant frequency: peak magnitude in positive spectrum
        [~, peakIdx]    = max(posMag);
        domFreq_Hz      = posFreqs(peakIdx);
        log2DomFreq     = log2(domFreq_Hz);

        % --- RMS Power in frequency domain (Parseval's Theorem / PSD) ---
        % Full FFT magnitudes (excluding DC already zeroed)
        fullMag     = abs(Y);
        rmsPower_linear = sqrt(sum(fullMag.^2) / N^2);  % RMS amplitude

        % Convert to dB (reference: 1.0 amplitude)
        if rmsPower_linear > 0
            rmsPower_dB = 20 * log10(rmsPower_linear);
        else
            rmsPower_dB = -Inf;
        end

        rmsPower_B = rmsPower_dB / 10;  % dB to Bel

        % --- Angle Calculation ---
        currentPoint = [log2DomFreq, rmsPower_B];
        dx = currentPoint(1) - prevPoint(1);
        dy = currentPoint(2) - prevPoint(2);
        angleRad = atan2(dy, dx);
        angleDeg = rad2deg(angleRad);

        % Convert to 0-360 counterclockwise (atan2 already gives CCW from east)
        if angleDeg < 0
            angleDeg = angleDeg + 360;
        end
        angleDeg = round(angleDeg, 2);

        % Store
        log2Freq_all(chunkIdx)  = log2DomFreq;
        rmsPowerB_all(chunkIdx) = rmsPower_B;
        angle_all(chunkIdx)     = angleDeg;
        chunkDur_all(chunkIdx)  = actualChunkDur;

        % MasterData row
        masterData(end+1, :) = {stimIdx, chunkIdx, domFreq_Hz, log2DomFreq, ...
                                  rmsPower_dB, rmsPower_B, angleDeg};

        % GridCATData row
        eventType = sprintf('Music%dOn', stimIdx);
        gridCATData(end+1, :) = {eventType, '', actualChunkDur, angleDeg};

        % Update previous point for next chunk's angle
        prevPoint = currentPoint;
    end

    %% --- PLOT GRID ---
    fig = figure('Visible', 'off');
    plot(log2Freq_all, rmsPowerB_all, '-o', 'LineWidth', 1.5, ...
         'MarkerFaceColor', 'b', 'MarkerEdgeColor', 'b', 'MarkerSize', 6);
    hold on;

    % Label each point with chunk number
    for chunkIdx = 1:numChunks
        text(log2Freq_all(chunkIdx), rmsPowerB_all(chunkIdx), ...
             sprintf('  %d', chunkIdx), ...
             'FontSize', 9, 'VerticalAlignment', 'bottom');
    end

    xlabel('DomFrequency(Log2Scaled)', 'FontSize', 22);
    ylabel('RMSPower(Bel)', 'FontSize', 22);
    title(sprintf('2B - Individual Grid: Stimulus %d', stimIdx), ...
          'FontSize', 30);
    grid on;
    axis auto;

    pngName = sprintf('DomFrequency_Log2Scaled_RMSPowerB_Grid_Stimuli%d.png', stimIdx);
    pngPath = fullfile(pngFolder, pngName);
    exportgraphics(fig, pngPath, 'Resolution', 150);
    close(fig);

    fprintf('Processed Stimulus %d: %d chunks\n', stimIdx, numChunks);
end

%% --- WRITE MASTER DATA EXCEL ---
masterHeaders = {'Stimuli Number', 'Event Number', 'Dominant Frequency (Hz)', ...
                 'Log2Scaled DomFrequency', 'RMSPower (dB)', 'RMSPower (B)', 'Angle'};
masterTable = cell2table(masterData, 'VariableNames', masterHeaders);

masterExcelPath = fullfile(folderPath, 'DomFrequency_Log2Scaled_RMSPowerB_MasterData.xlsx');
writetable(masterTable, masterExcelPath, 'Sheet', 1);
fprintf('Master data saved to: %s\n', masterExcelPath);

%% --- WRITE GRIDCAT DATA EXCEL ---
gridCATHeaders = {'EventType', 'Event Onset (s)', 'Event Duration (s)', 'Angle'};
gridCATTable = cell2table(gridCATData, 'VariableNames', gridCATHeaders);

gridCATExcelPath = fullfile(folderPath, 'DomFrequency_Log2Scaled_RMSPowerB_GridCATData.xlsx');
writetable(gridCATTable, gridCATExcelPath, 'Sheet', 1);
fprintf('GridCAT data saved to: %s\n', gridCATExcelPath);

fprintf('\nAll processing complete.\n');
fprintf('PNG grids saved to: %s\n', pngFolder);
