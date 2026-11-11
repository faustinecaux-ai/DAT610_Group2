%% Rebuild all the figures of the report from the saved results (no new simulation)
% Needs results_numerology.mat (from main.m) and, for the delay spread figure,
% results_delay_spread.mat (from delaySpreadStudy.m).
clear; close all; clc;

S = load('results_numerology.mat');
plotResults(S.cfg, S.BLER, S.thr, S.lat);

if isfile('results_delay_spread.mat')
    D = load('results_delay_spread.mat');
    plotDelaySpread(D.cfg, D.delaySpreads, D.BLER, D.snrdB, D.channelType);
else
    disp('results_delay_spread.mat not found: run delaySpreadStudy.m for fig_delay_spread.png');
end
disp('Figures written in the current folder (fig_*.png).');
