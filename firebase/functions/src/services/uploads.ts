import { randomInt } from 'node:crypto';
import { getStorage } from 'firebase-admin/storage';
import '../lib/db'; // initializeApp()

/**
 * Image uploads — port of Services/Uploads.php, stored in the default Firebase Storage bucket
 * under `uploads/` instead of UPLOAD_DIR (same file names, so `/api/uploads/<name>` URLs keep working).
 */
export const MAX_BYTES = 5 * 1024 * 1024;

export const MIME: Record<string, string> = {
  png: 'image/png',
  jpg: 'image/jpeg',
  jpeg: 'image/jpeg',
  webp: 'image/webp',
  gif: 'image/gif',
  avif: 'image/avif',
  svg: 'image/svg+xml',
};

const FOLDER = 'uploads/';
const file = (name: string) => getStorage().bucket().file(FOLDER + name);

/** `${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}` with the TS ext rules. */
export function filename(originalName: string): string {
  const parts = originalName.split('.');
  const last = parts[parts.length - 1];
  const raw = last === '' || last === '0' ? 'jpg' : last; // PHP `?:`
  const ext = raw.toLowerCase().replace(/[^a-z0-9]/g, '').slice(0, 5);
  const alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';
  let rand = '';
  for (let i = 0; i < 6; i++) rand += alphabet[randomInt(0, 36)];
  return `${Date.now()}-${rand}.${ext === '' || ext === '0' ? 'jpg' : ext}`;
}

/** Store bytes; returns the stored filename. */
export async function store(bytes: Buffer, originalName: string): Promise<string> {
  const name = filename(originalName);
  await file(name).save(bytes, { resumable: false, contentType: mimeFor(name) });
  return name;
}

/** The stored object, or null when missing. */
export async function find(name: string) {
  const f = file(name);
  const [exists] = await f.exists();
  return exists ? f : null;
}

export const validName = (name: string): boolean => /^[a-z0-9._-]+$/i.test(name);

export function mimeFor(name: string): string {
  const parts = name.split('.');
  return MIME[parts[parts.length - 1].toLowerCase()] ?? 'application/octet-stream';
}

export interface UploadedFile {
  filename: string;
  contentType: string;
  data: Buffer;
}

/** Minimal multipart/form-data reader: the first part named `field` (or `field[]`) that is a file. */
export function multipartFile(raw: Buffer, contentType: string, field: string): UploadedFile | null {
  const m = /boundary=(?:"([^"]+)"|([^;]+))/i.exec(contentType);
  if (!m) return null;
  const delim = Buffer.from('--' + (m[1] ?? m[2]).trim());
  let pos = raw.indexOf(delim);
  while (pos !== -1) {
    const start = pos + delim.length;
    if (raw.subarray(start, start + 2).toString() === '--') break; // closing delimiter
    const headEnd = raw.indexOf('\r\n\r\n', start);
    if (headEnd === -1) break;
    const next = raw.indexOf(delim, headEnd + 4);
    if (next === -1) break;
    const headers = raw.subarray(start, headEnd).toString('utf8');
    const disp = /content-disposition:[^\r\n]*/i.exec(headers)?.[0] ?? '';
    const name = /\bname="([^"]*)"/i.exec(disp)?.[1];
    const fname = /\bfilename="([^"]*)"/i.exec(disp)?.[1];
    if ((name === field || name === `${field}[]`) && fname !== undefined) {
      const data = raw.subarray(headEnd + 4, next - 2); // strip the CRLF before the delimiter
      if (fname === '' && data.length === 0) return null; // UPLOAD_ERR_NO_FILE
      const type = /content-type:\s*([^\r\n]*)/i.exec(headers)?.[1]?.trim() || 'application/octet-stream';
      return { filename: fname, contentType: type, data: Buffer.from(data) };
    }
    pos = next;
  }
  return null;
}
