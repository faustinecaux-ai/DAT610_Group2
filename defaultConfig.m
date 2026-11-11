function cfg = defaultConfig()
% DEFAULTCONFIG  Parameters of the study.
% Scenario: pedestrian on a 5G video call, urban street, line of sight (LOS),
% walking away from the base station. Downlink only (PDSCH).

%% Scenario
cfg.carrierFreqHz = 3.5e9;              % same carrier for all numerologies (see report)
cfg.speedKmh      = 3;                  % pedestrian -> Doppler = v*fc/c = 9.7 Hz
cfg.delaySpread   = 50e-9;              % s, UMi-LOS at 3.5 GHz (TR 38.901, Table 7.5-6)

%% Fixed parameters
cfg.tdlProfile      = 'TDL-D';          % LOS profile (K = 13.3 dB)
cfg.cdlProfile      = 'CDL-D';          % LOS profile
cfg.mimoCorrelation = 'Low';            % TDL spatial correlation
cfg.numLayers       = 2;                % 2 layers -> 2 Tx and 2 Rx antennas
cfg.cqi             = 9;                % fixed CQI -> fixed MCS (16QAM, R = 616/1024)
cfg.mcs             = cqiToMcs(cfg.cqi);
cfg.maxHarqTx       = 4;                % HARQ enabled, max transmissions per block
cfg.dmrsAddPos      = 1;                % additional DM-RS position
cfg.ldpcIter        = 8;                % max LDPC decoder iterations

%% Varying parameters
cfg.numerologies = 0:3;                 % mu = 0..3 -> SCS = 15, 30, 60, 120 kHz
% Number of RBs chosen to keep the occupied bandwidth roughly constant
% (~17-19 MHz): 19.1, 18.4, 17.3 and 17.3 MHz. Use [52 52 52 52] for a
% constant number of RBs instead.
cfg.nrb          = [106 51 24 12];
cfg.snrRange     = 0:3:30;              % nominal SNR per RE and Rx antenna (dB)
cfg.channels     = {'AWGN', 'TDL', 'CDL'};
cfg.cellLoadRange = [0 0.2 0.4 0.6 0.8]; % fraction of slots used by other users

%% Monte Carlo simulation
cfg.nRealizations       = 200;          % independent channel realizations
cfg.slotsPerRealization = 1;            % slots per realization (channel quasi static)
cfg.seed   = 0;
cfg.cellID = 1;

%% Video-call traffic and QoS (5QI 2: conversational video)
cfg.videoRate_Mbps  = 4;                % offered video rate (1080p call)
cfg.packetBits      = 1200 * 8;         % RTP packet of 1200 bytes
cfg.delayBudget_ms  = 150;              % packet delay budget (end to end)
cfg.maxResidualPER  = 1e-3;             % packet error rate requirement

%% Latency model
% UE processing time N1 in symbols (TS 38.214, Table 5.3-1, capability 1,
% additional DM-RS) for mu = 0..3. Typical values, can be modified.
cfg.N1symbols = [13 13 20 24];

%% Reporting
cfg.refSNR         = 20;                % reference SNR (dB)
cfg.refCellLoad    = 0.4;               % reference cell load
cfg.primaryChannel = 'TDL';             % channel used for the summary and breakdown
cfg.verbose        = true;
end
