#!/usr/bin/env python3
"""Rebuild location 1's general outcomes in the ITS model table from a label table.

    python review/label_audit/apply_location1_labels.py --labels <table.csv> [--require-complete]

The label table has one row per (item_name, item_modifications) at location 1
(VLZX7K2M9QD4T) and the columns vegan and vegetarian; meat, chicken and
location_id are optional. Every stage-7 line of location 1 whose pair is in the
table takes the table's vegan and vegetarian flags; a line whose pair is not in
the table keeps the AI label the published fits used, unless --require-complete
is given, which refuses any line the table does not cover. A complete table is
the intended input; a short table of overrides is accepted for testing.

The daily outcomes are rebuilt the way scripts/4.0_modeling_prep_2.ipynb in
restaurant-sales builds them: each line counts item_quantity units, outcome =
1 * flag, meat = 1 - vegetarian, nonvegan = 1 - vegan, summed by UTC day, and a
day with no line is 0. Only vegan_outcome, vegetarian_outcome, nonvegan_outcome
and meat_outcome of location 1's rows are replaced. Every other column of every
row, and every column of the other 19 restaurants, is carried over unchanged.
total_outcome cannot change, and chicken_fish_outcome is not rebuilt (the table
has no fish flag, and no chicken_fish fit is being refit).

Not rebuilt either: the price covariates (vegan/vegetarian/meat_price_real and
the *_window_* columns behind them) are averages over the same flags in the
notebook. They keep the published values, so a refit changes the outcome series
only.

Checked before anything is written, and the script stops if any fails:
  1. the stage-7 lines with their ORIGINAL labels rebuild location 1's five
     general outcomes in data/4_data_parquet_modeling/its/finalized.parquet
     exactly, every day;
  2. in the new table only location 1's rows and only those four outcome
     columns differ from the original;
  3. meat + vegetarian = total and vegan + nonvegan = total on every location 1
     day, before and after;
  4. no day before the first relabelled line changes.

Inputs are read only: restaurant-sales (RS_ROOT, default /home/godli/restaurant-
sales) and the original table. Writes the new table (default
data/4_data_parquet_modeling/its_location1_relabel/finalized.parquet, never the
original), labels_source.txt beside it (the label table's path in its git
checkout, commit, sha256 and coverage), and review/label_audit/location1_relabel_changes.csv, one row per
relabelled pair with its units.

Location 1's stage-7 file is the one file in that folder not named by an
anonymised ID. It is found by elimination, and its name is checked out of
everything this script writes. One stage-7 item carries location 1's own name;
it is renamed to L1 before the join, as the label table names it (hens
studies/location1/labels/build_labels.py).

location1_labels_fixture_blacksheep.csv is a temporary stand-in table: the
Black Sheep pairs only (vegetarian = TRUE, vegan as the AI had it), following
correct_manual.py, which rules Black Sheep a plant-based mock lamb (OVERRIDE
for Black Sheep Sandwich and Salad; VLZX7K2M9QD4T_rule masks "Black Sheep
Lamb" in modifications before looking for meat). Pairs that also add a real
meat (Add Chicken, Pork Set Up, ...) stay meat.
"""
import argparse, glob, hashlib, os, re, subprocess, sys
import numpy as np, pandas as pd, pyarrow as pa, pyarrow.parquet as pq

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.abspath(os.path.join(HERE, '..', '..'))
RS = os.environ.get('RS_ROOT', '/home/godli/restaurant-sales')
S7 = os.path.join(RS, 'data', '3_data_parquet_relabeled', '7_truly_consolidated')
SRC = os.path.join(ROOT, 'data', '4_data_parquet_modeling', 'its', 'finalized.parquet')
DST = os.path.join(ROOT, 'data', '4_data_parquet_modeling', 'its_location1_relabel', 'finalized.parquet')
CHANGES = os.path.join(HERE, 'location1_relabel_changes.csv')
LOC1 = 'VLZX7K2M9QD4T'
KEY = ['item_name', 'item_modifications']
ANON = 'L1'      # how the label table writes location 1's own name inside an item name
OUTCOMES = ['vegan', 'vegetarian', 'nonvegan', 'meat']          # the four rebuilt
CHECKED = OUTCOMES + ['total']                                   # rebuilt and compared


