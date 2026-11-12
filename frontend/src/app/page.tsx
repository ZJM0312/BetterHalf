'use client';
import { useState } from 'react';
import { useSpace } from '@/lib/store';
import Onboarding from '@/components/Onboarding';
import Together from '@/components/Together';
import Timeline from '@/components/Timeline';
import Decide from '@/components/Decide';
import Talk from '@/components/Talk';
import Bucket from '@/components/Bucket';
import Settings from '@/components/Settings';

const TABS = [
  { id: 'home', icon: '💞', label: '我们' },
  { id: 'timeline', icon: '📸', label: '回忆' },
  { id: 'talk', icon: '💬', label: '每日一问' },
  { id: 'decide', icon: '🎡', label: '帮我选' },
  { id: 'bucket', icon: '✅', label: '清单' },
  { id: 'settings', icon: '⚙️', label: '设置' },
] as const;
type Tab = (typeof TABS)[number]['id'];

export default function Home() {
  const { state, ready } = useSpace();
  const [tab, setTab] = useState<Tab>('home');
  if (!ready) return <div className="loading">♥</div>;
  if (!state) return <Onboarding />;

  return (
    <div className="app">
      <header className="topbar"><div className="logo">BetterHalf<span>♥</span></div></header>
      <main className="content">
        {tab === 'home' && <Together s={state} />}
        {tab === 'timeline' && <Timeline s={state} />}
        {tab === 'talk' && <Talk s={state} />}
        {tab === 'decide' && <Decide s={state} />}
        {tab === 'bucket' && <Bucket s={state} />}
        {tab === 'settings' && <Settings s={state} />}
      </main>
      <nav className="tabs">
        {TABS.map((t) => (
          <button key={t.id} className={tab === t.id ? 'on' : ''} onClick={() => setTab(t.id)}>
            <span>{t.icon}</span>{t.label}
          </button>
        ))}
      </nav>
    </div>
  );
}
