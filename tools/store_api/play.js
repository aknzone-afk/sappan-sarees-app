const fs = require('fs'), crypto = require('crypto'), https = require('https');
const sa = JSON.parse(fs.readFileSync('C:/BotSecrets/play_upload_sa.json', 'utf8'));
const PKG = 'com.sappansarees.retailapp';
function call(method, host, path, body, token, ctype) {
  return new Promise((res, rej) => {
    const h = { 'Content-Type': ctype || 'application/json' };
    if (token) h.Authorization = 'Bearer ' + token;
    const r = https.request({ host, path, method, headers: h }, s => { let d = ''; s.on('data', c => d += c); s.on('end', () => { let j; try { j = JSON.parse(d); } catch { j = d; } res({ status: s.statusCode, body: j }); }); });
    r.on('error', rej); if (body) r.write(typeof body === 'string' ? body : JSON.stringify(body)); r.end();
  });
}
async function token() {
  const now = Math.floor(Date.now() / 1000), b = o => Buffer.from(JSON.stringify(o)).toString('base64url');
  const u = b({ alg: 'RS256', typ: 'JWT' }) + '.' + b({ iss: sa.client_email, scope: 'https://www.googleapis.com/auth/androidpublisher', aud: 'https://oauth2.googleapis.com/token', iat: now, exp: now + 3500 });
  const jwt = u + '.' + crypto.sign('sha256', Buffer.from(u), sa.private_key).toString('base64url');
  const r = await call('POST', 'oauth2.googleapis.com', '/token', `grant_type=urn%3Aietf%3Aparams%3Aoauth%3Agrant-type%3Ajwt-bearer&assertion=${jwt}`, null, 'application/x-www-form-urlencoded');
  return r.body.access_token;
}
module.exports = { call, token, PKG };
if (require.main === module) (async () => {
  const t = await token(), base = `/androidpublisher/v3/applications/${PKG}`;
  const e = await call('POST', 'androidpublisher.googleapis.com', base + '/edits', {}, t);
  if (e.status !== 200) return console.log('edit', e.status, JSON.stringify(e.body));
  const tr = await call('GET', 'androidpublisher.googleapis.com', `${base}/edits/${e.body.id}/tracks`, null, t);
  console.log(JSON.stringify(tr.body, null, 1));
  await call('DELETE', 'androidpublisher.googleapis.com', `${base}/edits/${e.body.id}`, null, t);
})();
