<?php

// Public website + mobile app API — same paths and JSON as the Next.js admin.
// Route files per area live in routes/api/*.php.
foreach (glob(__DIR__.'/api/*.php') as $file) {
    require $file;
}
