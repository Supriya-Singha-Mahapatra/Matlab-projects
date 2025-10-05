function HVDC_System_Designer
    % Create main figure
    fig = figure('Name', 'HVDC System Designer', 'Position', [100, 100, 900, 600], 'NumberTitle', 'off');
    
    % Create tabs
    tabgroup = uitabgroup('Parent', fig, 'Position', [0, 0, 1, 0.95]);
    design_tab = uitab('Parent', tabgroup, 'Title', 'Design');
    simulation_tab = uitab('Parent', tabgroup, 'Title', 'Simulation');
    results_tab = uitab('Parent', tabgroup, 'Title', 'Results');
    
    % Design tab components
    uicontrol('Parent', design_tab, 'Style', 'text', 'String', 'Voltage (kV):', 'Position', [50, 450, 100, 20]);
    voltage_edit = uicontrol('Parent', design_tab, 'Style', 'edit', 'String', '500', 'Position', [160, 450, 100, 25]);
    
    uicontrol('Parent', design_tab, 'Style', 'text', 'String', 'Power (MW):', 'Position', [50, 400, 100, 20]);
    power_edit = uicontrol('Parent', design_tab, 'Style', 'edit', 'String', '1000', 'Position', [160, 400, 100, 25]);
    
    uicontrol('Parent', design_tab, 'Style', 'text', 'String', 'Distance (km):', 'Position', [50, 350, 100, 20]);
    distance_edit = uicontrol('Parent', design_tab, 'Style', 'edit', 'String', '500', 'Position', [160, 350, 100, 25]);
    
    uicontrol('Parent', design_tab, 'Style', 'text', 'String', 'Cable Type:', 'Position', [50, 300, 100, 20]);
    cable_dropdown = uicontrol('Parent', design_tab, 'Style', 'popupmenu', 'String', {'Overhead Line', 'Submarine Cable', 'Underground Cable'}, 'Position', [160, 300, 100, 25]);
    
    design_button = uicontrol('Parent', design_tab, 'Style', 'pushbutton', 'String', 'Design System', 'Position', [100, 200, 100, 30], 'Callback', @design_system);
    
    % Axes for system diagram
    ax = axes('Parent', design_tab, 'Position', [0.4, 0.1, 0.55, 0.8]);
    
    % Simulation tab components
    uicontrol('Parent', simulation_tab, 'Style', 'text', 'String', 'Simulation Time (s):', 'Position', [50, 450, 120, 20]);
    time_slider = uicontrol('Parent', simulation_tab, 'Style', 'slider', 'Min', 1, 'Max', 10, 'Value', 5, 'Position', [180, 450, 200, 20]);
    
    simulate_button = uicontrol('Parent', simulation_tab, 'Style', 'pushbutton', 'String', 'Simulate', 'Position', [100, 400, 100, 30], 'Callback', @simulate_system);
    
    sim_ax1 = axes('Parent', simulation_tab, 'Position', [0.1, 0.1, 0.8, 0.3]);
    sim_ax2 = axes('Parent', simulation_tab, 'Position', [0.1, 0.5, 0.8, 0.3]);
    
    % Results tab components
    results_text = uicontrol('Parent', results_tab, 'Style', 'edit', 'Max', 10, 'Min', 1, 'String', 'Simulation results will appear here after running simulation.', 'Position', [50, 200, 500, 200], 'HorizontalAlignment', 'left');
    
    export_button = uicontrol('Parent', results_tab, 'Style', 'pushbutton', 'String', 'Export Results', 'Position', [50, 100, 100, 30], 'Callback', @export_results);
    
    % Status label
    status_label = uicontrol('Parent', fig, 'Style', 'text', 'String', 'Status: Ready', 'Position', [20, 5, 500, 20], 'HorizontalAlignment', 'left');
    
    % Store data
    system_data = struct();
    simulation_results = struct();
    
    % Callback functions
    function design_system(~, ~)
        system_data.voltage = str2double(get(voltage_edit, 'String'));
        system_data.power = str2double(get(power_edit, 'String'));
        system_data.distance = str2double(get(distance_edit, 'String'));
        cable_types = get(cable_dropdown, 'String');
        system_data.cableType = cable_types{get(cable_dropdown, 'Value')};
        
        % Update system diagram
        update_system_diagram(ax, system_data);
        set(status_label, 'String', 'System designed successfully. Click "Simulate" to run simulation.');
    end

    function simulate_system(~, ~)
        set(status_label, 'String', 'Running simulation...');
        drawnow;
        
        % Simple simulation
        t = 0:0.01:get(time_slider, 'Value');
        Vdc = system_data.voltage * 1000;
        Pdc = system_data.power * 1e6;
        Idc = Pdc / Vdc;
        
        % Cable parameters
        switch system_data.cableType
            case 'Overhead Line'
                R = 0.01 * system_data.distance;
            case 'Submarine Cable'
                R = 0.02 * system_data.distance;
            case 'Underground Cable'
                R = 0.015 * system_data.distance;
        end
        
        % Simulate voltage and current
        V_sending = Vdc * ones(size(t));
        V_receiving = V_sending - Idc * R * (1 + 0.1 * sin(2*pi*0.5*t));
        I_dc = Idc * ones(size(t)) .* (1 + 0.05 * randn(size(t)));
        
        % Store results
        simulation_results.time = t;
        simulation_results.V_sending = V_sending;
        simulation_results.V_receiving = V_receiving;
        simulation_results.I_dc = I_dc;
        simulation_results.P_loss = Idc^2 * R;
        simulation_results.efficiency = (V_receiving(end) * I_dc(end)) / (V_sending(end) * I_dc(end)) * 100;
        
        % Update results text
        result_str = {
            'HVDC System Simulation Results:',
            sprintf('Transmission Distance: %d km', system_data.distance),
            sprintf('DC Voltage: %d kV', system_data.voltage),
            sprintf('DC Power: %d MW', system_data.power),
            sprintf('DC Current: %.1f A', Idc),
            sprintf('Resistance: %.2f Ω', R),
            sprintf('Power Loss: %.2f MW', simulation_results.P_loss/1e6),
            sprintf('Efficiency: %.2f%%', simulation_results.efficiency)
        };
        set(results_text, 'String', result_str);
        
        % Plot results
        plot(sim_ax1, t, V_sending/1000, 'b', 'LineWidth', 1.5);
        hold(sim_ax1, 'on');
        plot(sim_ax1, t, V_receiving/1000, 'r', 'LineWidth', 1.5);
        ylabel(sim_ax1, 'Voltage (kV)');
        legend(sim_ax1, 'Sending End', 'Receiving End');
        title(sim_ax1, 'HVDC System Simulation');
        grid(sim_ax1, 'on');
        hold(sim_ax1, 'off');
        
        plot(sim_ax2, t, I_dc, 'g', 'LineWidth', 1.5);
        ylabel(sim_ax2, 'Current (A)');
        xlabel(sim_ax2, 'Time (s)');
        grid(sim_ax2, 'on');
        
        set(status_label, 'String', 'Simulation completed successfully.');
    end

    function export_results(~, ~)
        assignin('base', 'HVDC_System_Data', system_data);
        assignin('base', 'HVDC_Simulation_Results', simulation_results);
        set(status_label, 'String', 'Data exported to workspace.');
    end

    % Initialize with default diagram
    system_data.voltage = 500;
    system_data.power = 1000;
    system_data.distance = 500;
    system_data.cableType = 'Overhead Line';
    update_system_diagram(ax, system_data);
