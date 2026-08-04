#!/usr/bin/env python3
"""Rebuild the manual labels with all default behaviour removed, then compare to the AI.

Two defaults are eliminated
---------------------------
1. `is_plant_based == 'Unsure'` with no manual-list membership came out as
   meat=False, vegetarian=False, vegan=False -- an UNKNOWN presented as a
   negative judgement. Now NA.
   (Any list membership forces a flag True: meat_list -> meat, and the
   vegetarian/vegan/drinks/alcohol lists -> vegetarian. So Unsure + all-false
   is exactly "never on a list", verified 1:1 against the data.)

2. `half_vegan_list` in relabel_items assigns np.random.rand(...) < 0.5 per row,
   so those items get a coin flip that changes on every rerun. Marked NA.

Manual source, per restaurant
-----------------------------
  2_consolidated/*_sales_and_menu.parquet joined on unique_id  (5 restaurants;
  reproduces the stored *_manual columns exactly -- 1.000 on all flags)
  7_truly_consolidated *_manual columns                        (VLZX7K2M9QD4T, JHDN7CF)

L69HYJ4Y3TR91's labels exist only in 2_consolidated; they were never carried
forward under the *_manual names. They are recovered here.

Modification handling is already baked in upstream: rename_items_by_modifications
turns (item, modification-regex) into a distinct item_name -- e.g.
('Beyond Burger', 'No Cheese|Vegan', 'Vegan Beyond Burger') -- so the manual
labels are genuinely per-modification.
"""
import pandas as pd, numpy as np, json, os, glob, gc, yaml, re, sys

H = os.path.dirname(os.path.abspath(__file__))
RS = '/home/godli/restaurant-sales'
CONS2 = f'{RS}/data/3_data_parquet_relabeled/2_consolidated'
CONS7 = f'{RS}/data/3_data_parquet_relabeled/7_truly_consolidated'
LAB = f'{RS}/scripts/labeling'
T1 = ['VLZX7K2M9QD4T', 'SRQS8F7JWA9MZ', '2HRX9P6HKXA8V', 'JHDN7CF1C03X5',
      'L69HYJ4Y3TR91', 'ED5J990H5VAZT', 'W8T41JZK0ZMEP']
LOCSTEM = {'VLZX7K2M9QD4T': 'loc0', 'SRQS8F7JWA9MZ': 'loc1', '2HRX9P6HKXA8V': 'loc2',
           'JHDN7CF1C03X5': 'loc3', 'L69HYJ4Y3TR91': 'loc4',
           'ED5J990H5VAZT': 'loc5', 'W8T41JZK0ZMEP': 'loc6'}


def half_vegan_items(loc):
    y = f'{LAB}/remapping/{LOCSTEM[loc]}_remappings.yaml'
    if not os.path.exists(y):
        return set()
    d = yaml.load(open(y, encoding='utf-8'), Loader=yaml.UnsafeLoader)
    return {x for x in (d.get('half_vegan_list') or []) if isinstance(x, str)}


def build_rows():
    frames, rep = [], []
    for loc in T1:
        f7 = f'{CONS7}/{loc}.parquet'
        have = pd.read_parquet(f7).columns
        cols = ['unique_id', 'item_name', 'item_modifications', 'item_quantity',
                'is_plant_based', 'vegan', 'vegetarian']
        cols = [c for c in cols if c in have]
        stored = [c for c in ('meat_manual', 'vegetarian_manual', 'vegan_manual') if c in have]
        d = pd.read_parquet(f7, columns=cols + stored)
        d['item_name'] = d.item_name.astype(str)
        d['item_modifications'] = d.item_modifications.fillna('').astype(str)

        f2 = glob.glob(f'{CONS2}/{loc}_sales_and_menu.parquet')
        src = None
        if f2 and 'unique_id' in d.columns:
            a = (pd.read_parquet(f2[0], columns=['unique_id', 'meat', 'vegetarian', 'vegan'])
                   .rename(columns={'meat': 'm_meat', 'vegetarian': 'm_vt', 'vegan': 'm_vg'})
                   .drop_duplicates('unique_id'))
            d = d.merge(a, on='unique_id', how='left')
            src = '2_consolidated'
            # a handful of rows miss the join; fall back to the stored *_manual
            # columns so an endorsed default is kept rather than discarded
            miss = d.m_meat.isna()
            if miss.any() and stored:
                for tgt, sc in (('m_meat', 'meat_manual'), ('m_vt', 'vegetarian_manual'),
                                ('m_vg', 'vegan_manual')):
                    if sc in d.columns:
                        d.loc[miss, tgt] = d.loc[miss, sc]
                print(f'  {loc}: {int(miss.sum())} unjoined rows fell back to stored *_manual')
            del a
        elif stored:
            d = d.rename(columns={'meat_manual': 'm_meat', 'vegetarian_manual': 'm_vt',
                                  'vegan_manual': 'm_vg'})
            src = '*_manual'
        else:
            print(f'  !! {loc}: no manual source at all'); continue

        B = lambda s: s.fillna(False).astype(bool)
        d['m_meat_b'], d['m_vt_b'], d['m_vg_b'] = B(d.m_meat), B(d.m_vt), B(d.m_vg)
        joined = d.m_meat.notna() if src == '2_consolidated' else pd.Series(True, index=d.index)

        allfalse = ~d.m_meat_b & ~d.m_vt_b & ~d.m_vg_b
        unsure = d.is_plant_based.eq('Unsure')
        hv = d.item_name.isin(half_vegan_items(loc))
        d['unknown'] = (unsure & allfalse) | ~joined | hv
        d['loc'] = loc
        d['ai_v'] = B(d.vegan); d['ai_vt'] = B(d.vegetarian)

        rep.append(dict(loc=loc, source=src, rows=len(d),
                        units=float(d.item_quantity.sum()),
                        unknown_rows=int(d.unknown.sum()),
                        unknown_units=float(d.loc[d.unknown, 'item_quantity'].sum()),
                        unjoined=int((~joined).sum()), halfvegan=int(hv.sum())))
        frames.append(d[['loc', 'item_name', 'item_modifications', 'item_quantity',
                         'is_plant_based', 'm_meat_b', 'm_vt_b', 'm_vg_b',
                         'ai_v', 'ai_vt', 'unknown']])
        del d; gc.collect()
    return pd.concat(frames, ignore_index=True), rep


