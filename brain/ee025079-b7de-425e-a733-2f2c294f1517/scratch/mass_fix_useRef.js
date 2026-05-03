const fs = require('fs');
const path = require('path');

function walk(dir) {
    let results = [];
    const list = fs.readdirSync(dir);
    list.forEach(file => {
        file = path.join(dir, file);
        const stat = fs.statSync(file);
        if (stat && stat.isDirectory()) {
            results = results.concat(walk(file));
        } else if (file.endsWith('.tsx') || file.endsWith('.ts')) {
            results.push(file);
        }
    });
    return results;
}

const files = walk('frontend/web/src');

files.forEach(file => {
    let content = fs.readFileSync(file, 'utf8');
    let changed = false;

    // 1. Handle imports: remove useRef from named imports if it exists
    const importRegex = /import\s+\{([^}]*)\}\s+from\s+['"]react['"]/g;
    content = content.replace(importRegex, (match, p1) => {
        if (p1.includes('useRef')) {
            changed = true;
            let parts = p1.split(',').map(s => s.trim());
            parts = parts.filter(p => p !== 'useRef');
            if (parts.length === 0) {
                return "import React from 'react'";
            }
            return `import React, { ${parts.join(', ')} } from 'react'`;
        }
        return match;
    });

    // 2. Ensure React is imported if we are using React.useRef
    if (content.includes('React.useRef') && !content.includes("import React") && !content.includes("import * as React")) {
        content = "import React from 'react'\n" + content;
        changed = true;
    }

    // 3. Fix bare useRef calls: replace \buseRef\( with React.useRef\(
    const bareRegex = /(?<!React\.)\buseRef\(/g;
    if (bareRegex.test(content)) {
        content = content.replace(bareRegex, 'React.useRef(');
        changed = true;
        // Check again for React import
        if (!content.includes("import React") && !content.includes("import * as React")) {
            content = "import React from 'react'\n" + content;
        }
    }

    if (changed) {
        console.log('Fixed:', file);
        fs.writeFileSync(file, content, 'utf8');
    }
});
