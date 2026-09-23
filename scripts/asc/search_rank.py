"""iTunes Search API（JP）でアプリの検索順位を見る。KW の辞書を編集して使う。

    python3 scripts/asc/search_rank.py
"""
import json,urllib.request,urllib.parse,sys,time
IDS={'tomoshibi':6794522211,'etude':6794500656,'takken':6791792412}
def lookup(i):
    d=json.load(urllib.request.urlopen(f'https://itunes.apple.com/lookup?id={i}&country=jp'))
    return d['results'][0] if d['results'] else None
for n,i in IDS.items():
    r=lookup(i)
    if not r: print(n,'NOT FOUND in JP store'); continue
    print(n, '| ver',r['version'],'| rating',r.get('averageUserRating'),r.get('userRatingCount'),'| langs',r.get('languageCodesISO2A'),'| minOS',r.get('minimumOsVersion'),'| released',r['releaseDate'][:10],'| current',r['currentVersionReleaseDate'][:10],'| genres',r.get('genres'),'| size',int(r['fileSizeBytes'])//1_000_000,'MB')
KW={'takken':['宅建','宅建 一問一答','宅建 過去問','宅建士','宅建 アプリ','宅建 無料','宅建 暗記','宅地建物取引士','宅建 独学','宅建 2026'],
    'etude':['即興演劇','エチュード','インプロ','即興 お題','演劇 お題','演劇','演劇 練習','シアターゲーム','アイスブレイク','演技 練習','エチュード お題','即興劇'],
    'tomoshibi':['舞台照明','照明シミュレーター','舞台 照明','ステージ照明','照明デザイン','演劇 照明','DMX','舞台美術','劇団','舞台監督','ライティング シミュレーション']}
for n,kws in KW.items():
    print('\n==',n)
    for kw in kws:
        u='https://itunes.apple.com/search?'+urllib.parse.urlencode({'term':kw,'country':'jp','entity':'software','limit':50})
        try: d=json.load(urllib.request.urlopen(u))
        except Exception as e: print(kw,'ERR',e); continue
        ids=[x['trackId'] for x in d['results']]
        rank=ids.index(IDS[n])+1 if IDS[n] in ids else None
        top=[x['trackName'][:18] for x in d['results'][:3]]
        print(f"{kw:22s} total={len(ids):2d} rank={rank}  top3={top}")
        time.sleep(0.5)
