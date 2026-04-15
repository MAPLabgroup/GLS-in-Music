%% DomFrequency_DomPower_Analysis.m
% Computes dominant frequency (Hz, Log2-scaled) and dominant power (dB, Bel)
% for consecutive 1.2-second chunks of each .wav file in a user-selected folder.
%
% Outputs:
%   1) DomFrequency_Log2Scaled_DomPowerB_MasterData.xlsx
%   2) DomFrequency_Log2Scaled_DomPowerB_GridCATData.xlsx
%   3) Folder: DomFrequency_Log2Scaled_DomPowerB_FullGrids/ (one .png per stimulus)

clc; clear; close all;
set(0,'DefaultAxesFontName','Arial')
%% ---- USER INPUT: Select folder ----------------------------------------
folderPath = uigetdir(pwd, 'Select folder containing .wav files');
if folderPath == 0
    error('No folder selected. Exiting.');
end

%% ---- Gather .wav files in natural numerical order ----------------------
allFiles = dir(fullfile(folderPath, '*.wav'));
if isempty(allFiles)
    error('No .wav files found in the selected folder.');
end

% Natural sort: extract leading integers for ordering
fileNames = {allFiles.name};
tokens = regexp(fileNames, '(\d+)', 'tokens');
leadNums = zeros(1, numel(fileNames));
for k = 1:numel(tokens)
    if ~isempty(tokens{k})
        leadNums(k) = str2double(tokens{k}{1}{1});
    end
end
[~, sortIdx] = sort(leadNums);
allFiles = allFiles(sortIdx);
nStimuli = numel(allFiles);

%% ---- Parameters --------------------------------------------------------
chunkDur = 1.2;   % seconds per chunk

%% ---- Initialise output tables ------------------------------------------
masterRows  = {};   % will become table
gridcatRows = {};

%% ---- Output folder for PNGs -------------------------------------------
pngFolder = fullfile(folderPath, 'DomFrequency_Log2Scaled_DomPowerB_FullGrids');
if ~exist(pngFolder, 'dir')
    mkdir(pngFolder);
end

