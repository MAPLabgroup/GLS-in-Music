%% PHASE 3: Sort Onset Data by Subjects
% Reads .txt files from a user-specified folder, parses filenames using a
% regex pattern, and sorts them into per-subject subfolders.

%% --- Input: Request folder from user ---
input_folder = uigetdir('', 'Select the folder containing .txt files');
if input_folder == 0
    error('No folder selected. Exiting.');
end

%% --- Get list of all .txt files in the input folder ---
file_list = dir(fullfile(input_folder, '*.txt'));
if isempty(file_list)
    error('No .txt files found in the selected folder.');
end

%% --- Extract feature_space_desc from the FIRST file (before loop) ---
regex_pattern = '^(.+)_GridCATData_(\d{3})_R\d';

first_filename = file_list(1).name;
% Remove file extension before applying regex
[~, first_name_no_ext, ~] = fileparts(first_filename);
first_tokens = regexp(first_name_no_ext, regex_pattern, 'tokens');

if isempty(first_tokens)
    error('First filename "%s" does not match the expected pattern.', first_filename);
end

feature_space_desc = first_tokens{1}{1};  % e.g., 'SomFeature_desc'

%% --- Create master output folder alongside the input folder ---
parent_folder = fileparts(input_folder);
master_folder_name = [feature_space_desc, '_Final_SubjSorted_GridCAT'];
master_folder_path = fullfile(parent_folder, master_folder_name);

if ~exist(master_folder_path, 'dir')
    mkdir(master_folder_path);
    fprintf('Created master output folder:\n  %s\n\n', master_folder_path);
else
    fprintf('Master output folder already exists:\n  %s\n\n', master_folder_path);
end

%% --- Loop through each .txt file ---
for i = 1:length(file_list)
    filename     = file_list(i).name;
    source_path  = fullfile(input_folder, filename);

    % Strip extension before regex matching
    [~, name_no_ext, ~] = fileparts(filename);

    % Apply regex to extract sort_subject_num
    tokens = regexp(name_no_ext, regex_pattern, 'tokens');

    if isempty(tokens)
        warning('File "%s" does not match the expected pattern. Skipping.', filename);
        continue;
    end

    sort_subject_num = tokens{1}{2};  % Three-digit subject number string

    % --- Build subject subfolder path ---
    subj_folder_name = [feature_space_desc, '_SubjSorted_', sort_subject_num];
    subj_folder_path = fullfile(master_folder_path, subj_folder_name);

    % --- Check if subject folder exists; create if not ---
    if ~exist(subj_folder_path, 'dir')
        mkdir(subj_folder_path);
        fprintf('[New Folder] Created: %s\n', subj_folder_name);
    end

    % --- Copy .txt file into the subject subfolder ---
    dest_path = fullfile(subj_folder_path, filename);
    copyfile(source_path, dest_path);
    fprintf('  -> Copied "%s" to subject folder "%s"\n', filename, subj_folder_name);
end

%% --- Done ---
fprintf('\nPhase 3 complete. All files sorted into:\n  %s\n', master_folder_path);
