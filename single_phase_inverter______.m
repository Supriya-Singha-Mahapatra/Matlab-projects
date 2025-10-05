%% Single-Phase Inverter Simulation with Monitoring System
% This script simulates a single-phase inverter with voltage regulation
% and monitoring capabilities

clear all;
close all;
clc;

%% Simulation Parameters
f_sw = 10e3;        % Switching frequency (Hz)
f_out = 50;         % Output frequency (Hz)
V_dc = 400;         % DC input voltage (V)
V_ref = 220;        % Reference RMS output voltage (V)
T_sim = 0.1;        % Simulation time (s)
Ts = 1e-6;          % Simulation step time (s)

%% Inverter Parameters
L_filter = 5e-3;    % Filter inductance (H)
C_filter = 10e-6;   % Filter capacitance (F)
R_load = 25;        % Load resistance (Ω)

%% Control Parameters
Kp = 0.1;           % Proportional gain
Ki = 5;             % Integral gain

%% Initialize Variables
t = 0:Ts:T_sim;
n = length(t);

% Preallocate arrays
V_out = zeros(1, n);
I_out = zeros(1, n);
V_error = zeros(1, n);
V_error_int = zeros(1, n);
mod_index = ones(1, n) * 0.8;  % Modulation index
PWM = zeros(1, n);
V_ab = zeros(1, n);
V_an = zeros(1, n);

%% Main Simulation Loop
for i = 2:n
    % Generate reference sine wave
    ref_wave = mod_index(i-1) * sin(2*pi*f_out*t(i));
    
    % Generate carrier wave (triangle wave)
    carrier = sawtooth(2*pi*f_sw*t(i), 0.5);
    
    % PWM generation (unipolar)
    if ref_wave > carrier
        PWM(i) = 1;
        V_ab(i) = V_dc;
    elseif -ref_wave > carrier
        PWM(i) = -1;
        V_ab(i) = -V_dc;
    else
        PWM(i) = 0;
        V_ab(i) = 0;
    end
    
    % Calculate output voltage using simple filter model
    % (This is a simplified model for simulation purposes)
    dt = Ts;
    if i > 1
        I_out(i) = I_out(i-1) + (V_ab(i) - V_out(i-1)) * dt / L_filter;
        V_out(i) = V_out(i-1) + (I_out(i) - V_out(i-1)/R_load) * dt / C_filter;
    end
    
    % Voltage regulation (PI controller)
    V_error(i) = V_ref - rms(V_out(1:i));
    V_error_int(i) = V_error_int(i-1) + V_error(i) * dt;
    
    % Update modulation index with anti-windup
    if mod_index(i-1) >= 1 && V_error_int(i) > 0
        V_error_int(i) = V_error_int(i-1); % Anti-windup
    elseif mod_index(i-1) <= 0.1 && V_error_int(i) < 0
        V_error_int(i) = V_error_int(i-1); % Anti-windup
    end
    
    mod_index(i) = mod_index(i-1) + Kp * (V_error(i) - V_error(i-1)) + Ki * V_error_int(i) * dt;
    
    % Limit modulation index between 0.1 and 1.0
    mod_index(i) = max(0.1, min(1.0, mod_index(i)));
end

%% Calculate RMS values
V_out_rms = rms(V_out);
I_out_rms = rms(I_out);
P_out = V_out_rms * I_out_rms;

%% Display Results
fprintf('Single-Phase Inverter Simulation Results:\n');
fprintf('-----------------------------------------\n');
fprintf('Output Voltage RMS: %.2f V (Reference: %.2f V)\n', V_out_rms, V_ref);
fprintf('Output Current RMS: %.2f A\n', I_out_rms);
fprintf('Output Power: %.2f W\n', P_out);
fprintf('Voltage Regulation Error: %.2f%%\n', abs(V_out_rms - V_ref)/V_ref*100);

%% Plot Results
figure('Position', [100, 100, 1200, 800]);

