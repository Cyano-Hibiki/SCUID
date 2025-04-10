% This script is used to process the raw data from the MFC setup.
% Author: Jerry Chen
% Date Created: 8/31/2022
% Last Updated: 8/31/2022

% example plotting by hand - leaving this here just in case we need to plot
% something on the fly
figure(30)
hold on
yyaxis left
plot(CNT_Results_NO(120).timeE(:,:)-CNT_Results_NO(120).timeE(1,:), CNT_Results_NO(120).r(:,1:6)./CNT_Results_NO(120).r(800,1:6));
legend('NO Pad 1','Pad 2','Pad 3','Pad 4','Pad 5','Pad 6')
yyaxis right
plot(CNT_Results_NO(120).timeE(:,:)-CNT_Results_NO(120).timeE(1,:), CNT_Results_NO(120).n2oppm(:,:));

figure(31)
hold on
yyaxis left
plot(CNT_Results_NO(118).timeE(:,:)-CNT_Results_NO(118).timeE(1,:), CNT_Results_NO(118).r(:,1:6)./CNT_Results_NO(118).r(800,1:6));
legend('NO Pad 1','Pad 2','Pad 3','Pad 4','Pad 5','Pad 6')
yyaxis right
plot(CNT_Results_NO(118).timeE(:,:)-CNT_Results_NO(118).timeE(1,:), CNT_Results_NO(118).noppm(:,:));

figure(31); 
plot(CNT_Results_NO(116).timeE(:,:)-CNT_Results_NO(116).timeE(1,:), CNT_Results_NO(116).r(:,1:6)./CNT_Results_NO(116).r(800,1:6))
% plot(CNT_Results_NO(116).timeE(:,:)-CNT_Results_NO(116).timeE(1,:), CNT_Results_NO(116).boardtemp(:,:)*100+7000,'r')
% 
% figure(31)
% hold on
% plot(CNT_Results_NO(93).timeE(:,:)-CNT_Results_NO(93).timeE(1,:), CNT_Results_NO(93).r(:,2));
% plot(CNT_Results_NO(93).timeE(:,:)-CNT_Results_NO(93).timeE(1,:), CNT_Results_NO(93).noppm(:,:)*100+6000,'g')
% plot(CNT_Results_NO(93).timeE(:,:)-CNT_Results_NO(93).timeE(1,:), CNT_Results_NO(93).boardtemp(:,:)*100+6000,'r')
% 
% figure(32)
% hold on
% plot(CNT_Results_NO(94).timeE(:,:)-CNT_Results_NO(94).timeE(1,:), CNT_Results_NO(94).r(:,2));
% plot(CNT_Results_NO(94).timeE(:,:)-CNT_Results_NO(94).timeE(1,:), CNT_Results_NO(94).noppm(:,:)*100+7500,'g')
% plot(CNT_Results_NO(94).timeE(:,:)-CNT_Results_NO(94).timeE(1,:), CNT_Results_NO(94).boardtemp(:,:)*100+7000,'r')


clear; close all; clc;

%% Basic Test Information <= MUST CHANGE EVERYTIME!
% -> Test Date 
target_date = datetime("2022-11-23","Format","yyyy-MM-dd");
% -> Target Board & Chip
target_board = 0;
target_chip = 23;
% -- Pads info
num_pads = 12;
target_pads = 1:6;
% -> Gas info
gas_type = "NO";
gas_conc = 23e4;%12.9;
gas_humidity = "RH";
mfc_name = "MFC1";
% -> Time window info
num_runs = 1;
num_steps = 1;      % number of steps per run
run_length = 7000;  % can be calculated from flow files; total run length in seconds, plus 1/2 of the purge in between runs.
step_length = 120;  % seconds for NO exposure
prepurge = 600;     % seconds
min_conc = 0.5;     % Concentration of the lowest step, in [ppm].
sample_rate = 2;    % How many samples per second?
temp_range = [20,30];
target_entry = 116; % <<<<<<<<<<<< CHANGE THIS, this is the row in the struct file we want to evaluate

