%% Sensitivity of the BLER to the delay spread (cyclic prefix vs channel delay)
% Fixed SNR, TDL channel, all numerologies. Takes a few minutes.
clear; close all; clc;

cfg = defaultConfig();
snrdB        = 30;
channelType  = 'TDL';
delaySpreads = [10 25 50 100] * 1e-9;     % s
lastTap      = 12.525;                    % TDL-D largest normalized delay

mus  = cfg.numerologies;
BLER = nan(numel(mus), numel(delaySpreads));

for iD = 1:numel(delaySpreads)
    cfg.delaySpread = delaySpreads(iD);
    for iMu = 1:numel(mus)
        res = simulateLink(mus(iMu), snrdB, channelType, cfg.mcs, cfg);
        BLER(iMu, iD) = res.BLER;
        fprintf('DS=%3.0f ns  mu=%d  BLER=%.3f\n', delaySpreads(iD)*1e9, mus(iMu), res.BLER);
    end
end

% Normal cyclic prefix duration (us) and ratio to the last TDL-D tap
cpUs = 4.6875 ./ 2.^mus(:);
fprintf('\nmu  CP(us)  last tap / CP for DS = %s ns\n', mat2str(delaySpreads*1e9));
for iMu = 1:numel(mus)
    fprintf('%d   %5.2f   %s\n', mus(iMu), cpUs(iMu), ...
        mat2str(round(100 * lastTap * delaySpreads * 1e6 / cpUs(iMu)) / 100));
end

save('results_delay_spread.mat', 'delaySpreads', 'BLER', 'snrdB', 'channelType', 'cfg');
plotDelaySpread(cfg, delaySpreads, BLER, snrdB, channelType);
