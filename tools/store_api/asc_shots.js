const fs = require('fs'), path = require('path'), crypto = require('crypto'), https = require('https');
const { req } = require('./asc.js');
const SET = 'd1a20cea-037a-473f-b64b-ca1465effe03';
const DIR = 'C:/Users/4001C/sappan-repo/store/shots';
function put(op, buf) {
  return new Promise((res, rej) => {
    const u = new URL(op.url);
    const headers = {};
    for (const h of op.requestHeaders || []) headers[h.name] = h.value;
    const part = buf.subarray(op.offset, op.offset + op.length);
    headers['Content-Length'] = part.length;
    const r = https.request({ host: u.host, path: u.pathname + u.search, method: op.method, headers }, s => { s.resume(); s.on('end', () => res(s.statusCode)); });
    r.on('error', rej); r.write(part); r.end();
  });
}
(async () => {
  const old = await req('GET', `/v1/appScreenshotSets/${SET}/appScreenshots`);
  for (const s of old.body.data) { const d = await req('DELETE', `/v1/appScreenshots/${s.id}`); console.log('deleted', s.attributes.fileName, d.status); }
  const files = fs.readdirSync(DIR).filter(f => f.endsWith('.png')).sort();
  for (const f of files) {
    const buf = fs.readFileSync(path.join(DIR, f));
    const r = await req('POST', '/v1/appScreenshots', { data: { type: 'appScreenshots', attributes: { fileName: f, fileSize: buf.length },
      relationships: { appScreenshotSet: { data: { type: 'appScreenshotSets', id: SET } } } } });
    if (r.status >= 300) { console.log('reserve fail', f, JSON.stringify(r.body).slice(0, 300)); continue; }
    const id = r.body.data.id;
    for (const op of r.body.data.attributes.uploadOperations) await put(op, buf);
    const md5 = crypto.createHash('md5').update(buf).digest('hex');
    const c = await req('PATCH', `/v1/appScreenshots/${id}`, { data: { type: 'appScreenshots', id, attributes: { uploaded: true, sourceFileChecksum: md5 } } });
    console.log('uploaded', f, c.status);
  }
  await new Promise(r => setTimeout(r, 15000));
  const now = await req('GET', `/v1/appScreenshotSets/${SET}/appScreenshots`);
  for (const s of now.body.data) console.log(s.attributes.fileName, JSON.stringify(s.attributes.assetDeliveryState && s.attributes.assetDeliveryState.state));
})();
