export function formatStoryAge(createdAt: string) {
  const time = new Date(createdAt).getTime();
  if (Number.isNaN(time)) return '';

  const elapsed = Date.now() - time;
  if (elapsed < 60_000) return 'Vừa xong';

  const minutes = Math.floor(elapsed / 60_000);
  if (minutes < 60) return `${minutes} phút`;

  const hours = Math.floor(minutes / 60);
  if (hours < 24) return `${hours} giờ`;

  const days = Math.floor(hours / 24);
  if (days < 7) return `${days} ngày`;

  const weeks = Math.floor(days / 7);
  if (weeks < 5) return `${weeks} tuần`;

  const months = Math.floor(days / 30);
  if (months < 12) return `${months} tháng`;

  return `${Math.floor(days / 365)} năm`;
}
