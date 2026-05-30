# Prompt: Offline-First + Auto-Sync (Flutter + Laravel)

> Tambahkan fitur offline-first dengan auto-sync ke aplikasi Flutter (Dart) + Laravel yang sudah ada.
> **Jangan ubah atau hapus kode yang sudah ada** — hanya tambahkan fitur baru ini sebagai lapisan tambahan.

---

## 1. Deteksi Koneksi — Flutter

- Gunakan package `connectivity_plus` untuk memantau status jaringan secara real-time
- Buat `ConnectivityService` sebagai singleton
- Expose stream `isOnline` agar bisa didengarkan di seluruh aplikasi
- Tampilkan banner kecil di atas layar:
  - **Online** → banner hilang / tidak tampil
  - **Offline** → banner merah: `"Tidak ada koneksi — data disimpan lokal"`
- Jangan tampilkan error dialog saat offline

---

## 2. Offline Queue — Flutter (sqflite)

- Gunakan `sqflite` untuk menyimpan antrian aksi saat offline
- Buat tabel `sync_queue` dengan kolom:

| Kolom | Tipe | Keterangan |
|---|---|---|
| `id` | INTEGER PRIMARY KEY AUTOINCREMENT | — |
| `action_type` | TEXT | Nama aksi, contoh: `'create_order'` |
| `payload` | TEXT | JSON string data aksi |
| `timestamp` | INTEGER | Unix timestamp milliseconds |
| `retry_count` | INTEGER DEFAULT 0 | Jumlah percobaan ulang |
| `status` | TEXT DEFAULT `'pending'` | `'pending'` / `'synced'` / `'failed'` |

- Buat `OfflineQueueService` dengan method:
  - `addToQueue(String actionType, Map payload)`
  - `getPendingItems()`
  - `markAsSynced(int id)`
  - `incrementRetry(int id)`
  - `markAsFailed(int id)`

---

## 3. Auto-Sync — Flutter

- Buat `SyncService` yang mendengarkan `ConnectivityService`
- Ketika status berubah menjadi **online** → langsung jalankan `_runSync()` otomatis
- **Tidak ada tombol sync manual sama sekali**
- Proses antrian secara **FIFO** (urut dari yang paling lama)
- Kirim setiap item ke endpoint Laravel:

```
POST /api/sync/batch
Header: Authorization: Bearer {token}
Body:   { "items": [ { "action_type", "payload", "timestamp" } ] }
```

- Jika **berhasil** → `markAsSynced(id)`
- Jika **gagal** (network error / 5xx):
  - `retry_count < 3` → `incrementRetry`, coba lagi di sync berikutnya
  - `retry_count >= 3` → `markAsFailed`, lewati

- Tampilkan SnackBar:
  - Mulai sync: `"Menyinkronkan {n} data..."`
  - Selesai: `"Semua data berhasil disinkronkan ✓"`
  - Ada yang gagal: `"Beberapa data gagal, akan dicoba lagi"`
- Tampilkan badge jumlah pending di UI jika `pending > 0`

---

## 4. Endpoint Sync — Laravel

- Tambahkan route baru: `POST /api/sync/batch`
- Gunakan middleware auth yang sudah dipakai di aplikasi ini
- Buat `SyncController` dengan method `batch()`:
  - Terima array `items` dari request
  - Untuk setiap item, proses berdasarkan `action_type`
  - Gunakan `DB::transaction()` untuk atomicity
  - **Conflict handling: last-write-wins** berdasarkan timestamp:
    - `timestamp client > updated_at DB` → update data
    - `timestamp client <= updated_at DB` → skip, kembalikan data server
  - Setelah data berhasil disimpan, panggil **broadcast event yang sudah ada** di aplikasi ini agar semua user tetap menerima notifikasi real-time seperti biasa
  - Kembalikan response:

```json
{
  "results": [
    {
      "id": 1,
      "status": "synced"
    },
    {
      "id": 2,
      "status": "conflict",
      "server_data": {}
    }
  ]
}
```

- Buat `SyncRequest` untuk validasi input

---

## 5. Package Baru yang Dibutuhkan

**Flutter** — tambahkan ke `pubspec.yaml`:

```yaml
connectivity_plus: ^6.0.0
sqflite: ^2.3.0
path: ^1.9.0
```

**Laravel** — tidak butuh package tambahan.

---

## 6. File yang Harus Dibuat (Baru)

**Flutter:**

```
connectivity_service.dart
offline_queue_service.dart
sync_service.dart
connection_banner_widget.dart
```

**Laravel:**

```
SyncController.php
SyncRequest.php
```

> Tambahkan route di file `api.php` yang sudah ada — jangan buat file baru.

---

## ⚠️ Catatan Penting untuk Agent

- **Jangan ubah** controller, model, atau event yang sudah ada
- Endpoint `/api/sync/batch` hanya sebagai pintu masuk data offline
- Setelah data masuk, alur proses tetap mengikuti logika bisnis yang sudah berjalan di aplikasi ini
- Integrasi broadcast real-time tetap menggunakan mekanisme yang sudah ada, **bukan membuat mekanisme baru**