%% Data Processing Options (Only Change When Needed!)
% Automatically detect rising edge of concentration data.
step_rise_auto_detect = true;
% - Manually input indices of rising edges below! 
rising_edges = [600,1320];  % 09-10-2022
% - Automatically find gas exposure ranges from gas concentration readings.
%   If set to false, also specify the desired sample length in seconds.
auto_expo_range = false;
sample_length = 60;     %changed this 9/28 from 180 to 60
% - Perform Moving Mean on data before normalization & baseline correction
enable_movmean = true;
% - Response sampling range for Resp vs Conc plots.
%   Averaging the response across this number of points centered at sample
%   points.
r_sample_width = 30;

%% Plot Settings (Only Change When Needed!)
% - Figure size
fig_size = [1400,600]; % 21:9 aspect ratio
% - Title Toggle
enable_title = false;
% - Pads not to put on the plots
pads_to_ignore = [11];

%% Initialization
% Setting figure state variable
fig_pos = [200,200,fig_size];

%% Loading Data
load("CNT_Results_NO.mat")
% Finding entry in struct according to given date & chip
% target_entry = get_target_entry(CNT_Results_NO,target_date,target_chip);

entry_result = CNT_Results_NO(target_entry,1);
% Show entry + addinfo field
fprintf("Entry: \t\t%d\n", target_entry);
fprintf("Entry Info: \t%s\n", entry_result.addinfo);

%% Data Processing
% Getting Time Stamps
ts = entry_result.timeE - entry_result.timeE(1);

% Concentration Data Clean-up
% conc_clean = hampel(entry_result.noppm,50);
switch upper(gas_type)
    case "NO"
        conc_clean = entry_result.noppm;
    case "N2O"
        conc_clean = entry_result.n2oppm;
    otherwise
        disp("You might have entered gas type wrong! Please double-check!")
        return
end
% ===== Manual override for 09/27 data (wrong field) =====
% conc_clean = entry_result.n2oppm;

% Replacing all the NaN values with 0
conc_clean(isnan(conc_clean)) = 0;

% Separating the entire data into individual runs
run_ranges = cell(num_runs,1);
for run = 1:num_runs-1
    ts_i = (run-1)*run_length;
    ts_f = ts_i + run_length;
    run_ranges{run} = find(ts >= ts_i & ts <= ts_f);
end
run_ranges{num_runs} = find(ts >= (num_runs-1)*run_length);

%% Auto detecting start of exposure steps
if step_rise_auto_detect
%     stp_i = detect_start(conc_clean,ts,step_length,prepurge);
    conc_grad = gradient(conc_clean, mean(diff(ts)));
    [pks, locs] = findpeaks(conc_grad, "MinPeakHeight", min_conc*0.9, ...
        "MinPeakDistance",(step_length)*sample_rate*1.1, Annotate="peaks");
    stp_i = locs;
else
    % Manually input rising edge index here!
    stp_i = rising_edges;
end
stp_f = zeros(size(stp_i));
if auto_expo_range
    stp_f = detect_end(conc_clean);
else
    for stp = 1:length(stp_i)
        [~, end_ind] = min(abs((ts(stp_i(stp)) + sample_length)-ts));
        stp_f(stp) = end_ind;
    end
end

% Checking total number of steps
% if size(stp_i,1) * size(stp_i,2) ~= num_steps*num_runs
%     disp("Error: failed to get the corretc total number of steps!")
%     return
% end
% 
% % Reshaping these vectors into 3 columns for 3 runs with 5 steps each.
% stp_i = reshape(stp_i,num_steps,num_runs);
% stp_f = reshape(stp_f,num_steps,num_runs);
% 
% % Testing if number of steps matches designed
% if isequal(size(stp_i), [num_steps num_runs])
%     disp("Detected step starting indices matches actual steps!")
% else
%     disp("Detected step starting indices DOES NOT match actual steps!")
%     return
% end

% Performing Moving Mean
r = entry_result.r;
if enable_movmean
    r = movmean(r,15,1);
end

