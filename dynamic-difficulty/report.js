'use strict';
const D=JSON.parse(document.getElementById('report-data').textContent);
const el=id=>document.getElementById(id);
const esc=x=>String(x).replace(/[&<>"']/g,c=>({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const pretty=x=>typeof x==='object'?JSON.stringify(x,null,2):String(x);
const opts=(values,current)=>values.map(x=>`<option value="${esc(x)}"${String(x)===String(current)?' selected':''}>${esc(x)}</option>`).join('');
function renderAvailability(){
 const o=el('origin-filter').value,a=el('available-filter').value,q=el('source-search').value.trim().toLowerCase();
 const rows=D.availability.filter(r=>(!o||r.origin===o)&&(!a||r.available===a)&&(!q||JSON.stringify(r).toLowerCase().includes(q)));
 el('availability-count').textContent=`显示 ${rows.length} / ${D.availability.length} 项`;
 el('availability-body').innerHTML=rows.map(r=>`<tr><td><b>${esc(r.label)}</b><br><small>${esc(r.id)}</small></td><td>${esc({client:'客户端',server:'服务端',mixed:'两端结合'}[r.origin])}<br><span class="badge">${esc(r.available)}</span></td><td>${esc(r.what_known)}</td><td>${esc(r.what_unknown)}</td><td><a href="${r.source_href}">原文 L${r.line}</a><br>${esc(r.evidence_type)}</td></tr>`).join('');
}
['origin-filter','available-filter','source-search'].forEach(id=>el(id).addEventListener('input',renderAvailability));renderAvailability();
el('matrix-group').innerHTML=opts([...new Set(D.matrix.map(r=>r.group))],0);
el('activity').innerHTML=opts(Array.from({length:16},(_,i)=>i+1),11);el('payment').innerHTML=opts(Array.from({length:16},(_,i)=>i+1),3);
function renderMatrix(){
 const g=+el('matrix-group').value,a=+el('activity').value,p=+el('payment').value,rows=D.matrix.filter(r=>r.group===g).sort((a,b)=>a.activity-b.activity);
 el('matrix-table').innerHTML='<thead><tr><th>活跃↓<br>付费档位→</th>'+Array.from({length:16},(_,i)=>`<th>${i+1}</th>`).join('')+'</tr></thead><tbody>'+rows.map(r=>'<tr><th>'+r.activity+'</th>'+Array.from({length:16},(_,i)=>{const v=r['pay'+(i+1)],h=v<0?153:30,l=96-Math.abs(v)*2;return `<td tabindex="0" data-a="${r.activity}" data-p="${i+1}" class="${r.activity===a&&i+1===p?'selected':''}" style="background:hsl(${h} 30% ${l}%)" aria-label="活跃${r.activity} 付费档位${i+1} 指数${v}">${v}</td>`}).join('')+'</tr>').join('')+'</tbody>';
 const row=rows.find(r=>r.activity===a);el('matrix-result').innerHTML=`组 ${g} · 活跃 ${a} · 付费档位 ${p} → <strong>基础指数 ${row['pay'+p]}</strong><br><small>只展示矩阵读值；能力、活动、区域限制尚未应用。源表第 ${row._source_line} 行。</small>`;
}
['matrix-group','activity','payment'].forEach(id=>el(id).addEventListener('change',renderMatrix));
el('matrix-table').addEventListener('click',e=>{const td=e.target.closest('td[data-a]');if(td){el('activity').value=td.dataset.a;el('payment').value=td.dataset.p;renderMatrix()}});
el('matrix-table').addEventListener('keydown',e=>{if(e.key==='Enter'||e.key===' '){e.preventDefault();e.target.click()}});renderMatrix();
el('final-group').innerHTML=opts([...new Set(D.final.map(r=>r.group))],0);el('final-index').innerHTML=opts(Array.from({length:19},(_,i)=>i-9),-1);
function renderFinal(){const g=+el('final-group').value,t=+el('base-target').value,i=+el('final-index').value;const row=D.final.filter(r=>r.group===g).sort((a,b)=>a.desiredDiff-b.desiredDiff).find(r=>t<=r.desiredDiff);const key=i<0?'diffIndexN'+(-i):'diffIndex'+i;el('final-result').innerHTML=row?`输入 ${t} → 命中上界 ${row.desiredDiff} 行 · 指数 ${i} → <strong>映射后设定 ${row[key]}</strong><br><small>源表第 ${row._source_line} 行；尚未应用保底前修正、保底和保底后修正。仅支持整数指数。</small>`:'该组未找到匹配行；不能外推未列值。'}
['final-group','base-target','final-index'].forEach(id=>el(id).addEventListener('input',renderFinal));renderFinal();
el('case-select').innerHTML=D.cases.map((c,i)=>`<option value="${i}">${esc(c.title)}</option>`).join('');el('case-fails').innerHTML=opts(Array.from({length:9},(_,i)=>i),0);
function renderCase(){const c=D.cases[+el('case-select').value],f=el('case-fails').value,last=c.steps[c.steps.length-1];el('case-result').innerHTML=`活跃 ${c.expected.activityIndex} · 付费档位 ${c.expected.paymentIndex} · 最终指数 ${c.expected.finalDiffIndex}<br>冻结其他输入，累计逻辑失败 ${f} 次 → <strong>内部设定 ${last.output[f]}</strong>`;el('case-assumptions').textContent=pretty(c.assumptions);el('case-steps').innerHTML=c.steps.map(s=>`<tr><td>${esc(s.label)}</td><td><pre>${esc(pretty(s.input))}</pre></td><td><pre>${esc(pretty(s.output))}</pre></td><td><a href="${s.source_href}">L${s.line}</a></td></tr>`).join('');}
['case-select','case-fails'].forEach(id=>el(id).addEventListener('change',renderCase));renderCase();
function feedbackDistribution(t,lo,hi){if(!(lo<t&&t<hi))return null;const p=(t-lo)/(hi-lo);return [0.01*(1-p),0.98*(1-p)+0.01*p,0.98*p+0.01*(1-p),0.01*p];}
function renderFeedback(){const t=+el('feedback-target').value,lo=+el('feedback-low').value,hi=+el('feedback-high').value,dist=feedbackDistribution(t,lo,hi);if(!dist){el('feedback-result').textContent='本演示只覆盖低反馈 < 目标 < 高反馈，且目标 >1.03、两候选为档0/1的相邻分支。';return;}if(t<=1.03){el('feedback-result').textContent='目标≤1.03进入专门低目标分支，本演示不计算。';return;}el('feedback-result').innerHTML=dist.map((p,i)=>`<div class="barrow"><span>最终档 ${i-1}</span><div class="bar"><i style="width:${p*100}%"></i></div><b>${(p*100).toFixed(2)}%</b></div>`).join('')+'<small>包含距离加权及98/1/1扰动；假定均匀抽样，无限幅碰撞和后续外部修正。反馈值由你构造，不是服务器实测。</small>';}
['feedback-target','feedback-low','feedback-high'].forEach(id=>el(id).addEventListener('input',renderFeedback));renderFeedback();
function calculateDs(fix,used,equiv){const line=fix===-16?9:0,off=fix===-16?12:0,lag=used-equiv+line,rate=Math.floor(Math.sign(lag)*Math.min(Math.abs(lag),30)/30*100+0.000001);let base=0;if(rate>0)base=rate<=30?Math.ceil(rate/3+0.0001):rate<=35?11:rate<=40?12:rate<=45?13:rate<=50?14:15;else base=rate< -30?-5:rate< -20?-4:rate< -15?-3:rate< -10?-2:rate< -5?-1:0;const rules=fix===-16?[[3,4,5],[5,6,5],[10,10,4]]:[[3,4,1],[5,10,2],[10,15,1]];let step=0;for(const [n,r,v]of rules)if(30-used<=n&&rate>r){step=v;break;}const ds=Math.max(-5,Math.min(15,base+off+step));return {line,off,lag,rate,base,step,ds};}
function renderDs(){const used=+el('used-steps').value,eq=+el('equivalent-steps').value;el('used-label').textContent=used;el('equivalent-label').textContent=eq.toFixed(1);const rows=[0,-16].map(f=>({f,...calculateDs(f,used,eq)}));el('ds-result').innerHTML='<div class="table-wrap"><table><thead><tr><th>diffFix</th><th>偏移后落后量</th><th>rate</th><th>基础ds</th><th>默认偏移</th><th>末段修正</th><th>最终ds</th></tr></thead><tbody>'+rows.map(r=>`<tr><td>${r.f}</td><td>${r.lag.toFixed(2)}</td><td>${r.rate}</td><td>${r.base}</td><td>${r.off}</td><td>${r.step}</td><td><strong>${r.ds}</strong></td></tr>`).join('')+'</tbody></table></div><small>固定30步；各反事实轨迹历史rate稳定，速度修正0；无stepFix、无加步区间、无lockedDeviation，旧链已启用。不是原游戏运行器。</small>';}
['used-steps','equivalent-steps'].forEach(id=>el(id).addEventListener('input',renderDs));renderDs();
el('reset-ds').addEventListener('click',()=>{el('used-steps').value=15;el('equivalent-steps').value=12.3;renderDs()});
el('print-report').addEventListener('click',()=>window.print());
el('expand-code').addEventListener('click',()=>document.querySelectorAll('#code details').forEach(x=>x.open=true));el('collapse-code').addEventListener('click',()=>document.querySelectorAll('#code details').forEach(x=>x.open=false));
const ob=new IntersectionObserver(entries=>{for(const entry of entries)if(entry.isIntersecting){document.querySelectorAll('aside a').forEach(a=>a.classList.toggle('active',a.getAttribute('href')==='#'+entry.target.id));}},{rootMargin:'-5% 0px -75% 0px'});document.querySelectorAll('section.chapter').forEach(x=>ob.observe(x));
window.reportMath={feedbackDistribution,calculateDs};window.reportReady=true;
// Preserve deep links into folded technical evidence.
function revealHashEvidence(){const key=decodeURIComponent(location.hash.slice(1));const target=document.getElementById(key);if(!target)return;let parent=target.parentElement,opened=false;while(parent){if(parent.tagName==='DETAILS'&&!parent.open){parent.open=true;opened=true;}parent=parent.parentElement;}if(opened)target.scrollIntoView();}
window.addEventListener('hashchange',revealHashEvidence);revealHashEvidence();
