<?php

namespace Tests\Unit;

use App\Services\UnitConverterService;
use Tests\TestCase;
use Exception;

class UnitConverterServiceTest extends TestCase
{
    /**
     * Test converting the same unit returns the same value.
     */
    public function test_same_unit_conversion(): void
    {
        $this->assertEquals(10.0, UnitConverterService::convert(10.0, 'g', 'g'));
        $this->assertEquals(5.5, UnitConverterService::convert(5.5, 'pcs', 'pcs'));
        $this->assertEquals(12.0, UnitConverterService::convert(12.0, 'l', 'L')); // Case insensitive
    }

    /**
     * Test mass/weight conversions (g <-> kg).
     */
    public function test_weight_conversions(): void
    {
        $this->assertEquals(1000.0, UnitConverterService::convert(1.0, 'kg', 'g'));
        $this->assertEquals(0.5, UnitConverterService::convert(500.0, 'g', 'kg'));
        $this->assertEquals(2500.0, UnitConverterService::convert(2.5, 'kg', 'g'));
    }

    /**
     * Test volume conversions (ml <-> l).
     */
    public function test_volume_conversions(): void
    {
        $this->assertEquals(2000.0, UnitConverterService::convert(2.0, 'l', 'ml'));
        $this->assertEquals(0.25, UnitConverterService::convert(250.0, 'ml', 'l'));
        $this->assertEquals(1500.0, UnitConverterService::convert(1.5, 'l', 'ml'));
    }

    /**
     * Test incompatible conversions throw exceptions.
     */
    public function test_incompatible_conversions_throw_exception(): void
    {
        $this->expectException(Exception::class);
        UnitConverterService::convert(10.0, 'g', 'ml');
    }

    /**
     * Test unit compatibility helper method.
     */
    public function test_unit_compatibility(): void
    {
        $this->assertTrue(UnitConverterService::areCompatible('g', 'kg'));
        $this->assertTrue(UnitConverterService::areCompatible('l', 'ml'));
        $this->assertTrue(UnitConverterService::areCompatible('pcs', 'pcs'));
        $this->assertFalse(UnitConverterService::areCompatible('g', 'ml'));
        $this->assertFalse(UnitConverterService::areCompatible('pcs', 'kg'));
    }
}