def stage7_location1():
    """Location 1's stage-7 file and its stem (the stem is never printed or written)."""
    odd = [f for f in sorted(glob.glob(os.path.join(S7, '*.parquet')))
           if not re.fullmatch(r'[A-Z0-9]{13}', os.path.basename(f)[:-len('.parquet')])]
    if len(odd) != 1:
        sys.exit(f'expected exactly one non-ID file in {S7}, found {len(odd)}')
    return odd[0], os.path.basename(odd[0])[:-len('.parquet')]


def as_bool(s, name):
    m = {'true': True, '1': True, 't': True, 'yes': True, 'false': False, '0': False, 'f': False, 'no': False}
    out = s.astype(str).str.strip().str.lower().map(m)
    if out.isna().any():
        sys.exit(f'label table: column {name} has values that are not TRUE/FALSE: '
                 f'{sorted(s[out.isna()].astype(str).unique())[:5]}')
    return out.astype(bool)


def read_labels(path, allow_meat_mismatch):
    t = pd.read_csv(path, dtype=str, keep_default_na=False)
    missing = {'item_name', 'item_modifications', 'vegan', 'vegetarian'} - set(t.columns)
    if missing:
        sys.exit(f'label table {path} lacks columns {sorted(missing)}')
    if 'location_id' in t.columns:
        t = t[t.location_id == LOC1]
    for c in ['vegan', 'vegetarian'] + [c for c in ['meat'] if c in t.columns]:
        t[c] = as_bool(t[c], c)
    if 'meat' in t.columns:
        bad = t.meat == t.vegetarian
        if bad.any() and not allow_meat_mismatch:
            sys.exit(f'label table: {int(bad.sum())} pairs have meat == vegetarian; the model defines meat as '
                     f'not vegetarian. Fix the table, or pass --allow-meat-mismatch to take meat from vegetarian.')
    if (t.vegan & ~t.vegetarian).any():
        sys.exit(f'label table: {int((t.vegan & ~t.vegetarian).sum())} pairs are vegan but not vegetarian')
    dup = t.duplicated(KEY, keep=False)
    if dup.any():
        conflict = t[dup].groupby(KEY)[['vegan', 'vegetarian']].nunique().max(axis=1) > 1
        if conflict.any():
            sys.exit(f'label table: {int(conflict.sum())} pairs appear more than once with different flags')
        t = t.drop_duplicates(KEY)
    return t[KEY + ['vegan', 'vegetarian']]


def describe(path):
    """The label table as its path inside its git checkout, with the commit and branch that hold it,
    so no workstation path is recorded; a file outside git is named by its basename."""
    d = os.path.dirname(os.path.abspath(path))
    git = lambda *a: subprocess.run(['git', '-C', d, *a], capture_output=True, text=True).stdout.strip()
    top = git('rev-parse', '--show-toplevel')
    if not top:
        return os.path.basename(path)
    dirty = ', modified since' if git('status', '--porcelain', '--', os.path.abspath(path)) else ''
    return (f"{os.path.relpath(os.path.abspath(path), top)} (git commit "
            f"{git('log', '-1', '--format=%h', '--', os.path.abspath(path))}{dirty}, "
            f"branch {git('rev-parse', '--abbrev-ref', 'HEAD')})")


def daily(day, q, vegan, veg):
    """The notebook's general outcomes: units of each flag summed by UTC day."""
    return (pd.DataFrame({'created_at': day, 'total': q, 'vegan': q * vegan, 'vegetarian': q * veg,
                          'nonvegan': q * (1 - vegan), 'meat': q * (1 - veg)})
            .groupby('created_at').sum())