% % Performing Baseline Correction for each run
% r_blc = r;
% for run = 1:num_runs
%     % Time stamps for this run
%     ts_run = ts(run_ranges{run,1});
%     % Indices corresponding to non-exposure
%     % conc_run = conc_clean(run_ranges{run,1});
%     conc_run = conc_clean(run_ranges{run,1});
%     non_expo_indices = find(~conc_run);
%     % baseline correction for each pad
%     for pad = target_pads
%         % Finding baseline by fitting to part of response with no exposure
%         X = ts_run(non_expo_indices);
%         r0_pad = r(stp_i(1,run)-5,pad);
%         r_norm_pad = (r(run_ranges{run,1},pad))/r0_pad;
%         Y = r_norm_pad(non_expo_indices);
% %         Y_mean = mean(Y);
% %         Y_cen = Y - Y_mean;
%         [r_fit_pad, gof] = fit(X,Y,'poly5'); % <--- FEEL FREE TO TWEAK!!!
%         baseline_pad = r_fit_pad(ts_run);
%         % Subtracting baseline from original response data
%         r_blc(run_ranges{run,1},pad) = r_norm_pad - baseline_pad;
%     end
% end

% % Calculating average concentration within each exposure step
% % and response at the sample point within each step (at 3 mins)
% conc_stp_avg = zeros(size(stp_i));
% for run = 1:num_runs
%     for step = 1:num_steps
%         sample_range = stp_i(step,run):stp_f(step,run);
%         conc_stp_avg(step,run) = mean(conc_clean(sample_range));
%     end
% end

% % Finding sample values of baseline-corrected rsponse to be used in the 
% % response vs concentration plot
% r_samp_locs = reshape(stp_f, [num_steps*num_runs,1]);
% r_samples = zeros(length(r_samp_locs),num_pads);

% for point = 1:length(r_samp_locs)
%     loc = r_samp_locs(point);
%     r_samp_range = (loc-r_sample_width/2):(loc+r_sample_width/2);
%     r_samples(point,:) = mean(r_blc(r_samp_range,:));
% end
% % Reshaping the samples into steps x runs x pads
% r_samples= reshape(r_samples, [num_steps num_runs num_pads]);

%% File Name - Part I
% Here is a quick note of how each file name is generated.
% Part 1 - Date, Board, Chip, MFC, Gas, Concentration, Humid/Dry 
%   Format: yyyy-MM-dd_Bx_Cx_MFCx_GAS_xxxppm_Humid
%   Same for all figs generated by running this script once.
% Part 2 - Data Range
%   Specify if the range is the entire test (Full) or one series (Runx)
% Part 3 - Y quantity, X quantity
%   Format: YQuantity1+YQuantity2_XQuantity
% Connect the three parts with underscores: Part1_Part2_Part3
% A general example:
%   "2022-09-12_B0_C14_Full_BoardTemp+BMETemp_Time"
filename1 = strcat(string(target_date,'yyyy-MM-dd'), ...
    "_B",num2str(target_board), "_C", num2str(target_chip), "_P", ...
        num2str(target_pads(1)), "-", num2str(target_pads(end)), ...
        "_", mfc_name, "_", gas_type, "_", ...
        num2str(gas_conc),"ppm_", gas_humidity);

%% Plotting

%% == RH + Board Temp vs Time (Full)
fig_rh_temp = figure('Name','Relative Humidity & Board Temp vs Time');
fig_rh_temp.FileName = filename1 + "_Full" + "_RH+BoardTemp_Time";
fig_rh_temp.Position = fig_pos;
tiledlayout(1,1);
ax_rh_temp = nexttile;
hold(ax_rh_temp,"on");
xlabel(ax_rh_temp,"Time [min]");
legend(ax_rh_temp);
colororder([0.8500 0.3250 0.0980; 0 0.4470 0.7410]) % Orange and Blue
% Temp on left y axis
yyaxis("left");
plot(ax_rh_temp,ts./60,entry_result.boardtemp,DisplayName="Board Temperature");
ylim(temp_range)
ylabel(strcat("Temperature [",char(176),"C]"));
% RH on right y axis
yyaxis("right");
plot(ax_rh_temp,ts./60,entry_result.rh,DisplayName="Relative Humidity");
ylabel("Relative Humidity [%]");
hold(ax_rh_temp,"off"); grid on;
if enable_title
    title(ax_rh_temp,"Relative Humidity & Board Temperature vs Time");
