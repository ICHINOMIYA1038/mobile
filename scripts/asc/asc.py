"""App Store Connect API の薄いラッパー（読み取り + 書き込み）。

前提: `pip install pyjwt cryptography`、鍵は ~/.appstoreconnect/private_keys/AuthKey_3URMU94JK9.p8
（Key ID / Issuer ID は ios-app-review-submission.md 参照）。

    python3 scripts/asc/asc.py            # 全アプリのバージョン状態と審査提出の一覧
    from asc import get, send             # 他スクリプトから
"""
import jwt, time, json, sys, urllib.request, urllib.parse
KEY_ID="3URMU94JK9"; ISS="1039c5ec-53b4-4125-b857-d5059f3f3e74"
key=open('/Users/ichinomiya/.appstoreconnect/private_keys/AuthKey_3URMU94JK9.p8').read()
def token():
    now=int(time.time())
    return jwt.encode({'iss':ISS,'iat':now,'exp':now+1100,'aud':'appstoreconnect-v1'},key,algorithm='ES256',headers={'kid':KEY_ID})
def get(path,params=None):
    url='https://api.appstoreconnect.apple.com'+path
    if params: url+='?'+urllib.parse.urlencode(params)
    req=urllib.request.Request(url,headers={'Authorization':'Bearer '+token()})
    try:
        return json.load(urllib.request.urlopen(req))
    except urllib.error.HTTPError as e:
        return {'error':e.code,'body':e.read().decode()[:500]}
if __name__=='__main__':
    apps=get('/v1/apps',{'limit':50,'fields[apps]':'name,bundleId,sku,primaryLocale'})
    for a in apps.get('data',[]):
        at=a['attributes']; aid=a['id']
        print(f"\n## {at['name']} ({at['bundleId']}) id={aid} locale={at.get('primaryLocale')}")
        vs=get(f'/v1/apps/{aid}/appStoreVersions',{'limit':5,'fields[appStoreVersions]':'versionString,appStoreState,appVersionState,createdDate,releaseType'})
        for v in vs.get('data',[]):
            va=v['attributes']; print(f"  version {va['versionString']}  state={va.get('appVersionState') or va.get('appStoreState')}  created={va['createdDate'][:10]}")
        rs=get('/v1/reviewSubmissions',{'filter[app]':aid,'limit':5,'fields[reviewSubmissions]':'state,submittedDate,platform'})
        for r in rs.get('data',[]):
            ra=r['attributes']; print(f"  submission {r['id'][:8]} state={ra['state']} submitted={ (ra.get('submittedDate') or '')[:10]}")

def send(method, path, body):
    url='https://api.appstoreconnect.apple.com'+path
    req=urllib.request.Request(url, data=json.dumps(body).encode(), method=method,
        headers={'Authorization':'Bearer '+token(),'Content-Type':'application/json'})
    try:
        r=urllib.request.urlopen(req); raw=r.read()
        return json.loads(raw) if raw else {}
    except urllib.error.HTTPError as e:
        return {'error':e.code,'body':e.read().decode()[:800]}
