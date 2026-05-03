const fs = require('fs');
const path = require('path');

const srcDir = 'frontend/web/src';

function getAllFiles(dir, allFiles = []) {
  const files = fs.readdirSync(dir);
  files.forEach(file => {
    const filePath = path.join(dir, file);
    if (fs.statSync(filePath).isDirectory()) {
      getAllFiles(filePath, allFiles);
    } else if (file.endsWith('.tsx') || file.endsWith('.ts')) {
      allFiles.push(filePath);
    }
  });
  return allFiles;
}

const files = getAllFiles(srcDir);
let fixedCount = 0;

files.forEach(file => {
  let lines = fs.readFileSync(file, 'utf8').split('\n');
  let newLines = [];
  let reactImportFound = false;

  for (let i = 0; i < lines.length; i++) {
    const line = lines[i];
    // Check if it's a React import line
    if (line.match(/import\s+React\b.*\bfrom\s+['"]react['"]/)) {
      if (reactImportFound) {
        console.log(`Removing duplicate React import in ${file} at line ${i + 1}`);
        continue; // Skip duplicate
      }
      reactImportFound = true;
    }
    newLines.push(line);
  }

  if (newLines.length !== lines.length) {
    fs.writeFileSync(file, newLines.join('\n'), 'utf8');
    fixedCount++;
  }
});

console.log(`Total files cleaned: ${fixedCount}`);
