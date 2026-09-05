%% Phase 2: COVID-19 Logistic Growth Modeling for Bangladesh
% This script continues from Phase 1 data loading and implements
% logistic growth model with parameter estimation and visualization

% NOTE: Do NOT use clear/clc here as it will delete Phase 1 variables!
% If running standalone, uncomment the line below:
% clear; clc; close all;

%% Load preprocessed Bangladesh data from Phase 1
% First check if variables already exist in workspace (continuous execution)
if exist('dates', 'var') && exist('cases', 'var') && exist('time_days', 'var')
    fprintf('✅ Using Bangladesh data from Phase 1 (already in workspace)\n');
    fprintf('Data points: %d\n', length(cases));
    fprintf('Date range: %s to %s\n', datestr(dates(1)), datestr(dates(end)));
else
    % If not in workspace, try loading from saved .mat or benchmark .csv
    loaded_flag = false;
    mat_candidates = {'bangladesh_covid_data.mat', fullfile('..', 'Data', 'bangladesh_covid_data.mat'), fullfile('Data', 'bangladesh_covid_data.mat')};
    for idx = 1:length(mat_candidates)
        if exist(mat_candidates{idx}, 'file')
            load(mat_candidates{idx});
            fprintf('✅ Bangladesh COVID-19 data loaded from: %s\n', mat_candidates{idx});
            loaded_flag = true;
            break;
        end
    end
    
    if ~loaded_flag
        csv_candidates = {'bangladesh_covid_processed.csv', fullfile('..', 'Data', 'bangladesh_covid_processed.csv'), fullfile('Data', 'bangladesh_covid_processed.csv')};
        for idx = 1:length(csv_candidates)
            if exist(csv_candidates{idx}, 'file')
                t_proc = readtable(csv_candidates{idx});
                dates = datetime(t_proc.Date);
                cases = t_proc.CumulativeCases;
                time_days = t_proc.TimeDays;
                fprintf('✅ Bangladesh COVID-19 benchmark loaded from: %s\n', csv_candidates{idx});
                loaded_flag = true;
                break;
            end
        end
    end
    
    if loaded_flag
        fprintf('Data points: %d\n', length(cases));
        fprintf('Date range: %s to %s\n', datestr(dates(1)), datestr(dates(end)));
    else
        error('❌ Error: Bangladesh data not found. Please run Phase 1 script or provide bangladesh_covid_processed.csv!');
    end
end

%% Step 2: Define Logistic Growth Model Function
% The logistic model: N(t) = K / (1 + exp(-r*(t-t0)))
% where: K = carrying capacity, r = growth rate, t0 = inflection point

logistic_model = @(params, t) params(1) ./ (1 + exp(-params(2) * (t - params(3))));

fprintf('\n✅ Logistic model function defined\n');
fprintf('Model: N(t) = K / (1 + exp(-r*(t-t0)))\n');

%% Step 3: Parameter Estimation using Curve Fitting

% Prepare data for fitting
t_data = time_days;  % Time in days since first case
N_data = cases;      % Cumulative cases

% Remove any zero cases to avoid fitting issues
nonzero_idx = N_data > 0;
t_fit = t_data(nonzero_idx);
N_fit = N_data(nonzero_idx);

fprintf('\n📊 Preparing data for curve fitting...\n');
fprintf('Using %d data points for fitting\n', length(N_fit));

% Initial parameter estimates
K_init = max(N_fit) * 2;        % Carrying capacity (twice the max observed)
r_init = 0.1;                   % Growth rate
t0_init = t_fit(round(end/2));  % Inflection point (middle of time range)

initial_params = [K_init, r_init, t0_init];
fprintf('Initial parameter estimates:\n');
fprintf('K (carrying capacity): %.0f\n', K_init);
fprintf('r (growth rate): %.4f\n', r_init);
fprintf('t0 (inflection point): %.1f days\n', t0_init);

% Parameter bounds (optional but recommended)
lower_bounds = [max(N_fit), 0.01, 0];           % K >= max_cases, r > 0, t0 >= 0
upper_bounds = [max(N_fit)*10, 1, max(t_fit)];  % Reasonable upper limits

% Curve fitting options
options = optimoptions('lsqcurvefit', 'Display', 'iter', 'MaxIterations', 1000);

