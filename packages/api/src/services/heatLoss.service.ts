/**
 * Heat Loss Calculation Service
 * Implements professional heat loss calculations based on:
 * - UK Building Regulations Part L
 * - CIBSE Guide A
 * - EN 12831 standard
 */

import { Decimal } from '@prisma/client/runtime/library';
import { logger } from '../utils/logger';

// ============================================================================
// Types
// ============================================================================

export interface Room {
  id: string;
  name: string;
  area: number;           // m²
  volume: number;         // m³
  ceilingHeight: number;  // m
  exteriorWalls: number;  // count
  windowArea: number;     // m²
  doorCount: number;      // count
  targetTemp: number;     // °C
}

export interface CalculationParams {
  outdoorTemp: number;    // °C (design temperature)
  indoorTemp: number;     // °C (target temperature)
  wallUValue: number;     // W/m²K
  windowUValue: number;   // W/m²K
  floorUValue: number;    // W/m²K
  ceilingUValue: number;  // W/m²K
  airChangeRate: number;  // ACH (air changes per hour)
}

export interface CalculationResult {
  transmissionLoss: number;   // W
  ventilationLoss: number;    // W
  totalHeatLoss: number;      // W
  designHeatLoad: number;     // W (with safety factor)
  safetyFactor: number;
  method: string;
  calculationTimeMs: number;
}

// ============================================================================
// Constants
// ============================================================================

const CONSTANTS = {
  AIR_DENSITY: 1.2,              // kg/m³ at 20°C
  SPECIFIC_HEAT_AIR: 1005,       // J/(kg·K)
  SAFETY_FACTOR: 1.15,           // 15% safety margin
  MIN_OUTDOOR_TEMP: -20,         // °C
  MAX_OUTDOOR_TEMP: 15,          // °C
  MIN_INDOOR_TEMP: 15,           // °C
  MAX_INDOOR_TEMP: 25,           // °C
};

// UK Design Temperatures by Location
export const UK_DESIGN_TEMPS = {
  LONDON: -3,
  BIRMINGHAM: -4,
  MANCHESTER: -4,
  EDINBURGH: -5,
  GLASGOW: -5,
  CARDIFF: -3,
  BELFAST: -4,
  DEFAULT: -3,
};

// Standard U-Values (W/m²K)
export const STANDARD_U_VALUES = {
  WALL: {
    UNINSULATED: 2.1,
    CAVITY_FILL: 0.55,
    EXTERNAL_INSULATION: 0.30,
    NEW_BUILD: 0.18,
  },
  WINDOW: {
    SINGLE_GLAZED: 5.0,
    DOUBLE_GLAZED: 2.8,
    DOUBLE_LOW_E: 1.8,
    TRIPLE_GLAZED: 0.8,
  },
  FLOOR: {
    UNINSULATED: 0.70,
    INSULATED: 0.25,
    SUSPENDED: 0.45,
  },
  CEILING: {
    UNINSULATED: 2.0,
    100MM_INSULATION: 0.4,
    270MM_INSULATION: 0.16,
  },
};

// ============================================================================
// Heat Loss Service
// ============================================================================

