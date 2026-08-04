#!/usr/bin/env python3
"""Recompute the manual labels with the Unsure bug fixed.

The bug
-------
src/foodcast/tools/labeling_functions.py:49 relabel_items()

    meat       = is_plant_based.eq('No')  .mask(name in veg_and_drink, False).mask(name in meat_list, True)
    vegetarian = is_plant_based.eq('Yes') .mask(name in veg_and_drink, True) .mask(name in meat_list, False)
    vegan      = is_plant_based.eq('Yes') .mask(...)

`is_plant_based` takes three values: Yes / No / Unsure. Both .eq('Yes') and
.eq('No') return False for Unsure, so an item that is merely UNKNOWN comes out
as meat=False, vegetarian=False, vegan=False -- indistinguishable from a
positive judgement that the dish is not vegetarian.

The fix: a row is LABELLED only if its item_name appears on one of the manual
lists, or is_plant_based is Yes/No. Otherwise all three are NA.

Nothing in restaurant-sales is read for writing or modified. Output goes to
review/label_audit/manual_rebuilt.parquet.
"""
import pandas as pd, numpy as np, json, os, ast, glob, gc, yaml

H = os.path.dirname(os.path.abspath(__file__))
RS = '/home/godli/restaurant-sales'
LAB = f'{RS}/scripts/labeling'
CONS = f'{RS}/data/3_data_parquet_relabeled/7_truly_consolidated'

LOC = {'VLZX7K2M9QD4T': 'loc0_VLZX7K2M9QD4T', 'SRQS8F7JWA9MZ': 'loc1_SRQS8F7JWA9MZ',
       '2HRX9P6HKXA8V': 'loc2_2HRX9P6HKXA8V', 'JHDN7CF1C03X5': 'loc3_JHDN7CF1C03X5',
       'L69HYJ4Y3TR91': 'loc4_L69HYJ4Y3TR91', 'ED5J990H5VAZT': 'loc5_ED5J990H5VAZT',
       'W8T41JZK0ZMEP': 'loc6_W8T41JZK0ZMEP'}
YAML_KEYS = dict(vegan='vegan_list', vegetarian='vegetarian_list', meat='meat_list',
                 drinks='non_alcoholic_drinks', alcohol='alcoholic_drinks')
# names the inline notebooks bind their lists to
INLINE = dict(vegan=['vegan_list', 'vegan'], vegetarian=['vegetarian_list', 'vegetarian'],
              meat=['meat_list', 'meat'], drinks=['non_alcoholic_drinks', 'drinks_list', 'drinks'],
              alcohol=['alcoholic_drinks', 'alcohol_list', 'alcohol'])


def flat(x):
    """YAML entries are sometimes tuples/lists; keep only the strings."""
    out = []
    for v in (x or []):
        if isinstance(v, str):
            out.append(v)
        elif isinstance(v, (list, tuple)):
            out += [i for i in v if isinstance(i, str)]
    return out


def lists_for(loc):
    stem = LOC[loc]
    y = f'{LAB}/remapping/{stem.split("_")[0]}_remappings.yaml'
    if os.path.exists(y):
        d = yaml.load(open(y, encoding='utf-8'), Loader=yaml.UnsafeLoader)
        return {k: flat(d.get(v)) for k, v in YAML_KEYS.items()}, 'yaml'
    # otherwise the lists are literals inside the labeling_1 notebook
    nb = json.load(open(f'{LAB}/labeling_1/{stem}.ipynb', encoding='utf-8'))
    src = '\n'.join(''.join(c['source']) for c in nb['cells'] if c['cell_type'] == 'code')
    found = {}
    for line in src.split('\n'):
        pass
    try:
        tree = ast.parse(src)
    except SyntaxError:
        # notebooks can carry magics; drop offending lines
        keep = [l for l in src.split('\n') if not l.lstrip().startswith(('%', '!', '?'))]
        tree = ast.parse('\n'.join(keep))
    binds = {}
    for node in ast.walk(tree):
        if isinstance(node, ast.Assign) and len(node.targets) == 1 and isinstance(node.targets[0], ast.Name):
            try:
                binds[node.targets[0].id] = ast.literal_eval(node.value)
            except Exception:
                pass
    for k, names in INLINE.items():
        found[k] = []
        for n in names:
            if isinstance(binds.get(n), list):
                found[k] = flat(binds[n])
                break
    return found, 'inline'