try
    % Perform curve fitting
    fprintf('\n🔄 Performing curve fitting...\n');
    [fitted_params, resnorm, residual, exitflag] = lsqcurvefit(...
        logistic_model, initial_params, t_fit, N_fit, lower_bounds, upper_bounds, options);
    
    if exitflag > 0
        fprintf('✅ Curve fitting completed successfully!\n');
    else
        fprintf('⚠️ Curve fitting completed with warnings (exitflag: %d)\n', exitflag);
    end
    
    % Extract fitted parameters
    K_fitted = fitted_params(1);
    r_fitted = fitted_params(2);
    t0_fitted = fitted_params(3);
    
    fprintf('\n📈 Fitted Parameters:\n');
    fprintf('K (carrying capacity): %.0f cases\n', K_fitted);
    fprintf('r (growth rate): %.4f per day\n', r_fitted);
    fprintf('t0 (inflection point): %.1f days\n', t0_fitted);
    
catch ME
    fprintf('❌ Error in curve fitting: %s\n', ME.message);
    fprintf('Using alternative optimization method...\n');
    
    % Alternative: Use fminsearch for robust fitting
    objective_function = @(params) sum((logistic_model(params, t_fit) - N_fit).^2);
    fitted_params = fminsearch(objective_function, initial_params);
    
    K_fitted = fitted_params(1);
    r_fitted = fitted_params(2);
    t0_fitted = fitted_params(3);
    
    fprintf('✅ Alternative fitting completed!\n');
    fprintf('Fitted Parameters:\n');
    fprintf('K (carrying capacity): %.0f cases\n', K_fitted);
    fprintf('r (growth rate): %.4f per day\n', r_fitted);
    fprintf('t0 (inflection point): %.1f days\n', t0_fitted);
end

%% Step 4: Model Evaluation and Predictions

% Generate smooth curve for plotting
t_smooth = linspace(0, max(t_data)*1.2, 1000);
N_predicted_smooth = logistic_model(fitted_params, t_smooth);

% Predictions for actual data points
N_predicted = logistic_model(fitted_params, t_data);

% Calculate model performance metrics
residuals = N_data - N_predicted;
rmse = sqrt(mean(residuals.^2));
mae = mean(abs(residuals));
r_squared = 1 - sum(residuals.^2) / sum((N_data - mean(N_data)).^2);

fprintf('\n📊 Model Performance Metrics:\n');
fprintf('RMSE (Root Mean Square Error): %.2f\n', rmse);
fprintf('MAE (Mean Absolute Error): %.2f\n', mae);
fprintf('R² (Coefficient of Determination): %.4f\n', r_squared);

% Calculate key dates
inflection_date = dates(1) + days(t0_fitted);
peak_growth_rate_date = inflection_date;  % Peak growth occurs at inflection point

% Find when model reaches 95% of carrying capacity
idx_95 = find(N_predicted_smooth >= 0.95 * K_fitted, 1);
if ~isempty(idx_95)
    saturation_time = t_smooth(idx_95);
    saturation_date = dates(1) + days(saturation_time);
else
    saturation_date = "Not reached in prediction period";
end

fprintf('\n📅 Key Dates and Insights:\n');
fprintf('Inflection point (peak growth): %s\n', datestr(inflection_date));
fprintf('Expected saturation (95%% of K): %s\n', datestr(saturation_date));
fprintf('Maximum theoretical cases: %.0f\n', K_fitted);

%% Step 5: Comprehensive Visualization

% Create comprehensive plot
figure('Position', [100, 100, 1200, 800]);

% Main plot: Actual vs Predicted
subplot(2, 2, 1);
plot(dates, N_data, 'bo-', 'MarkerSize', 4, 'LineWidth', 1.5, 'DisplayName', 'Actual Data');
hold on;
plot(dates(1) + days(t_smooth), N_predicted_smooth, 'r-', 'LineWidth', 2, 'DisplayName', 'Logistic Model');
plot(inflection_date, logistic_model(fitted_params, t0_fitted), 'go', 'MarkerSize', 10, 'LineWidth', 3, 'DisplayName', 'Inflection Point');
xlabel('Date');
ylabel('Cumulative Cases');
title('Bangladesh COVID-19: Actual vs Logistic Model');
legend('Location', 'southeast');
grid on;
xlim([dates(1) - days(10), dates(1) + days(max(t_smooth))]);

% Residuals plot
subplot(2, 2, 2);
plot(dates, residuals, 'ko-', 'MarkerSize', 4);
hold on;
yline(0, 'r--', 'LineWidth', 1);
xlabel('Date');
ylabel('Residuals (Actual - Predicted)');
title('Model Residuals');
grid on;

