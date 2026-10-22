// Hosting predeploy: copy the Flutter admin build into firebase/public (the Hosting root).
// Build it first: cd admin-app && flutter build web --release
const fs = require('fs');
const path = require('path');

const src = path.join(__dirname, '..', '..', 'admin-app', 'build', 'web');
const dest = path.join(__dirname, '..', 'public');

if (!fs.existsSync(path.join(src, 'index.html'))) {
  console.error(`No admin build at ${src} — run "flutter build web --release" in admin-app first.`);
  process.exit(1);
}
fs.rmSync(dest, { recursive: true, force: true });
fs.cpSync(src, dest, { recursive: true });
console.log(`Copied admin build -> ${dest}`);