end

%% == Board Temp + BME Temp vs Time (Full)
fig_temp_temp = figure('Name','Board Temp & BME Temp');
fig_temp_temp.FileName = filename1 + "_Full" + "_BoardTemp+BMETemp_Time";
fig_temp_temp.Position = fig_pos;
tiledlayout(1,1);
ax_temp_temp = nexttile;
hold(ax_temp_temp,"on");
xlabel(ax_temp_temp,"Time [min]");
ylabel(strcat("Temperature [",char(176),"C]"));
legend(ax_temp_temp);
plot(ax_temp_temp,ts./60,entry_result.boardtemp,LineWidth=2, ...
    DisplayName="Board Temperature");
plot(ax_temp_temp,ts./60,entry_result.bmetemp,LineWidth=2, ...
    DisplayName="BME Temperature");
hold(ax_temp_temp,"off");
ylim(temp_range); grid on;
if enable_title
    title(ax_temp_temp,"Board Temperature & BME Temperature vs Time");
end

%% == Normalized Signal + Concentration vs Time (Full)
fig_rsp_norm = figure('Name','Normalized Data & Concentration vs Time');
fig_rsp_norm.FileName = filename1 + "_Full" + "_RNorm+Conc_Time";
fig_rsp_norm.Position = fig_pos;
tiledlayout(1,1);
ax_rsp_norm = nexttile;
hold(ax_rsp_norm,"on");
xlabel(ax_rsp_norm,"Time [min]");
% Left y axis for response
yyaxis(ax_rsp_norm,"left");
for pad = target_pads
    if ismember(pad,pads_to_ignore)
        continue
    end
    r0 = r(stp_i(1,1)-5,pad);
    plot(ax_rsp_norm,ts./60,r(:,pad)/r0,...
        DisplayName=strcat("Pad ",num2str(pad)),LineWidth=2);
end
colororder(ax_rsp_norm,'default');
ylabel(ax_rsp_norm,"R/R_0 [-]");
% Right y axis for concentration
yyaxis(ax_rsp_norm,"right");
plot(ax_rsp_norm,ts./60,conc_clean,DisplayName=gas_type+" Concentration", ...
    LineStyle=':',Color="k");
ylabel(ax_rsp_norm,gas_type+" Concentration [ppm]");
legend(ax_rsp_norm,'NumColumns',2);
if enable_title
    title(ax_rsp_norm, strcat("Normalized Sensor Response vs Time (Pads ", ...
        num2str(target_pads(1)), "-", num2str(target_pads(end)), ")"))
end
grid on;
%% == Normalized Signal + Concentration vs Time (One Run,Pick Run 2)
run_pick = 1;
fig_rsp_run_norm = figure('Name', "Normalized Data & Concentration " + ...
    "vs Time - Run " + num2str(run_pick));
fig_rsp_run_norm.FileName = filename1 + "_Run" + num2str(run_pick) + "_RNorm+Conc_Time";
fig_rsp_run_norm.Position = fig_pos;
tiledlayout(1,1);
ax_rsp_run_norm = nexttile;
hold(ax_rsp_run_norm,"on");
xlabel(ax_rsp_run_norm,"Time [min]");
% Left y axis for response
yyaxis(ax_rsp_run_norm,"left");
for pad = target_pads
    if ismember(pad,pads_to_ignore)
        continue
    end
    r0 = r(stp_i(1,run_pick)-5,pad);
    plot(ax_rsp_run_norm,ts(run_ranges{run_pick})./60, ...
        r(run_ranges{run_pick},pad)/r0,...
        DisplayName=strcat("Pad ",num2str(pad)),LineWidth=2);
end
colororder(ax_rsp_run_norm,'default');
ylabel(ax_rsp_run_norm,"R/R_0 [-]");
% Right y axis for concentration
yyaxis(ax_rsp_run_norm,"right");
plot(ax_rsp_run_norm,ts(run_ranges{run_pick})./60, ...
    conc_clean(run_ranges{run_pick}),DisplayName=gas_type+" Concentration", ...
    Color="k",LineStyle=":");
