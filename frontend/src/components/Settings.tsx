'use client';
import { useRef, useState } from 'react';
import { State, importData, resetAll, setState } from '@/lib/store';
import { download } from '@/lib/media';

export default function Settings({ s }: { s: State }) {
  const [me, setMe] = useState(s.me);
  const [partner, setPartner] = useState(s.partner);
  const [date, setDate] = useState(s.startDate);
  const [msg, setMsg] = useState('');
  const fileRef = useRef<HTMLInputElement>(null);

  const save = () => { if (me.trim() && partner.trim() && date) { setState((st) => ({ ...st, me: me.trim(), partner: partner.trim(), startDate: date })); setMsg('已保存 ✓'); } };
  const exportData = () => {
    const blob = new Blob([JSON.stringify(s)], { type: 'application/json' });
    const url = URL.createObjectURL(blob);
    download(url, `betterhalf-备份-${new Date().toISOString().slice(0, 10)}.json`);
    setTimeout(() => URL.revokeObjectURL(url), 1000);
    setMsg('已导出备份，可以发给 TA 导入到另一台设备');
  };
  const onImport = async (f?: File) => {
    if (!f || !confirm('导入会覆盖当前设备上的数据，继续吗？')) return;
    setMsg(importData(await f.text()) ? '导入成功 ✓' : '备份文件无法识别');
  };

  return (
    <div className="stack">
      <div className="card">
        <h2>我们的资料</h2>
        <div className="row2">
          <label>你的昵称<input value={me} onChange={(e) => setMe(e.target.value)} maxLength={12} /></label>
          <label>TA 的昵称<input value={partner} onChange={(e) => setPartner(e.target.value)} maxLength={12} /></label>
        </div>
        <label>在一起的日子<input type="date" value={date} onChange={(e) => setDate(e.target.value)} /></label>
        <button className="btn primary" onClick={save}>保存</button>
      </div>
      <div className="card">
        <h2>数据与隐私</h2>
        <p className="muted">所有数据只保存在这台设备的浏览器里，不会上传到任何服务器。换手机或清理浏览器前，记得导出备份。</p>
        <div className="row">
          <button className="btn" onClick={exportData}>导出备份</button>
          <button className="btn" onClick={() => fileRef.current?.click()}>导入备份</button>
        </div>
        <input ref={fileRef} type="file" accept="application/json" hidden onChange={(e) => { onImport(e.target.files?.[0]); e.target.value = ''; }} />
        {msg && <p className="ok-msg">{msg}</p>}
      </div>
      <div className="card danger">
        <h2>清空数据</h2>
        <button className="btn warn" onClick={() => { if (confirm('确定清空这台设备上的全部数据？此操作不可恢复（除非你有备份）。')) resetAll(); }}>清空全部数据</button>
      </div>
    </div>
  );
}
