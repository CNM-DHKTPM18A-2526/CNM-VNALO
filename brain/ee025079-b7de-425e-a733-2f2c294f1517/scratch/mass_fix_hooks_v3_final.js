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

const reactApis = [
  'useState', 'useEffect', 'useContext', 'useReducer', 'useCallback', 
  'useMemo', 'useRef', 'useLayoutEffect', 'useImperativeHandle', 
  'useDebugValue', 'useDeferredValue', 'useTransition', 'useId',
  'forwardRef', 'memo', 'createContext', 'lazy', 'Suspense', 'Fragment', 'Profiler', 'StrictMode'
];

const files = getAllFiles(srcDir);
let fixedCount = 0;

files.forEach(file => {
  let content = fs.readFileSync(file, 'utf8');
  let changed = false;

  // 1. Replace React API calls with React.api
  reactApis.forEach(api => {
    // Matches api<Type>( or api( or api.property
    // Positive lookahead for ( or <
    const regex = new RegExp(`(?<!React\\.|type\\s+)\\b${api}\\b(?=\\s*[<(])`, 'g');
    if (regex.test(content)) {
      content = content.replace(regex, `React.${api}`);
      changed = true;
    }
  });

  // 2. Clean up imports from 'react'
  // Look for: import React, { ... } from 'react' or import { ... } from 'react'
  const importRegex = /import\s+(?:React\s*,\s*)?\{([^}]+)\}\s+from\s+['"]react['"]/g;
  content = content.replace(importRegex, (match, namedImports) => {
    let imports = namedImports.split(',').map(s => s.trim());
    let filtered = imports.filter(i => !reactApis.includes(i.replace(/^type\s+/, '')));
    if (filtered.length === 0) {
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