ylabel(ax_rsp_run_norm,gas_type+" Concentration [ppm]");
legend(ax_rsp_run_norm,'NumColumns',2);
if enable_title
    title(ax_rsp_run_norm, strcat("Normalized Sensor Response vs Time (Pads ", ...
        num2str(target_pads(1)), "-", num2str(target_pads(end)), ")"))
end
grid on;
hold(ax_rsp_run_norm,"off")


%% == Baseline Corrected Signal + Concentration vs Time (Each Run)
fig_rsp_blc = gobjects(num_runs,1);
for run = 1:num_runs
    fig_rsp_blc(run) = figure('Name', ...
        strcat("Response vs Time - Run ",num2str(run), ...
        " - Baseline Corrected"));
    fig_rsp_blc(run).FileName = filename1 + "_Run" + num2str(run) + "_RCorr+Conc_Time";
    fig_rsp_blc(run).Position = fig_pos;
    tiledlayout(1,1);
    ax_rsp_blc = nexttile;
    hold(ax_rsp_blc,"on");
    xlabel(ax_rsp_blc,"Time [min]");
    % Left y axis for response
    yyaxis(ax_rsp_blc,"left");    
    for pad = target_pads
        if ismember(pad,pads_to_ignore)
            continue
        end
        plot(ax_rsp_blc,ts(run_ranges{run,1})./60,r_blc(run_ranges{run,1}, pad), ...
            DisplayName=strcat("Pad ",num2str(pad)),LineWidth=2,LineStyle="-");
    end
    colororder(ax_rsp_blc,"default")
    yline(0,'k',HandleVisibility='off')
    ylabel(ax_rsp_blc,"R/R_0 [-]")
%     ylim(ax_rsp_blc, [-2e-3, 7e-3])
    % Right y axis for concentration
    yyaxis(ax_rsp_blc,"right")
    plot(ax_rsp_blc,ts(run_ranges{run})./60,conc_clean(run_ranges{run}), ...
        DisplayName=gas_type+" Concentration",Color="k",LineStyle=":");
%     plot(ax_rsp_blc,ts(run_ranges{run})./60,entry_result.rh(run_ranges{run}), ...
%         DisplayName=gas_type+" Concentration",Color="k",LineStyle=":");
    ylabel(ax_rsp_blc,gas_type+" Concentration [ppm]");
    ylim(ax_rsp_blc, [0, 2])
    legend(ax_rsp_blc,'NumColumns',2)
    hold(ax_rsp_blc,"off"); grid on;
    if enable_title
    title(ax_rsp_blc, strcat("Normalized Sensor Response vs Time ", ...
        "- Run ", num2str(run), " (Pads ", ...
        num2str(target_pads(1)), "-", num2str(target_pads(end)), ")"))
    end
end

%% == Response vs Concentration (Pads 7-12,Each Run)
fig_rvc = gobjects(num_runs,1);
for run = 1:num_runs
    fig_rvc(run) = figure('Name', ...
        strcat("Response vs Concentration - Run ",num2str(run), ...
        " - Baseline Corrected"));
    fig_rvc(run).FileName = filename1 + "_Run" + num2str(run) + "_RCorr_Conc";
    fig_rvc(run).Position = fig_pos;
    tiledlayout(1,1);
    ax_rvc = nexttile;
    hold(ax_rvc,"on");
    xlabel(ax_rvc,"Concentration [ppm]");
    ylabel(ax_rvc,"R/R_0 [-]")
%     ylim(ax_rvc, [-2e-3, 7e-3])
    for pad = target_pads
        if ismember(pad,pads_to_ignore)
            continue
        end
        plot(ax_rvc,conc_stp_avg(:,run), r_samples(:,run,pad),':.',...
            DisplayName=strcat("Pad ",num2str(pad)));
    end
    legend(ax_rvc,'NumColumns',2)
    hold(ax_rvc,"off")
    if enable_title
    title(ax_rvc, strcat("Normalized Sensor Response vs Concentration ", ...
        "- Run ", num2str(run), " (Pads ", ...
        num2str(target_pads(1)), "-", num2str(target_pads(end)), ")"))
    end