export class HeatLossService {
  /**
   * Calculate heat loss for a room
   */
  static async calculateRoomHeatLoss(
    room: Room,
    params: CalculationParams
  ): Promise<CalculationResult> {
    const startTime = Date.now();

    try {
      // Validate inputs
      this.validateInputs(room, params);

      // Calculate temperature difference
      const tempDiff = params.indoorTemp - params.outdoorTemp;

      // 1. Transmission Heat Loss (through building fabric)
      const transmissionLoss = this.calculateTransmissionLoss(
        room,
        params,
        tempDiff
      );

      // 2. Ventilation Heat Loss (air changes)
      const ventilationLoss = this.calculateVentilationLoss(
        room,
        params,
        tempDiff
      );

      // 3. Total heat loss
      const totalHeatLoss = transmissionLoss + ventilationLoss;

      // 4. Design heat load (with safety factor)
      const designHeatLoad = totalHeatLoss * CONSTANTS.SAFETY_FACTOR;

      const calculationTimeMs = Date.now() - startTime;

      logger.info('Heat loss calculated', {
        roomId: room.id,
        roomName: room.name,
        transmissionLoss,
        ventilationLoss,
        totalHeatLoss,
        designHeatLoad,
        calculationTimeMs,
      });

      return {
        transmissionLoss: this.round(transmissionLoss),
        ventilationLoss: this.round(ventilationLoss),
        totalHeatLoss: this.round(totalHeatLoss),
        designHeatLoad: this.round(designHeatLoad),
        safetyFactor: CONSTANTS.SAFETY_FACTOR,
        method: 'EN_12831',
        calculationTimeMs,
      };
    } catch (error) {
      logger.error('Heat loss calculation failed', {
        roomId: room.id,
        error: error instanceof Error ? error.message : 'Unknown error',
      });
      throw error;
    }
  }

  /**
   * Calculate transmission heat loss (through walls, windows, floor, ceiling)
   */
  private static calculateTransmissionLoss(
    room: Room,
    params: CalculationParams,
    tempDiff: number
  ): number {
    // Calculate wall area (total area - window area)
    const floorArea = room.area;
    const ceilingArea = room.area;

    // Estimate wall area from room dimensions
    // Assuming square room for simplicity: perimeter * height
    const roomPerimeter = 4 * Math.sqrt(floorArea);
    const totalWallArea = roomPerimeter * room.ceilingHeight;
    const wallArea = totalWallArea - room.windowArea;

    // Only exterior walls contribute to heat loss
    const exteriorWallFactor = room.exteriorWalls / 4; // 0 to 1
    const effectiveWallArea = wallArea * exteriorWallFactor;
    const effectiveWindowArea = room.windowArea * exteriorWallFactor;

    // Heat loss through each element: Q = U × A × ΔT
    const wallLoss = params.wallUValue * effectiveWallArea * tempDiff;
    const windowLoss = params.windowUValue * effectiveWindowArea * tempDiff;
    const floorLoss = params.floorUValue * floorArea * tempDiff * 0.5; // Ground heat loss is reduced
    const ceilingLoss = params.ceilingUValue * ceilingArea * tempDiff;

    return wallLoss + windowLoss + floorLoss + ceilingLoss;
  }

  /**
   * Calculate ventilation heat loss (air infiltration and ventilation)
   */
  private static calculateVentilationLoss(
    room: Room,
    params: CalculationParams,
    tempDiff: number
  ): number {
    // Volume flow rate (m³/h)
    const volumeFlowRate = room.volume * params.airChangeRate;

    // Convert to m³/s
    const volumeFlowRatePerSecond = volumeFlowRate / 3600;

    // Mass flow rate (kg/s)
    const massFlowRate = volumeFlowRatePerSecond * CONSTANTS.AIR_DENSITY;

    // Heat loss: Q = m × c × ΔT
    // where m = mass flow rate (kg/s)
    //       c = specific heat capacity of air (J/(kg·K))
    //       ΔT = temperature difference (K)
    const ventilationLoss = massFlowRate * CONSTANTS.SPECIFIC_HEAT_AIR * tempDiff;

    return ventilationLoss;
  }

  /**
   * Calculate recommended radiator size
   */
  static calculateRadiatorSize(
    designHeatLoad: number,
    flowTemp: number = 75,
    returnTemp: number = 65,
    roomTemp: number = 20
  ): {
    requiredOutput: number;
    meanWaterTemp: number;
    correction: number;
  } {
    // Mean water temperature
    const meanWaterTemp = (flowTemp + returnTemp) / 2;

    // Temperature difference
    const tempDiff = meanWaterTemp - roomTemp;

    // Correction factor for non-standard conditions
    // Standard conditions: 75/65/20 (flow/return/room)
    const standardTempDiff = 50; // (75+65)/2 - 20
    const correction = Math.pow(tempDiff / standardTempDiff, 1.3);

    // Required radiator output at standard conditions
    const requiredOutput = designHeatLoad / correction;

    return {
      requiredOutput: this.round(requiredOutput),
      meanWaterTemp: this.round(meanWaterTemp),
      correction: this.round(correction, 3),
    };
  }

