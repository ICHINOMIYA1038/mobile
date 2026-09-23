"""アップロード済みビルドの処理完了を待ち、指定バージョンに添付して審査に提出する。

    python3 scripts/asc/attach_submit.py <appId> <appStoreVersionId> <buildNumber>

事前に asc.py の send() で appStoreVersions を作り、ローカライズ（キーワード・リリースノート等）を
入れておく。輸出コンプライアンス（usesNonExemptEncryption=false）もここで設定する。
"""
import sys, time
from asc import get, send
APP, VER, BUILD_NO = sys.argv[1], sys.argv[2], sys.argv[3]
build=None
for i in range(40):   # up to ~20 min
    b=get('/v1/builds',{'filter[app]':APP,'filter[version]':BUILD_NO,'limit':3,'fields[builds]':'version,processingState'})
    for x in b.get('data',[]):
        if x['attributes']['version']==BUILD_NO and x['attributes']['processingState']=='VALID': build=x['id']
    if build: break
    print('waiting for build', BUILD_NO, [x['attributes'] for x in b.get('data',[])], flush=True); time.sleep(30)
if not build: print('BUILD NOT PROCESSED'); sys.exit(1)
print('encryption', send('PATCH',f'/v1/builds/{build}',{'data':{'type':'builds','id':build,'attributes':{'usesNonExemptEncryption':False}}}).get('data',{}).get('attributes',{}).get('usesNonExemptEncryption','ERR'))
r=send('PATCH',f'/v1/appStoreVersions/{VER}/relationships/build',{'data':{'type':'builds','id':build}}); print('attach', r if r else 'ok')
rs=get('/v1/reviewSubmissions',{'filter[app]':APP,'filter[state]':'READY_FOR_REVIEW,WAITING_FOR_REVIEW,IN_REVIEW,UNRESOLVED_ISSUES','limit':5,'fields[reviewSubmissions]':'state'})
open_=rs.get('data',[])
if open_: sid=open_[0]['id']; print('reuse submission', sid, open_[0]['attributes'])
else:
    r=send('POST','/v1/reviewSubmissions',{'data':{'type':'reviewSubmissions','attributes':{'platform':'IOS'},'relationships':{'app':{'data':{'type':'apps','id':APP}}}}})
    sid=r.get('data',{}).get('id'); print('created submission', sid or r)
item=send('POST','/v1/reviewSubmissionItems',{'data':{'type':'reviewSubmissionItems','relationships':{'reviewSubmission':{'data':{'type':'reviewSubmissions','id':sid}},'appStoreVersion':{'data':{'type':'appStoreVersions','id':VER}}}}})
print('item', item.get('data',{}).get('attributes',{}).get('state') or item)
sub=send('PATCH',f'/v1/reviewSubmissions/{sid}',{'data':{'type':'reviewSubmissions','id':sid,'attributes':{'submitted':True}}})
print('submit ->', sub.get('data',{}).get('attributes',{}).get('state') or sub)
v=get(f'/v1/appStoreVersions/{VER}',{'fields[appStoreVersions]':'versionString,appVersionState'}); print('version state', v['data']['attributes'])
