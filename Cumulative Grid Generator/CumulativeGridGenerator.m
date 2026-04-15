% Cumulative Grid Generator
% Plots 36 routes of 5 points each from a tab-delimited .txt file
set(0,'DefaultAxesFontName','Arial')
%% --- User Inputs ---
[fname, fpath] = uigetfile('*.txt', 'Select your data file');
if isequal(fname, 0)
    error('No file selected. Exiting.');
end
filepath = fullfile(fpath, fname);

fig_title   = input('What is the title of your figure? ', 's');
xaxis_title = input('What is the title of your x-axis? ', 's');
yaxis_title = input('What is the title of your y-axis? ', 's');

%% --- Load Data ---
data = readtable(filepath, 'FileType', 'text', 'Delimiter', '\t', ...
                 'HeaderLines', 0, 'VariableNamingRule', 'preserve');
% Row 1 is the header (already handled by readtable); data rows begin at row 2 by default.

%% --- Style Definitions ---
colors = [
    68,  119, 170;   % #4477AA
    238, 102, 119;   % #EE6677
    34,  136,  51;   % #228833
    204, 187,  68;   % #CCBB44
    102, 204, 238;   % #66CCEE
    170,  51, 119;   % #AA3377
] / 255;

markers = {'o', 's', '^', 'd', 'p', 'h'};

num_colors  = size(colors, 1);   % 6
num_markers = numel(markers);    % 6
% Cycling: all 6 markers within each color before moving to next color.
% Route r (1-indexed): color = ceil(r/6), marker = mod(r-1,6)+1

%% --- Figure Setup ---
fig = figure('Units', 'inches', 'Position', [1 1 12 8]);
ax  = axes(fig);
hold(ax, 'on');

num_routes = 36;
rows_per_route = 5;
legend_handles = gobjects(num_routes, 1);
legend_labels  = cell(num_routes, 1);

%% --- Plot Each Route ---
for r = 1:num_routes
    row_start = (r - 1) * rows_per_route + 1;
    row_end   = row_start + rows_per_route - 1;

    route_data = data(row_start:row_end, :);

    % Extract values
    S_num = route_data{1, 'Stimuli Number'};   % scalar from first row
    x_vals = route_data{:, 4};                  % 4th column
    y_vals = route_data{:, 6};                  % 6th column

    % Determine color and marker for this route
    color_idx  = ceil(r / num_markers);           % color changes every 6 routes
    marker_idx = mod(r - 1, num_markers) + 1;

    c = colors(color_idx, :);
    m = markers{marker_idx};

    % Plot connecting line
   h = plot(ax, x_vals, y_vals, ...
         'LineStyle', '-', ...
         'LineWidth', 1, ...
         'Color', c, ...
         'Marker', m, ...
         'MarkerSize', 6, ...
         'MarkerFaceColor', c, ...
         'MarkerEdgeColor', c, ...
         'DisplayName', sprintf('S%g', S_num));

    legend_handles(r) = h;
    legend_labels{r}  = sprintf('S%g', S_num);
end

%% --- Axes Labels & Title ---
title(ax, fig_title, 'FontSize', 36, 'FontWeight', 'bold');
xlabel(ax, xaxis_title, 'FontSize', 28);
ylabel(ax, yaxis_title, 'FontSize', 28);
box(ax, 'on');
grid(ax, 'on');

%% --- Legend (outside right) ---
lgd = legend(ax, legend_handles, legend_labels, ...
             'Location', 'eastoutside', ...
             'FontSize', 12);
lgd.Box = 'on';

%% --- Save Figure ---
output_name = sprintf('%s_cumulativegrid.png', fig_title);
output_path = fullfile(fpath, output_name);

exportgraphics(fig, output_path, 'Resolution', 300);
fprintf('Figure saved to: %s\n', output_path);