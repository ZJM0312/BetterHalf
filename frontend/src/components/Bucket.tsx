'use client';
import { useState } from 'react';
import { State, setState, todayKey, uid } from '@/lib/store';
import { BUCKET_IDEAS } from '@/lib/content';

export default function Bucket({ s }: { s: State }) {
  const [text, setText] = useState('');
  const done = s.bucket.filter((b) => b.done).length;
  const add = (t: string) => { if (t.trim()) setState((st) => ({ ...st, bucket: [...st.bucket, { id: uid(), text: t.trim(), done: false }] })); };
  const toggle = (id: string) => setState((st) => ({ ...st, bucket: st.bucket.map((b) => (b.id === id ? { ...b, done: !b.done, doneAt: !b.done ? todayKey() : undefined } : b)) }));
  const remove = (id: string) => setState((st) => ({ ...st, bucket: st.bucket.filter((b) => b.id !== id) }));
  const ideas = BUCKET_IDEAS.filter((i) => !s.bucket.some((b) => b.text === i));
  const items = [...s.bucket].sort((a, b) => Number(a.done) - Number(b.done));

  return (
    <div className="stack">
      <div className="card">
        <h2>我们要一起做的事 <span className="muted">{done}/{s.bucket.length}</span></h2>
        {s.bucket.length > 0 && <div className="bar"><div style={{ width: `${(done / s.bucket.length) * 100}%` }} /></div>}
        <form className="inline" onSubmit={(e) => { e.preventDefault(); add(text); setText(''); }}>
          <input placeholder="一起去看极光…" value={text} onChange={(e) => setText(e.target.value)} maxLength={40} />
          <button className="btn primary">添加</button>
        </form>
        <ul className="list bucket">
          {items.map((b) => (
            <li key={b.id} className={b.done ? 'done' : ''}>
              <label><input type="checkbox" checked={b.done} onChange={() => toggle(b.id)} /> {b.text}</label>
              <div className="right">{b.doneAt && <span className="muted">{b.doneAt}</span>}<button className="x" onClick={() => remove(b.id)}>×</button></div>
            </li>
          ))}
        </ul>
        {s.bucket.length === 0 && <div className="empty">还没有清单，从下面挑几个灵感吧</div>}
      </div>
      {ideas.length > 0 && (
        <div className="card">
          <h2>💡 灵感</h2>
          <div className="chips">{ideas.map((i) => <button key={i} className="chip" onClick={() => add(i)}>+ {i}</button>)}</div>
        </div>
      )}
    </div>
  );
}
