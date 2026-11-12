'use client';
import { useState } from 'react';
import { State, setState, uid } from '@/lib/store';
import { DECISION_PRESETS } from '@/lib/content';

const COLORS = ['#ff8fa3', '#ffb86b', '#ffd86b', '#8fd694', '#6bc7ff', '#a98bff', '#ff8fd8', '#7fe0d0'];

export default function Decide({ s }: { s: State }) {
  const [activeId, setActiveId] = useState(s.decisions[0]?.id);
  const list = s.decisions.find((d) => d.id === activeId) ?? s.decisions[0];
  const [opt, setOpt] = useState('');
  const [angle, setAngle] = useState(0);
  const [spinning, setSpinning] = useState(false);
  const [result, setResult] = useState<string | null>(null);

  const update = (options: string[]) => setState((st) => ({ ...st, decisions: st.decisions.map((d) => (d.id === list.id ? { ...d, options } : d)) }));
  const addPreset = (p: (typeof DECISION_PRESETS)[number]) => {
    const exist = s.decisions.find((d) => d.name === p.name);
    if (exist) return setActiveId(exist.id);
    const id = uid();
    setState((st) => ({ ...st, decisions: [...st.decisions, { id, ...p }] }));
    setActiveId(id); setResult(null);
  };
  const spin = () => {
    if (!list || list.options.length < 2 || spinning) return;
    const n = list.options.length;
    const idx = Math.floor(Math.random() * n);
    const seg = 360 / n;
    // pointer at top: rotate so the chosen segment's center lands at 0deg
    const target = 360 * 6 + (360 - (idx * seg + seg / 2));
    setResult(null); setSpinning(true);
    setAngle((a) => a - (a % 360) + target);
    setTimeout(() => { setSpinning(false); setResult(list.options[idx]); }, 3200);
  };

  const n = list?.options.length ?? 0;
  const gradient = n ? `conic-gradient(${list.options.map((_, i) => `${COLORS[i % COLORS.length]} ${(i * 100) / n}% ${((i + 1) * 100) / n}%`).join(',')})` : '#eee';

  return (
    <div className="stack">
      <div className="chips">
        {DECISION_PRESETS.map((p) => (
          <button key={p.name} className={list?.name === p.name ? 'chip on' : 'chip'} onClick={() => addPreset(p)}>{p.name}</button>
        ))}
      </div>
      {list && (
        <div className="card center">
          <h2>{list.name}</h2>
          <div className="wheel-wrap">
            <div className="pointer">▼</div>
            <div className="wheel" style={{ background: gradient, transform: `rotate(${angle}deg)`, transition: spinning ? 'transform 3.2s cubic-bezier(.17,.67,.2,1)' : 'none' }}>
              {list.options.map((o, i) => (
                <span key={i} style={{ transform: `rotate(${(i + 0.5) * (360 / n)}deg) translateY(calc(var(--wheel) * -0.3))` }}>{o}</span>
              ))}
            </div>
          </div>
          <button className="btn primary big" disabled={spinning || n < 2} onClick={spin}>{spinning ? '转呀转…' : n < 2 ? '至少添加 2 个选项' : '就听它的！'}</button>
          {result && <div className="result">🎉 决定了：<b>{result}</b></div>}
          <ul className="opts">
            {list.options.map((o, i) => (
              <li key={i}>{o}<button className="x" onClick={() => update(list.options.filter((_, j) => j !== i))}>×</button></li>
            ))}
          </ul>
          <form className="inline" onSubmit={(e) => { e.preventDefault(); if (opt.trim() && n < 12) { update([...list.options, opt.trim()]); setOpt(''); } }}>
            <input placeholder="加个选项（最多 12 个）" value={opt} onChange={(e) => setOpt(e.target.value)} maxLength={8} />
            <button className="btn">添加</button>
          </form>
        </div>
      )}
    </div>
  );
}
