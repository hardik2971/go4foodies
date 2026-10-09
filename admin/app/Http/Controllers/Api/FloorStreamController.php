<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Api\Support\Json;
use App\Http\Controllers\Api\Support\RawCacheControl;
use App\Http\Controllers\Controller;
use App\Support\Format;
use Carbon\Carbon;
use Illuminate\Support\Facades\Auth;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\StreamedResponse;

/**
 * GET /api/floor-stream — Server-Sent Events for the live floor plan (web session auth).
 * Emits `data: connected`, then every 4s either `data: refresh` (max updatedAt of
 * Table / TableSession / Order changed) or a `: ping` keep-alive comment.
 *
 * PHP holds a worker per open stream, so each stream ends after FLOOR_STREAM_MAX_SECONDS
 * (default 120); EventSource reconnects automatically.
 */
class FloorStreamController extends Controller
{
    private const INTERVAL = 4;

    public function stream()
    {
        if (! Auth::check()) {
            return Json::text('Unauthorized', 401);
        }
        // Don't hold the session file/lock for the life of the stream.
        if (app()->bound('session') && session()->isStarted()) {
            session()->save();
        }

        $maxSeconds = max(self::INTERVAL, (int) config('go4foodie.floor_stream_max_seconds'));

        return new StreamedResponse(function () use ($maxSeconds) {
            @set_time_limit($maxSeconds + 30);
            ignore_user_abort(false);
            while (ob_get_level() > 0) {
                @ob_end_flush();
            }

            $send = function (string $chunk) {
                echo $chunk;
                @flush();
            };

            $send("data: connected\n\n");
            try {
                $last = self::version();
            } catch (\Throwable) {
                $last = '';
            }

            $deadline = microtime(true) + $maxSeconds;
            while (microtime(true) + self::INTERVAL <= $deadline) {
                sleep(self::INTERVAL);
                if (connection_aborted()) {
                    break;
                }
                try {
                    $v = self::version();
                    if ($v !== $last) {
                        $last = $v;
                        $send("data: refresh\n\n");
                    } else {
                        $send(": ping\n\n"); // keep-alive comment
                    }
                } catch (\Throwable) {
                    // ignore transient DB errors
                }
                if (connection_aborted()) {
                    break;
                }
            }
        }, 200, [
            'Content-Type' => 'text/event-stream',
            RawCacheControl::HEADER => 'no-cache, no-transform',
            'Connection' => 'keep-alive',
            'X-Accel-Buffering' => 'no',
        ]);
    }

    /** `${t}-${s}-${o}` of max(updatedAt) epoch millis (0 when empty). */
    private static function version(): string
    {
        $ms = function (string $table) {
            $v = DB::table($table)->max('updatedAt');

            return $v ? (string) Format::ms(Carbon::parse($v, 'UTC')) : '0';
        };

        return $ms('Table').'-'.$ms('TableSession').'-'.$ms('Order');
    }
}
