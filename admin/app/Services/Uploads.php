<?php

namespace App\Services;

/**
 * Image uploads on disk — shared with the Next.js admin so existing image URLs keep working.
 * Directory: env UPLOAD_DIR, defaulting to the Next admin's own `admin/uploads` folder.
 */
final class Uploads
{
    public const MAX_BYTES = 5 * 1024 * 1024;

    public const MIME = [
        'png' => 'image/png',
        'jpg' => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'webp' => 'image/webp',
        'gif' => 'image/gif',
        'avif' => 'image/avif',
        'svg' => 'image/svg+xml',
    ];

    public static function dir(): string
    {
        $d = config('go4foodie.upload_dir');

        return $d ? (string) $d : base_path('../admin/uploads');
    }

    /** `${Date.now()}-${Math.random().toString(36).slice(2, 8)}.${ext}` with the TS ext rules. */
    public static function filename(string $originalName): string
    {
        $parts = explode('.', $originalName);
        $ext = substr(preg_replace('/[^a-z0-9]/', '', strtolower((string) end($parts) ?: 'jpg')), 0, 5) ?: 'jpg';
        $alphabet = '0123456789abcdefghijklmnopqrstuvwxyz';
        $rand = '';
        for ($i = 0; $i < 6; $i++) {
            $rand .= $alphabet[random_int(0, 35)];
        }

        return (int) floor(microtime(true) * 1000)."-$rand.$ext";
    }

    /** Store bytes; returns the stored filename. */
    public static function store(string $sourcePath, string $originalName): string
    {
        $dir = self::dir();
        if (! is_dir($dir) && ! @mkdir($dir, 0775, true) && ! is_dir($dir)) {
            throw new \RuntimeException("Cannot create upload dir $dir");
        }
        $name = self::filename($originalName);
        if (! @copy($sourcePath, $dir.DIRECTORY_SEPARATOR.$name)) {
            throw new \RuntimeException('Upload write failed');
        }

        return $name;
    }

    /** Validated absolute path of an uploaded file, or null (bad name / missing). */
    public static function path(string $name): ?string
    {
        $p = self::dir().DIRECTORY_SEPARATOR.$name;

        return is_file($p) ? $p : null;
    }

    public static function validName(string $name): bool
    {
        return (bool) preg_match('/^[a-z0-9._-]+$/i', $name);
    }

    public static function mimeFor(string $name): string
    {
        $parts = explode('.', $name);

        return self::MIME[strtolower((string) end($parts))] ?? 'application/octet-stream';
    }
}
