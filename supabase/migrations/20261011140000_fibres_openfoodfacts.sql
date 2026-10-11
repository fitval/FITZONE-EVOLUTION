-- ============================================================
-- FITZONE EVOLUTION — Fibres de 19 aliments absents de Ciqual (produits de marque et aliments courants)
-- ============================================================
-- Sources : Open Food Facts (fiber_100g) et USDA FoodData Central ; valeurs relues et validées par le coach le 2026-10-11.
-- Aliments saisis par portion (tranche de pain, de Wasa) : valeur convertie à la même base que leurs macros.
-- N'écrase rien : ne touche que les aliments dont les fibres sont encore vides. Une seule instruction.
-- ============================================================

update public.aliments as a set fibres = v.fibres from (values (1779653713789,0.8),(1781101026616,5.8),(1782391416226,1.7),(1773243030849,3.7),(1773243030964,35),(1780920205660,2.4),(1786608637591,0),(1773243030856,0),(1773243030880,3),(1773243030840,1.2),(1773243030842,0),(1782055430901,1.4),(1785451529019,2.2),(1773243030958,1.8),(1773243031013,0.5),(1783245008275,14),(1783503272592,14),(1785680030694,0.5),(1782298877138,3)) as v(id, fibres) where a.id = v.id and a.fibres is null;
