/**
 * Heat Loss Calculation Service Tests
 */

import { HeatLossService, Room, CalculationParams } from './heatLoss.service';

describe('HeatLossService', () => {
  const mockRoom: Room = {
    id: 'room-1',
    name: 'Living Room',
    area: 20, // m²
    volume: 50, // m³
    ceilingHeight: 2.5, // m
    exteriorWalls: 2, // 2 exterior walls
    windowArea: 4, // m²
    doorCount: 1,
    targetTemp: 20, // °C
  };

  const mockParams: CalculationParams = {
    outdoorTemp: -3, // UK design temperature
    indoorTemp: 20,
    wallUValue: 0.3, // Modern insulation
    windowUValue: 1.4, // Double glazed
    floorUValue: 0.25,
    ceilingUValue: 0.16,
    airChangeRate: 0.5, // ACH
  };

  describe('calculateRoomHeatLoss', () => {
    it('should calculate heat loss for a room', async () => {
      const result = await HeatLossService.calculateRoomHeatLoss(mockRoom, mockParams);

      expect(result).toBeDefined();
      expect(result.transmissionLoss).toBeGreaterThan(0);
      expect(result.ventilationLoss).toBeGreaterThan(0);
      expect(result.totalHeatLoss).toBeGreaterThan(0);
      expect(result.designHeatLoad).toBeGreaterThan(result.totalHeatLoss);
      expect(result.safetyFactor).toBe(1.15);
    });

    it('should throw error for invalid room area', async () => {
      const invalidRoom = { ...mockRoom, area: 0 };

      await expect(
        HeatLossService.calculateRoomHeatLoss(invalidRoom, mockParams)
      ).rejects.toThrow('Room area must be greater than 0');
    });

    it('should throw error for invalid temperatures', async () => {
      const invalidParams = { ...mockParams, indoorTemp: -5 };

      await expect(
        HeatLossService.calculateRoomHeatLoss(mockRoom, invalidParams)
      ).rejects.toThrow();
    });
  });

  describe('calculateRadiatorSize', () => {
    it('should calculate radiator size', () => {
      const result = HeatLossService.calculateRadiatorSize(2000, 75, 65, 20);

      expect(result.requiredOutput).toBeGreaterThan(0);
      expect(result.meanWaterTemp).toBe(70);
      expect(result.correction).toBeCloseTo(1, 1);
    });
  });
});
