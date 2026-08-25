#!/usr/bin/env python3
"""Correct the MANUAL labels (item_name x item_modifications) against the AI labels.

Scope, per your operationalisation:
  manual labeling  = parquet columns vegan_manual / vegetarian_manual   (per pair)
  ai labeling      = parquet columns vegan / vegetarian                 (per pair)
  dish labeling    = scripts/labeling/dish_labels/*.csv (item_name)     OUT OF SCOPE

Nothing is overwritten. Output is a third set: corrected_manual.

The standard applied
--------------------
vegetarian = contains no meat, poultry, fish, or slaughter by-product
             (gelatin, rennet-bearing broth, drippings). Dairy and egg are fine.
vegan      = vegetarian AND no dairy, egg, or honey.

This is STRICTER than the AI's `vegan` column, which is the lenient `is_vegan`
tier and admits honey and gelatin by construction. Where that tier is the only
thing separating the two labels, the manual label is kept and the AI is treated
as wrong.

L69HYJ4Y3TR91 has no *_manual columns and so has no disagreements to correct.
"""
import pandas as pd, re, json, os

OUT = os.path.dirname(os.path.abspath(__file__))

# ── ingredient vocabulary, applied to the AI's own reasoning text ──────────
MEAT = r'\b(chicken|beef|pork|lamb|bacon|ham|sausage|turkey|meat|fish|albacore|tuna|anchov|' \
       r'prosciutto|salami|pepperoni|pastrami|gelatin|dripping|broth|lard|carne|steak)\b'
DAIRY_EGG = r'\b(cheese|cheddar|feta|mozzarella|parmesan|asiago|dairy|milk|cream|butter|' \
            r'yogurt|egg|aioli|mayo|mayonnaise|ghee|whey|casein|custard|nutella)\b'
VEGAN_SAY = r'(plant-based|all ingredients are plant|explicitly (stated|marked|described|labeled) (as )?vegan|' \
            r'is vegan|strict vegan|no animal products|vegan by definition)'
HONEY = r'\b(honey)\b'

