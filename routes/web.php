<?php

use Illuminate\Support\Facades\Route;

Route::get('/', function () {
    return view('welcome');
});

Route::get('/preview/phone', function () {
    return view('phone_preview');
});

Route::get('/driver', function () {
    return view('driver_portal');
});
