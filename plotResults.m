function plotResults(cfg, BLER, thr, lat)
% PLOTRESULTS  Figures for the report.
%
%   Each channel (AWGN, TDL, CDL) is saved in its own PNG file, drawn at the
%   size used in the report (2.35 x 1.65 in) with 8 pt fonts, so the text of
%   the figures has the same size as the text of the paper. In LaTeX the three
%   files of one figure are put side by side with subfig.
%
%   lat : structure with fields
%         snr     [nMu x nCh x nSnr]   latency vs SNR at the reference cell load (s)
%         load    [nMu x nCh x nLoad]  latency vs cell load at the reference SNR (s)
%         comps   [nMu x 6]            latency components (primary channel)
%         capLoad [nMu x nCh x nLoad]  capacity vs cell load at the reference SNR (bit/s)
%         kRef    index of the reference SNR

mus  = cfg.numerologies;
snr  = cfg.snrRange;
nMu  = numel(mus);
nBlk = cfg.nRealizations * cfg.slotsPerRealization;
load = 100 * cfg.cellLoadRange;
jP   = find(strcmpi(cfg.channels, cfg.primaryChannel), 1);
if isempty(jP), jP = numel(cfg.channels); end

labels = cell(1, nMu);
for i = 1:nMu
    labels{i} = sprintf('\\mu=%d', mus(i));
end

plotPerChannel(cfg, snr, max(BLER, 0.5/nBlk), labels, 'SNR (dB)', ...
    'BLER', 'fig_bler', true, 0.1);
plotPerChannel(cfg, snr, thr.capacity / 1e6, labels, 'SNR (dB)', ...
    'Throughput (Mbit/s)', 'fig_throughput', false, cfg.videoRate_Mbps);
plotPerChannel(cfg, snr, thr.specEff, labels, 'SNR (dB)', ...
    'Spec. eff. (bit/s/Hz)', 'fig_spectral_efficiency', false, []);
plotPerChannel(cfg, snr, lat.snr * 1e3, labels, 'SNR (dB)', ...
    'Latency (ms)', 'fig_latency_vs_snr', true, []);
plotPerChannel(cfg, load, lat.capLoad / 1e6, labels, 'Cell load (%)', ...
    'Throughput (Mbit/s)', 'fig_throughput_vs_load', true, cfg.videoRate_Mbps);
plotPerChannel(cfg, load, lat.load * 1e3, labels, 'Cell load (%)', ...
    'Latency (ms)', 'fig_latency_vs_load', true, []);

% Latency breakdown (primary channel)
fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 3.4 2.6]);
ax = axes(fig);
comps = lat.comps * 1e3;
comps(~isfinite(comps)) = NaN;
bar(ax, comps, 'stacked'); grid(ax, 'on');
set(ax, 'XTickLabel', arrayfun(@(m) sprintf('\\mu=%d', m), mus, 'UniformOutput', false));
ylabel(ax, 'Latency (ms)');
legend(ax, {'Alignment', 'Scheduling', 'Queueing', 'Transmission', 'UE proc.', 'HARQ'}, ...
    'Location', 'northeast', 'FontSize', 6.5, 'Box', 'off');
set(ax, 'FontSize', 8, 'FontName', 'Times New Roman');
exportgraphics(fig, 'fig_latency_breakdown.png', 'Resolution', 300);
close(fig);
end

function plotPerChannel(cfg, x, data, labels, xlab, ylab, fname, logY, hline)
% data: [nMu x nCh x numel(x)]. One PNG per channel: <fname>_<channel>.png
nMu  = size(data, 1);
nCh  = numel(cfg.channels);
cols = lines(nMu);
for j = 1:nCh
    fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 2.35 1.65]);
    ax = axes(fig); hold(ax, 'on'); grid(ax, 'on');
    for i = 1:nMu
        plot(ax, x, squeeze(data(i, j, :)), '-o', 'Color', cols(i,:), ...
            'LineWidth', 1.2, 'MarkerSize', 3);
    end
    if logY, set(ax, 'YScale', 'log'); end
    if ~isempty(hline), yline(ax, hline, 'k:'); end
    xlabel(ax, xlab);
    ylabel(ax, ylab);
    set(ax, 'FontSize', 8, 'FontName', 'Times New Roman');
    if j == 1
        legend(ax, labels, 'Location', 'best', 'FontSize', 6.5, 'Box', 'off');
    end
    exportgraphics(fig, sprintf('%s_%s.png', fname, cfg.channels{j}), 'Resolution', 300);
    close(fig);
end
end