def main():
    R, rep = build_rows()
    print('=== manual source and the defaults removed ===')
    print(f"{'restaurant':16} {'source':16} {'rows':>9} {'units':>11} {'unknown':>9} {'unk units':>11} {'%':>6}")
    for r in rep:
        print(f"  {r['loc']:14} {r['source']:16} {r['rows']:>9,} {r['units']:>11,.0f} "
              f"{r['unknown_rows']:>9,} {r['unknown_units']:>11,.0f} "
              f"{100*r['unknown_units']/r['units']:>5.1f}%"
              + (f"   (unjoined {r['unjoined']}, coinflip {r['halfvegan']})"
                 if r['unjoined'] or r['halfvegan'] else ''))
    tot = R.item_quantity.sum(); unk = R.loc[R.unknown, 'item_quantity'].sum()
    print(f"\n  TOTAL  {len(R):,} rows  {tot:,.0f} units   unknown {unk:,.0f} ({100*unk/tot:.1f}%)")

    # ---- pair level -------------------------------------------------------
    K = R[~R.unknown]
    P = (K.groupby(['loc', 'item_name', 'item_modifications'], dropna=False)
           .agg(units=('item_quantity', 'sum'), rows=('item_quantity', 'size'),
                mv=('m_vg_b', 'mean'), mvt=('m_vt_b', 'mean'),
                av=('ai_v', 'mean'), avt=('ai_vt', 'mean')).reset_index())
    mixed = P[((P.mv > 0) & (P.mv < 1)) | ((P.mvt > 0) & (P.mvt < 1))]
    print(f"\n  labelled pairs {len(P):,}   internally mixed {len(mixed):,} "
          f"({mixed.units.sum():,.0f} units) -> treated as unknown")
    P = P[~P.index.isin(mixed.index)]
    for c in ('mv', 'mvt', 'av', 'avt'):
        P[c] = P[c] > 0.5
    D = P[(P.mv != P.av) | (P.mvt != P.avt)].copy()
    print(f"\n=== DISCREPANCIES manual vs AI, labelled pairs only ===")
    print(f"  pairs      {len(D):,} of {len(P):,}   {D.units.sum():,.0f} units "
          f"({100*D.units.sum()/P.units.sum():.1f}% of labelled volume)")
    print(f"  items      {D.groupby(['loc','item_name']).ngroups:,}")
    print(f"  vegan differs      {int((D.mv!=D.av).sum()):,}")
    print(f"  vegetarian differs {int((D.mvt!=D.avt).sum()):,}")
    print('\n  by restaurant:')
    g = D.groupby('loc').agg(pairs=('units', 'size'), units=('units', 'sum'))
    g['items'] = D.groupby('loc').item_name.nunique()
    print(g.sort_values('units', ascending=False).to_string())
    R.to_parquet(f'{H}/manual_fixed_rows.parquet', index=False)
    D.to_parquet(f'{H}/discrepancies.parquet', index=False)
    P.to_parquet(f'{H}/labelled_pairs.parquet', index=False)
    print(f"\n-> manual_fixed_rows.parquet, labelled_pairs.parquet, discrepancies.parquet")


if __name__ == '__main__':
    main()
