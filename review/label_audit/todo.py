#!/usr/bin/env python3
"""My worklist: every group you sent back with `e`, and what you said about it.

`e` in the app is not a label. It means "send this back for a fix". Those
groups carry no corrected label until I change the rule that produced them and
regenerate, at which point they come back into the app as a fresh proposal for
you to accept, override with the AI's label, or send back again.

    python3 todo.py            open items
    python3 todo.py --all      include ones I have since acted on
"""
import json, os, sys, argparse

H = os.path.dirname(os.path.abspath(__file__))
# tests must set VERDICTS_FILE; verdicts.jsonl is never truncated or written by me
VERD = os.environ.get('VERDICTS_FILE') or os.path.join(H, 'verdicts.jsonl')
CORR = os.path.join(H, 'corrections.json')
DONE = os.path.join(H, 'todo_resolved.json')


def jl(p):
    if not os.path.exists(p):
        return []
    return [json.loads(l) for l in open(p, encoding='utf-8') if l.strip()]


def fl(a):
    return f"vegan={'T' if a[0] else 'F'} veg={'T' if a[1] else 'F'}"


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--all', action='store_true')
    a = ap.parse_args()

    corr = {c['rid']: c for c in json.load(open(CORR, encoding='utf-8'))}
    latest = {}
    for r in jl(VERD):
        latest[r['rid']] = r
    resolved = set()
    if os.path.exists(DONE) and not a.all:
        resolved = set(json.load(open(DONE, encoding='utf-8')).get('resolved', []))

    todo = [(rid, r) for rid, r in sorted(latest.items())
            if r.get('verdict') == 'edit' and rid in corr and rid not in resolved]

    if not todo:
        print('Worklist empty. Nothing is waiting on me.')
        n = sum(1 for r in latest.values() if r.get('verdict') == 'edit')
        if n:
            print(f'({n} group(s) were sent back and are marked resolved; --all to see them)')
        return

    units = sum(corr[rid]['units'] for rid, _ in todo)
    print(f'{len(todo)} group(s) waiting on me   {units:,.0f} units\n')
    for rid, v in todo:
        c = corr[rid]
        print('=' * 96)
        print(f'GROUP {rid}   {c["loc"]}  /  {c["item"]}')
        print(f'  {c["units"]:,.0f} units · {c["pairs"]} pairs · {c.get("n_modstrings", 0)} modification strings')
        print(f'  manual   {fl(c["manual"])}')
        print(f'  I said   {fl(c["proposed"])}   ({c["confidence"]})')
        print(f'  AI said  {fl([c["ai"]["vegan"], c["ai"]["vegetarian"]])}')
        print(f'\n  YOUR NOTE: {v.get("note") or "(none given)"}\n')
        for m in (c.get('modlist') or [])[:6]:
            print(f'    {m[:90]}')
        if c.get('n_modstrings', 0) > 6:
            print(f'    ... +{c["n_modstrings"]-6} more')
        if c.get('menu_desc'):
            print(f'\n  MENU: {c["menu_desc"][:180]}')
        print()
    print('=' * 96)
    print('To act on these: change the rule in correct_manual.py (VLZX7K2M9QD4T_rule / OVERRIDE /')
    print('classify), rerun correct_manual.py + dish_definitions.py, then mark them resolved.')


if __name__ == '__main__':
    main()