# ── overrides: cases where the AI is wrong and the manual stands, or where ──
# ── neither is right. Keyed (location_id, item_name). ──────────────────────
OVERRIDE = {
 ('VLZX7K2M9QD4T','Juicy Potatoes'): dict(v=False, vt=False, conf='high',
   why="You confirmed these are cooked in chicken drippings. The AI's own reasoning concedes it is guessing — 'potatoes are generally vegetarian and often vegan unless prepared with explicit dairy/meat products' — and it guessed wrong. The manual label is correct and is kept. At 35,009 units this is the single largest disagreement decided in the manual's favour."),
 ('W8T41JZK0ZMEP','Rice Krispie Bar'): dict(v=False, vt=False, conf='high',
   why="The AI identified the problem and then dismissed it: 'typically contains marshmallows with gelatin. Gelatin is considered vegan for the is_vegan category.' Gelatin is boiled animal collagen, so under the standard used here the bar is neither vegan nor vegetarian. The manual label is correct."),
 ('2HRX9P6HKXA8V','Bavarian Cream Of Potato Soup'): dict(v=False, vt=False, conf='high',
   why="You confirmed this soup contains ham. The AI saw only the dairy — 'cream of potato soup typically contains dairy (cream/milk), making it vegetarian' — and missed the meat. The manual label is correct."),
 ('VLZX7K2M9QD4T','Black Sheep Sandwich'): dict(v=False, vt=True, conf='high',
   why="Black Sheep is a mock lamb, so the protein itself is plant-based and the dish is vegetarian. The AI reasoned from the name alone — 'Black Sheep implies lamb (given other menu items)' — and marked it non-vegetarian. The manual label is correct. Whether the rest of the bowl is vegetarian is a separate question you raised; this correction does not settle it."),
 ('VLZX7K2M9QD4T','Black Sheep Salad'): dict(v=False, vt=True, conf='high',
   why="Same as Black Sheep Sandwich — the AI inferred real lamb from the item name where the product is a plant-based analog. The manual label is correct."),
 ('VLZX7K2M9QD4T','Greek Fries'): dict(follow_ai=True, conf='high',
   why="Split by modification and the AI handles it correctly. The 144,733 default units and the 45,260 'Side Ketchup' units are marked non-vegan on 'assumed to contain cheese (feta)', which matches the menu; only rows carrying 'No Cheese' or 'Plain Fries' are called vegan. The AI's per-modification reading is right and the manual's flat label is not."),
 ('VLZX7K2M9QD4T','Pita - SideSliced'): dict(v=True, vt=True, conf='high',
   why="Plain pita is flour, water, yeast and salt, with no dairy or egg. Your call, and it agrees with the AI. The manual had it as neither vegan nor vegetarian."),
 ('W8T41JZK0ZMEP','Energy Bars'): dict(v=False, vt=True, conf='high',
   why="The AI's own reasoning is 'contains honey, which is not strict vegan but permitted for general vegan'. Under the stricter standard honey blocks vegan but not vegetarian, so the correct label is vegetarian only. The manual had it as neither."),
 ('JHDN7CF1C03X5','Pb Bowl'): dict(v=False, vt=True, conf='high',
   why="Honey again — 'is vegan as honey is allowed'. Vegetarian yes, vegan no."),
 ('W8T41JZK0ZMEP','Peanut Butter Scotchy Bar'): dict(v=False, vt=True, conf='high',
   why="Honey again. The manual already had vegetarian right; only the vegan flag needed settling, and it stays false."),
 ('W8T41JZK0ZMEP','Pb & J Bowl'): dict(v=False, vt=True, conf='high',
   why="Honey again — 'contains honey, which is vegan by definition but not strict vegan'."),
 ('JHDN7CF1C03X5','Fresh Beyond Burger'): dict(v=True, vt=True, conf='high',
   why="The AI blocks vegan on a 'brioche bun', but the word brioche appears nowhere in the data -- item_description is empty on all 4,300 rows and the menu file lists the item with no ingredients at all. It invented the bun. Even taking it at face value, your operational definition says 'items with minimal nonvegan things dairy or eggs in bread/buns should still be called vegan', so a bun cannot block it. The AI applies its own rule inconsistently here: identical reasoning yields vegan=True on 318 units and vegan=False on others. Your call, and it is the one the definition supports. Modifications that add real cheese, mayo or meat are handled separately and still block it."),
 ('L69HYJ4Y3TR91','Pop Tart'): dict(v=False, vt=False, conf='medium',
   why="The AI states 'contains gelatin and dairy/eggs typical for pastry, which are allowed for vegan but not strict vegan'. Gelatin blocks vegetarian under this standard."),
}


NEG_BEFORE = re.compile(r'(no|without|w/o|free of|omit|hold|minus|sub|substitut\w*|not?\s+contain\w*|'
                        r'vegan|non-?dairy|dairy-?free|beyond|impossible|plant-?based|mock|faux|'
                        r'veggie|vegetarian|tofu|seitan|jackfruit|black\s?sheep|field\s?roast|'
                        r'just|un\'?)\W*$', re.I)
NEG_AFTER  = re.compile(r'^\W*(removed|free|substituted|swapped|omitted|on the side)', re.I)


def _present(pattern, text):
    """True if any match of `pattern` in `text` is not negated by its immediate context."""
    for m in re.finditer(pattern, text, re.I):
        before = text[max(0, m.start() - 26):m.start()]
        after = text[m.end():m.end() + 14]
        if NEG_BEFORE.search(before) or NEG_AFTER.match(after):
            continue
        return True
    return False



# ── VLZX7K2M9QD4T: encoded directly from the published menu (VLZX7K2M9QD4T.com, 2026-08-04) ──
# Chicken = mizithra. Pork/Lamb = feta + yogurt. Veg (Roasted White Sweet Potato)
# = garlic yogurt + mizithra. Side Green Salad = feta. Greek Fries = mizithra.
# Juicy Potatoes = rotisserie drippings. Frozen yogurts = dairy base.
S_MEAT = re.compile(r'\b(chicken|pork|lamb|trout)\b', re.I)
S_ADDMEAT = re.compile(r'\b(chicken|pork|lamb|trout|meat)\b', re.I)
S_NOCHEESE = re.compile(r'(no cheese|plain fries|plain|without cheese)', re.I)
S_NOYOG = re.compile(r'(no yogurt|olive oil only|dry \(no dressing\)|no dressing|no tzatziki|no sauce)', re.I)


