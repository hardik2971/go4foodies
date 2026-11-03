// Hosting predeploy: copy the static website export into firebase/web-public (the "web" Hosting root).
// Build it first: cd website && npx next build   (output: 'export' -> website/out)
const fs = require('fs');
const path = require('path');

const src = path.join(__dirname, '..', '..', 'website', 'out');
const dest = path.join(__dirname, '..', 'web-public');

if (!fs.existsSync(path.join(src, 'index.html'))) {
  console.error(`No website build at ${src} — run "npx next build" in website first.`);
  process.exit(1);
}
fs.rmSync(dest, { recursive: true, force: true });
fs.cpSync(src, dest, { recursive: true });
console.log(`Copied website build -> ${dest}`);
