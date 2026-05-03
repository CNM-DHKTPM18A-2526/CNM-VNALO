const fs = require('fs');

const filesToFix = [
  'frontend/web/src/shared/components/Topbar.tsx',
  'frontend/web/src/shared/components/SettingsMenu.tsx',
  'frontend/web/src/pages/ProfilePage.tsx',
  'frontend/web/src/pages/ContactsPage.tsx',
  'frontend/web/src/features/notifications/NotificationContext.tsx',
  'frontend/web/src/features/chat/useChatSocket.ts',
  'frontend/web/src/pages/ChatPage.tsx',
  'frontend/web/src/features/chat/components/GroupCallModal.tsx',
  'frontend/web/src/features/chat/components/PremiumCallUI.tsx',
  'frontend/web/src/features/chat/components/CallModal.tsx'
];

filesToFix.forEach(file => {
  const fullPath = 'd:/Download/Project/cnm-vnalo/' + file;
  if (!fs.existsSync(fullPath)) {
    console.log('File not found:', fullPath);
    return;
  }
  let content = fs.readFileSync(fullPath, 'utf8');

  let changed = false;

  // 1. Replace useRef calls (both with ( and <)
  if (content.match(/([^.])useRef[<(]/)) {
    content = content.replace(/([^.])useRef\(/g, '$1React.useRef(');
    content = content.replace(/([^.])useRef</g, '$1React.useRef<');
    changed = true;
  }

  // 2. Fix imports if we used React.useRef
  if (changed) {
    // Ensure React is imported
    if (!content.includes("import React") && !content.includes("import * as React")) {
       content = "import React from 'react';\n" + content;
    }
    
    // Remove bare useRef from named imports
    content = content.replace(/import (.*?) \{ (.*?)useRef, (.*?) \} from 'react'/, "import $1 { $2$3 } from 'react'");
    content = content.replace(/import (.*?) \{ (.*?), useRef \} from 'react'/, "import $1 { $2 } from 'react'");
    content = content.replace(/import \{ useRef \} from 'react'/, ""); // If it was alone, it's covered by React import above or already exists
  }

  // Final cleanup of duplicate React imports
  const lines = content.split('\n');
  const newLines = [];
  let reactImportSeen = false;
  for (let line of lines) {
     if (line.includes("from 'react'") && (line.includes("import React") || line.includes("import * as React"))) {
        if (reactImportSeen) continue;
        reactImportSeen = true;
     }
     if (line.trim() === "" && newLines.length > 0 && newLines[newLines.length-1].trim() === "") continue; // Dedupe empty lines
     newLines.push(line);
  }
  content = newLines.join('\n');

  if (changed) {
    fs.writeFileSync(fullPath, content);
    console.log('Fixed:', file);
  }
});
