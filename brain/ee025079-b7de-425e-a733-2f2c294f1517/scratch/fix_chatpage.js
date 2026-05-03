const fs = require('fs');
const path = 'd:/Download/Project/cnm-vnalo/frontend/web/src/pages/ChatPage.tsx';
let content = fs.readFileSync(path, 'utf8');

// 1. Fix imports
content = content.replace(/import \{ (.*?)useRef, (.*?) \} from 'react'/, "import React, { $1$2 } from 'react'");
content = content.replace(/import \{ (.*?), useRef \} from 'react'/, "import React, { $1 } from 'react'");

// 2. Replace useRef calls
content = content.replace(/([^.])useRef\(/g, '$1React.useRef(');

// 3. Fix Mojibake at the end (approximate match)
content = content.replace(/Tin nhÃƒÆ’Ã‚Â¥Ãƒâ€šÃ‚Â»ÃƒÂ¢Ã¢â€šÂ¬Ã‚Â¢ÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â€šÂ¬Ã¢â‚¬Å“Ãƒâ€šÃ‚Â¸ ÃƒÆ’Ã‚Â¯Ãƒâ€šÃ‚Â¿Ãƒâ€šÃ‚Â½ÃƒÆ’Ã‚Â§ÃƒÂ¢Ã¢â€šÂ¬Ã…â€œÃƒâ€¦Ã‚Â  ghim/g, 'Tin nhắn được ghim');

// 4. Remove extra empty lines at end
content = content.trimEnd() + '\n';

fs.writeFileSync(path, content);
console.log('Done fixing ChatPage.tsx');