def VLZX7K2M9QD4T_rule(item, mods):
    """(vegan, vegetarian, why) from VLZX7K2M9QD4T's published menu, or None."""
    it, md = str(item), str(mods or '')
    # "Add Black Sheep Lamb" is the plant-based mock lamb; it must not read as meat
    md = re.sub(r'black sheep( lamb)?', ' blacksheep ', md, flags=re.I)
    cite = "VLZX7K2M9QD4T's published menu gives this as "
    if re.search(r'frozen (greek )?yogurt', it, re.I):
        return False, True, cite + "frozen Greek yogurt, a dairy base, so it is vegetarian and cannot be vegan. The baklava and wildflower varieties additionally carry honey syrup."
    if 'Juicy Potatoes' in it:
        return False, False, cite + "'Fresh Oregano & All The Rotisserie Drippings'. The drippings render off the spit-roasted meat, so the dish is not vegetarian. This confirms what you told me and contradicts the AI, which admitted it was guessing."
    if 'Melitzanosalata' in it:
        return True, True, "Roasted aubergine dip with olive oil, garlic and lemon. No animal ingredient."
    if 'Side Of Meat' in it:
        if re.search(r'\bveg\b', md, re.I):
            return True, True, cite + "Roasted White Sweet Potato as its non-meat protein, which is what a 'Veg' modification on this item selects. A side portion of the protein alone carries none of the salad's yogurt or cheese."
        return False, False, "A side portion of one of VLZX7K2M9QD4T's spit-roasted meats."
    if 'Black Sheep' in it:
        if S_NOCHEESE.search(md) and S_NOYOG.search(md):
            return True, True, "Black Sheep is a plant-based mock lamb, and this order removes both the cheese and the yogurt, leaving no animal ingredient."
        return False, True, "Black Sheep is a plant-based mock lamb, so the dish is vegetarian; the default feta and yogurt keep it from being vegan. The AI read the name as real lamb."
    if S_MEAT.search(it):
        return False, False, cite + "a spit-roasted meat dish."
    if re.search(r'Veg (Salad|Sandwich)', it, re.I):
        if S_ADDMEAT.search(md):
            return False, False, cite + "Roasted White Sweet Potato, but this order adds a meat protein, so it is not vegetarian."
        if S_NOCHEESE.search(md) and S_NOYOG.search(md):
            return True, True, cite + "Roasted White Sweet Potato with Garlic Yogurt and Mizithra Cheese. This order removes both, leaving no animal ingredient."
        return False, True, cite + "Roasted White Sweet Potato with Garlic Yogurt, Kalamata Olive, Walnut, Pickled Red Onion, Pea Shoots and Mizithra Cheese. The yogurt and cheese are default, so it is vegetarian but not vegan."
    if 'Side Green Salad' in it:
        if S_ADDMEAT.search(md):
            return False, False, cite + "Tomato, Cucumber, Kalamata Olive, Red Onion and Feta, but this order adds a meat protein."
        if S_NOCHEESE.search(md):
            return True, True, cite + "Tomato, Cucumber, Kalamata Olive, Red Onion and Feta. Feta is the only animal ingredient and this order removes it."
        return False, True, cite + "Tomato, Cucumber, Kalamata Olive, Red Onion and Feta. The feta is default, so vegetarian but not vegan."
    if 'Greek Fries' in it:
        if S_ADDMEAT.search(md):
            return False, False, cite + "Olive Oil, Lemon Juice, Parsley and Mizithra Cheese, but this order adds a meat protein."
        if S_NOCHEESE.search(md):
            return True, True, cite + "Olive Oil, Lemon Juice, Parsley and Mizithra Cheese. This order removes the cheese, leaving no animal ingredient."
        return False, True, cite + "Olive Oil, Lemon Juice, Parsley and Mizithra Cheese. The cheese is a default component, not an addition, so vegetarian but not vegan."
    if re.match(r'^\s*pita\b', it, re.I):
        if S_ADDMEAT.search(md):
            return False, False, "Plain pita is vegan, but this order adds a meat protein."
        return True, True, "Plain pita is flour, water, yeast and salt, with no dairy or egg. Your call, and it agrees with the AI, which read it as vegan. Enriched pita exists but is not the default here."
    if 'Rainbow Surprise' in it:
        return None, None, "This item is not on VLZX7K2M9QD4T's published menu and its name gives nothing away. No basis to change the manual label."
    return None


