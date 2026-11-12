import type { Metadata, Viewport } from 'next';
import './globals.css';

export const metadata: Metadata = {
  title: 'BetterHalf · 两个人的小宇宙',
  description: '情侣专属空间：在一起天数、纪念日倒数、回忆时间线、每日一问、今天吃什么转盘、情侣清单。无需注册，数据只属于你们。',
  manifest: '/manifest.webmanifest',
  appleWebApp: { capable: true, title: 'BetterHalf', statusBarStyle: 'default' },
};
export const viewport: Viewport = { themeColor: '#ff8fa3', width: 'device-width', initialScale: 1 };

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="zh-CN">
      <body>{children}</body>
    </html>
  );
}
