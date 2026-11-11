function out = computeThroughput(BLER, TBS, Tslot, bwHz, cfg, cellLoad)
% COMPUTETHROUGHPUT  Throughput and spectral efficiency with fixed MCS and HARQ.
%
%   BLER     : [nMu x nCh x nSnr]  first-transmission BLER (fixed MCS)
%   TBS      : [nMu x 1]           transport block size per slot (bits)
%   Tslot    : [nMu x 1]           slot duration (s)
%   bwHz     : [nMu x 1]           occupied bandwidth (Hz)
%   cellLoad : fraction of slots used by other users (0..1)
%
%   Model: HARQ enabled, independent retransmissions with the same BLER (no
%   combining gain, conservative), at most cfg.maxHarqTx transmissions.
%   The user is scheduled in a fraction alpha = 1 - cellLoad of the slots.
%       E[N]            = sum_{k=0}^{Nmax-1} BLER^k
%       residual BLER   = BLER^Nmax
%       link throughput = TBS (1 - BLER^Nmax) / (E[N] Tslot)
%       capacity        = alpha * link throughput     (maximum goodput of the user)
%       delivered       = min(video rate (1 - residual BLER), capacity)

[nMu, nCh, nSnr] = size(BLER);
Nmax  = cfg.maxHarqTx;
alpha = 1 - cellLoad;
offered = cfg.videoRate_Mbps * 1e6;

out.EN        = zeros(nMu, nCh, nSnr);
out.residual  = zeros(nMu, nCh, nSnr);
out.thrPhy    = zeros(nMu, nCh, nSnr);
out.capacity  = zeros(nMu, nCh, nSnr);
out.delivered = zeros(nMu, nCh, nSnr);
out.specEff   = zeros(nMu, nCh, nSnr);

for i = 1:nMu
    for j = 1:nCh
        for k = 1:nSnr
            b  = BLER(i, j, k);
            EN = sum(b .^ (0:Nmax-1));
            thrLink = TBS(i) * (1 - b^Nmax) / (EN * Tslot(i));

            out.EN(i,j,k)        = EN;
            out.residual(i,j,k)  = b^Nmax;
            out.thrPhy(i,j,k)    = TBS(i) * (1 - b) / Tslot(i);
            out.capacity(i,j,k)  = alpha * thrLink;
            out.delivered(i,j,k) = min(offered * (1 - b^Nmax), alpha * thrLink);
            out.specEff(i,j,k)   = thrLink / bwHz(i);
        end
    end
end
end
