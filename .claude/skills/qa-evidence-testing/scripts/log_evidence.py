"""Render OpenSearch search JSON into an HTML evidence page (highlighting key lines) for screenshotting.
usage: log_evidence.py <out.html> <title> <subtitle> <highlight-regex> <json> [<json> ...]"""
import html, json, re, sys
out, title, sub, hl = sys.argv[1:5]
rows = []
for path in sys.argv[5:]:
    data = json.load(open(path))
    # TC-02-company-profile-logs.json -> company-profile
    app = re.sub(r'^TC-\d+-', '', path.rsplit('/', 1)[-1].split('-logs')[0])
    for h in data.get('hits', []):
        msg = h.get('message') or h.get('@message') or ''
        rows.append((h.get('ts_sgt', ''), app, h.get('log_level') or '', msg, h.get('_index', ''), h.get('_id', '')))
rows.sort()
rx = re.compile(hl)
body = ''.join(
    f"<tr class='{'hl' if rx.search(m) else ''}'><td>{html.escape(t)}</td><td>{html.escape(a)}</td><td>{html.escape(l)}</td>"
    f"<td>{html.escape(m[:400])}</td><td class='id'>{html.escape(i)}<br>{html.escape(d)}</td></tr>" for t, a, l, m, i, d in rows)
n = sum(1 for r in rows if rx.search(r[3]))
open(out, 'w').write(f"""<html><head><meta charset='utf-8'><style>
body{{font-family:-apple-system,Helvetica,sans-serif;margin:24px}} h1{{font-size:22px;margin:0}} .sub{{color:#555;margin:6px 0 4px}}
.n{{font-weight:600;margin-bottom:12px}} table{{border-collapse:collapse;width:100%;font-size:12px}}
td{{border:1px solid #ddd;padding:4px 6px;vertical-align:top;font-family:Menlo,monospace}} tr.hl td{{background:#fff3b0;font-weight:600}}
td.id{{color:#888;font-size:10px}}</style></head><body><h1>{html.escape(title)}</h1><div class='sub'>{html.escape(sub)}</div>
<div class='n'>Highlighted (matches /{html.escape(hl)}/): {n} of {len(rows)} lines</div><table>
<tr><th>ts (SGT)</th><th>app</th><th>level</th><th>message</th><th>_index / _id</th></tr>{body}</table></body></html>""")
print(out, n, len(rows))
