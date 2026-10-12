'use strict';
const $ = (id) => document.getElementById(id);
const storageKey = 'afterclass-preview-v1';
let today = new Date();
let todayWeekday = (today.getDay() + 6) % 7 + 1;
let selectedDay = todayWeekday;
let editingID = null;
let demoMinute = null;
let helloTimer;
let featuredCharacter = {kind:'seed', name:'未', course:null};

const seedCourses = [
  {id:'m1', title:'机械原理',room:'教学楼 A · 302',day:1,start:'08:00',end:'09:35',color:0},
  {id:'m2', title:'大学英语',room:'教学楼 B · 208',day:1,start:'10:10',end:'11:45',color:1},
  {id:'t1', title:'高等数学',room:'教学楼 A · 201',day:2,start:'08:30',end:'10:05',color:2},
  {id:'t2', title:'机械原理',room:'教学楼 A · 302',day:2,start:'10:30',end:'12:05',color:0},
  {id:'t3', title:'体育',room:'西区操场',day:2,start:'14:30',end:'16:00',color:1},
  {id:'w1', title:'工程制图',room:'实验楼 · 405',day:3,start:'09:00',end:'11:00',color:3},
  {id:'th1',title:'大学英语',room:'教学楼 B · 208',day:4,start:'10:00',end:'11:35',color:1},
  {id:'f1', title:'机器人实验',room:'实验楼 · 101',day:5,start:'14:00',end:'16:00',color:0}
];
let state = {courses:seedCourses,messages:[]};
try {
  const saved = JSON.parse(localStorage.getItem(storageKey));
  if (saved && Array.isArray(saved.courses) && Array.isArray(saved.messages)
      && saved.courses.every(c => typeof c.id==='string' && typeof c.title==='string' && typeof c.room==='string'
          && Number.isInteger(c.day) && c.day>=1 && c.day<=7 && /^\d{2}:\d{2}$/.test(c.start) && /^\d{2}:\d{2}$/.test(c.end)
          && Number.isInteger(c.color) && c.color>=0 && c.color<=3)
      && saved.messages.every(m=>['user','assistant'].includes(m.role)&&typeof m.text==='string')) state=saved;
} catch { /* Preview opens with sample data if browser storage is unavailable. */ }

