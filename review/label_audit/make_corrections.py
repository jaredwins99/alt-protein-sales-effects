#!/usr/bin/env python3
"""Turn the rebuilt discrepancies into reviewable correction groups.

Input   discrepancies.parquet   (pair level, labelled pairs only, defaults removed)
Output  corrections.json        one row per group, for the app
        pair_groups.parquet     every disagreeing pair -> its group id

A group is (restaurant, item_name, manual label, proposed label). Proposals are
computed PER PAIR and grouped afterwards, so a group is never a blanket
item-level verdict.
"""
import pandas as pd, json, os, gc, sys

H = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, H)
from correct_manual import VLZX7K2M9QD4T_rule, OVERRIDE, classify   # noqa: E402

RS = '/home/godli/restaurant-sales'
CONS7 = f'{RS}/data/3_data_parquet_relabeled/7_truly_consolidated'


def main():
    D = pd.read_parquet(f'{H}/discrepancies.parquet').rename(columns={'loc': 'rest'})

    # attach the AI's reasoning for each pair
    rs = []
    for loc in D.rest.unique():
        d = pd.read_parquet(f'{CONS7}/{loc}.parquet',
                            columns=['item_name', 'item_modifications', 'reasoning_x'])
        d['item_name'] = d.item_name.astype(str)
        d['item_modifications'] = d.item_modifications.fillna('').astype(str)
        d = (d.dropna(subset=['reasoning_x'])
               .groupby(['item_name', 'item_modifications']).reasoning_x.first().reset_index())
        d['rest'] = loc
        rs.append(d); del d; gc.collect()
    RSN = pd.concat(rs, ignore_index=True)
    D = D.merge(RSN, on=['rest', 'item_name', 'item_modifications'], how='left')
    D['reasoning_x'] = D.reasoning_x.fillna('')

    pv, pvt, conf, why = [], [], [], []
    for t in D.itertuples():
        item, mods, rsn = str(t.item_name), str(t.item_modifications or ''), t.reasoning_x
        res = VLZX7K2M9QD4T_rule(item, mods) if t.rest == 'VLZX7K2M9QD4T' else None
        if res is not None:
            a, b, w = res
            if a is None:
                a, b, c = bool(t.mv), bool(t.mvt), 'ask'
            else:
                c = 'high'
            pv.append(a); pvt.append(b); conf.append(c); why.append(w); continue
        ov = OVERRIDE.get((t.rest, item))
        if ov and ov.get('follow_ai'):
            pv.append(bool(t.av)); pvt.append(bool(t.avt)); conf.append(ov['conf']); why.append(ov['why']); continue
        if ov:
            pv.append(ov['v']); pvt.append(ov['vt']); conf.append(ov['conf']); why.append(ov['why']); continue
        a, b, basis = classify(rsn, bool(t.av), bool(t.avt))
        if a is None:
            pv.append(bool(t.mv)); pvt.append(bool(t.mvt)); conf.append('ask')
            why.append(f"The AI's reasoning ({rsn!r}) names no ingredient I can decide on, so no change "
                       f"is asserted and the manual label stands. Needs your knowledge of the dish.")
        else:
            pv.append(a); pvt.append(b)
            conf.append('high' if (a == bool(t.av) and b == bool(t.avt)) else 'medium')
            why.append(f"The AI's reasoning is {rsn!r}. Under the stated standard that gives "
                       f"vegetarian={b} and vegan={a}, because {basis}. "
                       + ("The manual label disagrees with this and is corrected."
                          if (a != bool(t.mv) or b != bool(t.mvt))
                          else "This matches the manual label, which is kept."))
    D['pv'], D['pvt'], D['conf'], D['w'] = pv, pvt, conf, why

    G = (D.groupby(['rest', 'item_name', 'mv', 'mvt', 'pv', 'pvt'])
           .agg(units=('units', 'sum'), pairs=('units', 'size'),
                modlist=('item_modifications', lambda s: sorted({x for x in s if x})[:10]),
                n_modstrings=('item_modifications', lambda s: len({x for x in s if x})),
                mods=('item_modifications', lambda s: '; '.join(sorted({x for x in s if x})[:3])[:70]),
                why=('w', lambda s: s.iloc[0]), conf=('conf', lambda s: s.mode().iloc[0]),
                av=('av', lambda s: bool(s.mode().iloc[0])), avt=('avt', lambda s: bool(s.mode().iloc[0])),
                rsn=('reasoning_x', lambda s: next((x for x in s if x), '')))
           .reset_index().sort_values('units', ascending=False).reset_index(drop=True))

    tot = pd.read_parquet(f'{H}/labelled_pairs.parquet').units.sum()
    rows = []
    for i, r in G.iterrows():
        rows.append(dict(
            rid=i + 1, loc=r.rest, item=r.item_name,
            scope=(r.mods if r.mods else '(no modification)'),
            modlist=list(r.modlist), n_modstrings=int(r.n_modstrings),
            field='vegan+vegetarian', units=float(r.units), pairs=int(r.pairs),
            manual=[bool(r.mv), bool(r.mvt)], proposed=[bool(r.pv), bool(r.pvt)],
            confidence=r.conf, changed=bool((r.pv != r.mv) or (r.pvt != r.mvt)), reason=r.why,
            ai={'vegan': bool(r.av), 'vegetarian': bool(r.avt), 'reasoning': r.rsn,
                'categories': None, 'strict_vegan': None, 'mpbamod': None},
            menu_desc=None, pct_t1=round(100 * r.units / tot, 3), man_full=None, mods=[]))
    json.dump(rows, open(f'{H}/corrections.json', 'w'), indent=1)

    gid = {(r['loc'], r['item'], tuple(r['manual']), tuple(r['proposed'])): r['rid'] for r in rows}
    D['gid'] = [gid[(t.rest, t.item_name, (bool(t.mv), bool(t.mvt)), (bool(t.pv), bool(t.pvt)))]
                for t in D.itertuples()]
    D.rename(columns={'rest': 'location_id'})[
        ['location_id', 'item_name', 'item_modifications', 'units', 'gid']].to_parquet(
        f'{H}/pair_groups.parquet', index=False)

    import collections
    ch = [r for r in rows if r['changed']]
    print(f'{len(rows)} groups over {len(D):,} pairs   {sum(r["units"] for r in rows):,.0f} units')
    print(f'  manual CORRECTED : {len(ch):4d}  {sum(r["units"] for r in ch):11,.0f} units')
    print(f'  manual KEPT      : {len(rows)-len(ch):4d}  '
          f'{sum(r["units"] for r in rows if not r["changed"]):11,.0f} units')
    print(f'  confidence       : {dict(collections.Counter(r["confidence"] for r in rows))}')
    print('-> corrections.json, pair_groups.parquet')


if __name__ == '__main__':
    main()
