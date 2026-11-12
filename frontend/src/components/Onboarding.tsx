'use client';
import { useRef, useState } from 'react';
import { createSpace, importData, todayKey } from '@/lib/store';

const FEATURES = [
  ['💞', '在一起天数', '每天打开都能看到“我们在一起第 N 天”，纪念日自动倒数，再也不会忘记重要日子。'],
  ['📸', '回忆时间线', '随手记下吃过的店、看过的电影、吵过又和好的夜晚。'],
  ['🎡', '选择困难终结者', '“今天吃什么”“周末去哪”——转一下，不再互相说“都行”。'],
  ['💬', '每日一问', '每天一个走心问题，两个人各自回答再揭晓，聊出平时说不出口的话。'],
  ['✅', '情侣清单', '一起列下想做的 100 件事，一件件打卡。'],
  ['🔒', '数据只属于你们', '无需注册、无广告，数据只保存在你的设备上，可随时导出备份。'],
];

export default function Onboarding() {
  const [me, setMe] = useState('');
  const [partner, setPartner] = useState('');
  const [date, setDate] = useState('');
  const [err, setErr] = useState('');
  const fileRef = useRef<HTMLInputElement>(null);

  const start = (e: React.FormEvent) => {
    e.preventDefault();
    if (!me.trim() || !partner.trim()) return setErr('写下你们两个人的名字吧');
    if (!date) return setErr('选一下你们在一起的日子');
    if (date > todayKey()) return setErr('在一起的日子不能在未来哦');
    createSpace(me.trim(), partner.trim(), date);
  };
  const onImport = async (f?: File) => {
    if (!f) return;
    if (!importData(await f.text())) setErr('备份文件无法识别');
  };

  return (
    <main className="landing">
      <section className="hero">
        <div className="logo">BetterHalf<span>♥</span></div>
        <h1>两个人的小宇宙</h1>
        <p className="sub">记录在一起的每一天，告别“吃什么都行”，<br />把想说的话好好说给 TA 听。</p>
        <form className="card onboard" onSubmit={start}>
          <div className="row2">
            <label>你的昵称<input value={me} onChange={(e) => setMe(e.target.value)} placeholder="比如：小明" maxLength={12} /></label>
            <label>TA 的昵称<input value={partner} onChange={(e) => setPartner(e.target.value)} placeholder="比如：小红" maxLength={12} /></label>
          </div>
          <label>在一起的日子<input type="date" value={date} max={todayKey()} onChange={(e) => setDate(e.target.value)} /></label>
          {err && <p className="err">{err}</p>}
          <button className="btn primary big" type="submit">开启我们的空间 →</button>
          <button type="button" className="link" onClick={() => fileRef.current?.click()}>已有备份？导入数据</button>
          <input ref={fileRef} type="file" accept="application/json" hidden onChange={(e) => onImport(e.target.files?.[0])} />
        </form>
      </section>
      <section className="features">
        {FEATURES.map(([icon, t, d]) => (
          <div className="feature" key={t}><div className="ficon">{icon}</div><h3>{t}</h3><p>{d}</p></div>
        ))}
      </section>
      <footer className="foot">无需注册 · 30 秒开始 · 永久免费</footer>
    </main>
  );
}