end

%% == Overall Plot Format Settings
all_figs = findall(groot,'type','figure');
all_axes = findall(all_figs,'type','axes');
all_lines = findall(all_figs,'Type','Line');
set(all_axes,'FontSize',20, 'box','off')
all_lgds = findall(all_figs,'type','legend');
set(all_lgds,'edgecolor','none', 'location','northeast');
set(all_lines, 'LineWidth',2, 'MarkerSize',36);
% Setting all the y-axes to black
for i = 1:length(all_axes)
    ax = all_axes(i);
%     disp(length(ax.YAxis))
    for j = 1:length(ax.YAxis)
        ax.YAxis(j).Color = 'k';
    end
end
set(all_figs,"WindowState","normal");
grid on;
%% Saving Figures
asksave = input("Save all Figures? [Y/n]: ",'s');
switch lower(asksave)
    case {"y",''}
        plotpath = pwd + "/MFC_Plots";
        datepath = "/"+ string(target_date,'yyyy-MM-dd') + "_" ...
                    + gas_type + "_"+ num2str(gas_conc)+"ppm_"+ gas_humidity;
        chippath = "/Board" + num2str(target_board) + "_Chip" + ...
                    num2str(target_chip) + "_" + gas_humidity + "/";
        savepath = plotpath + datepath + chippath;
        if ~exist(savepath, 'dir')
            disp("There is no such directory:");
            disp(savepath);
            disp("I will create the directory for you.")
            mkdir(savepath)
        end
        for f = 1:length(all_figs)
            this_filename = all_figs(f).FileName;
            if contains(all_figs(f).FileName,".")
                this_filename = "/Entry_" + num2str(target_entry) + ...
                    "_" + this_filename + ".png";
            end
            disp("Saving: " + this_filename);
            saveas(all_figs(f),fullfile(savepath, this_filename),'png');
        end
        disp("Figures saved successfully under:")
        disp(savepath)
        set(all_figs,"WindowState","normal");
    otherwise
        set(all_figs,"WindowState","normal");
%         set(all_figs,"WindowStyle","docked")
end       

%% Custom Functions
% Find the desired entry in the struct
function target_entry = get_target_entry(Data_Struct,target_date,target_chip)
    for entry = 1:length(Data_Struct)
        if isempty(Data_Struct(entry,1).testdateM)
            continue
        elseif contains(datestr(Data_Struct(entry,1).testdateM),datestr(target_date))
            if isequal(Data_Struct(entry,1).chip, target_chip)
                target_entry = entry;
                break
            else
                continue
            end
        end
    end
end

% Detect Start of Exposure
function start_indices = detect_start(conc, time_stamp, step_length, prepurge)
    start_indices = [];
    for i = 16:length(conc)-15
        if conc(i) ~= 0
            if conc(i-15:i-1) ==0
                if conc(i+1:i+15) ~= 0
                    start_indices = [start_indices; i];
                end
            end
        end
    end
%     disp('Found the start of exposures at the following indices:');
%     disp(start_indices)
    % Cleaning off indices that are too close to each other. This usually
    % happens at the beginning of each exposure step where the MFCs would
    % over-react when openning up and then close for a brief while within
    % the supposed exposure period. It looks like a hole/well/crack within
    % each exposure step on the plot.
    % First, calculate the differences in seconds between each consecutive
    % marked indices.
    start_times = time_stamp(start_indices);
    separations = diff(start_times);
%     disp('Time separations between detected step starting points:')
%     disp(separations)
    start_indices(find(separations<step_length)+1) = [];
%     disp("Fixed start indices:")
%     disp(start_indices)
%     disp(start_times)
    start_indices(start_times < prepurge) = [];
end

% Detect End of Exposure
function end_indices = detect_end(conc)
    end_indices = [];
    for i = 16:length(conc)-15
        if conc(i) == 0
%             if noppm(i+1:i+15) ==0
                if conc(i-15:i-1) ~= 0
                    end_indices = [end_indices; i];
                end
%             end
        end
    end
    disp('Found the end of exposures at the following indices:');
    disp(end_indices)
end