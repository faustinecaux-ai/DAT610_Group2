function mcs = cqiToMcs(cqi)
% CQITOMCS  Map a CQI index (1..15) to modulation and target code rate.
%   Source: TS 38.214, Table 5.2.2.1-2 (64QAM CQI table).

tab = { ...
    'QPSK',   78;  'QPSK',  120;  'QPSK',  193;  'QPSK',  308;  'QPSK',  449; ...
    'QPSK',  602;  '16QAM', 378;  '16QAM', 490;  '16QAM', 616;  '64QAM', 466; ...
    '64QAM', 567;  '64QAM', 666;  '64QAM', 772;  '64QAM', 873;  '64QAM', 948};

assert(isscalar(cqi) && cqi >= 1 && cqi <= 15 && cqi == round(cqi), ...
    'CQI must be an integer between 1 and 15.');

mcs.Modulation     = tab{cqi, 1};
mcs.TargetCodeRate = tab{cqi, 2} / 1024;
end
