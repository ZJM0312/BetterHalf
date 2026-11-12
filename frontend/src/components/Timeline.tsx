'use client';
import { useRef, useState } from 'react';
import { State, setState, todayKey, uid } from '@/lib/store';
import { MOODS } from '@/lib/content';
import { compressImage } from '@/lib/media';

export default function Timeline({ s }: { s: State }) {
  const [text, setText] = useState('');
  const [date, setDate] = useState(todayKey());
  const [mood, setMood] = useState(MOODS[0]);
  const [by, setBy] = useState<'me' | 'partner'>('me');
  const [photo, setPhoto] = useState<string>();
  const [err, setErr] = useState('');
  const fileRef = useRef<HTMLInputElement>(null);

  const pick = async (f?: File) => {
    if (!f) return;
    try { setPhoto(await compressImage(f)); setErr(''); } catch (e) { setErr((e as Error).message); }
  };
  const add = (e: React.FormEvent) => {
    e.preventDefault();
    if (!text.trim() && !photo) return;
    const ok = setState((st) => ({ ...st, moments: [{ id: uid(), date, text: text.trim(), mood, photo, by }, ...st.moments] }));
    if (!ok) return setErr('存储空间满了：试试不带照片，或在“设置”里导出备份后清理旧回忆');
    setText(''); setPhoto(undefined); setErr('');
  };
  const remove = (id: string) => { if (confirm('删除这条回忆？')) setState((st) => ({ ...st, moments: st.moments.filter((m) => m.id !== id) })); };

  const sorted = [...s.moments].sort((a, b) => (a.date < b.date ? 1 : a.date > b.date ? -1 : 0));
  const onThisDay = s.moments.filter((m) => m.date.slice(5) === todayKey().slice(5) && m.date !== todayKey());

  return (
    <div className="stack">
      {onThisDay.length > 0 && (
        <div className="card memory-flash">
          <h2>📅 那年今天</h2>
          {onThisDay.map((m) => <p key={m.id}><b>{m.date.slice(0, 4)}</b> {m.mood} {m.text}</p>)}
        </div>
      )}
      <form className="card" onSubmit={add}>
        <h2>记录一个瞬间</h2>
        <textarea rows={3} placeholder="今天一起去吃了那家排队很久的店…" value={text} onChange={(e) => setText(e.target.value)} maxLength={500} />
        {photo && <div className="thumb"><img src={photo} alt="" /><button type="button" className="x" onClick={() => setPhoto(undefined)}>×</button></div>}
        <div className="moods">{MOODS.map((m) => <button type="button" key={m} className={m === mood ? 'on' : ''} onClick={() => setMood(m)}>{m}</button>)}</div>
        <div className="inline">
          <input type="date" value={date} max={todayKey()} onChange={(e) => setDate(e.target.value)} />
          <select value={by} onChange={(e) => setBy(e.target.value as 'me' | 'partner')}>
            <option value="me">{s.me} 记录</option><option value="partner">{s.partner} 记录</option>
          </select>
          <button type="button" className="btn" onClick={() => fileRef.current?.click()}>📷 照片</button>
          <button className="btn primary">保存</button>
        </div>
        <input ref={fileRef} type="file" accept="image/*" hidden onChange={(e) => { pick(e.target.files?.[0]); e.target.value = ''; }} />
        {err && <p className="err">{err}</p>}
      </form>
      {sorted.length === 0 ? (
        <div className="empty">还没有回忆，从今天开始记录吧 ✍️</div>
      ) : (
        <ol className="timeline">
          {sorted.map((m) => (
            <li key={m.id}>
              <div className="dot">{m.mood}</div>
              <div className="card moment">
                <div className="meta"><span>{m.date}</span><span>{m.by === 'me' ? s.me : s.partner}</span><button className="x" onClick={() => remove(m.id)} aria-label="删除">×</button></div>
                {m.text && <p>{m.text}</p>}
                {m.photo && <img src={m.photo} alt="" />}
              </div>
            </li>
          ))}
        </ol>
      )}
    </div>
  );
}