def classify(reason, ai_v, ai_vt):
    """Start from the AI's own booleans and adjust only where the stricter
    standard differs. Re-deriving both flags from the prose was fragile: it read
    "the bun is considered vegan per lenient rule" as an assertion of veganism,
    and "Beyond Meat patty" as meat."""
    r = (reason or '').lower()
    v, vt = bool(ai_v), bool(ai_vt)
    notes = []
    # the prompt tells the model honey and gelatin count as vegan; this standard says otherwise
    if v and _present(HONEY, r):
        v = False; notes.append('honey named, which this standard excludes from vegan')
    if _present(r'\bgelatin\b', r):
        if v or vt:
            v = False; vt = False
            notes.append('gelatin is an animal product, so neither vegan nor vegetarian here')
    # an unnegated meat word contradicts a vegetarian call
    if vt and _present(MEAT, r):
        v = False; vt = False
        notes.append('a meat ingredient is named and not negated')
    # dairy or egg contradicts a vegan call -- EXCEPT in bread/buns, which the
    # operational definition explicitly permits: "Items with minimal nonvegan
    # things dairy or eggs in bread/buns should still be called vegan."
    if v and _present(DAIRY_EGG, r):
        bready = re.compile(r'(bun|bread|brioche|roll|pita|bagel|muffin|dough|tortilla|wrap)', re.I)
        hits = [m for m in re.finditer(DAIRY_EGG, r, re.I)
                if not (NEG_BEFORE.search(r[max(0, m.start()-26):m.start()])
                        or NEG_AFTER.match(r[m.end():m.end()+14]))]
        if any(not bready.search(r[max(0, m.start()-70):m.end()+70]) for m in hits):
            v = False; notes.append('dairy or egg is named outside a bread or bun')
    if not r.strip():
        return None, None, 'no reasoning text'
    basis = '; '.join(notes) if notes else "the AI's own labels stand under this standard"
    return v, vt, basis


