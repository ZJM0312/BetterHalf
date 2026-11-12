'use client';
import { useState } from 'react';
import { State, setState, todayKey } from '@/lib/store';
import { questionFor } from '@/lib/content';

export default function Talk({ s }: { s: State }) {
  const key = todayKey();
  const q = questionFor(key);
  const ans = s.answers[key] ?? {};
  const [who, setWho] = useState<'me' | 'partner'>(ans.me ? 'partner' : 'me');
  const [draft, setDraft] = useState('');
  const both = !!(ans.me && ans.partner);

  const submit = () => {
    if (!draft.trim()) return;
    setState((st) => ({ ...st, answers: { ...st.answers, [key]: { ...st.answers[key], [who]: draft.trim() } } }));
    setDraft(''); setWho(who === 'me' ? 'partner' : 'me');
  };
  const streak = (() => {
    let n = 0; const d = new Date();
    for (;;) { const a = s.answers[todayKey(d)]; if (a?.me && a?.partner) { n++; d.setDate(d.getDate() - 1); } else break; }
    return n;
  })();
  const history = Object.entries(s.answers).filter(([k, a]) => k !== key && a.me && a.partner).sort((a, b) => (a[0] < b[0] ? 1 : -1));
  const name = (w: 'me' | 'partner') => (w === 'me' ? s.me : s.partner);

  return (
    <div className="stack">
      <div className="card question">
        <div className="muted">今日一问 · {key}{streak > 0 && ` · 🔥 连续 ${streak} 天`}</div>
        <h2>{q}</h2>
        {both ? (
          <div className="reveal">
            <div className="bubble l"><b>{s.me}</b><p>{ans.me}</p></div>
            <div className="bubble r"><b>{s.partner}</b><p>{ans.partner}</p></div>
            <p className="muted center">明天还有新问题哦 💌</p>
          </div>
        ) : (
          <>
            <div className="status">
              <span className={ans.me ? 'ok' : ''}>{s.me} {ans.me ? '✓ 已回答' : '未回答'}</span>
              <span className={ans.partner ? 'ok' : ''}>{s.partner} {ans.partner ? '✓ 已回答' : '未回答'}</span>
            </div>
            {!ans[who] ? (
              <>
                <p className="muted">轮到 <b>{name(who)}</b> 回答，对方先别偷看 🙈 两人都答完才会揭晓。</p>
                <textarea rows={4} value={draft} onChange={(e) => setDraft(e.target.value)} placeholder={`${name(who)} 的回答…`} maxLength={500} />
                <button className="btn primary big" onClick={submit}>提交并藏起来</button>
              </>
            ) : (
              <p className="muted">{name(who)} 已回答，把手机递给 {name(who === 'me' ? 'partner' : 'me')} 吧～
                <button className="link" onClick={() => setWho(who === 'me' ? 'partner' : 'me')}>切换</button></p>
            )}
          </>
        )}
      </div>
      {history.length > 0 && (
        <div className="card">
          <h2>我们聊过的</h2>
          {history.slice(0, 20).map(([k, a]) => (
            <details key={k} className="past">
              <summary><span className="muted">{k}</span> {questionFor(k)}</summary>
              <p><b>{s.me}：</b>{a.me}</p><p><b>{s.partner}：</b>{a.partner}</p>
            </details>
          ))}
        </div>
      )}
    </div>
  );
}