%% ---- Process each stimulus --------------------------------------------
for stimIdx = 1:nStimuli
    wavPath = fullfile(folderPath, allFiles(stimIdx).name);
    [audioData, fs] = audioread(wavPath);

    % Use mono (average channels if stereo)
    if size(audioData, 2) > 1
        audioData = mean(audioData, 2);
    end

    totalSamples = length(audioData);
    chunkSamples = round(chunkDur * fs);

    % --- Divide into chunks --------------------------------------------
    chunkStart = 1;
    chunkNum   = 0;
    chunkData  = {};   % cell of {samples, actualDuration}

    while chunkStart <= totalSamples
        chunkEnd = min(chunkStart + chunkSamples - 1, totalSamples);
        seg = audioData(chunkStart:chunkEnd);
        actualDur = length(seg) / fs;
        chunkNum = chunkNum + 1;
        chunkData{chunkNum} = struct('samples', seg, 'duration', actualDur); %#ok<AGROW>
        chunkStart = chunkEnd + 1;
    end

    nChunks = numel(chunkData);

    % Storage for this stimulus
    domFreq_Hz   = zeros(nChunks, 1);
    log2Freq     = zeros(nChunks, 1);
    domPow_dB    = zeros(nChunks, 1);
    domPow_B     = zeros(nChunks, 1);
    chunkDurs    = zeros(nChunks, 1);

    % --- Per-chunk DSP -------------------------------------------------
    for ci = 1:nChunks
        seg  = chunkData{ci}.samples;
        N    = length(seg);
        chunkDurs(ci) = chunkData{ci}.duration;

        % Remove DC component
        seg = seg - mean(seg);

        % FFT (positive frequencies only)
        Y     = fft(seg, N);
        nPos  = floor(N/2) + 1;          % number of positive-freq bins
        Y_pos = Y(1:nPos);

        % Normalised magnitude spectrum
        magNorm = abs(Y_pos) / N;
        magNorm(2:end-1) = 2 * magNorm(2:end-1);   % double for two-sided energy

        % Frequency axis
        freqAxis = (0:nPos-1) * (fs / N);

        % Dominant frequency = bin with peak magnitude (skip DC bin 0 Hz)
        [~, peakBin] = max(magNorm(2:end));   % exclude DC (index 1)
        peakBin = peakBin + 1;                % adjust back to 1-based indexing
        domFreq_Hz(ci) = freqAxis(peakBin);

        % Log2 of dominant frequency
        log2Freq(ci) = log2(domFreq_Hz(ci));

        % --- Dominant Power (PSD / Parseval) ---------------------------
        % PSD estimate: |Y|^2 / (N * fs)  [one-sided]
        psd = (abs(Y_pos).^2) / (N * fs);
        psd(2:end-1) = 2 * psd(2:end-1);   % one-sided correction

        % Power at dominant bin (integrate over 1 frequency resolution bin)
        df = fs / N;                        % frequency resolution
        domPower_lin = psd(peakBin) * df;   % W (normalised units)

        % Convert to dB (reference = 1)
        domPow_dB(ci) = 10 * log10(max(domPower_lin, eps));

        % Convert dB to Bel
        domPow_B(ci) = domPow_dB(ci) / 10;
    end

    % --- Angle calculation ---------------------------------------------
    % Points: (log2Freq(ci), domPow_B(ci))
    % Angle relative to previous point; chunk 1 relative to (0,0)
    angles = zeros(nChunks, 1);
    prevX = 0; prevY = 0;
    for ci = 1:nChunks
        dx = log2Freq(ci) - prevX;
        dy = domPow_B(ci)  - prevY;
        ang = atan2d(dy, dx);           % degrees, CCW from east
        if ang < 0
            ang = ang + 360;
        end
        angles(ci) = round(ang, 2);    % round to hundredth
        prevX = log2Freq(ci);
        prevY = domPow_B(ci);
    end

    % --- Accumulate master rows ----------------------------------------
    for ci = 1:nChunks
        masterRows{end+1} = {stimIdx, ci, domFreq_Hz(ci), log2Freq(ci), ...
                             domPow_dB(ci), domPow_B(ci), angles(ci)}; %#ok<AGROW>
    end

    % --- Accumulate GridCAT rows ----------------------------------------
    eventType = sprintf('Music%dOn', stimIdx);
    for ci = 1:nChunks
        gridcatRows{end+1} = {eventType, '', chunkDurs(ci), angles(ci)}; %#ok<AGROW>
    end

    % --- Plot grid -------------------------------------------------------
    fig = figure('Visible', 'off');
    plot(log2Freq, domPow_B, '-o', 'LineWidth', 1.5, 'MarkerSize', 6, ...
         'MarkerFaceColor', 'auto');
    hold on;
    for ci = 1:nChunks
        text(log2Freq(ci), domPow_B(ci), sprintf('  %d', ci), ...
             'FontSize', 9, 'VerticalAlignment', 'bottom');
    end
    xlabel('DomFrequency(Log2Scaled)', 'FontSize', 22);
    ylabel('DomPower(Bel)',                    'FontSize', 22);
    title(sprintf('2A - Individual Grid: Stimulus %d', stimIdx), ...
          'FontSize', 30);
    grid on;
    axis auto;

    pngName = sprintf('DomFrequency_Log2Scaled_DomPowerB_Grid_Stimuli%d.png', stimIdx);
    saveas(fig, fullfile(pngFolder, pngName));
    close(fig);

    fprintf('Processed stimulus %d (%d chunks)\n', stimIdx, nChunks);
end

%% ---- Write Master Excel -----------------------------------------------
masterTable = cell2table( ...
    vertcat(masterRows{:}), ...
    'VariableNames', {'Stimuli_Number', 'Event_Number', ...
                      'Dominant_Frequency_Hz', 'Log2Scaled_DomFrequency', ...
                      'DomPower_dB', 'DomPower_B', 'Angle'});

masterFile = fullfile(folderPath, 'DomFrequency_Log2Scaled_DomPowerB_MasterData.xlsx');
writetable(masterTable, masterFile, 'Sheet', 1);
fprintf('\nMaster Excel saved: %s\n', masterFile);

%% ---- Write GridCAT Excel ----------------------------------------------
gridcatTable = cell2table( ...
    vertcat(gridcatRows{:}), ...
    'VariableNames', {'EventType', 'Event_Onset_s', 'Event_Duration_s', 'Angle'});

gridcatFile = fullfile(folderPath, 'DomFrequency_Log2Scaled_DomPowerB_GridCATData.xlsx');
writetable(gridcatTable, gridcatFile, 'Sheet', 1);
fprintf('GridCAT Excel saved: %s\n', gridcatFile);

fprintf('\nDone. PNGs saved to: %s\n', pngFolder);
