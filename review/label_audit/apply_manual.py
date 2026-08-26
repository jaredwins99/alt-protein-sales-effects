#!/usr/bin/env python3
"""Write corrected_manual from the groups you accepted.

Granularity: item_name x item_modifications. A correction is accepted for a
GROUP of pairs -- the pairs sharing an item, a manual label and a proposed
label -- and is written to exactly those pairs. It is never applied at the item
level, so two groups of the same item can receive different corrections, and a
group you reject stays untouched even when a sibling group of the same item is
accepted.

The mapping comes from pair_groups.parquet, which correct_manual.py emits with
one row per disagreeing pair and its gid. gid == the rid shown in the app.

Everything is read-only except corrected_manual.parquet.
"""
import pandas as pd, json, os

H = os.path.dirname(os.path.abspath(__file__))
# tests must set VERDICTS_FILE; verdicts.jsonl is never truncated or written by me
VERD = os.environ.get('VERDICTS_FILE') or os.path.join(H, 'verdicts.jsonl')
CORR = os.path.join(H, 'corrections.json')
MAP = os.path.join(H, 'pair_groups.parquet')
DST = os.path.join(H, 'corrected_manual.parquet')


def jl(p):
    if not os.path.exists(p):
        return []
    return [json.loads(l) for l in open(p, encoding='utf-8') if l.strip()]


def main():
    corr = {c['rid']: c for c in json.load(open(CORR, encoding='utf-8'))}
    latest = {}
    for r in jl(VERD):
        latest[r['rid']] = r
    # verdict -> the label written for that group
    #   accept  my proposal          ai      the AI's label
    #   reject  the manual label     edit    NOTHING -- goes on my worklist
    #
    # `edit` is deliberately not a label. It means "send this back for a fix",
    # so the group stays unresolved and is reported as pending rather than
    # silently inheriting the manual label the user never endorsed.
    writes, pending = {}, {}
    for rid, r in latest.items():
        if rid not in corr:
            continue
        c, v = corr[rid], r.get('verdict')
        if v == 'accept':
            writes[rid] = (list(c['proposed']), 'accept')
        elif v == 'ai':
            writes[rid] = ([bool(c['ai']['vegan']), bool(c['ai']['vegetarian'])], 'ai')
        elif v == 'reject':
            writes[rid] = (list(c['manual']), 'manual_kept')
        elif v == 'edit':
            pending[rid] = r.get('note', '')

    n = {v: sum(1 for r in latest.values() if r.get('verdict') == v)
         for v in ('accept', 'ai', 'reject', 'edit')}
    print(f'{len(latest)} decided of {len(corr)}  ->  accept {n["accept"]}, ai {n["ai"]}, '
          f'keep-manual {n["reject"]}, for revision {n["edit"]}, undecided {len(corr)-len(latest)}')
    if not writes and not pending:
        print('Nothing decided yet. Go to http://192.168.0.124:8885 first.')
        return

    P = pd.read_parquet(os.path.join(H, 't1_pairs.parquet'))
    P = P[P.man_vegan.notna() | P.man_vegetarian.notna()].copy()
    B = lambda s: s.fillna(False).astype(bool)
    P['manual_vegan'], P['manual_vegetarian'] = B(P.man_vegan), B(P.man_vegetarian)
    P['ai_v'], P['ai_vt'] = B(P.ai_vegan), B(P.ai_vegetarian)

    M = pd.read_parquet(MAP)[['location_id', 'item_name', 'item_modifications', 'gid']]
    K = ['location_id', 'item_name', 'item_modifications']
    P = P.merge(M, on=K, how='left')
    if int(P.gid.notna().sum()) != len(M):
        print(f'  ! mapping matched {int(P.gid.notna().sum()):,} of {len(M):,} pairs')

    # start from the manual label, then overwrite only the accepted groups
    # nullable boolean: a group on my worklist must be able to hold "no label yet"
    P['corrected_vegan'] = P.manual_vegan.astype('boolean')
    P['corrected_vegetarian'] = P.manual_vegetarian.astype('boolean')
    P['applied_gid'] = 0
    P['source'] = 'undecided'
    # pairs that never disagreed carry the manual label and were never in question
    P.loc[P.gid.isna(), 'source'] = 'agreed'

    for rid in pending:
        m = P.gid == rid
        P.loc[m, 'source'] = 'pending_review'
        P.loc[m, 'corrected_vegan'] = pd.NA
        P.loc[m, 'corrected_vegetarian'] = pd.NA

    n_pairs = 0
    for rid in sorted(writes):
        (pv, pvt), src = writes[rid]
        m = P.gid == rid
        if not m.any():
            print(f'  ! group {rid} matched no pairs')
            continue
        P.loc[m, 'corrected_vegan'] = pv
        P.loc[m, 'corrected_vegetarian'] = pvt
        P.loc[m, 'applied_gid'] = rid
        P.loc[m, 'source'] = src
        n_pairs += int(m.sum())

    out = P[K + ['units', 'manual_vegan', 'manual_vegetarian', 'ai_v', 'ai_vt',
                 'corrected_vegan', 'corrected_vegetarian', 'gid', 'applied_gid',
                 'source']].rename(
        columns={'ai_v': 'ai_vegan', 'ai_vt': 'ai_vegetarian', 'gid': 'group_id'})
    out.to_parquet(DST, index=False)

    print('\nlabel provenance, by pair:')
    for s, k in out.groupby('source').size().items():
        print(f'   {s:15} {k:>8,} pairs   {out.loc[out.source==s,"units"].sum():>11,.0f} units')

    if pending:
        pu = out.loc[out.source == 'pending_review', 'units'].sum()
        print(f'\n  {len(pending)} group(s) are PENDING REVISION -- {pu:,.0f} units left with a null '
              f'label, deliberately.\n  Run:  python3 todo.py')

    ch = out[out.applied_gid > 0]
    touched = ch.groupby(['location_id', 'item_name']).ngroups
    multi = int((out[out.group_id.notna()].groupby(['location_id', 'item_name'])
                 .group_id.nunique() > 1).sum())
    print(f'\npairs rewritten  {n_pairs:,}   ({ch.units.sum():,.0f} units)')
    print(f'items touched    {touched}   (one item can receive several different corrections)')
    print(f'items whose disagreeing pairs span >1 group: {multi}'
          f'   <- an item-level write would corrupt these')
    print(f'\nvegan       manual {int(out.manual_vegan.sum()):,}'
          f' -> corrected {int(out.corrected_vegan.sum()):,}')
    print(f'vegetarian  manual {int(out.manual_vegetarian.sum()):,}'
          f' -> corrected {int(out.corrected_vegetarian.sum()):,}')
    print(f'\n-> {DST}')


if __name__ == '__main__':
    main()
