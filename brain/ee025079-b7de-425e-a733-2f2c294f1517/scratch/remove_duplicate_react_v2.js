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
let totalRemoved = 0;

files.forEach(file => {
  let content = fs.readFileSync(file, 'utf8');
  let lines = content.split('\n');
  let reactImportIndices = [];

  for (let i = 0; i < lines.length; i++) {
    if (lines[i].includes("from 'react'") || lines[i].includes('from "react"')) {
      reactImportIndices.push(i);
    }
  }

  if (reactImportIndices.length > 1) {
    console.log(`Found ${reactImportIndices.length} React imports in ${file}`);
    
    // Merge them into the first one if possible, or just keep the most "complete" one.
    // For simplicity, if we have "import React from 'react'" and another one,
    // let's try to keep the one that has the most stuff.
    
    let bestIndex = reactImportIndices[0];
    for (let j = 1; j < reactImportIndices.length; j++) {
       // If the second one has more characters, it might be the better one
       if (lines[reactImportIndices[j]].length > lines[bestIndex].length) {
         bestIndex = reactImportIndices[j];
       }
    }
    
    let newLines = [];
    for (let i = 0; i < lines.length; i++) {
      if (reactImportIndices.includes(i)) {
        if (i === bestIndex) {
          newLines.push(lines[i]);
        } else {
          totalRemoved++;
        }
      } else {
        newLines.push(lines[i]);
      }
    }
    fs.writeFileSync(file, newLines.join('\n'), 'utf8');
  }
});

console.log(`Total duplicate imports removed: ${totalRemoved}`);