% Growth rate plot
subplot(2, 2, 3);
% Calculate daily growth rate from logistic model
daily_growth = r_fitted * N_predicted_smooth .* (1 - N_predicted_smooth/K_fitted);
plot(dates(1) + days(t_smooth), daily_growth, 'g-', 'LineWidth', 2);
hold on;
plot(inflection_date, max(daily_growth), 'ro', 'MarkerSize', 10, 'LineWidth', 3);
xlabel('Date');
ylabel('Daily New Cases (from model)');
title('Predicted Daily Growth Rate');
grid on;

% Parameter sensitivity analysis
subplot(2, 2, 4);
t_test = linspace(0, max(t_data)*1.2, 500);
plot(t_test, logistic_model([K_fitted, r_fitted, t0_fitted], t_test), 'r-', 'LineWidth', 2, 'DisplayName', 'Best Fit');
hold on;
plot(t_test, logistic_model([K_fitted*0.8, r_fitted, t0_fitted], t_test), 'b--', 'LineWidth', 1.5, 'DisplayName', 'K -20%');
plot(t_test, logistic_model([K_fitted*1.2, r_fitted, t0_fitted], t_test), 'g--', 'LineWidth', 1.5, 'DisplayName', 'K +20%');
xlabel('Time (days)');
ylabel('Cumulative Cases');
title('Parameter Sensitivity Analysis');
legend('Location', 'southeast');
grid on;

sgtitle('COVID-19 Logistic Growth Model Analysis for Bangladesh', 'FontSize', 14, 'FontWeight', 'bold');

%% Step 6: Save Results and Export Data

% Save all results
results = struct();
results.fitted_params = fitted_params;
results.K = K_fitted;
results.r = r_fitted;
results.t0 = t0_fitted;
results.rmse = rmse;
results.mae = mae;
results.r_squared = r_squared;
results.inflection_date = inflection_date;
results.saturation_date = saturation_date;
results.time_days = t_data;
results.actual_cases = N_data;
results.predicted_cases = N_predicted;
results.dates = dates;

save('bangladesh_logistic_results.mat', 'results');
fprintf('\n💾 Results saved to: bangladesh_logistic_results.mat\n');

% Export results to CSV
results_table = table(dates, N_data, N_predicted, residuals, ...
    'VariableNames', {'Date', 'ActualCases', 'PredictedCases', 'Residuals'});
writetable(results_table, 'bangladesh_logistic_predictions.csv');
fprintf('📄 Predictions exported to: bangladesh_logistic_predictions.csv\n');

% Export model parameters
params_table = table({'K'; 'r'; 't0'}, [K_fitted; r_fitted; t0_fitted], ...
    {'Carrying Capacity'; 'Growth Rate'; 'Inflection Point'}, ...
    'VariableNames', {'Parameter', 'Value', 'Description'});
writetable(params_table, 'bangladesh_model_parameters.csv');
fprintf('📊 Parameters exported to: bangladesh_model_parameters.csv\n');

%% Step 7: Generate Summary Report

fprintf('\n');
fprintf(repmat('=', 1, 60));
fprintf('\n');
fprintf('📋 PHASE 2 COMPLETION SUMMARY\n');
fprintf(repmat('=', 1, 60));
fprintf('\n');
fprintf('✅ Logistic growth model implemented\n');
fprintf('✅ Parameters estimated using curve fitting\n');
fprintf('✅ Model performance evaluated\n');
fprintf('✅ Comprehensive visualizations created\n');
fprintf('✅ Results saved and exported\n');
fprintf('\n📈 MODEL QUALITY:\n');
if r_squared > 0.95
    fprintf('🟢 Excellent fit (R² = %.4f)\n', r_squared);
elseif r_squared > 0.90
    fprintf('🟡 Good fit (R² = %.4f)\n', r_squared);
elseif r_squared > 0.80
    fprintf('🟠 Moderate fit (R² = %.4f)\n', r_squared);
else
    fprintf('🔴 Poor fit (R² = %.4f) - Consider alternative models\n', r_squared);
end

fprintf('\n🎯 NEXT STEPS (Phase 3 - Analysis):\n');
fprintf('1. Interpret the fitted parameters\n');
fprintf('2. Analyze model limitations\n');
fprintf('3. Compare with actual pandemic progression\n');
fprintf('4. Prepare final report\n');

fprintf('\n📁 FILES CREATED:\n');
fprintf('- bangladesh_logistic_results.mat\n');
fprintf('- bangladesh_logistic_predictions.csv\n');
fprintf('- bangladesh_model_parameters.csv\n');
fprintf('- Comprehensive analysis plots\n');

fprintf('\n');
fprintf(repmat('=', 1, 60));
fprintf('\n');
fprintf('Phase 2 completed successfully! 🎉\n');
fprintf(repmat('=', 1, 60));
fprintf('\n');