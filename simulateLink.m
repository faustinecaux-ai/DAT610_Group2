function res = simulateLink(mu, SNRdB, channelType, mcs, cfg)
% SIMULATELINK  Full PDSCH downlink link (DL-SCH, OFDM, MIMO channel, MMSE).
%
%   res = simulateLink(mu, SNRdB, channelType, mcs, cfg)
%
%   mu          : numerology (0..3)
%   SNRdB       : nominal SNR per resource element and Rx antenna (dB)
%   channelType : 'AWGN', 'TDL' or 'CDL'
%   mcs         : struct with fields Modulation and TargetCodeRate
%   cfg         : structure from defaultConfig
%
%   Assumptions: cfg.numLayers layers sent on as many Tx antennas (no
%   precoding), same number of Rx antennas, full DL slots (14 PDSCH symbols),
%   perfect timing synchronization, DM-RS based channel estimation, MMSE
%   equalization. Each slot carries a new transport block: only the first
%   transmission is simulated, HARQ is handled in computeThroughput /
%   computeLatency from the measured BLER.

nL  = cfg.numLayers;
scs = 15 * 2^mu;
nrb = cfg.nrb(mu + 1);

%% Carrier
carrier = nrCarrierConfig;
carrier.NCellID           = cfg.cellID;
carrier.SubcarrierSpacing = scs;
carrier.NSizeGrid         = nrb;
carrier.NStartGrid        = 0;

%% PDSCH
pdsch = nrPDSCHConfig;
pdsch.PRBSet           = 0:nrb-1;
pdsch.SymbolAllocation = [0 14];
pdsch.MappingType      = 'A';
pdsch.Modulation       = mcs.Modulation;
pdsch.NumLayers        = nL;
pdsch.DMRS.DMRSConfigurationType   = 1;
pdsch.DMRS.DMRSTypeAPosition       = 2;
pdsch.DMRS.DMRSLength              = 1;
pdsch.DMRS.DMRSAdditionalPosition  = cfg.dmrsAddPos;
pdsch.DMRS.DMRSPortSet             = 0:nL-1;
pdsch.DMRS.NumCDMGroupsWithoutData = 1;

[pdschIndices, pdschInfo] = nrPDSCHIndices(carrier, pdsch);
dmrsIndices = nrPDSCHDMRSIndices(carrier, pdsch);

% Transport block size
tcr = mcs.TargetCodeRate;
tbs = nrTBS(pdsch.Modulation, nL, numel(pdsch.PRBSet), ...
            pdschInfo.NREPerPRB, tcr, 0);

%% Channel coding
encodeDLSCH = nrDLSCH;
encodeDLSCH.TargetCodeRate = tcr;

%% OFDM and noise parameters
ofdmInfo = nrOFDMInfo(carrier);
snrLin   = 10^(SNRdB/10);
N0       = 1 / sqrt(2.0 * double(ofdmInfo.Nfft) * snrLin);  % noise std per Rx antenna

useChannel = ~strcmpi(channelType, 'AWGN');

%% Monte Carlo loop
rng(cfg.seed);
nErr = 0;
nBlk = 0;

