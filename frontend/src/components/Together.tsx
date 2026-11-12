'use client';
import { useState } from 'react';
import { Anniversary, State, daysBetween, daysUntil, nextMilestone, setState, todayKey, uid } from '@/lib/store';
import { download, renderShareCard } from '@/lib/media';

const LINES = ['余生请多指教', '和你在一起的每一天都算数', '喜欢你，是一件很长的事', '今天也很喜欢你'];

export default function Together({ s }: { s: State }) {
  const today = todayKey();
  const days = daysBetween(s.startDate, today) + 1; // 在一起当天算第 1 天
  const ms = nextMilestone(days);
  const [name, setName] = useState('');
  const [date, setDate] = useState('');
  const [yearly, setYearly] = useState(true);
  const [preview, setPreview] = useState<string | null>(null);

  const list = [
    ...s.anniversaries,
    { id: '_start', name: '在一起纪念日', date: s.startDate, yearly: true } as Anniversary,
  ]
    .map((a) => ({ a, left: daysUntil(a, today) }))
    .filter((x) => x.left !== null)
    .sort((x, y) => x.left! - y.left!);

  const add = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim() || !date) return;
    setState((st) => ({ ...st, anniversaries: [...st.anniversaries, { id: uid(), name: name.trim(), date, yearly }] }));
    setName(''); setDate('');
  };
  const remove = (id: string) => setState((st) => ({ ...st, anniversaries: st.anniversaries.filter((a) => a.id !== id) }));
  const share = () => setPreview(renderShareCard({
    me: s.me, partner: s.partner, days, startDate: s.startDate, line: LINES[days % LINES.length],
  }));

  return (
    <div className="stack">
      <div className="card hero-card">
        <div className="names">{s.me} <span className="beat">♥</span> {s.partner}</div>
        <div className="label">我们已经在一起</div>
        <div className="big-num">{days}<small>天</small></div>
        <div><span className="pill">距离{ms.label}还有 {ms.left} 天</span></div>
        <button className="btn ghost" onClick={share}>生成分享卡片 ✨</button>
      </div>

      {preview && (
        <div className="modal" onClick={() => setPreview(null)}>
          <div className="modal-body" onClick={(e) => e.stopPropagation()}>
            <img src={preview} alt="分享卡片" />
            <p className="hint">手机上可长按图片保存，发朋友圈 / 小红书</p>
            <div className="row">
              <button className="btn primary" onClick={() => download(preview, `我们在一起第${days}天.png`)}>保存图片</button>
              <button className="btn" onClick={() => setPreview(null)}>关闭</button>
            </div>
          </div>
        </div>
      )}

      <div className="card">
        <h2>纪念日倒数</h2>
        <ul className="list">
          {list.map(({ a, left }) => (
            <li key={a.id} className={left === 0 ? 'today' : ''}>
              <div><b>{a.name}</b><span className="muted">{a.date}{a.yearly ? ' · 每年' : ''}</span></div>
              <div className="right">
                <span className="count">{left === 0 ? '就是今天 🎉' : <>还有 <b>{left}</b> 天</>}</span>
                {a.id !== '_start' && <button className="x" aria-label="删除" onClick={() => remove(a.id)}>×</button>}
              </div>
            </li>
          ))}
        </ul>
        <form className="inline" onSubmit={add}>
          <input placeholder="TA 的生日 / 第一次旅行…" value={name} onChange={(e) => setName(e.target.value)} maxLength={20} />
          <input type="date" value={date} onChange={(e) => setDate(e.target.value)} />
          <label className="check"><input type="checkbox" checked={yearly} onChange={(e) => setYearly(e.target.checked)} />每年</label>
          <button className="btn primary">添加</button>
        </form>
      </div>
    </div>
  );
}