  /**
   * Calculate heat loss for entire building (sum of all rooms)
   */
  static calculateBuildingHeatLoss(
    rooms: Room[],
    params: CalculationParams
  ): Promise<{
    rooms: Array<{ roomId: string; result: CalculationResult }>;
    totalHeatLoss: number;
    totalDesignLoad: number;
  }> {
    return Promise.all(
      rooms.map(async (room) => ({
        roomId: room.id,
        result: await this.calculateRoomHeatLoss(room, params),
      }))
    ).then((results) => {
      const totalHeatLoss = results.reduce(
        (sum, r) => sum + r.result.totalHeatLoss,
        0
      );
      const totalDesignLoad = results.reduce(
        (sum, r) => sum + r.result.designHeatLoad,
        0
      );

      return {
        rooms: results,
        totalHeatLoss: this.round(totalHeatLoss),
        totalDesignLoad: this.round(totalDesignLoad),
      };
    });
  }

  /**
   * Validate calculation inputs
   */
  private static validateInputs(room: Room, params: CalculationParams): void {
    // Room validation
    if (room.area <= 0) {
      throw new Error('Room area must be greater than 0');
    }
    if (room.volume <= 0) {
      throw new Error('Room volume must be greater than 0');
    }
    if (room.ceilingHeight <= 0) {
      throw new Error('Ceiling height must be greater than 0');
    }

    // Temperature validation
    if (params.outdoorTemp < CONSTANTS.MIN_OUTDOOR_TEMP) {
      throw new Error(`Outdoor temperature too low (min: ${CONSTANTS.MIN_OUTDOOR_TEMP}°C)`);
    }
    if (params.outdoorTemp > CONSTANTS.MAX_OUTDOOR_TEMP) {
      throw new Error(`Outdoor temperature too high (max: ${CONSTANTS.MAX_OUTDOOR_TEMP}°C)`);
    }
    if (params.indoorTemp < CONSTANTS.MIN_INDOOR_TEMP) {
      throw new Error(`Indoor temperature too low (min: ${CONSTANTS.MIN_INDOOR_TEMP}°C)`);
    }
    if (params.indoorTemp > CONSTANTS.MAX_INDOOR_TEMP) {
      throw new Error(`Indoor temperature too high (max: ${CONSTANTS.MAX_INDOOR_TEMP}°C)`);
    }
    if (params.indoorTemp <= params.outdoorTemp) {
      throw new Error('Indoor temperature must be greater than outdoor temperature');
    }

    // U-value validation
    if (params.wallUValue <= 0 || params.wallUValue > 10) {
      throw new Error('Invalid wall U-value (must be 0-10 W/m²K)');
    }
    if (params.windowUValue <= 0 || params.windowUValue > 10) {
      throw new Error('Invalid window U-value (must be 0-10 W/m²K)');
    }
    if (params.floorUValue <= 0 || params.floorUValue > 10) {
      throw new Error('Invalid floor U-value (must be 0-10 W/m²K)');
    }
    if (params.ceilingUValue <= 0 || params.ceilingUValue > 10) {
      throw new Error('Invalid ceiling U-value (must be 0-10 W/m²K)');
    }

    // Air change rate validation
    if (params.airChangeRate < 0 || params.airChangeRate > 10) {
      throw new Error('Invalid air change rate (must be 0-10 ACH)');
    }
  }

  /**
   * Round to specified precision
   */
  private static round(value: number, precision: number = 2): number {
    const multiplier = Math.pow(10, precision);
    return Math.round(value * multiplier) / multiplier;
  }
}

export default HeatLossService;
