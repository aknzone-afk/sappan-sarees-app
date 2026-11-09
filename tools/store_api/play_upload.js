const fs = require('fs'), https = require('https');
const { call, token, PKG } = require('./play.js');
const AAB = 'C:/Users/4001C/sappan-repo/app/build/app/outputs/bundle/release/app-release.aab';
const H = 'androidpublisher.googleapis.com', base = `/androidpublisher/v3/applications/${PKG}`;
const notes = [{ language: 'en-US', text: 'Now Samppan Sarees. View any saree on a model; faster first launch.' }];
const ren = s => String(s || '').replace(/\bSappan\b/g, 'Samppan').replace(/\bSAPPAN\b/g, 'SAMPPAN');
function upload(t, editId) {
  const data = fs.readFileSync(AAB);
  return new Promise((res, rej) => {
    const r = https.request({ host: H, method: 'POST', path: `/upload${base}/edits/${editId}/bundles?uploadType=media`,
      headers: { Authorization: 'Bearer ' + t, 'Content-Type': 'application/octet-stream', 'Content-Length': data.length } },
      s => { let d = ''; s.on('data', c => d += c); s.on('end', () => res({ status: s.statusCode, body: JSON.parse(d) })); });
    r.setTimeout(600000); r.on('error', rej); r.write(data); r.end();
  });
}
(async () => {
  const t = await token();
  const e = await call('POST', H, base + '/edits', {}, t); const id = e.body.id;
  const ls = await call('GET', H, `${base}/edits/${id}/listings`, null, t);
  for (const l of ls.body.listings || []) {
    const upd = { language: l.language, title: ren(l.title), shortDescription: ren(l.shortDescription), fullDescription: ren(l.fullDescription) };
    const r = await call('PUT', H, `${base}/edits/${id}/listings/${l.language}`, upd, t);
    console.log('listing', l.language, r.status, JSON.stringify(l.title), '->', JSON.stringify(upd.title), r.status >= 300 ? JSON.stringify(r.body).slice(0, 300) : '');
  }
  const u = await upload(t, id); console.log('upload', u.status, JSON.stringify(u.body).slice(0, 200));
  if (u.status !== 200) return;
  const vc = String(u.body.versionCode);
  for (const track of ['internal', 'alpha']) {
    const r = await call('PUT', H, `${base}/edits/${id}/tracks/${track}`, { track, releases: [{ name: `1.0.0 (${vc})`, versionCodes: [vc], releaseNotes: notes, status: 'completed' }] }, t);
    console.log(track, r.status, r.status >= 300 ? JSON.stringify(r.body).slice(0, 300) : '');
  }
  const c = await call('POST', H, `${base}/edits/${id}:commit`, null, t);
  console.log('commit', c.status, JSON.stringify(c.body).slice(0, 500));
})();
