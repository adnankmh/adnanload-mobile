"""Report measured artifacts, never invented sizes. Run after Flutter build."""
from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[1]
files=sorted(set(list((root/'build/app/outputs/flutter-apk').glob('*.apk'))+
                 list((root/'build/app/outputs/bundle/release').glob('*.aab'))))
def digest(path):
    h=hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda:stream.read(1024*1024),b''):
            h.update(chunk)
    return h.hexdigest()

report=[]
for f in files:
    report.append({'file':str(f.relative_to(root)),'bytes':f.stat().st_size,
                   'mib':round(f.stat().st_size/1048576,2),
                   'sha256':digest(f)})
out=root/'build/release-size-report.json'
out.parent.mkdir(exist_ok=True,parents=True)
out.write_text(json.dumps({'artifacts':report},ensure_ascii=False,indent=2),encoding='utf-8')
print('Measured artifacts:')
for item in report:print(item['file'],item['mib'],'MiB')
if not report:
    print('No release APK/AAB found. This is not a measured size report.')
