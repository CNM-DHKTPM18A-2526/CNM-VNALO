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

const hooks = [
  'useState', 'useEffect', 'useContext', 'useReducer', 'useCallback', 
  'useMemo', 'useRef', 'useLayoutEffect', 'useImperativeHandle', 
  'useDebugValue', 'useDeferredValue', 'useTransition', 'useId'
];

const files = getAllFiles(srcDir);
let fixedCount = 0;

files.forEach(file => {
  let content = fs.readFileSync(file, 'utf8');
  let changed = false;

  // 1. Replace hook calls with React.hook
  hooks.forEach(hook => {
    // Matches hook<Type>( or hook(
    // Positive lookahead for ( or < to ensure it's a call/generic
    const regex = new RegExp(`(?<!React\\.)\\b${hook}\\b(?=\\s*[<(])`, 'g');
    if (regex.test(content)) {
      content = content.replace(regex, `React.${hook}`);
      changed = true;
    }
  });

  // 2. Clean up imports from 'react'
  // Look for: import React, { ... } from 'react'
  const importRegex = /import\s+React,\s*\{([^}]+)\}\s+from\s+['"]react['"]/g;
  content = content.replace(importRegex, (match, namedImports) => {
    let imports = namedImports.split(',').map(s => s.trim());
    let filtered = imports.filter(i => !hooks.includes(i));
    if (filtered.length === 0) {
      return "import React from 'react'";
    }
    return `import React, { ${filtered.join(', ')} } from 'react'`;
  });

  // Also handle cases without React already imported
  const importRegex2 = /import\s+\{([^}]+)\}\s+from\s+['"]react['"]/g;
  content = content.replace(importRegex2, (match, namedImports) => {
    let imports = namedImports.split(',').map(s => s.trim());
    let filtered = imports.filter(i => !hooks.includes(i));
    if (filtered.length === 0) {
       // If all were hooks, we still need React if we replaced them
       return "import React from 'react'";
    }
    return `import React, { ${filtered.join(', ')} } from 'react'`;
  });

  if (changed) {
    fs.writeFileSync(file, content, 'utf8');
    fixedCount++;
    console.log(`Fixed: ${file}`);
  }
});

console.log(`Total files fixed: ${fixedCount}`);
