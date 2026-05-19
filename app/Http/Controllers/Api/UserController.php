<?php

namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use App\Models\User;
use App\Models\AuditLog;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Validator;
use Exception;

class UserController extends Controller
{
    /**
     * Display a listing of all users.
     */
    public function index()
    {
        $users = User::orderBy('id', 'desc')->get();

        return response()->json([
            'status' => 'success',
            'data' => $users
        ]);
    }

    /**
     * Store a newly created user in storage.
     */
    public function store(Request $request)
    {
        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users',
            'password' => 'required|string|min:6',
            'role' => 'required|string|in:admin,rnd,kepala_produksi,kepala_gudang'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Validasi gagal.',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            $user = User::create([
                'name' => $request->name,
                'email' => $request->email,
                'password' => Hash::make($request->password),
                'role' => $request->role,
            ]);

            $currentUser = $request->user();

            // Log Audit
            AuditLog::logAction(
                $currentUser ? $currentUser->id : null,
                'manage_users',
                "Mendaftarkan Pengguna Baru: {$user->name} ({$user->email}) dengan peran '{$user->role}'.",
                $user,
                ['name' => $user->name, 'email' => $user->email, 'role' => $user->role]
            );

            // Broadcast real-time event
            event(new \App\Events\RealTimeActionEvent(
                $currentUser ? $currentUser->name : 'Administrator',
                $currentUser ? $currentUser->role : 'admin',
                'manage_users',
                "Admin mendaftarkan pengguna baru: '{$user->name}' ({$user->email}) sebagai " . strtoupper($user->role)
            ));

            return response()->json([
                'status' => 'success',
                'message' => 'Pengguna baru berhasil didaftarkan.',
                'data' => $user
            ]);

        } catch (Exception $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Gagal mendaftarkan pengguna: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Update the specified user in storage.
     */
    public function update(Request $request, $id)
    {
        $user = User::find($id);

        if (!$user) {
            return response()->json([
                'status' => 'error',
                'message' => 'Pengguna tidak ditemukan.'
            ], 404);
        }

        $validator = Validator::make($request->all(), [
            'name' => 'required|string|max:255',
            'email' => 'required|string|email|max:255|unique:users,email,' . $user->id,
            'password' => 'nullable|string|min:6',
            'role' => 'required|string|in:admin,rnd,kepala_produksi,kepala_gudang'
        ]);

        if ($validator->fails()) {
            return response()->json([
                'status' => 'error',
                'message' => 'Validasi gagal.',
                'errors' => $validator->errors()
            ], 422);
        }

        try {
            $currentUser = $request->user();

            // Safety check: Prevent the only admin from demoting their own role
            if ($user->id === $currentUser->id && $request->role !== 'admin') {
                $otherAdminsCount = User::where('role', 'admin')->where('id', '!=', $user->id)->count();
                if ($otherAdminsCount === 0) {
                    return response()->json([
                        'status' => 'error',
                        'message' => 'Aksi ditolak. Anda adalah satu-satunya administrator aktif. Anda tidak dapat mengubah peran Anda sendiri.'
                    ], 403);
                }
            }

            $updateData = [
                'name' => $request->name,
                'email' => $request->email,
                'role' => $request->role,
            ];

            $passwordChanged = false;
            if ($request->filled('password')) {
                $updateData['password'] = Hash::make($request->password);
                $passwordChanged = true;
            }

            $user->update($updateData);

            // If password changed, revoke all user tokens for security
            if ($passwordChanged) {
                $user->tokens()->delete();
            }

            // Log Audit
            AuditLog::logAction(
                $currentUser ? $currentUser->id : null,
                'manage_users',
                "Memperbarui Pengguna: {$user->name} ({$user->email}). Peran: {$user->role}." . ($passwordChanged ? " (Password diubah)" : ""),
                $user,
                ['name' => $user->name, 'email' => $user->email, 'role' => $user->role, 'password_changed' => $passwordChanged]
            );

            // Broadcast real-time event
            event(new \App\Events\RealTimeActionEvent(
                $currentUser ? $currentUser->name : 'Administrator',
                $currentUser ? $currentUser->role : 'admin',
                'manage_users',
                "Admin memperbarui informasi pengguna: '{$user->name}' ({$user->email})"
            ));

            return response()->json([
                'status' => 'success',
                'message' => 'Data pengguna berhasil diperbarui.',
                'data' => $user
            ]);

        } catch (Exception $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Gagal memperbarui pengguna: ' . $e->getMessage()
            ], 500);
        }
    }

    /**
     * Remove the specified user from storage.
     */
    public function destroy(Request $request, $id)
    {
        $user = User::find($id);

        if (!$user) {
            return response()->json([
                'status' => 'error',
                'message' => 'Pengguna tidak ditemukan.'
            ], 404);
        }

        $currentUser = $request->user();

        // Safety lockout: Admin cannot delete their own active account
        if ($user->id === $currentUser->id) {
            return response()->json([
                'status' => 'error',
                'message' => 'Aksi ditolak. Anda tidak diperbolehkan menghapus akun Anda sendiri demi alasan keamanan.'
            ], 403);
        }

        try {
            // Revoke all tokens first
            $user->tokens()->delete();
            
            $deletedName = $user->name;
            $deletedEmail = $user->email;
            $user->delete();

            // Log Audit
            AuditLog::logAction(
                $currentUser ? $currentUser->id : null,
                'manage_users',
                "Menghapus Pengguna: {$deletedName} ({$deletedEmail})",
                null,
                ['name' => $deletedName, 'email' => $deletedEmail]
            );

            // Broadcast real-time event
            event(new \App\Events\RealTimeActionEvent(
                $currentUser ? $currentUser->name : 'Administrator',
                $currentUser ? $currentUser->role : 'admin',
                'manage_users',
                "Admin menghapus akun pengguna: '{$deletedName}' ({$deletedEmail})"
            ));

            return response()->json([
                'status' => 'success',
                'message' => 'Akun pengguna berhasil dihapus.'
            ]);

        } catch (Exception $e) {
            return response()->json([
                'status' => 'error',
                'message' => 'Gagal menghapus pengguna: ' . $e->getMessage()
            ], 500);
        }
    }
}
