# -*- coding: utf-8 -*-
"""Read-only lexical inventory; does not execute Lua or infer online activity availability."""
from pathlib import Path
import re,json,csv,hashlib
OUT=Path(__file__).resolve().parent
ROOT=OUT.parents[2]
SRC=ROOT/'analysis/native_decode/decoded'
INDEX=json.loads((ROOT/'analysis/native_decode/decoded-index.json').read_text())
EXPECTED={x['decoded'].split('decoded/',1)[1]:x['sha256'] for x in INDEX['files']}
def sha(p): return hashlib.sha256(p.read_bytes()).hexdigest()
def rel(p): return p.relative_to(SRC).as_posix()
def dump(name,x): (OUT/name).write_text(json.dumps(x,ensure_ascii=False,indent=2)+'\n')
def csvout(name,rows):
    if not rows:return
    with (OUT/name).open('w',newline='') as f:
        w=csv.DictWriter(f,fieldnames=list(rows[0]));w.writeheader()
        for r in rows:w.writerow({k:json.dumps(v,ensure_ascii=False) if isinstance(v,(list,dict)) else v for k,v in r.items()})
def clean(s):
    # Preserve strings and line numbers; discard line/block comments.
    pat=r'--\[(=*)\[[\s\S]*?\]\1\]|--[^\n]*|"(?:\\.|[^"\\])*"|\'(?:\\.|[^\'\\])*\''
    return re.sub(pat,lambda m: re.sub(r'[^\n]',' ',m[0]) if m[0].startswith('--') else m[0],s)
files=sorted(SRC.rglob('*.lua'));raw={rel(p):p.read_text() for p in files};code={k:clean(v) for k,v in raw.items()}
def ev(path,n,text):return {'path':path,'line':n,'text':text.strip()}
registrations=[]
for path,s in code.items():
    if '/spring/' not in path:continue
    for m in re.finditer(r'\bclass\s*=\s*["\'](amf\.feature\.(?:localactivity\.[^"\']+|promotefullpackage\.[^"\']+))["\']',s):
        klass=m[1];before=s[:m.start()];ids=list(re.finditer(r'\bid\s*=\s*["\']([^"\']+)',before))
        registrations.append({'module':klass.split('.')[3] if '.localactivity.' in klass else 'promotefullpackage','bean_id':ids[-1][1] if ids else '', 'class':klass,'target_path':klass.replace('.','/')+'.lua','source':path,'line':s[:m.start()].count('\n')+1})
localroot=SRC/'amf/feature/localactivity';modules=sorted([p.name for p in localroot.iterdir() if p.is_dir()])
rows=[];configs=[];popup=[];hashes=[]
for module in modules+['promotefullpackage']:
    prefix='amf/feature/'+('localactivity/' if module!='promotefullpackage' else '')+module+'/'
    paths=[p for p in code if p.startswith(prefix)]
    regs=[r for r in registrations if r['module']==module]
    ids=[];names=[];configpaths=[];pops=[];refs=[];dynamic=[]
    for path in paths:
        conf=any(x in path.lower() for x in ['/config/','/const/']) or re.search(r'(?:Const|Config|Meta)\.lua$',path)
        if conf:configpaths.append(path)
        for n,line in enumerate(code[path].splitlines(),1):
            if re.search(r'getActConfig|getActivityConfig|serverVersionedConfig|configMd5|fromServer|syncFromActInfo|\bactSource\s*=|\bACT_SOURCE\s*=',line): dynamic.append(ev(path,n,line))
            # Identity assignments only; retain all exact evidence rather than silently choosing an ID.
            m=re.search(r'\b(actId|ACT_ID|activityId|activityID)\s*=\s*(\d+)\b',line)
            if m and ('Manager' in path or 'Mgr' in path or conf):ids.append({**ev(path,n,line),'value':int(m[2])})
            m=re.search(r'\b(actChName|ACT_CH_NAME|ActivityCHName|actName|DISPLAY_NAME)\s*=\s*(["\'])(.*?)\2',line)
            if m and re.search('[\u4e00-\u9fff]',m[3]):names.append({**ev(path,n,line),'value':m[3]})
            if re.search(r'\b(checkPoint|checkpoint)\s*=|_getAutoPopConfigList|:registerAutoPop|:register\(|AutoPopupConst\.PopStage|PopupCheckPoint\.',line):
                pops.append(ev(path,n,line))
            if conf:
                m=re.match(r'\s*(?:[\w.]+\.)?(\w+)\s*=\s*(true|false|-?\d+(?:\.\d+)?|"[^"\n]*"|\'[^\'\n]*\')\s*[,;]?',line)
                if m:configs.append({'module':module,**ev(path,n,line),'field':m[1],'literal':m[2],'literal_type':('boolean' if m[2] in ('true','false') else 'string' if m[2][0] in ('\"', "'") else 'number'),'scope':'package_literal_consumer_not_automatically_verified'})
    # All external lexical references are coverage seeds, not proof of a live initializer.
    for path,s in code.items():
        if path.startswith(prefix):continue
        needle=prefix[:-1].replace('/','.')+'.'
        if needle in s:
            refs += [ev(path,n,line) for n,line in enumerate(s.splitlines(),1) if needle in line]
    rows.append({'module':module,'registration_status':'spring_di_declared' if regs else 'directory_only_or_other_loader','source_files':len(paths),'bean_registrations':regs,'identity_ids':sorted(set(x['value'] for x in ids)),'id_evidence':ids,'chinese_names':sorted(set(x['value'] for x in names)),'name_evidence':names,'config_paths':configpaths,'dynamic_config_and_state_read_evidence':dynamic,'popup_evidence_count':len(pops),'popup_evidence':pops,'external_reference_count':len(refs),'external_references':refs,'online_enabled':'unknown'})
    popup += [{'module':module,**e} for e in pops]
