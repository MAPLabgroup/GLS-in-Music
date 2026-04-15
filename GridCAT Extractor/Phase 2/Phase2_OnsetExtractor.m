%% PHASE 2: Match and Add Onset Times on GridCAT Data

% --- User Inputs ---
alphaFolder = uigetdir('', 'Select the folder containing alpha .txt files');
if alphaFolder == 0, error('No alpha folder selected.'); end

[betaFile, betaPath] = uigetfile('*.txt', 'Select the beta .txt file');
if isequal(betaFile, 0), error('No beta file selected.'); end
betaFullPath = fullfile(betaPath, betaFile);

% --- Output Folder ---
parentDir = fileparts(alphaFolder);
outputFolder = fullfile(parentDir, 'Complete_GridCATOnset');
if ~exist(outputFolder, 'dir'), mkdir(outputFolder); end

% --- Get all .txt files in alpha folder ---
alphaFiles = dir(fullfile(alphaFolder, '*.txt'));
if isempty(alphaFiles), error('No .txt files found in the selected alpha folder.'); end

% --- Process each alpha file ---
for iFile = 1:length(alphaFiles)

    % Step 1: Reload beta from original file path
    betaTable = readtable(betaFullPath, 'FileType', 'text', 'Delimiter', '\t', ...
                          'VariableNamingRule', 'preserve');

    alphaFilename = alphaFiles(iFile).name;

    % Step 2: Parse C and D from filename
    tokens = regexp(alphaFilename, '(\d{3})_R(\d)', 'tokens');
    if isempty(tokens)
        warning('Filename "%s" does not match expected pattern. Skipping.', alphaFilename);
        continue;
    end
    EachSubjectNum = tokens{1}{1};  % e.g., '012'
    EachRunNum     = tokens{1}{2};  % e.g., '1'

    % Read alpha file
    alphaTable = readtable(fullfile(alphaFolder, alphaFilename), ...
                           'FileType', 'text', 'Delimiter', '\t', ...
                           'VariableNamingRule', 'preserve');
    numAlphaRows = height(alphaTable);

    % --- Step 3 & 4: Loop through each row of alpha ---
    numMatched = 0;

    for iRow = 1:numAlphaRows

        % Step 3a-b: Get onset time and stim number
        EachOnsetTime = alphaTable.HOLDStimStartTime(iRow);
        EachStim      = alphaTable.StimNum(iRow);

        % Step 4: Find matching block in beta
        % EventType column values follow "Music[#]On"
        eventTypeCol = betaTable.('EventType');

        % Extract [#] from each EventType value
        stimNums = nan(height(betaTable), 1);
        for k = 1:height(betaTable)
            tok = regexp(eventTypeCol{k}, 'Music(\d+)On', 'tokens');
            if ~isempty(tok)
                stimNums(k) = str2double(tok{1}{1});
            end
        end

        % Find first row where [#] matches EachStim
        matchIdx = find(stimNums == EachStim, 1, 'first');

        if isempty(matchIdx)
            warning('StimNum %d not found in beta EventType column.', EachStim);
            continue;
        end

        % Ensure 5 contiguous rows exist
        blockRows = matchIdx : matchIdx + 4;
        if blockRows(end) > height(betaTable)
            warning('Incomplete block for StimNum %d. Skipping.', EachStim);
            continue;
        end

        % Step 4c: Cascading onset calculation across 5 rows
        betaTable.('Event Onset (s)')(blockRows(1)) = EachOnsetTime;
        for b = 2:5
            prevOnset    = betaTable.('Event Onset (s)')(blockRows(b-1));
            prevDuration = betaTable.('Event Duration (s)')(blockRows(b-1));
            betaTable.('Event Onset (s)')(blockRows(b)) = prevOnset + prevDuration;
        end

        numMatched = numMatched + 1;

    end  % end alpha row loop

    % Step 5: Delete unmatched blocks and reorder matched blocks
    alphaStimList = alphaTable.StimNum;  % ordered list of stims in alpha

    % Re-extract stimNums from (possibly updated) beta
    eventTypeCol = betaTable.('EventType');
    stimNums = nan(height(betaTable), 1);
    for k = 1:height(betaTable)
        tok = regexp(eventTypeCol{k}, 'Music(\d+)On', 'tokens');
        if ~isempty(tok)
            stimNums(k) = str2double(tok{1}{1});
        end
    end

    % Find rows that belong to matched stims; reorder by alpha stim order
    orderedRows = [];
    for s = 1:length(alphaStimList)
        stim = alphaStimList(s);
        firstMatch = find(stimNums == stim, 1, 'first');
        if ~isempty(firstMatch)
            orderedRows = [orderedRows, firstMatch : firstMatch + 4]; %#ok<AGROW>
        end
    end

    numDeletedRows = height(betaTable) - length(orderedRows);
    betaTable = betaTable(orderedRows, :);

    % Step 6: Replace EventType values based on [#]
    for k = 1:height(betaTable)
        tok = regexp(betaTable.('EventType'){k}, 'Music(\d+)On', 'tokens');
        if ~isempty(tok)
            stimVal = str2double(tok{1}{1});
            if stimVal >= 25
                betaTable.('EventType'){k} = 'MusicControl';
            elseif stimVal >= 1 && stimVal <= 24 && mod(stimVal, 2) ~= 0
                betaTable.('EventType'){k} = 'MusicReg';
            elseif stimVal >= 1 && stimVal <= 24 && mod(stimVal, 2) == 0
                betaTable.('EventType'){k} = 'MusicIrreg';
            end
        end
    end

    numOutputRows = height(betaTable);

    % Step 8: Print summary
    fprintf('\n--- Summary for: %s ---\n', alphaFilename);
    fprintf('  Alpha rows read:        %d\n', numAlphaRows);
    fprintf('  Stimuli matched:        %d\n', numMatched);
    fprintf('  Rows written to output: %d\n', numOutputRows);
    fprintf('  Rows deleted from beta: %d\n', numDeletedRows);

    % Step 9: Construct output filename
    [~, betaBaseName, betaExt] = fileparts(betaFile);
    outputFilename = sprintf('%s_%s_R%s%s', betaBaseName, EachSubjectNum, EachRunNum, betaExt);

    % Step 7 & 10: Save without header row
    outputFullPath = fullfile(outputFolder, outputFilename);
    writetable(betaTable, outputFullPath, ...
               'FileType', 'text', 'Delimiter', '\t', 'WriteVariableNames', false);

end  % end alpha file loop

fprintf('\nAll files processed. Output saved to:\n  %s\n', outputFolder);