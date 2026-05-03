const fs = require('fs');
const path = require('path');

const srcDir = 'frontend/web/src';

function getAllFiles(dir, allFiles = []) {
  const files = fs.readdirSync(dir);
  files.forEach(file => {
    const filePath = path.join(dir, file);
    if (fs.statSync(filePath).isDirectory()) {
      getAllFiles(filePath, allFiles);
    } else if (file.endsWith('.tsx') || file.endsWith('.ts') || file.endsWith('.css') || file.endsWith('.html')) {
      allFiles.push(filePath);
    }
  });
  return allFiles;
}

const files = getAllFiles(srcDir);
let fixedCount = 0;

files.forEach(file => {
  let buffer = fs.readFileSync(file);
  let changed = false;

  // 1. Remove UTF-8 BOM if present
  if (buffer[0] === 0xEF && buffer[1] === 0xBB && buffer[2] === 0xBF) {
    console.log(`Removing BOM from ${file}`);
    buffer = buffer.slice(3);
    changed = true;
  }

  // 2. Convert to string and check for other weirdness if needed
  let content = buffer.toString('utf8');
  
  // Optional: check for null bytes or other control characters
  const originalLength = content.length;
  // eslint-disable-next-line no-control-regex
  content = content.replace(/[\x00-\x08\x0B\x0C\x0E-\x1F]/g, '');
  if (content.length !== originalLength) {
    console.log(`Removed control characters from ${file}`);
    changed = true;
  }

  if (changed) {
    fs.writeFileSync(file, content, 'utf8');
    fixedCount++;
  }
});

console.log(`Total files sanitized: ${fixedCount}`);
