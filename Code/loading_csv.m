%% COVID-19 Data Loading and Bangladesh Extraction Script
% This script loads COVID-19 data from CSV and extracts Bangladesh data
% for logistic growth modeling

clear; clc; close all;

%% Method 1: Using readtable (Recommended for most CSV files)
try
    % Search for CSV file in local directory, Data directory, or extract from zip
    candidate_files = {'owid-covid-data.csv', fullfile('..', 'Data', 'owid-covid-data.csv'), fullfile('Data', 'owid-covid-data.csv')};
    filename = '';
    for idx = 1:length(candidate_files)
        if exist(candidate_files{idx}, 'file')
            filename = candidate_files{idx};
            break;
        end
    end
    if isempty(filename)
        % Check for zip archive in Data directory
        candidate_zips = {fullfile('..', 'Data', 'owid-covid-data.zip'), fullfile('Data', 'owid-covid-data.zip')};
        for idx = 1:length(candidate_zips)
            if exist(candidate_zips{idx}, 'file')
                fprintf('Unzipping dataset from %s...\n', candidate_zips{idx});
                target_dir = fileparts(candidate_zips{idx});
                unzip(candidate_zips{idx}, target_dir);
                filename = fullfile(target_dir, 'owid-covid-data.csv');
                break;
            end
        end
    end
    if isempty(filename)
        filename = 'owid-covid-data.csv'; % fallback to default
    end
    
    % Read the table
    fprintf('Loading dataset from: %s\n', filename);
    data_table = readtable(filename);
    
    % Display basic information about the dataset
    fprintf('Dataset loaded successfully!\n');
    fprintf('Dataset size: %d rows x %d columns\n', height(data_table), width(data_table));
    fprintf('Column names:\n');
    disp(data_table.Properties.VariableNames);
    
    % Display first few rows to understand structure
    fprintf('\nFirst 5 rows of the dataset:\n');
    disp(head(data_table, 5));
    
catch ME
    fprintf('Error loading file: %s\n', ME.message);
    fprintf('Please check if the file exists and the filename is correct.\n');
end

%% Method 2: Extract Bangladesh Data
% Common column names for COVID data - adjust based on your dataset structure
possible_country_columns = {'Country', 'country', 'Country_Region', 'location', 'Entity'};
possible_date_columns = {'Date', 'date', 'dateRep', 'time', 'Day'};
possible_cases_columns = {'Cases', 'cases', 'total_cases', 'Cumulative_cases', 'cumulative_cases'};

% Find the correct column names in your dataset
country_col = '';
date_col = '';
cases_col = '';

for i = 1:length(possible_country_columns)
    if any(strcmp(data_table.Properties.VariableNames, possible_country_columns{i}))
        country_col = possible_country_columns{i};
        break;
    end
end

for i = 1:length(possible_date_columns)
    if any(strcmp(data_table.Properties.VariableNames, possible_date_columns{i}))
        date_col = possible_date_columns{i};
        break;
    end
end

for i = 1:length(possible_cases_columns)
    if any(strcmp(data_table.Properties.VariableNames, possible_cases_columns{i}))
        cases_col = possible_cases_columns{i};
        break;
    end
end

% Check if we found the required columns
if isempty(country_col) || isempty(date_col) || isempty(cases_col)
    fprintf('\nWarning: Could not automatically identify all required columns.\n');
    fprintf('Please manually specify the column names:\n');
    fprintf('Available columns: ');
    disp(data_table.Properties.VariableNames);
    
    % Manual column specification (uncomment and modify as needed)
    % country_col = 'Country';  % Replace with your country column name
    % date_col = 'Date';        % Replace with your date column name
    % cases_col = 'Cases';      % Replace with your cases column name
else
    fprintf('\nDetected columns:\n');
    fprintf('Country column: %s\n', country_col);
    fprintf('Date column: %s\n', date_col);
    fprintf('Cases column: %s\n', cases_col);
end

