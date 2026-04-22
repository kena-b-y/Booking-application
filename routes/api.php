<?php

use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;
use App\Http\Controllers\Api\BookingController;

Route::post('/bookings', [BookingController::class, 'store']);
Route::get('/bookings/{booking}', [BookingController::class, 'show']);

Route::get('/health', fn() => response()->json(['status' => 'ok']));