const characterMeta = {
  compass:{name:'规',color:'#4f63c7',hello:'圆合上了。先别急着解下一题。'},
  fold:{name:'折',color:'#178f87',hello:'这张纸，终于可以抬头看看你了。'},
  comma:{name:'逗',color:'#d05243',hello:'先逗留一下。句子晚一点再继续。'},
  cam:{name:'凸',color:'#6d7550',hello:'齿轮停了。现在轮到你松一口气。'},
  spring:{name:'弹',color:'#d17b3f',hello:'拉伸一下吧。今天不必一直绷紧。'},
  probe:{name:'试',color:'#725eaa',hello:'实验结束。失败的数据也算见过世界。'},
  seed:{name:'未',color:'#657267',hello:'我还没有名字。下次再慢慢认识。'}
};
function subjectKind(title=''){
  if(/高等数学|数学|微积分|线性代数|概率/.test(title))return 'compass';
  if(/工程制图|制图|设计表达|CAD|画法几何/.test(title))return 'fold';
  if(/英语|语言|写作|语文/.test(title))return 'comma';
  if(/机械|机原|机构|齿轮/.test(title))return 'cam';
  if(/体育|体能|篮球|足球|游泳/.test(title))return 'spring';
  if(/机器人|实验|编程|计算机|电子/.test(title))return 'probe';
  return 'seed';
}
function clamp(value,min=0,max=1){return Math.max(min,Math.min(max,value));}
function characterSVG(kind,progress,phase,label=''){
  const p=clamp(progress),alive=phase!=='class',eyes=alive?'<g class="character-eyes" fill="currentColor" stroke="none"><circle cx="116" cy="83" r="3.2"/><circle cx="136" cy="83" r="3.2"/></g>':'';
  const common='viewBox="0 0 252 178" role="img" data-kind="'+kind+'"';
  if(kind==='compass')return `<svg ${common}><g fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path class="trace" pathLength="100" style="--trace:${100-p*100}" d="M62 119 A66 66 0 1 1 190 119"/><circle cx="126" cy="56" r="9"/><path d="M121 64 86 139M131 64l35 75M75 139h23M154 139h23"/><path class="progress-hand" d="M126 56 126 ${56+74*p}"/></g>${eyes}</svg>`;
  if(kind==='fold'){
    const opacity=(n)=>p>=n?1:.12;
    return `<svg ${common}><g fill="none" stroke="currentColor" stroke-width="3" stroke-linejoin="round"><path d="M62 48h50v42H62z" opacity="${opacity(.05)}"/><path d="M112 48h50v42h-50z" opacity="${opacity(.28)}"/><path d="M112 90h50v42h-50z" opacity="${opacity(.5)}"/><path d="M162 90h40v42h-40z" opacity="${opacity(.72)}"/><path d="M72 132h40v32H72z" opacity="${opacity(.9)}"/><path class="fold-line" d="M112 48v84M62 90h140"/></g>${eyes}</svg>`;
  }
  if(kind==='comma')return `<svg ${common}><g fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"><path d="M45 68h${Math.round(112*p)}"/><path d="M45 101h${Math.round(148*p)}"/><path d="M45 134h${Math.round(92*p)}"/><path d="M170 48c22 0 30 14 30 31 0 18-10 30-27 41 8-11 10-19 5-28-14-4-18-13-18-22 0-12 4-22 10-22z"/></g>${eyes}</svg>`;
  if(kind==='cam')return `<svg ${common}><g fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><circle cx="108" cy="91" r="48"/><circle cx="108" cy="91" r="7"/><path class="cam-arm" style="--turn:${p}turn" d="M108 91 148 64l39 29"/><path d="M187 65v56M173 121h28"/></g>${eyes}</svg>`;
  if(kind==='spring'){
    const w=35+55*p;
    return `<svg ${common}><g fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><path d="M45 90h25l14-${w/4} ${w/2} ${w/2}-${w} ${w/2} ${w/2}-${w/4} 14h26"/><path d="M45 72v36M207 72v36"/></g>${eyes}</svg>`;
  }
  if(kind==='probe')return `<svg ${common}><g fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round" stroke-linejoin="round"><rect x="70" y="62" width="78" height="66" rx="8"/><path d="M148 79h31l20 ${Math.round(23+32*p)}M178 79v46M58 139h142"/><circle cx="199" cy="${Math.round(102+32*p)}" r="6"/><path d="M88 50v12m42-12v12"/></g>${eyes}</svg>`;
  const initial=(label.trim()[0]||'未').replace(/[<>&]/g,'');
  return `<svg ${common}><g fill="none" stroke="currentColor" stroke-width="3" stroke-linecap="round"><path class="trace" pathLength="100" style="--trace:${100-p*100}" d="M54 92c0-37 31-58 72-58s72 21 72 58-31 58-72 58-72-21-72-58z"/></g><text x="126" y="104" text-anchor="middle" fill="currentColor" font-size="34" font-family="sans-serif">${initial}</text>${eyes}</svg>`;
}
function persist(){try{localStorage.setItem(storageKey,JSON.stringify(state));}catch{$('characterCaption').textContent='浏览器没能保存这次修改。关闭前请留意。';}}
function textNode(tag,text,className){const e=document.createElement(tag);e.textContent=text;if(className)e.className=className;return e;}
function coursesFor(day){return state.courses.filter(c=>c.day===day).sort((a,b)=>a.start.localeCompare(b.start));}
function minutes(t){const [h,m]=t.split(':').map(Number);return h*60+m;}
function clockMinute(){const n=new Date();return demoMinute ?? n.getHours()*60+n.getMinutes();}
function courseCard(c,editable=false){
  const card=document.createElement(editable?'button':'div');card.className=`course-card color-${c.color}`;card.dataset.kind=subjectKind(c.title);
  const time=textNode('span','','course-time');time.append(textNode('b',c.start),textNode('small',c.end));
  const info=textNode('span','','course-info');info.append(textNode('b',c.title),textNode('small','⌖  '+(c.room||'教室待定')));
  let status='稍后';const minute=clockMinute();
  if(!editable){
    if(minute>=minutes(c.end))status='已结束';else if(minute>=minutes(c.start))status='上课中';else if(coursesFor(todayWeekday).find(x=>minutes(x.start)>minute)?.id===c.id)status='下一节';
    card.classList.toggle('past',status==='已结束');card.classList.toggle('current',status==='上课中');
  }
  const mark=textNode('span','','course-mark');mark.append(textNode('i',characterMeta[subjectKind(c.title)].name),textNode('small',editable?'编辑':status));card.append(time,info,mark);
  if(editable){card.type='button';card.setAttribute('aria-label','编辑 '+c.title);card.onclick=()=>openEditor(c);}return card;
}
function renderCourses(container,day,editable=false,skipID=null){
  container.replaceChildren();const courses=coursesFor(day).filter(c=>c.id!==skipID);
  if(!courses.length){const empty=textNode('div','','empty-day');empty.append(textNode('span','○'),textNode('p',skipID?'这一刻，只留给上面的角色。':'今天留白，刚好装一点快乐。'));container.append(empty);}
  for(const c of courses)container.append(courseCard(c,editable));
}
function renderSchedule(){
  $('dateLabel').textContent=today.toLocaleDateString('zh-CN',{month:'long',day:'numeric',weekday:'long'});
  const monday=new Date(today);monday.setDate(today.getDate()-(todayWeekday-1));$('dayStrip').replaceChildren();
  for(let i=1;i<=7;i++){
    const date=new Date(monday);date.setDate(monday.getDate()+i-1);const button=document.createElement('button');button.className=i===selectedDay?'selected':'';
    button.setAttribute('aria-pressed',String(i===selectedDay));button.setAttribute('aria-label','星期'+['一','二','三','四','五','六','日'][i-1]);button.append(textNode('span',['一','二','三','四','五','六','日'][i-1]),textNode('b',String(date.getDate())));
    const dot=document.createElement('i');if(!coursesFor(i).length)dot.style.background='transparent';button.append(dot);button.onclick=()=>{selectedDay=i;renderSchedule();};$('dayStrip').append(button);
  }
  $('selectedDayTitle').textContent='星期'+['一','二','三','四','五','六','日'][selectedDay-1];renderCourses($('dayCourses'),selectedDay,true);renderMoment();
}
function renderMoment(){
  const list=coursesFor(todayWeekday),m=clockMinute();const current=list.find(c=>minutes(c.start)<=m&&m<minutes(c.end));const next=list.find(c=>minutes(c.start)>m);const ended=list.filter(c=>minutes(c.end)<=m);const done=ended.length;
  const phase=!list.length?'empty':current?'class':next?(done?'break':'before'):'finished';const course=current||next||ended.at(-1)||null;
  const labels={empty:'今天，留一点空白',before:'下一节，慢慢准备',class:'现在，它正在成为这门课',break:'课间，下一位已经到了',finished:'最后一位，转过身来了'};
  const box=$('momentCard');box.replaceChildren();const heading=textNode('div','','moment-heading');heading.append(textNode('span',labels[phase]),textNode('span',demoMinute===null?'此刻':'演示','moment-tag'));box.append(heading);
  if(course){box.append(textNode('h3',course.title));const detail=textNode('div','','moment-detail');detail.append(textNode('span','⌖ '+(course.room||'教室待定')),textNode('span',course.start+' — '+course.end));box.append(detail);}else box.append(textNode('h3','不必把每一格填满。'));
  let timing='添加课程后，这里会跟着一天变化。';if(current)timing='还剩 '+(minutes(current.end)-m)+' 分钟。它会在下课时完成。';else if(next)timing='距开始还有 '+(minutes(next.start)-m)+' 分钟。';else if(list.length)timing='今天登记的 '+list.length+' 节课，都已到结束时间。';box.append(textNode('p',timing,'moment-timing'));
  const kind=course?subjectKind(course.title):'seed',meta=characterMeta[kind];let progress=0;if(current)progress=(m-minutes(current.start))/(minutes(current.end)-minutes(current.start));else if(phase==='finished')progress=1;
  featuredCharacter={kind,name:meta.name,course};$('subjectStage').dataset.phase=phase;$('subjectStage').style.setProperty('--subject',meta.color);$('characterName').textContent=course?`${meta.name} · ${course.title}`:'未 · 自由留白';
  $('stagePhase').textContent={empty:'今天休息',before:'起点等待',class:'器物状态 '+Math.round(progress*100)+'%',break:'下一节准备',finished:'人物状态'}[phase];$('characterMount').innerHTML=characterSVG(kind,progress,phase,course?.title||'未');
  const button=$('characterButton');button.disabled=phase==='class';button.setAttribute('aria-label',phase==='class'?`${course.title}上课中，角色暂不回应`:`和${meta.name}打招呼`);
  $('characterCaption').textContent=phase==='class'?`${meta.name}正在完成这节课。下课后再见。`:phase==='finished'?`${meta.name}完成了今天最后一段时间。`:phase==='break'?`${meta.name}已经到了起点，等下一节开始。`:phase==='before'?`${meta.name}还没成为器物，可以先看你一眼。`:'今天没有角色需要赶来。';
  $('chatPromptLabel').textContent=course?`和${meta.name}说两句`:'把空白说给我听';$('courseCount').textContent=list.length?`${done} / ${list.length} 节已结束`:'今天没有登记的课程';document.querySelector('#todayScreen .section-heading h3').textContent=course?'今天的其他安排':'今天的安排';renderCourses($('todayCourses'),todayWeekday,false,course?.id);
}
function navigate(tab){
  for(const name of ['today','timetable','chat'])$(name+'Screen').hidden=name!==tab;for(const b of document.querySelectorAll('[data-tab]')){b.classList.toggle('active',b.dataset.tab===tab);if(b.dataset.tab===tab)b.setAttribute('aria-current','page');else b.removeAttribute('aria-current');}
  $('appScroll').scrollTop=0;if(tab==='chat')renderMessages();
}
document.querySelectorAll('[data-tab]').forEach(b=>b.onclick=()=>navigate(b.dataset.tab));$('chatPrompt').onclick=()=>navigate('chat');$('settingsButton').onclick=()=>$('settingsDialog').showModal();
$('characterButton').onclick=()=>{
  if($('characterButton').disabled)return;clearTimeout(helloTimer);const meta=characterMeta[featuredCharacter.kind];$('characterCaption').textContent=meta.hello;$('characterButton').classList.remove('hello');void $('characterButton').offsetWidth;$('characterButton').classList.add('hello');helloTimer=setTimeout(()=>$('characterButton').classList.remove('hello'),900);
};
$('previewTime').oninput=()=>{if(!$('previewTime').value)return;demoMinute=minutes($('previewTime').value);$('clockMode').textContent='演示中 · 不修改课表';renderSchedule();};$('liveClock').onclick=()=>{demoMinute=null;$('previewTime').value='';$('clockMode').textContent='实时 · 不修改课表';renderSchedule();};setInterval(()=>{const n=new Date();today=n;todayWeekday=(n.getDay()+6)%7+1;renderSchedule();},30000);
function renderMessages(){
  $('messages').replaceChildren();if(!state.messages.length){const empty=textNode('div','','chat-empty');const art=textNode('div','','chat-character');art.innerHTML=characterSVG(featuredCharacter.kind,1,'finished',featuredCharacter.course?.title||'未');empty.append(art,textNode('h3','不用组织语言。'),textNode('p','今天见过你的角色，都在这里安静听着。'));$('messages').append(empty);}
  for(const message of state.messages){const item=textNode('div',message.text,'message '+message.role);if(message.role==='assistant')item.append(textNode('small','离线回应'));$('messages').append(item);}
}
$('chatForm').onsubmit=e=>{
  e.preventDefault();const value=$('chatInput').value.trim().slice(0,2000);if(!value)return;state.messages.push({role:'user',text:value});let answer='我听见了。现在是离线互动；原生 App 接通 AI 后，会由今天的学科角色接着聊。';if(/累|困/.test(value))answer='嗯。先在这里停一会儿。';else if(/开心|成功|过了/.test(value))answer='这件事，值得记一下。';state.messages.push({role:'assistant',text:answer});state.messages=state.messages.slice(-200);persist();$('chatInput').value='';renderMessages();$('appScroll').scrollTop=$('appScroll').scrollHeight;
};
$('clearChat').onclick=()=>$('clearDialog').showModal();$('clearDialog').addEventListener('close',()=>{if($('clearDialog').returnValue==='clear'){state.messages=[];persist();renderMessages();}});
function openEditor(course){
  editingID=course?.id||null;$('editorTitle').textContent=course?'编辑课程':'新的一门课';$('courseTitle').value=course?.title||'';$('courseRoom').value=course?.room||'';$('courseStart').value=course?.start||'08:00';$('courseEnd').value=course?.end||'09:35';$('courseColor').value=course?.color??0;$('deleteCourse').hidden=!course;$('courseError').textContent='';$('courseDialog').showModal();
}
$('addCourse').onclick=()=>openEditor();$('closeEditor').onclick=()=>$('courseDialog').close();$('courseForm').onsubmit=e=>{
  e.preventDefault();const title=$('courseTitle').value.trim(),start=$('courseStart').value,end=$('courseEnd').value;if(!title){$('courseError').textContent='给这门课起个名字吧。';return;}if(end<=start){$('courseError').textContent='结束时间要晚于开始时间。';return;}
  const course={id:editingID||crypto.randomUUID(),title,room:$('courseRoom').value.trim(),start,end,day:selectedDay,color:Number($('courseColor').value)};const index=state.courses.findIndex(c=>c.id===course.id);if(index>=0)state.courses[index]=course;else state.courses.push(course);persist();renderSchedule();$('courseDialog').close();
};
$('deleteCourse').onclick=()=>{state.courses=state.courses.filter(c=>c.id!==editingID);persist();renderSchedule();$('courseDialog').close();};renderSchedule();
