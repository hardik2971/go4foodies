<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Support\Json;
use App\Http\Controllers\Api\Support\RawCacheControl;
use App\Http\Controllers\Controller;
use App\Services\Uploads;
use App\Support\MobileJwt;
use App\Support\Rbac;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

/** POST /api/upload + GET /api/uploads/{name} — port of app/api/upload(s)/**. */
class UploadController extends Controller
{
    /**
     * POST /api/upload — multipart `file` (image ≤ 5MB) → {url} (absolute, from the request host).
     * Auth: admin web session, or a staff bearer token that may edit the menu (mobile app).
     */
    public function store(Request $req)
    {
        $mobile = MobileJwt::fromRequest($req);
        if (! Auth::check() && ! ($mobile && Rbac::can($mobile['role'], 'manage:menu'))) {
            return Json::error('Unauthorized', 401);
        }

        $file = $req->file('file');
        if (is_array($file)) {
            $file = $file[0] ?? null;
        }
        if (! $file) {
            return Json::error('No file provided', 400);
        }
        if (! $file->isValid()) {
            // PHP rejected it before we saw it (upload_max_filesize / post_max_size).
            return in_array($file->getError(), [UPLOAD_ERR_INI_SIZE, UPLOAD_ERR_FORM_SIZE], true)
                ? Json::error('Image must be under 5MB', 413)
                : Json::error('No file provided', 400);
        }
        if (! str_starts_with((string) $file->getClientMimeType(), 'image/')) {
            return Json::error('Only image files are allowed', 415);
        }
        if ($file->getSize() > Uploads::MAX_BYTES) {
            return Json::error('Image must be under 5MB', 413);
        }

        try {
            $name = Uploads::store($file->getRealPath(), $file->getClientOriginalName());
        } catch (\Throwable $e) {
            report($e);

            return Json::error('Could not save image', 500);
        }

        return Json::response(['url' => $req->getSchemeAndHttpHost().'/api/uploads/'.$name], 201);
    }

    /** GET /api/uploads/{name} — public, path-traversal safe. */
    public function show(string $name)
    {
        if (! Uploads::validName($name)) {
            return Json::text('Bad request', 400);
        }
        $path = Uploads::path($name);
        if (! $path) {
            return Json::text('Not found', 404);
        }

        return response(file_get_contents($path), 200, [
            'Content-Type' => Uploads::mimeFor($name),
            RawCacheControl::HEADER => 'public, max-age=31536000, immutable',
        ]);
    }
}
