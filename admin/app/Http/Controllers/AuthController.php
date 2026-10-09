<?php

namespace App\Http\Controllers;

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Auth;

/** Admin web sign-in — same rules as the Credentials provider in auth.ts. */
class AuthController extends Controller
{
    public function show()
    {
        return view('auth.login');
    }

    public function login(Request $request)
    {
        $data = $request->validate([
            'email' => ['required', 'email'],
            'password' => ['required', 'string', 'min:1'],
        ]);

        try {
            $ok = Auth::attempt(['email' => $data['email'], 'password' => $data['password']], true);
        } catch (\Throwable $e) {
            // DB unreachable (e.g. SSH tunnel down) → clean failure, not an error page.
            report($e);

            return back()->withInput($request->only('email'))
                ->with('error', 'Cannot reach the database right now. Please try again shortly.');
        }

        if (! $ok) {
            return back()->withInput($request->only('email'))->with('error', 'Invalid email or password.');
        }

        $request->session()->regenerate();

        return redirect()->intended('/dashboard');
    }

    public function logout(Request $request)
    {
        Auth::logout();
        $request->session()->invalidate();
        $request->session()->regenerateToken();

        return redirect('/login');
    }
}
