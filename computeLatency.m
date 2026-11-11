function lat = computeLatency(mu, tbs, bler, Tslot, cellLoad, cfg)
% COMPUTELATENCY  Mean downlink latency of a video packet.
%
%   lat = computeLatency(mu, tbs, bler, Tslot, cellLoad, cfg)
%
%   mu       : numerology (0..3)
%   tbs      : transport block size per slot (bits)
%   bler     : first-transmission BLER measured by simulation
%   Tslot    : slot duration (s)
%   cellLoad : fraction of slots used by other users (0..1)
%
%   Traffic: Poisson packet arrivals at cfg.videoRate_Mbps, packets of
%   cfg.packetBits. The user is granted each slot with probability
%   alpha = 1 - cellLoad (round-robin-like sharing with other users).
%
%   Components (mean values):
%     align : wait for the next slot boundary                      = Tslot/2
%     sched : wait for the first granted slot                      = Tslot (1/alpha - 1)
%     queue : M/D/1 queueing delay                                 = rho Ts / (2 (1 - rho))
%     tx    : transmission of the nSlots slots of the packet
%     ue    : UE processing after the last slot (N1 symbols)
%     retx  : HARQ retransmissions, (E[N]-1) x (HARQ RTT + granted slot)
%
%   Assumptions: FDD-like link (one UL opportunity per slot), gNB processing
%   time equal to N1, retransmission of a block = 1 granted slot. If rho >= 1
%   the queue is unstable and the latency is Inf.

Nmax  = cfg.maxHarqTx;
alpha = 1 - cellLoad;
Tsym  = Tslot / 14;
N1    = cfg.N1symbols(mu + 1);

if alpha <= 0
    lat = struct('align',Inf,'sched',Inf,'queue',Inf,'tx',Inf,'ue',Inf, ...
        'retx',Inf,'total',Inf,'rho',Inf,'EN',NaN,'nSlots',NaN,'lossProb',1);
    return;
end

% Mean number of transmissions per block (truncated geometric)
EN = sum(bler .^ (0:Nmax-1));

% Packet service
nSlots = ceil(cfg.packetBits / tbs);                  % slots needed to send one packet
% Load: a slot can carry several packets, so the occupation is fractional
Ts     = (cfg.packetBits / tbs) * EN * Tslot / alpha; % mean channel occupation per packet (s)
lambda = cfg.videoRate_Mbps * 1e6 / cfg.packetBits;   % packets per second
rho    = lambda * Ts;

% Components
Talign = Tslot / 2;
Tsched = Tslot * (1/alpha - 1);
if rho < 1
    Tqueue = rho * Ts / (2 * (1 - rho));
else
    Tqueue = Inf;
end
Ttx = Tslot * (nSlots + (nSlots - 1) * (1/alpha - 1));
Tue = N1 * Tsym;

% HARQ RTT: UE processing + UL feedback slot + gNB processing,
% rounded up to the start of the next slot
Tharq = ceil((Tue + Tslot + N1 * Tsym) / Tslot) * Tslot;
Tretx = (EN - 1) * (Tharq + Tslot / alpha);

lat.align    = Talign;
lat.sched    = Tsched;
lat.queue    = Tqueue;
lat.tx       = Ttx;
lat.ue       = Tue;
lat.retx     = Tretx;
lat.total    = Talign + Tsched + Tqueue + Ttx + Tue + Tretx;
lat.rho      = rho;
lat.EN       = EN;
lat.nSlots   = nSlots;
lat.lossProb = bler ^ Nmax;                           % residual packet loss probability
end
