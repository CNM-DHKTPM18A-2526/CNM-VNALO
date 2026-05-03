const fs = require('fs');

const file = 'frontend/web/src/pages/ChatPage.tsx';
let buffer = fs.readFileSync(file);

// Check for UTF-8 BOM
if (buffer[0] === 0xEF && buffer[1] === 0xBB && buffer[2] === 0xBF) {
    console.log('BOM detected, removing...');
    buffer = buffer.slice(3);
    fs.writeFileSync(file, buffer);
    console.log('BOM removed.');
} else {
    console.log('No BOM detected.');
}
