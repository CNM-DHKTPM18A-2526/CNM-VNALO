const fs = require('fs');

const file = 'frontend/web/src/pages/ChatPage.tsx';
let content = fs.readFileSync(file, 'utf8');

// Use very broad regex to catch the corrupted patterns regardless of exact byte sequence
content = content.replace(/fallbackUserDisplayName\(_userId: string\): string \{\s+return '.*?'/g, "fallbackUserDisplayName(_userId: string): string {\n  return 'Người dùng'");
content = content.replace(/normalized === 'NgA\+.*?'/g, "normalized === 'Người dùng'");
content = content.replace(/\/\^NgA\+.*?\s\+\[0-9a-f\]\{6,\}\$\/i/g, "/^Người dùng\\s+[0-9a-f]{6,}$/i");
content = content.replace(/if \(id === user\?\.id\) return '.*?'/g, "if (id === user?.id) return 'Bạn'");
content = content.replace(/userMapRef\.current\[id\]\?\.displayName \|\| '.*?'/g, "userMapRef.current[id]?.displayName || 'Người dùng'");
content = content.replace(/const icon = groupType === 'image' \? '.*?' : '.*?';/g, "const icon = groupType === 'image' ? '🖼️' : '📎';");
content = content.replace(/const label = groupType === 'image' \? '.*?' : '.*?';/g, "const label = groupType === 'image' ? 'hình ảnh' : 'tập tin';");
content = content.replace(/const prefix = message\.senderId === user\?\.id \? '.*?' : \(senderName \? `\$\{senderName\}: ` : ''\);/g, "const prefix = message.senderId === user?.id ? 'Bạn: ' : (senderName ? `${senderName}: ` : '');");

// Fix recalled message text
content = content.replace(/lastMessage: '.*?' \}/g, "lastMessage: 'Tin nhắn đã được thu hồi' }");

fs.writeFileSync(file, content, 'utf8');
console.log('Fixed major corruption in ChatPage.tsx');
