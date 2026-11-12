/** Downscale an image file to a JPEG data URL so it fits in localStorage. */
export function compressImage(file: File, max = 720, quality = 0.7): Promise<string> {
  return new Promise((resolve, reject) => {
    const img = new Image();
    const url = URL.createObjectURL(file);
    img.onload = () => {
      const scale = Math.min(1, max / Math.max(img.width, img.height));
      const c = document.createElement('canvas');
      c.width = Math.round(img.width * scale); c.height = Math.round(img.height * scale);
      c.getContext('2d')!.drawImage(img, 0, 0, c.width, c.height);
      URL.revokeObjectURL(url);
      resolve(c.toDataURL('image/jpeg', quality));
    };
    img.onerror = () => { URL.revokeObjectURL(url); reject(new Error('无法读取图片')); };
    img.src = url;
  });
}

/** Render a shareable 1080x1440 "we've been together N days" poster. */
export function renderShareCard(opts: { me: string; partner: string; days: number; startDate: string; line: string }): string {
  const W = 1080, H = 1440;
  const c = document.createElement('canvas'); c.width = W; c.height = H;
  const g = c.getContext('2d')!;
  const bg = g.createLinearGradient(0, 0, W, H);
  bg.addColorStop(0, '#ff8fa3'); bg.addColorStop(1, '#c86dd7');
  g.fillStyle = bg; g.fillRect(0, 0, W, H);
  g.fillStyle = 'rgba(255,255,255,0.12)';
  for (let i = 0; i < 18; i++) {
    const x = (i * 173) % W, y = (i * 311) % H, r = 20 + (i % 5) * 14;
    heart(g, x, y, r);
  }
  g.fillStyle = '#fff'; g.textAlign = 'center';
  g.font = '600 52px -apple-system, "PingFang SC", sans-serif';
  g.fillText(`${opts.me}  ♥  ${opts.partner}`, W / 2, 330);
  g.font = '400 44px -apple-system, "PingFang SC", sans-serif';
  g.fillText('我们已经在一起', W / 2, 520);
  g.font = '800 300px -apple-system, "PingFang SC", sans-serif';
  g.fillText(String(opts.days), W / 2, 830);
  g.font = '400 56px -apple-system, "PingFang SC", sans-serif';
  g.fillText('天', W / 2, 930);
  g.font = 'italic 40px -apple-system, "PingFang SC", sans-serif';
  g.fillStyle = 'rgba(255,255,255,0.92)';
  g.fillText(`“${opts.line}”`, W / 2, 1100);
  g.font = '400 32px -apple-system, "PingFang SC", sans-serif';
  g.fillStyle = 'rgba(255,255,255,0.75)';
  g.fillText(`since ${opts.startDate.replace(/-/g, '.')}  ·  BetterHalf`, W / 2, 1340);
  return c.toDataURL('image/png');
}
function heart(g: CanvasRenderingContext2D, x: number, y: number, r: number) {
  g.beginPath();
  g.moveTo(x, y + r / 4);
  g.bezierCurveTo(x, y - r / 2, x - r, y - r / 2, x - r, y + r / 4);
  g.bezierCurveTo(x - r, y + r, x, y + r * 1.3, x, y + r * 1.6);
  g.bezierCurveTo(x, y + r * 1.3, x + r, y + r, x + r, y + r / 4);
  g.bezierCurveTo(x + r, y - r / 2, x, y - r / 2, x, y + r / 4);
  g.fill();
}

export function download(dataUrl: string, name: string) {
  const a = document.createElement('a'); a.href = dataUrl; a.download = name; a.click();
}
