-- Lot CORR-ENERGIE : meme charge, regle de croissance COUPEE par le reglage de banc no_grow (temoin : le reseau reste sature).
return require("scenarios/energie_demande_common")("demande-temoin", { radars = 8, expect = "stay", no_grow = true, check_tick = 40000 })
