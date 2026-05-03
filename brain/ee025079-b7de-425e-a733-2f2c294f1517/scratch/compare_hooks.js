const fs = require('fs');

const current = fs.readFileSync('frontend/web/src/pages/ChatPage.tsx', 'utf8');
const stable = fs.readFileSync('brain/ee025079-b7de-425e-a733-2f2c294f1517/scratch/ChatPage_stable.tsx', 'utf8');

const getHooks = (content) => {
  const hooks = [];
  const lines = content.split('\n');
  lines.forEach(line => {
    const match = line.match(/const \[(.*?), set(.*?)\] = useState/);
    if (match) hooks.push(match[1]);
    const refMatch = line.match(/const (.*?)Ref = (?:React\.)?useRef/);
    if (refMatch) hooks.push(refMatch[1]);
    const refMatch2 = line.match(/const (.*?) = (?:React\.)?useRef/);
    if (refMatch2 && !hooks.includes(refMatch2[1])) hooks.push(refMatch2[1]);
  });
  return hooks;
};

const currentHooks = getHooks(current);
const stableHooks = getHooks(stable);

console.log('--- Missing Hooks (In stable but not in current) ---');
stableHooks.forEach(h => {
  if (!currentHooks.includes(h)) console.log(h);
});

console.log('\n--- Extra Hooks (In current but not in stable) ---');
currentHooks.forEach(h => {
  if (!stableHooks.includes(h)) console.log(h);
});
