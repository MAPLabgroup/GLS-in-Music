function Phase1_UpdateEF_to_EFHold()
% PHASE 1: Update EF to EF_Hold
% Reads tab-delimited .txt event files, extracts rows where eventcode == 3,
% and saves output to 'EventFiles_HOLD' folder.

%% --- Get input folder from user ---
input_folder = uigetdir('', 'Select folder containing event .txt files');
if input_folder == 0
    disp('No folder selected. Exiting.');
    return;
end

%% --- Create output folder ---
parent_dir = fileparts(input_folder);
output_folder = fullfile(parent_dir, 'EventFiles_HOLD');
if ~exist(output_folder, 'dir')
    mkdir(output_folder);
end

%% --- Get all .txt files in the input folder ---
txt_files = dir(fullfile(input_folder, '*.txt'));
if isempty(txt_files)
    disp('No .txt files found in the selected folder.');
    return;
end

%% --- Process each .txt file ---
for i = 1:length(txt_files)
    filename = txt_files(i).name;
    filepath = fullfile(input_folder, filename);

    fprintf('Processing: %s\n', filename);

    % --- Step 1: Parse run_num (A) and subject_num (B) from filename ---
    tokens = regexp(filename, '_run(\d)_(\d{3})', 'tokens');
    if isempty(tokens)
        fprintf('  Skipping: filename does not match expected pattern.\n');
        continue;
    end
    run_num     = tokens{1}{1};  % A (single digit, as string)
    subject_num = tokens{1}{2};  % B (three digits, as string)

    % --- Step 2 & 3: Check if first row contains 'eventcode' ---
    fid = fopen(filepath, 'r');
    first_line = fgetl(fid);
    fclose(fid);

    has_header = contains(lower(first_line), 'eventcode');

    % --- Read the file ---
    opts = delimitedTextImportOptions('Delimiter', '\t');

    if has_header
        % Read with headers
        opts.DataLines       = [2, Inf];
        opts.VariableNamesLine = 1;
        T = readtable(filepath, opts);
    else
        % Read without headers, assign column names manually
        opts.DataLines         = [1, Inf];
        opts.VariableNamesLine = 0;
        T = readtable(filepath, opts);

        % Assign names by position: col1=eventcode, col2=time, col3=stimulusID
        num_cols = width(T);
        col_names = T.Properties.VariableNames;  % default: Var1, Var2, ...
        if num_cols >= 1, col_names{1} = 'eventcode';   end
        if num_cols >= 2, col_names{2} = 'time';        end
        if num_cols >= 3, col_names{3} = 'stimulusID';  end
        T.Properties.VariableNames = col_names;
    end

    % --- Step 4: Extract rows where eventcode == 3 ---
    % Handle eventcode column whether numeric or string
    if isnumeric(T.eventcode)
        mask = T.eventcode == 3;
    else
        mask = strcmp(strtrim(string(T.eventcode)), '3');
    end

    extracted = T(mask, :);

    % --- Step 4b: Skip file if no rows found ---
    if isempty(extracted)
        fprintf('  No rows with eventcode == 3. Skipping output.\n');
        continue;
    end

    % --- Step 4c: Store relevant columns ---
    HOLDOnsetTime    = extracted.time;
    HOLDstimulus_num = extracted.stimulusID;

    % --- Step 5: Build output table with exactly two columns ---
    output_table = table(HOLDOnsetTime, HOLDstimulus_num, ...
        'VariableNames', {'HOLDStimStartTime', 'StimNum'});

    % --- Step 5 (naming): "[B]_R[A]_HOLDEventFile.txt" ---
    out_filename = sprintf('%s_R%s_HOLDEventFile.txt', subject_num, run_num);
    out_filepath = fullfile(output_folder, out_filename);

    % --- Write tab-delimited output ---
    writetable(output_table, out_filepath, ...
        'Delimiter', '\t', 'FileType', 'text');

    fprintf('  Saved: %s\n', out_filename);
end

fprintf('\nDone. Output files saved to:\n  %s\n', output_folder);
end