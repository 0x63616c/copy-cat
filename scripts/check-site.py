#!/usr/bin/env python3
"""Validate the static site's local links/assets without extra dependencies."""
from html.parser import HTMLParser
from pathlib import Path
from urllib.parse import urlsplit, unquote

root = Path(__file__).resolve().parent.parent / 'site'

class Page(HTMLParser):
    def __init__(self):
        super().__init__()
        self.links, self.ids, self.errors = [], set(), []
    def handle_starttag(self, tag, attrs):
        attrs = dict(attrs)
        if 'id' in attrs:
            self.ids.add(attrs['id'])
        if tag == 'img' and 'alt' not in attrs:
            self.errors.append('Image missing alt text')
        for attr in ('src', 'href'):
            if attr in attrs:
                self.links.append(attrs[attr])

page = Page()
page.feed((root / 'index.html').read_text())
for link in page.links:
    parts = urlsplit(link)
    if parts.scheme or parts.netloc:
        continue
    if parts.path and not (root / unquote(parts.path)).exists():
        page.errors.append(f'Missing local target: {link}')
    if not parts.path and parts.fragment and parts.fragment not in page.ids:
        page.errors.append(f'Missing section: {link}')
if page.errors:
    raise SystemExit('\n'.join(page.errors))
print(f'Website OK: {len(page.links)} links/assets checked')