def compute(df, L, fix):
    """Reproduce relabel_items. fix=True -> Unsure & unlisted becomes NA."""
    veg_and_drink = set(L['vegetarian']) | set(L['vegan']) | set(L['drinks']) | set(L['alcohol'])
    vegan_and_drink = set(L['vegan']) | set(L['drinks']) | set(L['alcohol'])
    meat_l, veg_l, vgn_l = set(L['meat']), set(L['vegetarian']), set(L['vegan'])
    n = df.item_name
    ipb = df.is_plant_based

    meat = ipb.eq('No').mask(n.isin(veg_and_drink), False).mask(n.isin(meat_l), True)
    vt = ipb.eq('Yes').mask(n.isin(veg_and_drink), True).mask(n.isin(meat_l), False)
    vg = (ipb.eq('Yes').mask(n.isin(vegan_and_drink), True)
          .mask(n.isin(veg_l) & ~n.isin(vgn_l), False).mask(n.isin(meat_l), False))
    if not fix:
        return meat, vt, vg, None
    listed = n.isin(veg_and_drink | meat_l | vgn_l | veg_l)
    known = listed | ipb.isin(['Yes', 'No'])
    return (meat.astype('boolean').mask(~known), vt.astype('boolean').mask(~known),
            vg.astype('boolean').mask(~known), known)


def main():
    out, report = [], []
    for loc in LOC:
        f = f'{CONS}/{loc}.parquet'
        if not os.path.exists(f):
            print(f'  {loc}: no parquet'); continue
        cols = ['item_name', 'item_modifications', 'item_quantity', 'is_plant_based',
                'vegan', 'vegetarian']
        have = pd.read_parquet(f).columns
        cols += [c for c in ('meat_manual', 'vegetarian_manual', 'vegan_manual') if c in have]
        d = pd.read_parquet(f, columns=cols)
        d['item_name'] = d.item_name.astype(str)
        d['item_modifications'] = d.item_modifications.fillna('').astype(str)
        L, src = lists_for(loc)

        m0, t0, g0 = compute(d, L, fix=False)[:3]
        # fidelity check against the stored columns, where they exist
        rep = dict(loc=loc, source=src, rows=len(d),
                   lists={k: len(v) for k, v in L.items()})
        if 'vegan_manual' in d.columns:
            B = lambda s: s.fillna(False).astype(bool)
            rep['repro_meat'] = float((m0.values == B(d.meat_manual).values).mean())
            rep['repro_vt'] = float((t0.values == B(d.vegetarian_manual).values).mean())
            rep['repro_vg'] = float((g0.values == B(d.vegan_manual).values).mean())
        m1, t1, g1, known = compute(d, L, fix=True)
        d = d.assign(loc=loc, old_meat=m0.values, old_vegetarian=t0.values, old_vegan=g0.values,
                     new_meat=m1.values, new_vegetarian=t1.values, new_vegan=g1.values,
                     labelled=known.values)
        rep['labelled_pct_units'] = float(
            d.loc[d.labelled, 'item_quantity'].sum() / d.item_quantity.sum())
        report.append(rep)
        out.append(d)
        del d; gc.collect()

    P = pd.concat(out, ignore_index=True)
    P.to_parquet(os.path.join(H, 'manual_rebuilt.parquet'), index=False)

    print('=== reproduction of the existing *_manual columns (1.000 = exact) ===')
    for r in report:
        s = (f"  {r['loc']:15} {r['source']:6} rows {r['rows']:>8,}  "
             f"lists v/vt/m {r['lists']['vegan']}/{r['lists']['vegetarian']}/{r['lists']['meat']}")
        if 'repro_meat' in r:
            s += (f"   repro meat {r['repro_meat']:.3f} vt {r['repro_vt']:.3f} vg {r['repro_vg']:.3f}")
        else:
            s += '   (no stored columns)'
        s += f"   labelled {r['labelled_pct_units']:.1%} of units"
        print(s)
    print(f"\n-> manual_rebuilt.parquet  ({len(P):,} rows)")


if __name__ == '__main__':
    main()
