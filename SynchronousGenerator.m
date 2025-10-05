classdef SynchronousGenerator < handle
    properties
        % Electrical Parameters
        Rated_Power          % Rated power (VA)
        Rated_Voltage        % Rated voltage (V)
        Rated_Frequency      % Rated frequency (Hz)
        Poles                % Number of poles
        
        % Stator Parameters
        Rs                   % Stator resistance (ohm)
        Xd                   % d-axis synchronous reactance (ohm)
        Xq                   % q-axis synchronous reactance (ohm)
        Xd_prime             % d-axis transient reactance (ohm)
        Xq_prime             % q-axis transient reactance (ohm)
        Xd_double_prime      % d-axis subtransient reactance (ohm)
        Xq_double_prime      % q-axis subtransient reactance (ohm)
        
        % Time Constants
        Tdo_prime            % d-axis open circuit transient time constant (s)
        Tqo_prime            % q-axis open circuit transient time constant (s)
        Tdo_double_prime     % d-axis open circuit subtransient time constant (s)
        Tqo_double_prime     % q-axis open circuit subtransient time constant (s)
        
        % Inertia Parameters
        H                    % Inertia constant (s)
        D                    % Damping coefficient
        
        % Operating Conditions
        Field_Voltage        % Field voltage
        Mechanical_Torque    % Mechanical torque input
        Theta                % Rotor angle (rad)
        Omega                % Rotor speed (rad/s)
        
        % Internal States
        Id                   % d-axis current
        Iq                   % q-axis current
        Vd                   % d-axis voltage
        Vq                   % q-axis voltage
        Ed_prime             % d-axis transient voltage
        Eq_prime             % q-axis transient voltage
    end
    
    methods
        function obj = SynchronousGenerator(parameters)
            % Constructor - Initialize generator parameters
            if nargin > 0
                obj.Rated_Power = parameters.Rated_Power;
                obj.Rated_Voltage = parameters.Rated_Voltage;
                obj.Rated_Frequency = parameters.Rated_Frequency;
                obj.Poles = parameters.Poles;
                obj.Rs = parameters.Rs;
                obj.Xd = parameters.Xd;
                obj.Xq = parameters.Xq;
                obj.Xd_prime = parameters.Xd_prime;
                obj.Xq_prime = parameters.Xq_prime;
                obj.Xd_double_prime = parameters.Xd_double_prime;
                obj.Xq_double_prime = parameters.Xq_double_prime;
                obj.Tdo_prime = parameters.Tdo_prime;
                obj.Tqo_prime = parameters.Tqo_prime;
                obj.Tdo_double_prime = parameters.Tdo_double_prime;
                obj.Tqo_double_prime = parameters.Tqo_double_prime;
                obj.H = parameters.H;
                obj.D = parameters.D;
            else
                % Default parameters (typical values)
                obj.setDefaultParameters();
            end
            
            % Initialize operating conditions
            obj.Field_Voltage = 1.0;
            obj.Mechanical_Torque = 0.8;
            obj.Theta = 0;
            obj.Omega = 2*pi*obj.Rated_Frequency;
        end
        
        function setDefaultParameters(obj)
            % Set default parameters for a typical synchronous generator
            obj.Rated_Power = 100e6;          % 100 MVA
            obj.Rated_Voltage = 13.8e3;       % 13.8 kV
            obj.Rated_Frequency = 60;         % 60 Hz
            obj.Poles = 4;                    % 4 poles
            
            % Per unit parameters (base: generator rating)
            obj.Rs = 0.003;                   % Stator resistance
            obj.Xd = 1.8;                     % d-axis sync reactance
            obj.Xq = 1.7;                     % q-axis sync reactance
            obj.Xd_prime = 0.3;               % d-axis transient reactance
            obj.Xq_prime = 0.55;              % q-axis transient reactance
            obj.Xd_double_prime = 0.25;       % d-axis subtransient reactance
            obj.Xq_double_prime = 0.25;       % q-axis subtransient reactance
            
            obj.Tdo_prime = 5.0;              % d-axis transient time constant
            obj.Tqo_prime = 0.8;              % q-axis transient time constant
            obj.Tdo_double_prime = 0.03;      % d-axis subtransient time constant
            obj.Tqo_double_prime = 0.04;      % q-axis subtransient time constant
            
            obj.H = 3.0;                      % Inertia constant (seconds)
            obj.D = 2.0;                      % Damping coefficient
        end
        
        function [V_abc, I_abc] = calculateSteadyState(obj, P, Q, V_terminal)
            % Calculate steady-state operating conditions
            % Inputs: P (active power), Q (reactive power), V_terminal
            
            S = complex(P, Q);
            I_phasor = conj(S / V_terminal);
            
            % Convert to dq reference frame
            delta = angle(V_terminal) + atan2(real(I_phasor)*obj.Xq, ...
                     abs(V_terminal) + real(I_phasor)*obj.Rs + imag(I_phasor)*obj.Xq);
            
            Vd = abs(V_terminal) * sin(delta - angle(V_terminal));
            Vq = abs(V_terminal) * cos(delta - angle(V_terminal));
            
            Id = (Vq - abs(V_terminal)*cos(delta)) / obj.Xd;
            Iq = (abs(V_terminal)*sin(delta) - Vd) / obj.Xq;
            
            % Calculate field voltage
            Ef = Vq + obj.Rs*Iq + obj.Xd*Id;
            
            obj.Vd = Vd; obj.Vq = Vq;
            obj.Id = Id; obj.Iq = Iq;
            obj.Field_Voltage = Ef;
            obj.Theta = delta;
            
            % Convert back to abc coordinates
            V_abc = obj.dq2abc([Vd; Vq], delta);
            I_abc = obj.dq2abc([Id; Iq], delta);
        end
        
        function [dstates, electrical_torque] = dynamics(obj, t, states, V_terminal, mech_torque)
            % Dynamic model of synchronous generator (6th order)
            % States: [delta, omega, Ed', Eq', Ed'', Eq'']
            
            delta = states(1);
            omega = states(2);
            Ed_prime = states(3);
            Eq_prime = states(4);
            Ed_double_prime = states(5);
            Eq_double_prime = states(6);
            
            % Convert terminal voltage to dq frame
            V_dq = obj.abc2dq(V_terminal, delta);
            Vd = V_dq(1); Vq = V_dq(2);
            
            % Calculate currents
            Xl_val = obj.Xl();
            Id = (Vd - Ed_double_prime + (obj.Xq_double_prime - obj.Xq_prime)*...
                 (Vq - Eq_double_prime)/(obj.Xq_double_prime - Xl_val)) / ...
                 (obj.Xd_double_prime - (obj.Xd_double_prime - obj.Xd_prime)^2/...
                 (obj.Xd_double_prime - Xl_val));
            
            Iq = (Vq - Eq_double_prime) / (obj.Xq_double_prime - Xl_val);
            
            % Electrical torque
            electrical_torque = Vd*Id + Vq*Iq + (obj.Xq - obj.Xd)*Id*Iq;
            
            % Swing equation
            d_delta = omega - 1.0;  % pu speed deviation
            d_omega = (mech_torque - electrical_torque - obj.D*d_delta) / (2*obj.H);
            
            % Flux decay equations
            d_Ed_prime = (-Ed_prime - (obj.Xq - obj.Xq_prime)*Iq) / obj.Tqo_prime;
            d_Eq_prime = (obj.Field_Voltage - Eq_prime + (obj.Xd - obj.Xd_prime)*Id) / obj.Tdo_prime;
            
            % Subtransient equations
            d_Ed_double_prime = (-Ed_double_prime + Ed_prime - ...
                                (obj.Xq_prime - Xl_val)*Iq) / obj.Tqo_double_prime;
            d_Eq_double_prime = (-Eq_double_prime + Eq_prime + ...
                                (obj.Xd_prime - Xl_val)*Id) / obj.Tdo_double_prime;
            
            dstates = [d_delta; d_omega; d_Ed_prime; d_Eq_prime; ...
                      d_Ed_double_prime; d_Eq_double_prime];
        end
        
        function Xl = Xl(obj)
            % Leakage reactance (approximation)
            Xl = 0.15 * min(obj.Xd_double_prime, obj.Xq_double_prime);
        end
        
        function dq = abc2dq(obj, abc, theta)
            % Convert ABC to DQ reference frame
            T = 2/3 * [cos(theta), cos(theta-2*pi/3), cos(theta+2*pi/3);
                       -sin(theta), -sin(theta-2*pi/3), -sin(theta+2*pi/3)];
            dq = T * abc;
        end
        
        function abc = dq2abc(obj, dq, theta)
            % Convert DQ to ABC reference frame
            T_inv = [cos(theta), -sin(theta);
                     cos(theta-2*pi/3), -sin(theta-2*pi/3);
                     cos(theta+2*pi/3), -sin(theta+2*pi/3)];
            abc = T_inv * dq;
        end
        
        function displayParameters(obj)
            % Display all generator parameters
            fprintf('\n=== Synchronous Generator Parameters ===\n');
            fprintf('Rated Power: %.1f MVA\n', obj.Rated_Power/1e6);
            fprintf('Rated Voltage: %.1f kV\n', obj.Rated_Voltage/1e3);
            fprintf('Rated Frequency: %.1f Hz\n', obj.Rated_Frequency);
            fprintf('Number of Poles: %d\n', obj.Poles);
            
            fprintf('\n--- Reactance Parameters (pu) ---\n');
            fprintf('Xd = %.3f, Xq = %.3f\n', obj.Xd, obj.Xq);
            fprintf("Xd' = %.3f, Xq' = %.3f\n", obj.Xd_prime, obj.Xq_prime);
            fprintf("Xd'' = %.3f, Xq'' = %.3f\n", obj.Xd_double_prime, obj.Xq_double_prime);
            fprintf('Rs = %.4f\n', obj.Rs);
            
            fprintf('\n--- Time Constants (s) ---\n');
            fprintf("Tdo' = %.3f, Tqo' = %.3f\n", obj.Tdo_prime, obj.Tqo_prime);
            fprintf("Tdo'' = %.3f, Tqo'' = %.3f\n", obj.Tdo_double_prime, obj.Tqo_double_prime);
            
            fprintf('\n--- Mechanical Parameters ---\n');
            fprintf('Inertia Constant H = %.2f s\n', obj.H);
            fprintf('Damping Coefficient D = %.2f\n', obj.D);
        end
    end
end