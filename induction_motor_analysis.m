function induction_motor_analysis()
    % Induction Motor Parameters (typical 4-pole, 50Hz motor)
    V_rated = 400;          % Rated voltage (V)
    f = 50;                 % Frequency (Hz)
    P = 4;                  % Number of poles
    R1 = 0.2;               % Stator resistance (Ω)
    R2 = 0.15;              % Rotor resistance referred to stator (Ω)
    X1 = 0.4;               % Stator reactance (Ω)
    X2 = 0.4;               % Rotor reactance referred to stator (Ω)
    Xm = 15;                % Magnetizing reactance (Ω)
    
    % Slip range (from no-load to standstill)
    s = linspace(0.001, 1, 1000); % Slip values
    
    % Calculate performance parameters
    [T, I, P_out, efficiency, power_factor] = calculate_performance(V_rated, f, P, R1, R2, X1, X2, Xm, s);
    
    % Plot results
    plot_results(s, T, I, P_out, efficiency, power_factor);
end

function [T, I, P_out, efficiency, power_factor] = calculate_performance(V, f, P, R1, R2, X1, X2, Xm, s)
    % Calculate synchronous speed
    ns = 120 * f / P;       % Synchronous speed (RPM)
    ws = 2 * pi * ns / 60;  % Synchronous speed (rad/s)
    
    % Initialize arrays
    T = zeros(size(s));
    I = zeros(size(s));
    P_out = zeros(size(s));
    efficiency = zeros(size(s));
    power_factor = zeros(size(s));
    
    for i = 1:length(s)
        % Positive sequence impedance calculation
        Z2 = R2/s(i) + 1j*X2;      % Rotor impedance
        Zm = 1j*Xm;                % Magnetizing impedance
        Z_parallel = (Zm * Z2) / (Zm + Z2); % Parallel combination
        Z_total = R1 + 1j*X1 + Z_parallel; % Total impedance
        
        % Current calculation
        I(i) = V / abs(Z_total);
        
        % Power factor
        power_factor(i) = cos(angle(Z_total));
        
        % Torque calculation
        I2 = I(i) * abs(Zm / (Zm + Z2)); % Rotor current
        T(i) = (3 * I2^2 * R2 / s(i)) / ws;
        
        % Output power
        P_out(i) = T(i) * ws * (1 - s(i));
        
        % Input power
        P_in = 3 * V * I(i) * power_factor(i);
        
        % Efficiency
        efficiency(i) = (P_out(i) / P_in) * 100;
    end
end

function plot_results(s, T, I, P_out, efficiency, power_factor)
    figure('Position', [100, 100, 1200, 800]);
    
    % Torque vs Slip
    subplot(2,2,1);
    plot(s, T, 'b-', 'LineWidth', 2);
    xlabel('Slip');
    ylabel('Torque (Nm)');
    title('Torque vs Slip');
    grid on;
    
    % Current vs Slip
    subplot(2,2,2);
    plot(s, I, 'r-', 'LineWidth', 2);
    xlabel('Slip');
    ylabel('Current (A)');
    title('Stator Current vs Slip');
    grid on;
    
    % Efficiency vs Slip
    subplot(2,2,3);
    plot(s, efficiency, 'g-', 'LineWidth', 2);
    xlabel('Slip');
    ylabel('Efficiency (%)');
    title('Efficiency vs Slip');
    grid on;
    
    % Power Factor vs Slip
    subplot(2,2,4);
    plot(s, power_factor, 'm-', 'LineWidth', 2);
    xlabel('Slip');
    ylabel('Power Factor');
    title('Power Factor vs Slip');
    grid on;
end