for r = 1:cfg.nRealizations

    if useChannel
        [channel, maxChDelay] = makeChannel(channelType, cfg, ...
            ofdmInfo.SampleRate, cfg.seed + r);   % same channel for all SNR
    end

    for s = 0:cfg.slotsPerRealization-1

        carrier.NSlot = mod(s, carrier.SlotsPerFrame);

        % --- Transmitter ---
        trBlk = randi([0 1], tbs, 1);
        setTransportBlock(encodeDLSCH, trBlk);
        codeword = encodeDLSCH(pdsch.Modulation, nL, pdschInfo.G, 0);

        pdschSym = nrPDSCH(carrier, pdsch, codeword);
        dmrsSym  = nrPDSCHDMRS(carrier, pdsch);

        txGrid = nrResourceGrid(carrier, nL);
        txGrid(pdschIndices) = pdschSym;
        txGrid(dmrsIndices)  = dmrsSym;
        txWave = nrOFDMModulate(carrier, txGrid);

        % --- Channel ---
        if useChannel
            txPad = [txWave; zeros(maxChDelay, size(txWave, 2))];
            [rxWave, pathGains, ~] = channel(txPad);
            pathFilters = getPathFilters(channel);
            offset = nrPerfectTimingEstimate(pathGains, pathFilters);
        else
            rxWave = txWave;       % identity channel
            offset = 0;
        end

        noise  = N0 * complex(randn(size(rxWave)), randn(size(rxWave)));
        rxWave = rxWave + noise;

        % --- Receiver ---
        rxWave = rxWave(1+offset:end, :);
        rxGrid = nrOFDMDemodulate(carrier, rxWave);
        [K, L, R] = size(rxGrid);
        if L < carrier.SymbolsPerSlot
            rxGrid = cat(2, rxGrid, zeros(K, carrier.SymbolsPerSlot - L, R));
        end

        [hEst, nVar] = nrChannelEstimate(carrier, rxGrid, dmrsIndices, dmrsSym, ...
            'CDMLengths', pdsch.DMRS.CDMLengths);

        [pdschRx, pdschH] = nrExtractResources(pdschIndices, rxGrid, hEst);
        [pdschEq, csi]    = nrEqualizeMMSE(pdschRx, pdschH, nVar);

        llr = nrPDSCHDecode(carrier, pdsch, pdschEq, nVar);
        if iscell(llr)
            llr = llr{1};
        end

        % Scale the LLRs by the CSI (layer demapping keeps the LLR order)
        csiCw = nrLayerDemap(csi);
        if iscell(csiCw)
            csiCw = csiCw{1};
        end
        csiCw = csiCw(:);
        Qm  = numel(llr) / numel(csiCw);
        llr = llr .* reshape(repmat(csiCw.', Qm, 1), [], 1);

        % New decoder for every slot: no residual HARQ soft combining
        decodeDLSCH = nrDLSCHDecoder;
        decodeDLSCH.TargetCodeRate            = tcr;
        decodeDLSCH.TransportBlockLength      = tbs;
        decodeDLSCH.LDPCDecodingAlgorithm     = 'Normalized min-sum';
        decodeDLSCH.MaximumLDPCIterationCount = cfg.ldpcIter;
        [~, blkErr] = decodeDLSCH(llr, pdsch.Modulation, nL, 0);

        nErr = nErr + double(blkErr);
        nBlk = nBlk + 1;
    end
end

%% Results
res.mu          = mu;
res.SCS_kHz     = scs;
res.SNRdB       = SNRdB;
res.channel     = channelType;
res.nBlocks     = nBlk;
res.nErrors     = nErr;
res.BLER        = nErr / nBlk;
res.TBS         = tbs;
res.Tslot       = 1e-3 / 2^mu;
res.bandwidthHz = nrb * 12 * scs * 1e3;
end

%% ------------------------------------------------------------------------
function [channel, maxChDelay] = makeChannel(channelType, cfg, sampleRate, seed)
% Build a TDL or CDL channel for a pedestrian user.

nL = cfg.numLayers;
fd = cfg.speedKmh / 3.6 * cfg.carrierFreqHz / 299792458;   % max Doppler shift (Hz)

switch upper(channelType)
    case 'TDL'
        channel = nrTDLChannel;
        channel.DelayProfile        = cfg.tdlProfile;
        channel.DelaySpread         = cfg.delaySpread;
        channel.MaximumDopplerShift = fd;
        channel.SampleRate          = sampleRate;
        channel.NumTransmitAntennas = nL;
        channel.NumReceiveAntennas  = nL;
        channel.MIMOCorrelation     = cfg.mimoCorrelation;
        channel.Seed                = seed;
    case 'CDL'
        % Cross-polarized arrays: [rows columns polarizations panelsV panelsH]
        % (1 or 2 layers: 1 or 2 polarizations)
        channel = nrCDLChannel;
        channel.DelayProfile        = cfg.cdlProfile;
        channel.DelaySpread         = cfg.delaySpread;
        channel.CarrierFrequency    = cfg.carrierFreqHz;
        channel.MaximumDopplerShift = fd;
        channel.SampleRate          = sampleRate;
        % Isotropic elements on both sides: the default 38.901 element has
        % about 8 dBi of gain, which would shift the nominal SNR.
        channel.TransmitAntennaArray.Size = [1 1 nL 1 1];
        channel.ReceiveAntennaArray.Size  = [1 1 nL 1 1];
        channel.TransmitAntennaArray.Element = 'isotropic';
        channel.ReceiveAntennaArray.Element  = 'isotropic';
        channel.Seed                = seed;
    otherwise
        error('Unknown channel type: %s', channelType);
end

chInfo     = info(channel);
maxChDelay = ceil(max(chInfo.PathDelays * sampleRate)) + chInfo.ChannelFilterDelay;
end
