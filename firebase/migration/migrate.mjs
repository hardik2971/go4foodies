// One-shot MySQL (mysqldump) -> Firestore migration for go4foodies.
//
//   node migrate.mjs --dry-run            parse + report, write nothing
//   node migrate.mjs                      write to Firestore (merges by id; safe to re-run)
//   node migrate.mjs --reset              delete existing docs first, then write (exact copy of the dump)
//
// Options: --dump <path to .sql>  --key <service account json>
// Ids are kept as-is (cuid strings), so every reference between collections still resolves.
// Collection layout is documented in docs/firebase-migration/04-firestore-schema.md.

import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import admin from 'firebase-admin';

const here = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(here, '..', '..');
const arg = (name, def) => {
  const i = process.argv.indexOf(name);
  return i > -1 ? process.argv[i + 1] : def;
};
const DRY = process.argv.includes('--dry-run');
const DUMP = arg('--dump', path.join(root, 'secrets', 'restaurant_db.sql'));
const KEY = arg('--key', path.join(root, 'secrets', 'go4foodies-firebase-admin.json'));

// MySQL table -> Firestore collection. OrderItem is embedded into orders[].items.
const COLLECTIONS = {
  AuditLog: 'auditLogs',
  Category: 'categories',
  Customer: 'customers',
  DashboardConfig: 'dashboardConfig',
  Employee: 'employees',
  GiftCard: 'giftCards',
  InventoryItem: 'inventoryItems',
  MenuItem: 'menuItems',
  Order: 'orders',
  Outlet: 'outlets',
  OutletMetric: 'outletMetrics',
  Payment: 'payments',
  Reservation: 'reservations',
  RestaurantProfile: 'restaurantProfile',
  Table: 'tables',
  TableSession: 'tableSessions',
  User: 'users',
};
// Tables whose `password` column moves to the locked credentials collection.
const CREDENTIAL_KIND = { User: 'user', Employee: 'employee', Customer: 'customer' };

// ---- mysqldump parsing ----

/** Column name -> kind ('date' | 'number' | 'bool' | 'string') per table, from CREATE TABLE. */
function parseSchemas(sql) {
  const schemas = {};
  const re = /CREATE TABLE `(\w+)` \(([\s\S]*?)\n\) ENGINE/g;
  for (const m of sql.matchAll(re)) {
    const cols = [];
    for (const line of m[2].split('\n')) {
      const c = line.match(/^\s*`(\w+)` (\w+)(\((\d+)(,\d+)?\))?/);
      if (!c) continue;
      const [, name, type, , len] = c;
      let kind = 'string';
      if (type === 'datetime') kind = 'date';
      else if (type === 'tinyint' && len === '1') kind = 'bool';
      else if (['int', 'bigint', 'decimal', 'double', 'float', 'tinyint', 'smallint'].includes(type)) kind = 'number';
      cols.push({ name, kind });
    }
    schemas[m[1]] = cols;
  }
  return schemas;
}

/** Parse the VALUES (...),(...); tuple list of one INSERT statement. */
function parseTuples(s) {
  const rows = [];
  let i = 0;
  const n = s.length;
  while (i < n) {
    while (i < n && s[i] !== '(') i++;
    if (i >= n) break;
    i++;
    const row = [];
    for (;;) {
      while (s[i] === ' ') i++;
      if (s[i] === "'") {
        i++;
        let out = '';
        for (;;) {
          const ch = s[i];
          if (ch === '\\') {
            const nx = s[i + 1];
            out += { n: '\n', r: '\r', t: '\t', 0: '\0', Z: '\x1a', b: '\b' }[nx] ?? nx;
            i += 2;
          } else if (ch === "'") {
            if (s[i + 1] === "'") { out += "'"; i += 2; } else { i++; break; }
          } else { out += ch; i++; }
        }
        row.push(out);
      } else {
        let j = i;
        while (s[j] !== ',' && s[j] !== ')') j++;
        const raw = s.slice(i, j).trim();
        row.push(raw === 'NULL' ? null : raw);
        i = j;
      }
      if (s[i] === ',') { i++; continue; }
      if (s[i] === ')') { i++; break; }
      throw new Error(`Unexpected character at ${i}: ${s.slice(i, i + 20)}`);
    }
    rows.push(row);
  }
  return rows;
}