end

function update_system_diagram(ax, system_data)
    cla(ax);
    hold(ax, 'on');
    
    % Draw sending end (rectifier)
    rectangle(ax, 'Position', [50, 150, 100, 100], 'Curvature', 0.2, 'FaceColor', [0.9 0.9 0.9]);
    text(ax, 100, 200, 'Rectifier', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    % Draw receiving end (inverter)
    rectangle(ax, 'Position', [450, 150, 100, 100], 'Curvature', 0.2, 'FaceColor', [0.9 0.9 0.9]);
    text(ax, 500, 200, 'Inverter', 'HorizontalAlignment', 'center', 'FontWeight', 'bold');
    
    % Draw DC transmission line
    plot(ax, [150, 450], [200, 200], 'k', 'LineWidth', 3);
    plot(ax, [150, 450], [190, 190], 'k--', 'LineWidth', 1);
    
    % Add labels for parameters
    text(ax, 100, 130, sprintf('Voltage: %d kV', system_data.voltage), 'HorizontalAlignment', 'center');
    text(ax, 100, 110, sprintf('Power: %d MW', system_data.power), 'HorizontalAlignment', 'center');
    text(ax, 300, 220, sprintf('Distance: %d km', system_data.distance), 'HorizontalAlignment', 'center');
    text(ax, 300, 170, sprintf('Cable: %s', system_data.cableType), 'HorizontalAlignment', 'center');
    
    hold(ax, 'off');
    axis(ax, 'equal');
    axis(ax, [0 600 0 300]);
    ax.XAxis.Visible = 'off';
    ax.YAxis.Visible = 'off';
    ax.Box = 'on';
end