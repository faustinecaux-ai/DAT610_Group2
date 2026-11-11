%% 5G NR numerology: throughput, latency and BLER for a pedestrian video call
% Required files in the same folder:
%   defaultConfig.m, cqiToMcs.m, simulateLink.m, computeThroughput.m,
%   computeLatency.m, plotResults.m
clear; close all; clc;

%% Configuration
cfg = defaultConfig();

quickTest = false;      % true = quick test (few points, few slots)
runSimulation = true;   % false = reuse BLER from results_numerology.mat (post-processing only)
if quickTest
    cfg.snrRange            = 0:10:30;
    cfg.nRealizations       = 4;
    cfg.slotsPerRealization = 5;
    cfg.cellLoadRange       = [0 0.4 0.8];
    cfg.refSNR              = 20;
end
cfg.mcs = cqiToMcs(cfg.cqi);   % in case cfg.cqi was changed above

mus   = cfg.numerologies;
nMu   = numel(mus);
nCh   = numel(cfg.channels);
nSnr  = numel(cfg.snrRange);
nLoad = numel(cfg.cellLoadRange);

fprintf('5G NR study: %d numerologies, %d channels, %d SNR points\n', nMu, nCh, nSnr);
fprintf('CQI %d (%s, R=%.3f), %d layers, HARQ max %d tx, %d blocks per point\n\n', ...
    cfg.cqi, cfg.mcs.Modulation, cfg.mcs.TargetCodeRate, cfg.numLayers, ...
    cfg.maxHarqTx, cfg.nRealizations * cfg.slotsPerRealization);

%% 1) Link-level simulation sweep (or reload of saved results)
tStart = tic;
if ~runSimulation
    S = load('results_numerology.mat', 'BLER', 'TBS', 'Tslot', 'bwHz');
    BLER = S.BLER; TBS = S.TBS; Tslot = S.Tslot; bwHz = S.bwHz;
    assert(isequal(size(BLER), [nMu nCh nSnr]), ...
        'Saved results do not match the current cfg (numerologies, channels, SNR range).');
else
BLER  = nan(nMu, nCh, nSnr);
TBS   = nan(nMu, 1);
Tslot = nan(nMu, 1);
bwHz  = nan(nMu, 1);

tStart = tic;
for iMu = 1:nMu
    mu = mus(iMu);
    for iCh = 1:nCh
        for iSnr = 1:nSnr
            res = simulateLink(mu, cfg.snrRange(iSnr), cfg.channels{iCh}, cfg.mcs, cfg);
            BLER(iMu, iCh, iSnr) = res.BLER;
            TBS(iMu)   = res.TBS;
            Tslot(iMu) = res.Tslot;
            bwHz(iMu)  = res.bandwidthHz;
            if cfg.verbose
                fprintf('mu=%d  %-4s  SNR=%5.1f dB  BLER=%.3f  [%.0f s]\n', ...
                    mu, cfg.channels{iCh}, cfg.snrRange(iSnr), res.BLER, toc(tStart));
            end
        end
    end
end
end   % runSimulation

%% 2) Throughput and spectral efficiency (reference cell load)
thr = computeThroughput(BLER, TBS, Tslot, bwHz, cfg, cfg.refCellLoad);

%% 3) Latency
[~, kRef] = min(abs(cfg.snrRange - cfg.refSNR));
jP = find(strcmpi(cfg.channels, cfg.primaryChannel), 1);
if isempty(jP), jP = nCh; end

latSNR  = nan(nMu, nCh, nSnr);
latLoad = nan(nMu, nCh, nLoad);
comps   = nan(nMu, 6);

for iMu = 1:nMu
    mu = mus(iMu);
    for iCh = 1:nCh
        % Latency vs SNR (reference cell load), only where the PER requirement is met
        for iSnr = 1:nSnr
            L = computeLatency(mu, TBS(iMu), BLER(iMu, iCh, iSnr), ...
                Tslot(iMu), cfg.refCellLoad, cfg);
            if L.lossProb <= cfg.maxResidualPER
                latSNR(iMu, iCh, iSnr) = L.total;
            end
        end
        % Latency vs cell load (reference SNR)
        for iLoad = 1:nLoad
            L = computeLatency(mu, TBS(iMu), BLER(iMu, iCh, kRef), ...
                Tslot(iMu), cfg.cellLoadRange(iLoad), cfg);
            if L.lossProb <= cfg.maxResidualPER
                latLoad(iMu, iCh, iLoad) = L.total;
            end
        end
    end
    % Breakdown (primary channel, reference SNR and cell load)
    L = computeLatency(mu, TBS(iMu), BLER(iMu, jP, kRef), Tslot(iMu), cfg.refCellLoad, cfg);
    comps(iMu, :) = [L.align, L.sched, L.queue, L.tx, L.ue, L.retx];
end

% Throughput vs cell load (reference SNR)
capLoad = nan(nMu, nCh, nLoad);
delLoad = nan(nMu, nCh, nLoad);
for iLoad = 1:nLoad
    t = computeThroughput(BLER(:, :, kRef), TBS, Tslot, bwHz, cfg, cfg.cellLoadRange(iLoad));
    capLoad(:, :, iLoad) = t.capacity(:, :, 1);
    delLoad(:, :, iLoad) = t.delivered(:, :, 1);
end

lat.snr     = latSNR;
lat.load    = latLoad;
lat.comps   = comps;
lat.capLoad = capLoad;
lat.delLoad = delLoad;
lat.kRef    = kRef;

%% 4) Summary table (primary channel, reference SNR and cell load)
fprintf('\n=== Summary: %s, SNR = %d dB, cell load %.0f%%, video %.1f Mbit/s ===\n', ...
    cfg.channels{jP}, cfg.snrRange(kRef), 100 * cfg.refCellLoad, cfg.videoRate_Mbps);
fprintf('mu  SCS(kHz)  Slot(ms)  BW(MHz)  TBS(bits)   BLER    Resid.   Capacity(Mb/s)  Deliv.(Mb/s)  SE(b/s/Hz)  Latency(ms)\n');
for iMu = 1:nMu
    fprintf('%d   %6d    %6.3f    %6.1f   %8d   %5.3f   %.1e   %10.2f      %8.2f      %6.2f     %8.3f\n', ...
        mus(iMu), 15 * 2^mus(iMu), Tslot(iMu) * 1e3, bwHz(iMu) / 1e6, TBS(iMu), ...
        BLER(iMu, jP, kRef), thr.residual(iMu, jP, kRef), ...
        thr.capacity(iMu, jP, kRef) / 1e6, thr.delivered(iMu, jP, kRef) / 1e6, ...
        thr.specEff(iMu, jP, kRef), latSNR(iMu, jP, kRef) * 1e3);
end

%% 5) Figures and saving
plotResults(cfg, BLER, thr, lat);
save('results_numerology.mat', 'cfg', 'BLER', 'TBS', 'Tslot', 'bwHz', 'thr', 'lat');
fprintf('\nDone in %.1f min. Results: results_numerology.mat, figures: fig_*.png\n', ...
    toc(tStart) / 60);