function parseDump(sql) {
  const schemas = parseSchemas(sql);
  const data = {};
  for (const m of sql.matchAll(/^INSERT INTO `(\w+)` VALUES (.*);$/gm)) {
    const cols = schemas[m[1]];
    if (!cols) throw new Error(`No schema for ${m[1]}`);
    for (const tuple of parseTuples(m[2])) {
      if (tuple.length !== cols.length) throw new Error(`${m[1]}: ${tuple.length} values for ${cols.length} columns`);
      const row = {};
      cols.forEach((c, k) => { row[c.name] = convert(tuple[k], c.kind); });
      (data[m[1]] ??= []).push(row);
    }
  }
  return { schemas, data };
}

function convert(v, kind) {
  if (v === null) return null;
  switch (kind) {
    case 'date': return admin.firestore.Timestamp.fromDate(new Date(v.replace(' ', 'T') + 'Z')); // dump is UTC
    case 'number': return Number(v);
    case 'bool': return v === '1';
    default: return v;
  }
}

// ---- build Firestore documents ----

function buildDocs(data) {
  const docs = []; // { path, data }
  const itemsByOrder = {};
  for (const it of data.OrderItem ?? []) {
    const { orderId, ...rest } = it;
    (itemsByOrder[orderId] ??= []).push(rest);
  }
  for (const [table, coll] of Object.entries(COLLECTIONS)) {
    for (const row of data[table] ?? []) {
      const { id, ...fields } = row;
      if (CREDENTIAL_KIND[table]) {
        const kind = CREDENTIAL_KIND[table];
        const hash = fields.password ?? null;
        delete fields.password;
        docs.push({
          path: `credentials/${kind}_${id}`,
          data: { kind, refId: id, email: (fields.email ?? '').toLowerCase() || null, passwordHash: hash },
        });
      }
      if (table === 'Order') fields.items = itemsByOrder[id] ?? [];
      if (table === 'Customer' || table === 'User' || table === 'Employee') {
        fields.emailLower = fields.email ? fields.email.toLowerCase() : null;
      }
      docs.push({ path: `${coll}/${id}`, data: fields });
    }
  }
  const orphanItems = Object.keys(itemsByOrder).filter((oid) => !(data.Order ?? []).some((o) => o.id === oid));
  return { docs, orphanItems };
}

// ---- main ----

const sql = fs.readFileSync(DUMP, 'utf8');
const { data } = parseDump(sql);
const { docs, orphanItems } = buildDocs(data);

console.log(`Dump: ${DUMP}`);
for (const [t, rows] of Object.entries(data)) console.log(`  ${t.padEnd(18)} ${rows.length}`);
const byColl = {};
for (const d of docs) byColl[d.path.split('/')[0]] = (byColl[d.path.split('/')[0]] ?? 0) + 1;
console.log('Firestore documents:');
for (const [c, n] of Object.entries(byColl)) console.log(`  ${c.padEnd(18)} ${n}`);
if (orphanItems.length) console.warn(`WARNING: order items for missing orders: ${orphanItems.join(', ')}`);

if (DRY) {
  console.log('\nDry run — nothing written. Sample order:');
  console.log(JSON.stringify(docs.find((d) => d.path.startsWith('orders/'))?.data, null, 2));
  process.exit(0);
}

admin.initializeApp({ credential: admin.credential.cert(JSON.parse(fs.readFileSync(KEY, 'utf8'))) });
const db = admin.firestore();

// --reset: delete every document in the managed collections first, so Firestore matches the dump
// exactly (use for the final cut-over from the VPS, or to undo test data).
if (process.argv.includes('--reset')) {
  let removed = 0;
  for (const coll of [...Object.values(COLLECTIONS), 'credentials']) {
    const snap = await db.collection(coll).get();
    const del = db.bulkWriter();
    for (const d of snap.docs) del.delete(d.ref);
    await del.close();
    removed += snap.size;
  }
  console.log(`Reset: removed ${removed} existing documents.`);
}

const writer = db.bulkWriter();
let failed = 0;
writer.onWriteError((e) => { failed++; console.error(`Failed ${e.documentRef.path}: ${e.message}`); return false; });
for (const d of docs) writer.set(db.doc(d.path), d.data);
await writer.close();
console.log(`\nWrote ${docs.length - failed} documents (${failed} failed).`);
