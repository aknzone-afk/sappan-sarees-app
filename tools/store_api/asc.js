const fs = require('fs'), crypto = require('crypto'), https = require('https');
const KID = 'JA9Z53XA29';
const ISS = fs.readFileSync('C:/BotSecrets/apple/issuer_id.txt', 'utf8').trim();
const KEY = fs.readFileSync(`C:/BotSecrets/apple/AuthKey_${KID}.p8`, 'utf8');
const b64 = o => Buffer.from(JSON.stringify(o)).toString('base64url');
function jwt() {
  const now = Math.floor(Date.now() / 1000);
  const h = b64({ alg: 'ES256', kid: KID, typ: 'JWT' }), p = b64({ iss: ISS, iat: now, exp: now + 1100, aud: 'appstoreconnect-v1' });
  const sig = crypto.sign('sha256', Buffer.from(`${h}.${p}`), { key: KEY, dsaEncoding: 'ieee-p1363' }).toString('base64url');
  return `${h}.${p}.${sig}`;
}
function req(method, path, body) {
  return new Promise((res, rej) => {
    const r = https.request({ host: 'api.appstoreconnect.apple.com', path, method, headers: { Authorization: 'Bearer ' + jwt(), 'Content-Type': 'application/json' } }, s => {
      let d = ''; s.on('data', c => d += c); s.on('end', () => res({ status: s.statusCode, body: d ? JSON.parse(d) : null }));
    });
    r.on('error', rej); if (body) r.write(JSON.stringify(body)); r.end();
  });
}
module.exports = { req };
if (require.main === module) {
  const [m, p, b] = process.argv.slice(2).length === 1 ? ['GET', process.argv[2]] : process.argv.slice(2);
  req(m, p, b ? JSON.parse(b) : undefined).then(r => console.log(r.status, JSON.stringify(r.body, null, 1)));
}
