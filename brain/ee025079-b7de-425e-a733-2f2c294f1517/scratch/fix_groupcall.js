const fs = require('fs');
const path = 'd:/Download/Project/cnm-vnalo/frontend/web/src/features/chat/components/GroupCallModal.tsx';
let content = fs.readFileSync(path, 'utf8');

// 1. Fix imports
content = content.replace(/import React, \{ (.*?)useEffect, (.*?)useState (.*?) \} from 'react'/, "import React, { $1useEffect, $2useState $3 } from 'react'");
// If it's different
content = content.replace(/import React, \{ useEffect, useState \} from 'react'/, "import React, { useEffect, useState } from 'react'");

// 2. Replace useRef calls
content = content.replace(/([^.])useRef\(/g, '$1React.useRef(');
content = content.replace(/([^.])useRef</g, '$1React.useRef<');

fs.writeFileSync(path, content);
console.log('Fixed GroupCallModal.tsx');