def main():
    ap = argparse.ArgumentParser(description=__doc__.split('\n')[0])
    ap.add_argument('--labels', required=True)
    ap.add_argument('--require-complete', action='store_true')
    ap.add_argument('--allow-meat-mismatch', action='store_true')
    ap.add_argument('--out', default=DST)
    a = ap.parse_args()
    out = os.path.abspath(a.out)
    if out == os.path.abspath(SRC):
        sys.exit('refusing to overwrite the original ITS table')

    f7, hidden = stage7_location1()
    hid = re.compile(re.escape(hidden), re.I)
    lines = pd.read_parquet(f7, columns=['created_at', 'item_quantity', 'vegan', 'vegetarian'] + KEY)
    lines['item_name'] = lines.item_name.astype(str).str.replace(hid, ANON, regex=True)
    lines['item_modifications'] = lines.item_modifications.fillna('').astype(str)
    lines['day'] = lines.created_at.dt.tz_convert('UTC').dt.normalize()
    q = lines.item_quantity.to_numpy()
    if (q != np.floor(q)).any() or lines[['vegan', 'vegetarian']].isna().any().any():
        sys.exit('stage-7 lines have fractional quantities or missing labels; the rebuild assumes neither')

    # ── relabel ──────────────────────────────────────────────────────────
    labels = read_labels(a.labels, a.allow_meat_mismatch)
    j = lines[KEY].merge(labels, on=KEY, how='left', suffixes=('', '_new'), validate='many_to_one')
    hit = j.vegan.notna().to_numpy()
    print(f'label table: {len(labels)} pairs; covers {hit.mean():.2%} of location 1 lines, '
          f'{q[hit].sum() / q.sum():.2%} of units')
    if a.require_complete and not hit.all():
        miss = lines[~hit].groupby(KEY).item_quantity.sum().sort_values(ascending=False)
        sys.exit(f'--require-complete: {len(miss)} pairs ({int(miss.sum())} units) are not in the table')
    v0, g0 = lines.vegan.to_numpy(bool), lines.vegetarian.to_numpy(bool)
    v1 = np.where(hit, j.vegan.to_numpy(object), v0).astype(bool)
    g1 = np.where(hit, j.vegetarian.to_numpy(object), g0).astype(bool)

    # ── rebuild, and check 1 ─────────────────────────────────────────────
    old = daily(lines.day, q, v0.astype(int), g0.astype(int))
    new = daily(lines.day, q, v1.astype(int), g1.astype(int))
    T = pq.read_table(SRC)
    loc = T.column('location_id').to_numpy(zero_copy_only=False)
    rows = np.flatnonzero(loc == LOC1)
    days = pd.DatetimeIndex(T.column('created_at').to_pandas().iloc[rows])
    if not set(old.index) <= set(days):
        sys.exit('stage-7 has location 1 days outside its ITS rows')
    old, new = old.reindex(days, fill_value=0), new.reindex(days, fill_value=0)
    for o in CHECKED:
        have = T.column(f'{o}_outcome').to_numpy()[rows]
        if not np.array_equal(have, old[o].to_numpy(float)):
            sys.exit(f'check 1 failed: original labels do not rebuild {o}_outcome '
                     f'({int((have != old[o].to_numpy(float)).sum())} days differ)')
    print(f'check 1: original labels rebuild all {len(CHECKED)} general outcomes on all {len(rows)} days exactly')

    # ── new table ────────────────────────────────────────────────────────
    N = T
    for o in OUTCOMES:
        col = T.column(f'{o}_outcome').to_numpy().copy()
        col[rows] = new[o].to_numpy(float)
        i = N.schema.get_field_index(f'{o}_outcome')
        N = N.set_column(i, N.schema.field(i), pa.array(col, type=N.schema.field(i).type))

    # ── checks 2-4 ───────────────────────────────────────────────────────
    other = np.ones(len(loc), bool); other[rows] = False
    for name in T.column_names:
        a0, a1 = T.column(name), N.column(name)
        if name not in [f'{o}_outcome' for o in OUTCOMES]:
            if not a0.equals(a1):
                sys.exit(f'check 2 failed: {name} changed')
        elif not np.array_equal(a0.to_numpy()[other], a1.to_numpy()[other]):
            sys.exit(f'check 2 failed: {name} changed outside location 1')
    if N.schema != T.schema or not N.schema.equals(T.schema, check_metadata=True):
        sys.exit('check 2 failed: schema changed')
    changed = [o for o in OUTCOMES if not new[o].equals(old[o])]
    print(f'check 2: only location 1 x {changed or "nothing"} differ; the other '
          f'{len(T.column_names) - len(OUTCOMES)} columns and the other {len(loc) - len(rows)} rows unchanged')
    for x, tag in [(old, 'before'), (new, 'after')]:
        if not ((x.meat + x.vegetarian == x.total).all() and (x.vegan + x.nonvegan == x.total).all()):
            sys.exit(f'check 3 failed {tag}')
    print('check 3: meat + vegetarian = total and vegan + nonvegan = total on every day, before and after')
    flipped = (v0 != v1) | (g0 != g1)
    if flipped.any():
        first = lines.day[flipped].min()
        diff = (new[OUTCOMES] != old[OUTCOMES]).any(axis=1)
        if diff[diff.index < first].any():
            sys.exit('check 4 failed: a day before the first relabelled line changed')
        print(f'check 4: first relabelled line {first.date()}, first changed day '
              f'{diff[diff].index.min().date() if diff.any() else "none"}, nothing earlier changed')

    # ── report ───────────────────────────────────────────────────────────
    intro = pd.read_csv(os.path.join(ROOT, 'data', 'before_after_details_true.csv')).set_index('location_id')
    cut = pd.Timestamp(intro.loc[LOC1, 'cross_over_date']).tz_convert('UTC')
    pre = old.index < cut
    per = pd.DataFrame({(p, w): x[CHECKED][m].sum() for p, m in [(f'before {cut.date()}', pre),
                                                                  (f'from {cut.date()}', ~pre), ('all', pre | ~pre)]
                        for w, x in [('old', old), ('new', new)]}).astype(int)
    print('units, location 1 (all of its rows, which is the window every fit uses):')
    print(per.to_string())

    ch = lines.assign(units=q, vegan_old=v0, vegetarian_old=g0, vegan_new=v1, vegetarian_new=g1)[flipped]
    ch = (ch.groupby(KEY + ['vegan_old', 'vegetarian_old', 'vegan_new', 'vegetarian_new'])
          .agg(units=('units', 'sum'), lines=('units', 'size'), first_day=('day', 'min'), last_day=('day', 'max'))
          .reset_index().sort_values('units', ascending=False))
    ch['units'] = ch.units.astype(int)
    for c in ['first_day', 'last_day']:
        ch[c] = ch[c].dt.date.astype(str)
    ch.insert(0, 'location_id', LOC1)
    if ch.astype(str).apply(lambda s: s.str.contains(hid)).any().any():
        sys.exit('location 1 stem found in the change list')

    os.makedirs(os.path.dirname(out), exist_ok=True)
    pq.write_table(N, out, compression='snappy')
    back = pq.read_table(out)
    if not back.equals(N) or not back.schema.equals(T.schema, check_metadata=True):
        sys.exit(f'{out} does not read back as written')
    ch.to_csv(CHANGES, index=False)
    # what the table was built from; bash_scripts/slurm/slurm_location1_relabel.sh refuses to fit
    # a table built from a label table that does not cover every line
    src = '\n'.join([f'labels: {describe(a.labels)}',
                     f'sha256: {hashlib.sha256(open(a.labels, "rb").read()).hexdigest()}',
                     f'pairs: {len(labels)}',
                     f'units covered: {q[hit].sum() / q.sum():.4%}',
                     f'complete: {"yes" if hit.all() else "no"}',
                     f'relabelled pairs: {len(ch)}, units: {int(ch.units.sum())}',
                     f'changed outcomes: {" ".join(changed) or "none"}', ''])
    if hid.search(src):
        sys.exit('location 1 stem found in the label table path')
    open(os.path.join(os.path.dirname(out), 'labels_source.txt'), 'w').write(src)
    print(f'wrote {os.path.relpath(out, ROOT)}, labels_source.txt beside it, and '
          f'{os.path.relpath(CHANGES, ROOT)} ({len(ch)} relabelled pairs, {int(ch.units.sum())} units)')


if __name__ == '__main__':
    main()
