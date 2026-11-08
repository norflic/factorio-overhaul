--[[
  Lot ROUGES-0659 (8/11) : SUITE À PART, longue (45 à 65 min à priorité Idle), de la §7 de tests/ia3f_test.lua sur 24 GRAINES :
  le pétrole allumé (fo-war-petrole) n'est pas pire qu'éteint au-delà du hasard, chemins ratés à 30 % (moteur simulé).
  Marges calculées avant la mesure (fo-logs/2026-11-08_ROUGES/CRITERE_IA3F.md) : m = 6 graines, 10,6 min ; faux rouge 3,55 %.
  Puissance : C1 rouge 74 % du temps si la chance allumé tombe de 0,72 à 0,4, 92 % à 0,3. Le nom ne finit pas par « _test » :
  les balayages de tests/*_test.lua ne la jouent pas ; elle se lance à la main, depuis la racine du mod :
      lua5.2 tests/ia3f_petrole24.lua
  Elle rejoue aussi les §1 à §6 (déterministes, quelques minutes), pas la §7b (suite rapide).
]]
arg = { [0] = "tests/ia3f_test.lua", "--graines24" }
dofile("tests/ia3f_test.lua")