# UBF enum and explicitly selected platform registration lists.
p='ubf/UBFActivity/UBFActRegister.lua';s=code[p];enum={};enumrows=[]
for n,line in enumerate(raw[p].splitlines(),1):
    m=re.match(r'\s*(k\w+)\s*=\s*(\d+)\s*,?\s*(?:--\s*(.*))?$',line)
    if m:enum[m[1]]=int(m[2]);enumrows.append({'enum':m[1],'act_id':int(m[2]),'comment_label':m[3] or '', 'source':p,'line':n})
registerblocks=list(re.finditer(r'NeedRegisterUBFActIds\s*=\s*\{(.*?)\}',s,re.S));ubfregs=[]
assert len(registerblocks)==2
for platform,block in zip(['minigame','native_app'],registerblocks):
    for m in re.finditer(r'UBFActivityIdConst\.(\w+)',block[1]):
        ubfregs.append({'platform':platform,'enum':m[1],'act_id':enum[m[1]],'source':p,'line':s[:block.start(1)+m.start()].count('\n')+1})
ubfconfigs=[]
for path,s in code.items():
    if not re.match(r'ubf/UBFActivity/config/(?:webGame/)?actConfig_',path):continue
    ident=Path(path).stem.replace('actConfig_','');aid=int(ident.split('_')[0]) if ident.split('_')[0].isdigit() else None
    def val(key):
        m=re.search(r'\b'+key+r'\s*=\s*(["\'])(.*?)\1',s)
        return {'value':m[2],'line':s[:m.start()].count('\n')+1} if m else None
    ubfconfigs.append({'config_key':ident,'act_id':aid,'path':path,'ActivityCHName':val('ActivityCHName'),'ActivityName':val('ActivityName'),'registered_platforms':sorted(set(r['platform'] for r in ubfregs if r['act_id']==aid)),'top_level_sections':[m[1] for m in re.finditer(r'^  (\w+)\s*=',s,re.M)],'sha256':sha(SRC/path),'online_enabled':'unknown'})
# Bind every file in scanned source, not just selected claims, to decoder output hash.
for p in files:
    name=rel(p);actual=sha(p);hashes.append({'path':name,'sha256':actual,'decoder_sha256':EXPECTED.get(name),'matches_decoder':EXPECTED.get(name)==actual,'lines':raw[name].count('\n')+1})
summary={'source_apk_sha256':INDEX['source_apk_sha256'],'all_decoded_lua_scanned':len(files),'hash_matches_decoder':sum(x['matches_decoder'] for x in hashes),'hash_mismatch':[x for x in hashes if not x['matches_decoder']],'localactivity_directories':len(modules),'catalog_modules_including_external_promotefullpackage':len(rows),'spring_di_rows':len(registrations),'localactivity_spring_di_rows':sum('.localactivity.' in r['class'] for r in registrations),'localactivity_di_declared_modules':len({r['module'] for r in registrations if '.localactivity.' in r['class']}),'localactivitydi_rows':sum(r['source'].endswith('/LocalActivityDI.lua') for r in registrations),'ubf_enum_rows':len(enumrows),'ubf_registered_native_app':sum(x['platform']=='native_app' for x in ubfregs),'ubf_registered_minigame':sum(x['platform']=='minigame' for x in ubfregs),'ubf_config_files':len(ubfconfigs),'ubf_config_numeric_unique_ids':len({x['act_id'] for x in ubfconfigs if x['act_id']}),'lexical_popup_evidence':len(popup),'config_literal_rows':len(configs),'note':'Lexical inventory and declared registrations only; not online enablement or semantic branch completion.'}
for name,data in [('catalog.json',rows),('registrations.json',registrations),('ubf-register.json',ubfregs),('ubf-enum.json',enumrows),('ubf-configs.json',ubfconfigs),('source-hashes.json',hashes),('summary.json',summary)]:dump(name,data)
csvout('catalog.csv',[{k:r[k] for k in ['module','registration_status','source_files','identity_ids','chinese_names','config_paths','popup_evidence_count','external_reference_count','online_enabled']} for r in rows])
for name,data in [('registrations.csv',registrations),('ubf-register.csv',ubfregs),('ubf-enum.csv',enumrows),('ubf-configs.csv',ubfconfigs),('popup-evidence.csv',popup),('config-literals.csv',configs)]:csvout(name,data)
print(json.dumps(summary,ensure_ascii=False,indent=2))

# Additional reviewed classification; declaration, module loader, and developer gate are separate facts.
for r in rows:
    if r['module']=='returngift':
        r['registration_status']='giftpackage_stage_modules_registered'
        r['registration_note']='ModuleConfig.lua:176-199 declares VINE_SCENE/STORE/START_PANEL/ADD_STEP active=true; no Spring bean needed for these modules.'
    elif r['module']=='processgiftautopopup':
        r['registration_note']='External references found to RewardFlyHelper only; ProcessGiftMgr entry not proven by this inventory.'
    elif r['module']=='supermagicbirdgift':
        r['registration_note']='Manager:isEnabledInLevel :200-217 returns false outside DevelopMode. DevelopMode additionally needs debugEnabled and super-bird checks. TestConfig is not an online offer.'
    r['ubf_config_matches']=[c for c in ubfconfigs if c['act_id'] in r['identity_ids']]
dump('catalog.json',rows)
csvout('catalog.csv',[{k:r.get(k,'') for k in ['module','registration_status','registration_note','source_files','identity_ids','chinese_names','config_paths','popup_evidence_count','external_reference_count','online_enabled']} for r in rows])
csvout('dynamic-config-evidence.csv',[{'module':r['module'],**e} for r in rows for e in r['dynamic_config_and_state_read_evidence']])
