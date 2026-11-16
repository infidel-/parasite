# inline the snapshot and every asset into one self-contained preview page (WebGL refuses file:// textures)
# usage: python3 build.py <out.html>
import base64, json, os, sys
J = os.path.dirname(os.path.abspath(__file__))
A = J + '/inputs'
mime = {'.png': 'image/png', '.jpg': 'image/jpeg'}
assets = {}
for n in sorted(os.listdir(A)):
  ext = os.path.splitext(n)[1]
  if ext in mime:
    assets[n] = 'data:%s;base64,%s' % (mime[ext], base64.b64encode(open(A + '/' + n, 'rb').read()).decode())
html = open(J + '/preview.src.html').read()
html = html.replace('{{SNAP}}', open(A + '/snap.json').read().strip())
html = html.replace('{{ASSETS}}', json.dumps(assets))
open(sys.argv[1], 'w').write(html)
print('ok', len(html))
