<?php

namespace Database\Seeders;

use App\Models\User;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

class DatabaseSeeder extends Seeder
{
    /**
     * Seed the application's database.
     */
    public function run(): void
    {
        // Seed Users
        $users = [
            [
                'name' => 'Administrator',
                'email' => 'admin@faacos.com',
                'password' => Hash::make('password'),
                'role' => 'admin',
            ],
            [
                'name' => 'R&D Scientist',
                'email' => 'rnd@faacos.com',
                'password' => Hash::make('password'),
                'role' => 'rnd',
            ],
            [
                'name' => 'Kepala Produksi',
                'email' => 'produksi@faacos.com',
                'password' => Hash::make('password'),
                'role' => 'kepala_produksi',
            ],
            [
                'name' => 'Kepala Gudang',
                'email' => 'gudang@faacos.com',
                'password' => Hash::make('password'),
                'role' => 'kepala_gudang',
            ],
        ];

        foreach ($users as $userData) {
            User::updateOrCreate(['email' => $userData['email']], $userData);
        }

        // Seed Suppliers
        $suppliers = [
            [
                'code' => 'SUP-001',
                'name' => 'PT. Sarana Kimia Tama',
                'contact_person' => 'Budi Santoso',
                'phone' => '081234567890',
                'email' => 'sales@saranakimia.com',
                'address' => 'Kawasan Industri Cikarang Blok B-12, Bekasi',
                'status' => true,
            ],
            [
                'code' => 'SUP-002',
                'name' => 'CV. Indo Pack Pratama',
                'contact_person' => 'Siti Aminah',
                'phone' => '082198765432',
                'email' => 'info@indopack.co.id',
                'address' => 'Jl. Pahlawan No. 45, Sidoarjo',
                'status' => true,
            ],
        ];

        foreach ($suppliers as $sup) {
            DB::table('suppliers')->updateOrInsert(['code' => $sup['code']], $sup);
        }

        // Seed Ingredients (Raw Materials & Packaging)
        $ingredients = [
            // Raw Materials
            [
                'code' => 'RAW-001',
                'name' => 'Niacinamide (Vitamin B3) Powder',
                'type' => 'raw_material',
                'unit' => 'kg',
                'price_per_unit' => 350000.00, // Rp 350.000 per kg
                'current_stock' => 15.0000,   // 15 kg
                'minimum_stock' => 5.0000,
                'expired_at' => now()->addDays(5)->toDateString(), // Segera Expired
            ],
            [
                'code' => 'RAW-002',
                'name' => 'Glycerin USP Grade',
                'type' => 'raw_material',
                'unit' => 'l',
                'price_per_unit' => 85000.00,  // Rp 85.000 per Liter
                'current_stock' => 50.0000,   // 50 Liter
                'minimum_stock' => 10.0000,
                'expired_at' => now()->subDays(10)->toDateString(), // Bahan Expired
            ],
            [
                'code' => 'RAW-003',
                'name' => 'Distilled Water (Aqua Dest)',
                'type' => 'raw_material',
                'unit' => 'l',
                'price_per_unit' => 5000.00,   // Rp 5.000 per Liter
                'current_stock' => 500.0000,  // 500 Liter
                'minimum_stock' => 50.0000,
                'expired_at' => now()->addDays(365)->toDateString(), // Active/Far Expiry
            ],
            [
                'code' => 'RAW-004',
                'name' => 'Hyaluronic Acid Powder',
                'type' => 'raw_material',
                'unit' => 'g',
                'price_per_unit' => 12000.00,   // Rp 12.000 per gram
                'current_stock' => 500.0000,   // 500 gram (0.5 kg)
                'minimum_stock' => 100.0000,
                'expired_at' => now()->subDays(20)->toDateString(), // Bahan Expired
            ],
            [
                'code' => 'RAW-005',
                'name' => 'Centella Asiatica Extract',
                'type' => 'raw_material',
                'unit' => 'ml',
                'price_per_unit' => 450.00,     // Rp 450 per ml
                'current_stock' => 0.0000,      // 0 ml (intentionally empty!)
                'minimum_stock' => 1000.0000,
                'expired_at' => now()->addDays(12)->toDateString(), // Segera Expired
            ],
            // Packaging
            [
                'code' => 'PKG-001',
                'name' => 'Premium Glass Jar 50ml',
                'type' => 'packaging',
                'unit' => 'pcs',
                'price_per_unit' => 8500.00,    // Rp 8.500 per pcs
                'current_stock' => 1200.0000,  // 1200 pcs
                'minimum_stock' => 200.0000,
                'expired_at' => null, // No expiry
            ],
            [
                'code' => 'PKG-002',
                'name' => 'Faacos Glowing Cream Outer Box',
                'type' => 'packaging',
                'unit' => 'pcs',
                'price_per_unit' => 2500.00,    // Rp 2.500 per pcs
                'current_stock' => 1500.0000,  // 1500 pcs
                'minimum_stock' => 200.0000,
                'expired_at' => null, // No expiry
            ],
        ];

        foreach ($ingredients as $ing) {
            DB::table('ingredients')->updateOrInsert(['code' => $ing['code']], $ing);
        }
    }
}
