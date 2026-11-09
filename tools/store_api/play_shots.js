const fs = require('fs'), path = require('path'), https = require('https');
const { call, token, PKG } = require('./play.js');
const H = 'androidpublisher.googleapis.com', base = `/androidpublisher/v3/applications/${PKG}`;
const DIR = 'C:/Users/4001C/sappan-repo/store/shots';
function up(t, id, buf) {
  return new Promise((res, rej) => {
    const r = https.request({ host: H, method: 'POST', path: `/upload${base}/edits/${id}/listings/en-US/phoneScreenshots?uploadType=media`,
      headers: { Authorization: 'Bearer ' + t, 'Content-Type': 'image/png', 'Content-Length': buf.length } },
      s => { let d = ''; s.on('data', c => d += c); s.on('end', () => res({ status: s.statusCode, body: d })); });
    r.on('error', rej); r.write(buf); r.end();
  });
}
(async () => {
  const t = await token();
  const e = await call('POST', H, base + '/edits', {}, t); const id = e.body.id;
  const del = await call('DELETE', H, `${base}/edits/${id}/listings/en-US/phoneScreenshots`, null, t);
  console.log('delete old', del.status);
  for (const f of fs.readdirSync(DIR).filter(f => f.endsWith('.png')).sort()) {
    const r = await up(t, id, fs.readFileSync(path.join(DIR, f)));
    console.log('up', f, r.status, r.status >= 300 ? r.body.slice(0, 200) : '');
  }
  const c = await call('POST', H, `${base}/edits/${id}:commit`, null, t);
  console.log('commit', c.status, JSON.stringify(c.body).slice(0, 300));
})();