% Subplot 1: Output Voltage and Current
subplot(3, 2, 1);
plot(t, V_out, 'b', 'LineWidth', 1.5);
hold on;
plot(t, I_out*50, 'r', 'LineWidth', 1.5); % Scaled for better visualization
title('Output Voltage and Current');
xlabel('Time (s)');
ylabel('Voltage (V) / Current (A)');
legend('Voltage (V)', 'Current x50 (A)');
grid on;

% Subplot 2: PWM Signal and Carrier
subplot(3, 2, 2);
plot(t(1:1000), PWM(1:1000), 'r', 'LineWidth', 1.5);
hold on;
plot(t(1:1000), mod_index(1:1000).*sin(2*pi*f_out*t(1:1000)), 'b', 'LineWidth', 1.5);
carrier_plot = sawtooth(2*pi*f_sw*t(1:1000), 0.5);
plot(t(1:1000), carrier_plot, 'g', 'LineWidth', 1);
title('PWM Modulation (Zoomed)');
xlabel('Time (s)');
ylabel('Amplitude');
legend('PWM', 'Reference', 'Carrier');
grid on;
xlim([0, 1/f_sw*10]);

% Subplot 3: Modulation Index
subplot(3, 2, 3);
plot(t, mod_index, 'LineWidth', 1.5);
title('Modulation Index');
xlabel('Time (s)');
ylabel('Index');
grid on;

% Subplot 4: Voltage Error
subplot(3, 2, 4);
plot(t, V_error, 'LineWidth', 1.5);
title('Voltage Regulation Error');
xlabel('Time (s)');
ylabel('Error (V)');
grid on;

% Subplot 5: FFT Analysis of Output Voltage
subplot(3, 2, 5);
N = length(V_out);
Y = fft(V_out);
P2 = abs(Y/N);
P1 = P2(1:N/2+1);
P1(2:end-1) = 2*P1(2:end-1);
f = (0:(N/2))/N/Ts;
plot(f, P1, 'LineWidth', 1.5);
title('FFT of Output Voltage');
xlabel('Frequency (Hz)');
ylabel('|V(f)|');
xlim([0, 5*f_sw]);
grid on;

% Subplot 6: Output Power
subplot(3, 2, 6);
instant_power = V_out .* I_out;
plot(t, instant_power, 'LineWidth', 1.5);
title('Output Power');
xlabel('Time (s)');
ylabel('Power (W)');
grid on;

%% Monitoring System Simulation
fprintf('\nMonitoring System Status:\n');
fprintf('-----------------------------------------\n');

% Check for overvoltage
if max(abs(V_out)) > 1.2 * V_ref * sqrt(2)
    fprintf('WARNING: Overvoltage detected!\n');
else
    fprintf('Voltage levels: NORMAL\n');
end

% Check for overload
if max(abs(I_out)) > 15
    fprintf('WARNING: Overcurrent detected!\n');
else
    fprintf('Current levels: NORMAL\n');
end

% Check temperature (simulated)
inverter_temp = 45 + 20 * (P_out / 2000); % Simple temperature model
fprintf('Simulated Inverter Temperature: %.1f°C\n', inverter_temp);
if inverter_temp > 85
    fprintf('WARNING: High temperature detected!\n');
elseif inverter_temp > 70
    fprintf('CAUTION: Temperature approaching limits\n');
else
    fprintf('Temperature: NORMAL\n');
end

% Check efficiency
P_in = V_dc * mean(abs(I_out)) * 0.95; % Approximate input power
efficiency = P_out / P_in * 100;
fprintf('Estimated Efficiency: %.1f%%\n', efficiency);

% Maintenance indicator
operating_hours = 2500; % Simulated operating hours
fprintf('Simulated Operating Hours: %d\n', operating_hours);
if operating_hours > 10000
    fprintf('MAINTENANCE REQUIRED: Capacitor aging likely\n');
elseif operating_hours > 5000
    fprintf('MAINTENANCE ADVISORY: Schedule inspection soon\n');
else
    fprintf('Maintenance status: OK\n');
end