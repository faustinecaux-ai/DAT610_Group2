function plotDelaySpread(cfg, delaySpreads, BLER, snrdB, channelType)
% PLOTDELAYSPREAD  BLER versus delay spread (3.4 x 2.6 in, 8 pt fonts).
%   BLER : [nMu x nDS], delaySpreads in seconds.

mus  = cfg.numerologies;
nBlk = cfg.nRealizations * cfg.slotsPerRealization;
cols = lines(numel(mus));

fig = figure('Color', 'w', 'Units', 'inches', 'Position', [1 1 3.4 2.6]);
ax = axes(fig); hold(ax, 'on'); grid(ax, 'on');
for iMu = 1:numel(mus)
    plot(ax, delaySpreads * 1e9, max(BLER(iMu, :), 0.5/nBlk), '-o', ...
        'Color', cols(iMu,:), 'LineWidth', 1.2, 'MarkerSize', 3);
end
set(ax, 'YScale', 'log', 'FontSize', 8, 'FontName', 'Times New Roman');
xlabel(ax, 'Delay spread (ns)');
ylabel(ax, 'BLER');
legend(ax, arrayfun(@(m) sprintf('\\mu=%d (%d kHz)', m, 15*2^m), mus, 'UniformOutput', false), ...
    'Location', 'northwest', 'FontSize', 7, 'Box', 'off');
exportgraphics(fig, 'fig_delay_spread.png', 'Resolution', 300);
close(fig);
end
