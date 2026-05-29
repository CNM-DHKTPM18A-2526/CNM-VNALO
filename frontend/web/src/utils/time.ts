export function formatRelativeTime(d: Date): string {
  const now = new Date();
  const diffSec = Math.floor((now.getTime() - d.getTime()) / 1000);
  if (diffSec < 60) return 'Vừa xong';
  if (diffSec < 3600) {
    const m = Math.floor(diffSec / 60);
    return `${m} phút`;
  }
  if (diffSec < 86400) {
    const h = Math.floor(diffSec / 3600);
    return `${h} giờ`;
  }
  // Else: show day + month + time e.g. "24 tháng 5 lúc 22:00"
  const day = d.getDate();
  const month = d.getMonth() + 1;
  const hh = d.getHours().toString().padStart(2, '0');
  const mm = d.getMinutes().toString().padStart(2, '0');
  return `${day} tháng ${month} lúc ${hh}:${mm}`;
}

export function formatFullDate(d: Date): string {
  const datePart = new Intl.DateTimeFormat('vi-VN', {
    weekday: 'long',
    day: 'numeric',
    month: 'long',
    year: 'numeric',
  }).format(d);
  const timePart = d.toLocaleTimeString('vi-VN', { hour: '2-digit', minute: '2-digit' });
  return `${datePart} lúc ${timePart}`;
}
