classdef Turbine
    % TURBINE Class for modeling turbine characteristics and performance
    % 
    % Example usage:
    %   turbine = Turbine('GasTurbine', 10000, 0.85);
    %   efficiency = turbine.calculateEfficiency(0.7);
    %   power = turbine.calculatePower(500, 300, 1.2);
    
    properties
        % Basic turbine properties
        Name string              % Turbine name/type
        RatedPower double        % Rated power output (kW)
        MaxEfficiency double     % Maximum efficiency (0-1)
        DesignPressureRatio double % Design pressure ratio
        DesignMassFlow double    % Design mass flow rate (kg/s)
        TurbineType string       % Type: 'Gas', 'Steam', 'Wind', 'Hydro'
        
        % Performance characteristics
        EfficiencyCurve          % Efficiency vs load curve
        PressureRatioRange       % Operating pressure ratio range [min, max]
        SpeedRange               % Operating speed range [min, max] (RPM)
    end
    
    properties (Constant)
        % Physical constants
        GAMMA = 1.4;             % Specific heat ratio for air
        R = 287;                 % Gas constant (J/kg·K)
        CP = 1005;               % Specific heat at constant pressure (J/kg·K)
    end
    
    methods
        function obj = Turbine(name, ratedPower, maxEfficiency, varargin)
            % TURBINE Constructor method
            %
            % Inputs:
            %   name - Turbine name/identifier
            %   ratedPower - Rated power output (kW)
            %   maxEfficiency - Maximum efficiency (0-1)
            %
            % Optional inputs (name-value pairs):
            %   'TurbineType' - Type of turbine
            %   'DesignPressureRatio' - Design pressure ratio
            %   'DesignMassFlow' - Design mass flow rate (kg/s)
            %   'PressureRatioRange' - Operating range [min, max]
            %   'SpeedRange' - Speed range [min, max] (RPM)
            
            % Set required properties
            obj.Name = name;
            obj.RatedPower = ratedPower;
            obj.MaxEfficiency = maxEfficiency;
            
            % Set default values
            obj.TurbineType = 'Gas';
            obj.DesignPressureRatio = 3;
            obj.DesignMassFlow = 10;
            obj.PressureRatioRange = [1.5, 5];
            obj.SpeedRange = [5000, 15000];
            
            % Process optional inputs
            if nargin > 3
                for i = 1:2:length(varargin)
                    switch lower(varargin{i})
                        case 'turbinetype'
                            obj.TurbineType = varargin{i+1};
                        case 'designpressureratio'
                            obj.DesignPressureRatio = varargin{i+1};
                        case 'designmassflow'
                            obj.DesignMassFlow = varargin{i+1};
                        case 'pressureratiorange'
                            obj.PressureRatioRange = varargin{i+1};
                        case 'speedrange'
                            obj.SpeedRange = varargin{i+1};
                    end
                end
            end
            
            % Generate default efficiency curve
            obj = obj.generateEfficiencyCurve();
        end
        
        function obj = generateEfficiencyCurve(obj)
            % GENERATEEFFICIENCYCURVE Create default efficiency vs load curve
            loadPoints = linspace(0.2, 1.2, 20); % Load fraction
            efficiencyPoints = obj.MaxEfficiency * (1 - 0.3*(loadPoints - 1).^2);
            obj.EfficiencyCurve = [loadPoints; efficiencyPoints];
        end
        
        function efficiency = calculateEfficiency(obj, loadFraction)
            % CALCULATEEFFICIENCY Calculate efficiency at given load
            %
            % Input: loadFraction - Fraction of rated load (0-1.2)
            % Output: efficiency - Turbine efficiency (0-1)
            
            % Ensure load is within bounds
            loadFraction = max(0.2, min(1.2, loadFraction));
            
            % Interpolate efficiency from curve
            efficiency = interp1(obj.EfficiencyCurve(1,:), ...
                                obj.EfficiencyCurve(2,:), ...
                                loadFraction, 'pchip');
        end
        
        function power = calculatePower(obj, inletTemp, outletTemp, massFlow)
            % CALCULATEPOWER Calculate power output from thermodynamic parameters
            %
            % Inputs:
            %   inletTemp - Inlet temperature (K)
            %   outletTemp - Outlet temperature (K)
            %   massFlow - Mass flow rate (kg/s)
            % Output: power - Power output (kW)
            
            power = massFlow * obj.CP * (inletTemp - outletTemp) / 1000;
        end
        
        function power = calculatePowerFromPressure(obj, inletTemp, pressureRatio, massFlow, efficiency)
            % CALCULATEPOWERFROMPRESSURE Calculate power from pressure ratio
            %
            % Inputs:
            %   inletTemp - Inlet temperature (K)
            %   pressureRatio - Pressure ratio (P_in/P_out)
            %   massFlow - Mass flow rate (kg/s)
            %   efficiency - Isentropic efficiency (0-1)
            % Output: power - Power output (kW)
            
            % Ideal temperature drop (isentropic)
            tempRatioIdeal = pressureRatio^((obj.GAMMA-1)/obj.GAMMA);
            idealWork = obj.CP * inletTemp * (1 - 1/tempRatioIdeal);
            
            % Actual work with efficiency
            actualWork = efficiency * idealWork;
            
            power = massFlow * actualWork / 1000;
        end
        
        function [power, efficiency] = simulateOperation(obj, inletTemp, pressureRatio, massFlow)
            % SIMULATEOPERATION Simulate turbine operation
            %
            % Inputs:
            %   inletTemp - Inlet temperature (K)
            %   pressureRatio - Pressure ratio
            %   massFlow - Mass flow rate (kg/s)
            % Outputs:
            %   power - Power output (kW)
            %   efficiency - Operating efficiency
            
            % Calculate load fraction
            designPower = obj.calculatePowerFromPressure(inletTemp, ...
                obj.DesignPressureRatio, obj.DesignMassFlow, obj.MaxEfficiency);
            currentDesignPower = obj.calculatePowerFromPressure(inletTemp, ...
                pressureRatio, massFlow, obj.MaxEfficiency);
            
            loadFraction = currentDesignPower / designPower;
            
            % Get efficiency at this load
            efficiency = obj.calculateEfficiency(loadFraction);
            
            % Calculate actual power
            power = obj.calculatePowerFromPressure(inletTemp, pressureRatio, massFlow, efficiency);
        end
        
        function plotEfficiencyCurve(obj)
            % PLOTEFFICIENCYCURVE Plot efficiency vs load curve
            figure;
            plot(obj.EfficiencyCurve(1,:), obj.EfficiencyCurve(2,:), ...
                'b-', 'LineWidth', 2);
            hold on;
            plot(obj.EfficiencyCurve(1,:), obj.EfficiencyCurve(2,:), ...
                'ro', 'MarkerSize', 6);
            
            xlabel('Load Fraction');
            ylabel('Efficiency');
            title(sprintf('Efficiency Curve - %s', obj.Name));
            grid on;
            axis([0.2 1.2 0 obj.MaxEfficiency*1.1]);
            
            % Mark design point
            designLoad = 1.0;
            designEff = interp1(obj.EfficiencyCurve(1,:), ...
                               obj.EfficiencyCurve(2,:), designLoad);
            plot(designLoad, designEff, 'go', 'MarkerSize', 10, ...
                'MarkerFaceColor', 'g');
            
            legend('Efficiency Curve', 'Data Points', 'Design Point', ...
                'Location', 'best');
        end
        
        function displayInfo(obj)
            % DISPLAYINFO Display turbine information
            fprintf('=== Turbine Information ===\n');
            fprintf('Name: %s\n', obj.Name);
            fprintf('Type: %s Turbine\n', obj.TurbineType);
            fprintf('Rated Power: %.1f kW\n', obj.RatedPower);
            fprintf('Maximum Efficiency: %.3f\n', obj.MaxEfficiency);
            fprintf('Design Pressure Ratio: %.2f\n', obj.DesignPressureRatio);
            fprintf('Design Mass Flow: %.2f kg/s\n', obj.DesignMassFlow);
            fprintf('Pressure Ratio Range: [%.1f, %.1f]\n', ...
                obj.PressureRatioRange(1), obj.PressureRatioRange(2));
            fprintf('Speed Range: [%d, %d] RPM\n\n', ...
                obj.SpeedRange(1), obj.SpeedRange(2));
        end
    end
    
    methods (Static)
        function turbine = createSampleTurbine(type)
            % CREATESAMPLETURBINE Create a sample turbine of specified type
            %
            % Input: type - 'Gas', 'Steam', 'Wind', or 'Hydro'
            % Output: turbine - Preconfigured turbine object
            
            switch lower(type)
                case 'gas'
                    turbine = Turbine('IndustrialGasTurbine', 15000, 0.88, ...
                        'TurbineType', 'Gas', ...
                        'DesignPressureRatio', 4.5, ...
                        'DesignMassFlow', 12.5, ...
                        'PressureRatioRange', [2, 6], ...
                        'SpeedRange', [8000, 12000]);
                    
                case 'steam'
                    turbine = Turbine('SteamTurbine', 25000, 0.82, ...
                        'TurbineType', 'Steam', ...
                        'DesignPressureRatio', 8.0, ...
                        'DesignMassFlow', 15.0, ...
                        'PressureRatioRange', [4, 12], ...
                        'SpeedRange', [3000, 3600]);
                    
                case 'wind'
                    turbine = Turbine('WindTurbine', 2000, 0.45, ...
                        'TurbineType', 'Wind', ...
                        'DesignPressureRatio', 1.0, ... % Not applicable
                        'DesignMassFlow', 0, ... % Not applicable
                        'PressureRatioRange', [1, 1], ... % Not applicable
                        'SpeedRange', [10, 25]); % RPM
                    
                case 'hydro'
                    turbine = Turbine('HydroTurbine', 5000, 0.92, ...
                        'TurbineType', 'Hydro', ...
                        'DesignPressureRatio', 1.2, ...
                        'DesignMassFlow', 50.0, ...
                        'PressureRatioRange', [1.1, 1.5], ...
                        'SpeedRange', [150, 300]);
                    
                otherwise
                    error('Unknown turbine type. Use: Gas, Steam, Wind, or Hydro');
            end
        end
    end
end