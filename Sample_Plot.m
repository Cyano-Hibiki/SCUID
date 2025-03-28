clear; close all; clc;

% Creating a new figure
fig_sin = figure();
% Getting axis handle
tiledlayout(1,1)
ax1 = nexttile;
hold(ax1, "on")
% Plotting the data
x = 0:pi/100:2*pi;
plot(ax1, x, sin(x), LineWidth=2, DisplayName="Emphasized Data")
% Removing box around axis
box off
% Setting font size
fontsize(ax1, 20, "points")
% Labelling x and y axes
xlabel("Meaningful X [Unit]")
ylabel("Meaningful Y [Unit]")
% Generating legend box
legend(ax1)
% Removing box around legend
legend boxoff

% To add more data to the same axis
plot(ax1, x, cos(x), LineWidth=1, DisplayName="Other Data")

% To add a vertical line with label on the axis
% Note that you may have to manually assign font size here
xline(ax1, pi,'-','$\pi$', DisplayName='A Vertical Line',FontSize=20, ...
    Interpreter='latex');
% To not show a vertical line it in legend box
xline(ax1, pi/2, ':', '$0.5 \pi$', HandleVisibility='off', FontSize=20, ...
    Interpreter='latex');

% Saving figure to computer
filename = "Sample_Plot";
saveas(fig_sin, filename, "png");
