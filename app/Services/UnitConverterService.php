<?php

namespace App\Services;

use Exception;

class UnitConverterService
{
    /**
     * Conversion rates between units.
     * Array format: [from_unit][to_unit] => multiplier
     */
    private static array $conversionRates = [
        'g' => [
            'g' => 1.0,
            'kg' => 0.001
        ],
        'kg' => [
            'g' => 1000.0,
            'kg' => 1.0
        ],
        'ml' => [
            'ml' => 1.0,
            'l' => 0.001
        ],
        'l' => [
            'ml' => 1000.0,
            'l' => 1.0
        ],
        'pcs' => [
            'pcs' => 1.0
        ]
    ];

    /**
     * Convert quantity from one unit to another.
     * 
     * @param float $quantity
     * @param string $fromUnit
     * @param string $toUnit
     * @return float
     * @throws Exception
     */
    public static function convert(float $quantity, string $fromUnit, string $toUnit): float
    {
        $from = strtolower(trim($fromUnit));
        $to = strtolower(trim($toUnit));

        if ($from === $to) {
            return $quantity;
        }

        if (!isset(self::$conversionRates[$from][$to])) {
            throw new Exception("Incompatible unit conversion from '{$fromUnit}' to '{$toUnit}'. Only conversions within weight (g <-> kg) or volume (ml <-> l) are supported.");
        }

        return $quantity * self::$conversionRates[$from][$to];
    }

    /**
     * Check if two units are compatible for conversion.
     * 
     * @param string $unitA
     * @param string $unitB
     * @return bool
     */
    public static function areCompatible(string $unitA, string $unitB): bool
    {
        $a = strtolower(trim($unitA));
        $b = strtolower(trim($unitB));

        return isset(self::$conversionRates[$a][$b]);
    }
}
