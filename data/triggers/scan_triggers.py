#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Reproducible lexical index; NOT control-flow proof. Run from research root."""
from pathlib import Path
import re,json,csv,hashlib
ROOT=Path('analysis/native_decode/decoded'); OUT=Path('analysis/activity-push-2026-10-21/triggers')
def clean(s):
 # retain offsets/newlines while removing comments; quoted strings kept for evidence
 return re.sub(r'--\[\[.*?\]\]|--[^\n]*',lambda m:re.sub(r'[^\n]',' ',m[0]),s,flags=re.S)
def block(s,start):
 depth=0; quote=None; esc=False
 for i in range(start,len(s)):
  c=s[i]
  if quote:
   if esc: esc=False
   elif c=='\\':esc=True
   elif c==quote:quote=None
  elif c in "\"'":quote=c
  elif c=='{':depth+=1
  elif c=='}':
   depth-=1
   if depth==0:return i+1
 return min(len(s),start+3000)
rows=[]; providers=[]
for f in sorted(ROOT.rglob('*.lua')):
 raw=f.read_text();s=clean(raw);rel=str(f.relative_to(ROOT));sha=hashlib.sha256(f.read_bytes()).hexdigest()
 funcs=list(re.finditer(r'^function\s+([^\n]+)',s,re.M))
 def context(pos):
  prior=[m for m in funcs if m.start()<=pos]
  if not prior:return '',0,len(s)
  m=prior[-1]; n=next((x.start() for x in funcs if x.start()>m.start()),len(s));return m[1],m.start(),n
 for m in re.finditer(r':(?:registerPopup|addPopupConfig)\s*\(',s):
  # function definitions aren't consumers
  fn,a,b=context(m.start())
  if s[s.rfind('\n',0,m.start())+1:m.start()].lstrip().startswith('function '):continue
  start=m.end(); end=block(s,s.index('{',start)) if s[start:].lstrip().startswith('{') else s.find('\n',start)
  text=raw[m.start():end]; rows.append(dict(kind='direct_call',source=rel,line=raw.count('\n',0,m.start())+1,sha256=sha,function=fn,checkpoint=(re.search(r'checkPoint\s*=\s*([^,\n]+)',text) or re.search(r'(.+)',text))[1].strip(),stages=re.findall(r'(?:PopStage|popStage)\.(STAGE_\w+)',text),code=text,context=raw[a:b],review='indexed_not_semantically_closed'))
 for fm in funcs:
  if not re.search(r':_?getAutoPopConfigList\(',fm[1]):continue
  fn,a,b=context(fm.start()); providers.append(dict(source=rel,line=raw.count('\n',0,a)+1,sha256=sha,function=fn))
  for m in re.finditer(r'checkPoint\s*=\s*([^,\n]+)',s[a:b]):
   pos=a+m.start(); brace=s.rfind('{',a,pos);end=block(s,brace);text=raw[brace:end]
   rows.append(dict(kind='plugin_config',source=rel,line=raw.count('\n',0,pos)+1,sha256=sha,function=fn,checkpoint=m[1].strip(),stages=re.findall(r'(?:PopStage|popStage)\.(STAGE_\w+)',text),code=text,context=raw[a:b],review='indexed_not_semantically_closed'))
for i,r in enumerate(rows):r['id']=f'TR{i+1:03d}';r['is_debug_or_test']=('/debug/' in r['source']);r['localactivity_module']=r['source'].split('/localactivity/')[1].split('/')[0] if '/localactivity/' in r['source'] else ''
OUT.mkdir(parents=True,exist_ok=True)
(OUT/'trigger-inventory.json').write_text(json.dumps({'scope':'Lexical calls and plugin-returned checkpoint entries; comments excluded; registration does not prove runtime enabling; dynamic registrations may escape lexical patterns. Context ends at next top-level function and is evidence, not fully transitive audit.','source_root':str(ROOT),'counts':{'rows':len(rows),'localactivity_rows':sum(bool(x['localactivity_module']) for x in rows),'localactivity_modules':len({x['localactivity_module'] for x in rows if x['localactivity_module']})},'providers':providers,'rows':rows},ensure_ascii=False,indent=2))
fields=['id','kind','source','line','sha256','function','checkpoint','stages','localactivity_module','is_debug_or_test','review','code']
with (OUT/'trigger-inventory.csv').open('w',newline='',encoding='utf-8-sig') as f:
 w=csv.DictWriter(f,fieldnames=fields,extrasaction='ignore');w.writeheader();w.writerows({**r,'stages':'|'.join(r['stages'])} for r in rows)
print(len(rows),'rows;',len({r['localactivity_module'] for r in rows if r['localactivity_module']}),'local activity modules')