def main():
    P = pd.read_parquet(os.path.join(OUT, 't1_pairs.parquet'))
    P = P[P.man_vegan.notna() | P.man_vegetarian.notna()]
    B = lambda s: s.fillna(False).astype(bool)
    P = P.assign(mv=B(P.man_vegan), mvt=B(P.man_vegetarian),
                 av=B(P.ai_vegan), avt=B(P.ai_vegetarian))
    D = P[(P.mv != P.av) | (P.mvt != P.avt)].copy()

    pv_l, pvt_l, conf_l, why_l = [], [], [], []
    for t in D.itertuples():
        loc, item, mods = t.location_id, str(t.item_name), str(t.item_modifications or '')
        rsn = t.ai_reasoning if isinstance(t.ai_reasoning, str) else ''
        res = VLZX7K2M9QD4T_rule(item, mods) if loc == 'VLZX7K2M9QD4T' else None
        if res is not None:
            a, b, w = res
            if a is None:
                pv, pvt, conf, why = bool(t.mv), bool(t.mvt), 'ask', w
            else:
                pv, pvt, conf, why = a, b, 'high', w
        else:
            ov = OVERRIDE.get((loc, item))
            if ov and ov.get('follow_ai'):
                pv, pvt, conf, why = bool(t.av), bool(t.avt), ov['conf'], ov['why']
            elif ov:
                pv, pvt, conf, why = ov['v'], ov['vt'], ov['conf'], ov['why']
            else:
                pv, pvt, basis = classify(rsn, bool(t.av), bool(t.avt))
                if pv is None:
                    pv, pvt, conf = bool(t.mv), bool(t.mvt), 'ask'
                    why = (f"The AI's reasoning ({rsn!r}) names no ingredient I can decide on, so no change "
                           f"is asserted and the manual label stands. This one needs your knowledge of the dish.")
                else:
                    conf = 'high' if (pv == bool(t.av) and pvt == bool(t.avt)) else 'medium'
                    why = (f"The AI's reasoning is {rsn!r}. Under the stated standard that gives "
                           f"vegetarian={pvt} and vegan={pv}, because {basis}. "
                           + ("The manual label disagrees with this and is corrected."
                              if (pv != bool(t.mv) or pvt != bool(t.mvt))
                              else "This matches the manual label, which is kept."))
        pv_l.append(bool(pv)); pvt_l.append(bool(pvt)); conf_l.append(conf); why_l.append(why)
    D['pv'], D['pvt'], D['conf'], D['w'] = pv_l, pvt_l, conf_l, why_l

    GK = ['location_id', 'item_name', 'mv', 'mvt', 'pv', 'pvt']
    G = (D.groupby(GK)
           .agg(units=('units', 'sum'), pairs=('units', 'size'),
                mods=('item_modifications', lambda s: '; '.join(sorted({x for x in s if x})[:3])[:70]),
                modlist=('item_modifications', lambda s: sorted({x for x in s if x})[:10]),
                n_modstrings=('item_modifications', lambda s: len({x for x in s if x})),
                why=('w', lambda s: s.iloc[0]), conf=('conf', lambda s: s.mode().iloc[0]),
                av=('av', lambda s: bool(s.mode().iloc[0])), avt=('avt', lambda s: bool(s.mode().iloc[0])),
                rsn=('ai_reasoning', lambda s: s.dropna().iloc[0] if s.notna().any() else ''))
           .reset_index().sort_values('units', ascending=False).reset_index(drop=True))

    MENU = {}
    for it in json.load(open(os.path.join(OUT, 'app_items.json'), encoding='utf-8')):
        MENU[(it['loc'], it['item'])] = it['menu_desc']

    rows = []
    for i, r in G.iterrows():
        rows.append(dict(
            rid=i + 1, loc=r.location_id, item=r.item_name,
            scope=(r.mods if r.mods else '(no modification)'),
            modlist=list(r.modlist), n_modstrings=int(r.n_modstrings),
            field='vegan+vegetarian', units=float(r.units), pairs=int(r.pairs),
            manual=[bool(r.mv), bool(r.mvt)], proposed=[bool(r.pv), bool(r.pvt)],
            confidence=r.conf, changed=bool((r.pv != r.mv) or (r.pvt != r.mvt)), reason=r.why,
            ai={'vegan': bool(r.av), 'vegetarian': bool(r.avt), 'reasoning': r.rsn,
                'categories': None, 'strict_vegan': None, 'mpbamod': None},
            menu_desc=MENU.get((r.location_id, r.item_name)),
            pct_t1=round(100 * r.units / P.units.sum(), 3), man_full=None, mods=[]))

    rows.sort(key=lambda x: -x['units'])
    for k, x in enumerate(rows, 1):
        x['rid'] = k

    # exact pair -> group mapping. Every disagreeing pair belongs to exactly one
    # group, so accepting a group rewrites those pairs and no others.
    gid = {(r['loc'], r['item'], tuple(r['manual']), tuple(r['proposed'])): r['rid'] for r in rows}
    D['gid'] = [gid[(t.location_id, t.item_name, (bool(t.mv), bool(t.mvt)), (bool(t.pv), bool(t.pvt)))]
                for t in D.itertuples()]
    D[['location_id', 'item_name', 'item_modifications', 'units', 'gid']].to_parquet(
        os.path.join(OUT, 'pair_groups.parquet'), index=False)
    assert D.gid.notna().all() and len(D) == D.gid.notna().sum()
    print(f'pair->group map: {len(D):,} pairs over {D.gid.nunique()} groups '
          f'-> pair_groups.parquet')
    json.dump(rows, open(os.path.join(OUT, 'corrections.json'), 'w'), indent=1)

    import collections
    ch = [r for r in rows if r['changed']]
    c = collections.Counter(r['confidence'] for r in rows)
    print(f'{len(rows)} decisions   {sum(r["units"] for r in rows):,.0f} units')
    print(f'  manual CORRECTED : {len(ch):4d}  {sum(r["units"] for r in ch):11,.0f} units')
    print(f'  manual KEPT      : {len(rows)-len(ch):4d}  {sum(r["units"] for r in rows if not r["changed"]):11,.0f} units')
    print(f'  confidence       : {dict(c)}')
    print('-> corrections.json')


if __name__ == '__main__':
    main()
