"""Build the deck.gl viewer page from viewer-template.html and the exported
mesh data. Run from the repository root:
  python3 survey/dev-drafts/mathgl-terrain/build-viewer.py
"""
import os
here = 'survey/dev-drafts/mathgl-terrain'
tpl = open(os.path.join(here, 'viewer-template.html')).read()
data = open(os.path.join(here, 'cache', 'viewer-data.json')).read()
page = tpl.replace('__DATA__', data.replace('</', '<\\/'))
head, body = page.split('<main>', 1)
body = '<main>' + body
out_dir = 'docs/dev-drafts/mathgl-breaklines/viewer'
os.makedirs(out_dir, exist_ok=True)
with open(os.path.join(out_dir, 'index.html'), 'w') as f:
    f.write('<!doctype html>\n<html lang="en">\n<head>\n<meta charset="utf-8">\n'
            '<meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">\n'
            + head + '</head>\n<body>\n' + body + '\n</body>\n</html>\n')
print('wrote', os.path.join(out_dir, 'index.html'))
