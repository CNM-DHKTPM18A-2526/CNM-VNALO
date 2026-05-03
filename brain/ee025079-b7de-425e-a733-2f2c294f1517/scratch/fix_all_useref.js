const fs = require('fs');

const filesToFix = [
  'frontend/web/src/shared/components/Topbar.tsx',
  'frontend/web/src/shared/components/SettingsMenu.tsx',
  'frontend/web/src/pages/ProfilePage.tsx',
  'frontend/web/src/pages/ContactsPage.tsx',
  'frontend/web/src/features/notifications/NotificationContext.tsx',
  'frontend/web/src/features/chat/useChatSocket.ts'
];

filesToFix.forEach(file => {
  const fullPath = 'd:/Download/Project/cnm-vnalo/' + file;
  if (!fs.existsSync(fullPath)) {
    console.log('File not found:', fullPath);
    return;
  }
  let content = fs.readFileSync(fullPath, 'utf8');

  if (content.includes('useRef')) {
    // 1. Fix imports
    content = content.replace(/import (.*?) \{ (.*?)useRef, (.*?) \} from 'react'/, "import React, { $2$3 } from 'react'");
    content = content.replace(/import (.*?) \{ (.*?), useRef \} from 'react'/, "import React, { $2 } from 'react'");
    content = content.replace(/import \{ useRef \} from 'react'/, "import React from 'react'");

    // 2. Replace useRef calls
    content = content.replace(/([^.])useRef\(/g, '$1React.useRef(');
    content = content.replace(/([^.])useRef</g, '$1React.useRef<');
    
    // Clean up possible duplicate React imports if any
    const lines = content.split('\n');
    const newLines = [];
    let reactImportSeen = false;
    for (let line of lines) {
       if (line.includes("from 'react'") && line.includes("import React")) {
          if (reactImportSeen) continue;
          reactImportSeen = true;
       }
       newLines.push(line);
    }
    content = newLines.join('\n');

    fs.writeFileSync(fullPath, content);
    console.log('Fixed:', file);
  }
});