%% Extract Bangladesh Data
if ~isempty(country_col) && ~isempty(date_col) && ~isempty(cases_col)
    try
        % Find Bangladesh data (try different possible names)
        bangladesh_names = {'Bangladesh', 'BANGLADESH', 'bangladesh', 'BGD', 'BD'};
        bangladesh_data = table();
        
        for i = 1:length(bangladesh_names)
            bangladesh_indices = strcmp(data_table.(country_col), bangladesh_names{i});
            if any(bangladesh_indices)
                bangladesh_data = data_table(bangladesh_indices, :);
                fprintf('\nBangladesh data found using name: %s\n', bangladesh_names{i});
                break;
            end
        end
        
        if isempty(bangladesh_data)
            fprintf('\nBangladesh data not found. Available countries:\n');
            unique_countries = unique(data_table.(country_col));
            disp(unique_countries);
        else
            % Process Bangladesh data
            fprintf('Bangladesh data extracted: %d records\n', height(bangladesh_data));
            
            % Extract date and cases vectors
            dates = bangladesh_data.(date_col);
            cases = bangladesh_data.(cases_col);
            
            % Convert dates to datetime if they're not already
            if ~isdatetime(dates)
                if isnumeric(dates)
                    % If dates are numeric, assume they're days since start
                    dates = datetime(2020, 1, 1) + days(dates - 1);
                else
                    % Try to parse as datetime
                    dates = datetime(dates, 'InputFormat', 'auto');
                end
            end
            
            % Sort by date
            [dates, sort_idx] = sort(dates);
            cases = cases(sort_idx);
            
            % Remove any NaN or negative values
            valid_idx = ~isnan(cases) & cases >= 0;
            dates = dates(valid_idx);
            cases = cases(valid_idx);
            
            % Create time vector (days since first case)
            time_days = days(dates - dates(1));
            
            % Display summary
            fprintf('\nBangladesh COVID-19 Data Summary:\n');
            fprintf('Date range: %s to %s\n', datestr(dates(1)), datestr(dates(end)));
            fprintf('Total data points: %d\n', length(cases));
            fprintf('Maximum cases: %d\n', max(cases));
            fprintf('Final cases: %d\n', cases(end));
            
            % Quick visualization
            figure('Name', 'Bangladesh COVID-19 Cases');
            plot(dates, cases, 'b-', 'LineWidth', 2);
            xlabel('Date');
            ylabel('Cumulative Cases');
            title('Bangladesh COVID-19 Cumulative Cases');
            grid on;
            
            % Save processed data for modeling
            save('bangladesh_covid_data.mat', 'dates', 'cases', 'time_days');
            fprintf('\nData saved to: bangladesh_covid_data.mat\n');
            
            % Export to CSV for backup
            bangladesh_processed = table(dates, cases, time_days, ...
                'VariableNames', {'Date', 'CumulativeCases', 'TimeDays'});
            writetable(bangladesh_processed, 'bangladesh_covid_processed.csv');
            fprintf('Processed data exported to: bangladesh_covid_processed.csv\n');
            
        end
        
    catch ME
        fprintf('Error processing Bangladesh data: %s\n', ME.message);
    end
end

%% Method 3: Alternative loading method if readtable doesn't work
% Uncomment this section if you have issues with readtable

% try
%     % For simple CSV files with numeric data
%     filename = 'your_covid_data.csv';
%     data_matrix = csvread(filename, 1, 0);  % Skip header row
%     
%     % Read header separately
%     fid = fopen(filename, 'r');
%     header = fgetl(fid);
%     fclose(fid);
%     
%     fprintf('Data loaded as matrix: %d x %d\n', size(data_matrix, 1), size(data_matrix, 2));
%     fprintf('Header: %s\n', header);
%     
% catch ME
%     fprintf('Alternative loading method failed: %s\n', ME.message);
% end

%% Helper function to display unique values in a column


fprintf('\n=== Script completed ===\n');
fprintf('Next steps:\n');
fprintf('1. Check if Bangladesh data was extracted successfully\n');
fprintf('2. Examine the plot to understand the data pattern\n');
fprintf('3. Use the processed data for logistic growth modeling\n');

function display_unique_values(data_table, column_name)
    if any(strcmp(data_table.Properties.VariableNames, column_name))
        unique_vals = unique(data_table.(column_name));
        fprintf('Unique values in %s:\n', column_name);
        if length(unique_vals) > 20
            fprintf('Too many unique values (%d). Showing first 20:\n', length(unique_vals));
            disp(unique_vals(1:20));
        else
            disp(unique_vals);
        end
    else
        fprintf('Column %s not found in dataset.\n', column_name);
    end
end