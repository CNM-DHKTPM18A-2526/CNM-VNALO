const fs = require('fs');

const file = 'frontend/web/src/pages/ChatPage.tsx';
let content = fs.readFileSync(file, 'utf8');

const replacements = [
    [/NgÃƒÂ¢Ã¢â‚¬ËœÃ‚Â¹ÃƒÂ¥Ã‚Â»Ã¢â€žÂ¢ÃƒÂ°Ã‚Â©Ã‚Â¥Ã¢â‚¬Â°\s+dÃƒÂ§Ã‚Â¾Ã¢â‚¬Â¦ng/g, 'Người dùng'],
    [/NgÆ°á» i dÃ¹ng/g, 'Người dùng'],
    [/Ng?i dA1ng/g, 'Người dùng'],
    [/NgA\+AAAA\?i dAA1ng/g, 'Người dùng'],
    [/Bn/g, 'Bạn'],
    [/hAnh nh/g, 'hình ảnh'],
    [/t-p tin/g, 'tập tin'],
    [/Tin nhA\?n Ä‘A\? Ä‘Æ°Æ¡i thu hA\?i/g, 'Tin nhắn đã được thu hồi'],
    [/Tin nháº¯n Ä‘Ã£ Ä‘Æ°á»£c thu há»“i/g, 'Tin nhắn đã được thu hồi'],
    [/Äang hoA\?t Ä‘A\?ng/g, 'Đang hoạt động'],
    [/Äang táº£i tin nháº¯n/g, 'Đang tải tin nhắn'],
    [/Tin nháº¯n ghim/g, 'Tin nhắn ghim'],
    [/ThÃ nh viÃªn/g, 'Thành viên'],
    [/NgÆ°á» i láº¡/g, 'Người lạ'],
    [/Gá»i yÃªu cáº§u káº¿t báº¡n/g, 'Gửi yêu cầu kết bạn'],
    [/Gá»i káº¿t báº¡n/g, 'Gửi kết bạn'],
];

replacements.forEach(([regex, replacement]) => {
    content = content.replace(regex, replacement);
});

// Also fix those weird A'A,A_A?s things
content = content.replace(/\/\/ A'A,A_A\?sA,AA\?sA,AA'A,A_A\?sA,AA\?sA,A/g, '//');
content = content.replace(/['"]NgA'A,AAAA\?sAA<"A\?sA,A1A'A,AA\?sA,AAAA,_A,AA'A,AA\?sA,AcA\?sA,AAAA\?sAA,A dA'A,A A\?sA,A_AAA\?sAA,Ang['"]/g, "'Người dùng'");

fs.writeFileSync(file, content, 'utf8');
console.log('Fixed Mojibake in ChatPage.tsx');
