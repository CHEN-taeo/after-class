'use strict';
const {chromium}=require('playwright');
const fs=require('node:fs');
const path=require('node:path');
const {pathToFileURL}=require('node:url');
const assert=require('node:assert/strict');
const root=path.resolve(__dirname,'..');
const results=[];

(async()=>{
  const browser=await chromium.launch({headless:true,channel:process.env.AFTERCLASS_BROWSER_CHANNEL||'msedge'});
  try {
    const page=await browser.newPage({viewport:{width:1440,height:1060},deviceScaleFactor:1});
    const errors=[];page.on('pageerror',e=>errors.push(e.message));
    await page.clock.install({time:new Date('2026-10-06T08:00:00+08:00')});
    const previewURL=pathToFileURL(path.join(root,'preview/index.html')).href;await page.goto(previewURL,{waitUntil:'load'});await page.evaluate(()=>localStorage.clear());await page.reload({waitUntil:'load'});
    await page.locator('#characterMount svg').waitFor();await page.screenshot({path:path.join(root,'validation/desktop.png'),fullPage:true});

    assert.match(await page.locator('#momentCard').innerText(),/下一节/);assert.match(await page.locator('#characterName').innerText(),/规 · 高等数学/);
    assert.equal(await page.locator('#characterMount svg').getAttribute('data-kind'),'compass');assert.equal(await page.locator('.character-eyes circle').count(),2);results.push('before class shows the subject character');
    await page.locator('#characterButton').click();assert.match(await page.locator('#characterCaption').innerText(),/圆合上了/);results.push('character answers a tap while off class');

    await page.locator('#previewTime').fill('08:30');assert.match(await page.locator('#momentCard').innerText(),/正在成为这门课/);assert.match(await page.locator('#stagePhase').innerText(),/器物状态 0%/);
    assert.equal(await page.locator('.character-eyes').count(),0);assert.equal(await page.locator('#characterButton').isDisabled(),true);results.push('class start removes eyes and disables social interaction');
    await page.locator('#previewTime').fill('09:15');assert.match(await page.locator('#stagePhase').innerText(),/器物状态 47%/);results.push('character drawing follows course progress');
    await page.locator('#previewTime').fill('10:05');assert.match(await page.locator('#momentCard').innerText(),/课间/);assert.match(await page.locator('#characterName').innerText(),/凸 · 机械原理/);assert.equal(await page.locator('.character-eyes circle').count(),2);results.push('break hands the stage to the next subject');
    await page.locator('#previewTime').fill('16:00');assert.match(await page.locator('#momentCard').innerText(),/转过身来了/);assert.match(await page.locator('#characterName').innerText(),/弹 · 体育/);assert.match(await page.locator('#stagePhase').innerText(),/人物状态/);results.push('last subject becomes a character after class');
    assert.equal(await page.locator('#todayCourses [data-kind="spring"]').count(),0);results.push('featured course is not duplicated below');
    await page.locator('#liveClock').click();assert.match(await page.locator('#clockMode').innerText(),/实时/);

    await page.getByRole('button',{name:'课表',exact:true}).click();await page.getByRole('button',{name:'星期三',exact:true}).click();await page.getByRole('button',{name:'添加课程',exact:true}).click();
    await page.locator('#courseTitle').fill('测试实验课');await page.locator('#courseRoom').fill('实验楼 102');await page.locator('#courseStart').fill('14:00');await page.locator('#courseEnd').fill('13:00');
    await page.getByRole('button',{name:'保存这门课',exact:true}).click();assert.match(await page.locator('#courseError').innerText(),/晚于/);results.push('invalid end time blocked');
    await page.locator('#courseEnd').fill('15:30');await page.getByRole('button',{name:'保存这门课',exact:true}).click();assert.equal(await page.getByRole('button',{name:'编辑 测试实验课',exact:true}).count(),1);results.push('course create');
    await page.reload({waitUntil:'networkidle'});await page.getByRole('button',{name:'课表',exact:true}).click();await page.getByRole('button',{name:'星期三',exact:true}).click();await page.getByRole('button',{name:'编辑 测试实验课',exact:true}).click();await page.locator('#courseTitle').fill('已修改实验课');await page.getByRole('button',{name:'保存这门课',exact:true}).click();
    assert.equal(await page.getByRole('button',{name:'编辑 已修改实验课',exact:true}).count(),1);results.push('course persistence and edit');await page.getByRole('button',{name:'编辑 已修改实验课',exact:true}).click();await page.getByRole('button',{name:'删除课程',exact:true}).click();assert.equal(await page.getByRole('button',{name:'编辑 已修改实验课',exact:true}).count(),0);results.push('course delete');

    await page.getByRole('button',{name:'说两句',exact:true}).click();await page.getByLabel('发送消息给今天的角色').fill('今天好累');await page.getByRole('button',{name:'发送消息',exact:true}).click();assert.match(await page.locator('#messages').innerText(),/先在这里停一会儿/);assert.match(await page.locator('#messages').innerText(),/离线回应/);results.push('offline chat is restrained and labeled');
    await page.reload({waitUntil:'networkidle'});await page.getByRole('button',{name:'说两句',exact:true}).click();assert.match(await page.locator('#messages').innerText(),/今天好累/);results.push('chat persistence');
    await page.getByLabel('发送消息给今天的角色').fill('<img src=x onerror=alert(1)>');await page.getByRole('button',{name:'发送消息',exact:true}).click();assert.equal(await page.locator('#messages .message img').count(),0);results.push('chat renders input as plain text');
    await page.getByRole('button',{name:'清空聊天记录',exact:true}).click();await page.getByRole('button',{name:'取消',exact:true}).click();assert.ok(await page.locator('.message').count()>0);results.push('clear cancel preserves data');await page.getByRole('button',{name:'清空聊天记录',exact:true}).click();await page.getByRole('button',{name:'清空',exact:true}).click();assert.equal(await page.locator('.message').count(),0);results.push('clear confirmed');
    await page.getByRole('button',{name:'今天',exact:true}).click();await page.getByRole('button',{name:'打开设置',exact:true}).click();assert.match(await page.locator('#settingsDialog').innerText(),/不收集密钥/);await page.getByRole('button',{name:'知道了',exact:true}).click();results.push('preview does not collect credentials');

    for(const width of [375,390,430]){
      await page.setViewportSize({width,height:844});await page.reload({waitUntil:'networkidle'});const overflow=await page.evaluate(()=>document.documentElement.scrollWidth>innerWidth);assert.equal(overflow,false);results.push(`no horizontal overflow at ${width}px`);
      if(width===390){await page.locator('#previewTime').fill('09:15');await page.screenshot({path:path.join(root,'validation/iphone.png')});await page.locator('#previewTime').fill('16:00');await page.screenshot({path:path.join(root,'validation/after-class.png')});await page.getByRole('button',{name:'说两句',exact:true}).click();await page.screenshot({path:path.join(root,'validation/chat.png')});}
    }
    await page.emulateMedia({reducedMotion:'reduce'});await page.getByRole('button',{name:'今天',exact:true}).click();await page.locator('#previewTime').fill('16:00');const motion=await page.locator('.character-eyes').evaluate(el=>getComputedStyle(el).animationName);assert.equal(motion,'none');results.push('reduced motion respected');
    assert.deepEqual(errors,[]);results.push('no browser JavaScript exceptions');fs.writeFileSync(path.join(root,'validation/preview-check.json'),JSON.stringify({passed:true,checks:results},null,2));console.log(JSON.stringify({passed:true,count:results.length,checks:results},null,2));
  } finally {await browser.close();}
})().catch(e=>{console.error(e);process.exit(1);});
