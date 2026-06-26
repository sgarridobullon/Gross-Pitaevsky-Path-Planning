% =========================================================================
% COMPLETE: GPE Quantum Swarm Navigation (Cinematic Smooth + Slow Target Edition)
% Cluttered Environment Strategy with Dynamically Moving Goal & Dual Figures
% =========================================================================
clear; clc; close all;

%% 1. Grid & Environment Setup
N = 200;                
L = 100;%<-------------------------                 
x = linspace(-L/2, L/2, N);
y = linspace(-L/2, L/2, N);
dx = x(2) - x(1);
dy = y(2) - y(1);
[X, Y] = meshgrid(x, y);
kx = (2*pi/L) * [0:N/2-1, -N/2:-1]; 
[KX, KY] = meshgrid(kx, kx);
K2 = KX.^2 + KY.^2;     

%% 2. Physics & Swarm Parameters (OPTIMIZED FOR SMOOTHNESS)
hbar = 1;               
m = 1;                  
g = 55.0;               
dt_wave = 0.005;        
dt_drone = 0.05;        
density_thresh = 1e-3;  
arrival_radius = 0.8;   

% --- OPTIMIZED SMOOTHING TUNERS ---
max_total_v = 6.0;      
max_force = 4.5;        
drone_inertia = 0.92;   
k_rep_obs = 140.0;      
classical_speed = 3.0;  
quantum_gain = 3.5;     

% --- SWARM SEPARATION TUNERS ---
k_rep_drone = 35.0;     
d_drone = 1.40;         

%% 3. Narrow Passage, Center Drone Setup & Moving Goal Definitions
start_x = -10; start_y = -10;
obs_amp = 700;
V_room = zeros(N, N);

% Vertical divider walls at x = 0 creating a central corridor gap
wall_y_top = 3.5:1.2:12;       
wall_y_bottom = -12:1.2:-2.5;   
center_drone_coords = [0, 0]; 
clutter_centers = [ ...
    zeros(length(wall_y_top), 1), wall_y_top'; ...
    zeros(length(wall_y_bottom), 1), wall_y_bottom'; ...
    center_drone_coords ... 
];
clutter_radius = 0.45; 
for k = 1:size(clutter_centers, 1)
    cx = clutter_centers(k, 1);
    cy = clutter_centers(k, 2);
    V_room = V_room + obs_amp * exp(-((X - cx).^2 + (Y - cy).^2) / (2 * clutter_radius^2));
end
V_bound = 120 * (abs(X) > L/2 - 2) + 120 * (abs(Y) > L/2 - 2);

% --- INITIAL SWARM DEFINITION ---
num_drones = 1; 
drones = [start_x + randn(num_drones,1)*0.7, start_y + randn(num_drones,1)*0.7];
drone_vel = zeros(num_drones, 2); 
max_trail_len = 20;
trail_hist_x = repmat(drones(:,1), 1, max_trail_len);
trail_hist_y = repmat(drones(:,2), 1, max_trail_len);

% Telemetry metrics logging arrays
max_steps = 2800;
time_hist = 1:max_steps;
min_drone_dist_hist = NaN(1, max_steps);
min_obs_dist_hist = NaN(1, max_steps);

% Initialize Wave Function centered on starting drone swarm location
psi = exp(-((X - start_x).^2 + (Y - start_y).^2) / 4.0);
psi = 0.0*psi / sqrt(trapz(y, trapz(x, abs(psi).^2, 2)));

%% 4. Separate Windows Canvas Initialization
% --- FIGURE 1: Arena Flight Tracker Display ---
figArena = figure('Name', 'GPE Control Center: Dynamic Track Mode', 'Color', 'w', 'Position', [50, 400, 1100, 500]);
% Subplot 1: Density Field
ax1 = subplot(1, 2, 1);
density_plot = imagesc(x, y, abs(psi).^2);
set(ax1, 'YDir', 'normal', 'Layer', 'top'); hold on; axis equal; xlim([-13 13]); ylim([-13 13]);
colormap(ax1, flipud(parula)); colorbar(ax1);
grid(ax1, 'on'); ax1.GridColor = 'w'; ax1.GridAlpha = 0.15;
title('Arena Flight Space: Density Projection', 'FontSize', 11, 'FontWeight', 'bold');
for k = 1:size(clutter_centers, 1)
    if all(clutter_centers(k, :) == [0, 0])
        rectangle('Position', [clutter_centers(k,1)-clutter_radius, clutter_centers(k,2)-clutter_radius, clutter_radius*2, clutter_radius*2], ...
                  'Curvature', [1 1], 'FaceColor', [0.63 0.08 0.18], 'EdgeColor', 'w', 'LineWidth', 1, 'Parent', ax1);
    else
        rectangle('Position', [clutter_centers(k,1)-clutter_radius, clutter_centers(k,2)-clutter_radius, clutter_radius*2, clutter_radius*2], ...
                  'Curvature', [1 1], 'FaceColor', [0.15 0.15 0.18], 'EdgeColor', 'none', 'Parent', ax1);
    end
end
trail_plots = plot(NaN, NaN, 'Color', [0.93 0.69 0.13 0.35], 'LineWidth', 1.1, 'Parent', ax1); 
goal_p1 = plot(NaN, NaN, 'gp', 'MarkerSize', 14, 'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k');
drone_p1 = plot(drones(:,1), drones(:,2), 'wo', 'MarkerSize', 5.0, 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'w');

% Subplot 2: Phase Map & Vectors
ax2 = subplot(1, 2, 2);
phase_plot = imagesc(x, y, angle(psi));
set(ax2, 'YDir', 'normal', 'Layer', 'top'); hold on; axis equal; xlim([-13 13]); ylim([-13 13]);
colormap(ax2, hsv); colorbar(ax2);
grid(ax2, 'on'); ax2.GridColor = 'k'; ax2.GridAlpha = 0.1;
title('Velocity Flows & Phase Gradient', 'FontSize', 11, 'FontWeight', 'bold');
contour(ax2, X, Y, V_room, [150 150], 'LineColor', [0.3 0.3 0.3], 'LineWidth', 1.5);
q_skip = 6; 
X_q = X(1:q_skip:end, 1:q_skip:end); Y_q = Y(1:q_skip:end, 1:q_skip:end);
quiver_plot = quiver(X_q, Y_q, zeros(size(X_q)), zeros(size(X_q)), 1.2, 'w', 'LineWidth', 0.8, 'Parent', ax2);
goal_p2 = plot(NaN, NaN, 'kp', 'MarkerSize', 12, 'MarkerFaceColor', 'w', 'MarkerEdgeColor', 'k');
drone_p2 = plot(drones(:,1), drones(:,2), 'ko', 'MarkerSize', 4.0, 'MarkerFaceColor', 'k', 'MarkerEdgeColor', 'w');

% --- FIGURE 2: Safety Telemetry Dashboard ---
figTelemetry = figure('Name', 'GPE Control Center: Safety Telemetry Dashboard', 'Color', 'w', 'Position', [50, 50, 1100, 300]);
ax3 = axes('Parent', figTelemetry);
hold(ax3, 'on'); grid(ax3, 'on'); box(ax3, 'on');
xlim(ax3, [0 max_steps]); ylim(ax3, [0 5.0]);
xlabel(ax3, 'Timeline Frame (t)'); ylabel(ax3, 'Clearance Distance (meters)');
title(ax3, 'Real-time Distance Profiler (Inter-drone & Obstacle Proximity)', 'FontSize', 11, 'FontWeight', 'bold');
line_drone = plot(ax3, time_hist, min_drone_dist_hist, 'Color', [0.85 0.33 0.1], 'LineWidth', 1.6, 'DisplayName', 'Minimum Inter-Drone Separation');
line_obs   = plot(ax3, time_hist, min_obs_dist_hist, 'Color', [0 0.45 0.74], 'LineWidth', 1.6, 'DisplayName', 'Minimum Obstacle Clearance');
yline(ax3, d_drone, '--r', 'Drone Threshold Boundary', 'LineWidth', 1.2, 'LabelHorizontalAlignment', 'right');
legend(ax3, 'Location', 'northeast');

%% 5. Main Simulation Loop
for t = 1:max_steps
    
    % --- DYNAMIC DRONE INJECTION MECHANISM ---
    if mod(t, 100) == 0
        num_drones = num_drones + 1;
        
        % Spawn a new drone back near the home launch point (-10, -8)
        new_spawn = [start_x + randn()*0.3, start_y + randn()*0.3];
        drones = [drones; new_spawn];
        
        % Initialize new row vectors tracking state for the new drone
        drone_vel = [drone_vel; 0, 0];
        trail_hist_x = [trail_hist_x; repmat(new_spawn(1), 1, max_trail_len)];
        trail_hist_y = [trail_hist_y; repmat(new_spawn(2), 1, max_trail_len)];
    end
    
    % --- A. Update Dynamic Target Mechanics (Lissajous Exploration Vector) ---
    % SLOWED: Lower time coefficients reduce target sweeping speed across the canvas
    goal_x = 9.5 * sin(0.007 * t + 0.3);
    goal_y = 8.5 * sin(0.00 * t);
    
    % --- B. Quantum Guide Potential Mapping ---
    V_target_well = -15.0 * exp(-((X - goal_x).^2 + (Y - goal_y).^2) / 18.0);
    V = V_room + V_target_well - 1i * V_bound; 
    
    % --- C. Wave Evolution Split Step Implementation ---
    density = abs(psi).^2;
    psi = psi .* exp(-1i * (V + g * density) * (dt_wave / 2) / hbar);
    
    psi_k = fft2(psi);
    psi_k = psi_k .* exp(-1i * (hbar^2 / (2*m)) * K2 * dt_wave / hbar);
    psi = ifft2(psi_k);
    
    density = abs(psi).^2;
    psi = psi .* exp(-1i * (V + g * density) * (dt_wave / 2) / hbar);
    
    % --- D. Phase Flow Extractions ---
    [dpsi_dx, dpsi_dy] = gradient(psi, dx, dy);
    Jx = imag(conj(psi) .* dpsi_dx); Jy = imag(conj(psi) .* dpsi_dy);
    
    vx_field = zeros(N, N); vy_field = zeros(N, N);
    mask = density > density_thresh;
    vx_field(mask) = (hbar / m) * (Jx(mask) ./ density(mask));
    vy_field(mask) = (hbar / m) * (Jy(mask) ./ density(mask));
    
    max_v_quantum = 16.0;
    speed_field = sqrt(vx_field.^2 + vy_field.^2);
    too_fast = speed_field > max_v_quantum;
    vx_field(too_fast) = vx_field(too_fast) ./ speed_field(too_fast) * max_v_quantum;
    vy_field(too_fast) = vy_field(too_fast) ./ speed_field(too_fast) * max_v_quantum;
    
    % --- E. Drone Swarm Updates ---
    target_vx = interp2(X, Y, vx_field, drones(:,1), drones(:,2), 'linear', 0);
    target_vy = interp2(X, Y, vy_field, drones(:,1), drones(:,2), 'linear', 0);
    
    frame_min_drone_dist = Inf;
    frame_min_obs_dist = Inf;
    
    for i = 1:num_drones
        dir_to_goal = [goal_x, goal_y] - drones(i,:);
        dist_to_goal = norm(dir_to_goal);
        
        % 1. Classical Vector
        v_classical_x = classical_speed * (dir_to_goal(1) / max(dist_to_goal, 0.1));
        v_classical_y = classical_speed * (dir_to_goal(2) / max(dist_to_goal, 0.1));
        
        % 2. Quantum Fluid Field Guidance
        v_quantum_x = target_vx(i) * quantum_gain;
        v_quantum_y = target_vy(i) * quantum_gain;
        
        % 3. Smooth Drone-to-Drone Separation Forces & Telemetry Tracking
        v_rep_x = 0; v_rep_y = 0;
        for j = 1:num_drones
            if i ~= j
                diff_vec = drones(i,:) - drones(j,:);
                dist_to_drone = norm(diff_vec);
                
                if dist_to_drone < frame_min_drone_dist
                    frame_min_drone_dist = dist_to_drone;
                end
                
                if dist_to_drone < d_drone && dist_to_drone > 0.05
                    rep_mag = k_rep_drone * (1/dist_to_drone - 1/d_drone) / (dist_to_drone + 0.1);
                    v_rep_x = v_rep_x + rep_mag * (diff_vec(1) / dist_to_drone);
                    v_rep_y = v_rep_y + rep_mag * (diff_vec(2) / dist_to_drone);
                end
            end
        end
        
        % 4. Smooth Obstacle Avoidance Field & Telemetry Tracking
        v_obs_x = 0; v_obs_y = 0;
        for k = 1:size(clutter_centers, 1)
            diff_obs = drones(i,:) - clutter_centers(k,:);
            dist_to_obs = norm(diff_obs);
            
            current_surface_dist = max(0, dist_to_obs - clutter_radius);
            if current_surface_dist < frame_min_obs_dist
                frame_min_obs_dist = current_surface_dist;
            end
            
            min_dist = clutter_radius + 0.2;
            if dist_to_obs < min_dist + 1.0 
                obs_push = k_rep_obs * exp(-(dist_to_obs - min_dist) * 3.0);
                v_obs_x = v_obs_x + obs_push * (diff_obs(1) / max(dist_to_obs, 0.01));
                v_obs_y = v_obs_y + obs_push * (diff_obs(2) / max(dist_to_obs, 0.01));
            end
        end
        
        % Combine intended targets into a steering force framework
        desired_vx = v_classical_x + v_quantum_x + v_rep_x + v_obs_x;
        desired_vy = v_classical_y + v_quantum_y + v_rep_y + v_obs_y;
        
        % Calculate steering force vector
        steer_x = desired_vx - drone_vel(i,1);
        steer_y = desired_vy - drone_vel(i,2);
        
        % Smoothly clip steering force magnitude 
        steer_norm = sqrt(steer_x^2 + steer_y^2);
        if steer_norm > max_force
            steer_x = (steer_x / steer_norm) * max_force;
            steer_y = (steer_y / steer_norm) * max_force;
        end
        
        % Integrate velocity with momentum smoothing
        drone_vel(i,1) = drone_vel(i,1) * drone_inertia + steer_x * (1 - drone_inertia);
        drone_vel(i,2) = drone_vel(i,2) * drone_inertia + steer_y * (1 - drone_inertia);
        
        % Cap final speed magnitude safely
        total_speed = sqrt(drone_vel(i,1)^2 + drone_vel(i,2)^2);
        if total_speed > max_total_v
            drone_vel(i,1) = (drone_vel(i,1) / total_speed) * max_total_v;
            drone_vel(i,2) = (drone_vel(i,2) / total_speed) * max_total_v;
        end
        
        % Position updates dynamically across frames
        drones(i,1) = drones(i,1) + drone_vel(i,1) * dt_drone;
        drones(i,2) = drones(i,2) + drone_vel(i,2) * dt_drone;
        
        % Soft boundary clamp fallback to keep drone within visual arena bounds
        drones(i,1) = max(-L/2+0.5, min(L/2-0.5, drones(i,1)));
        drones(i,2) = max(-L/2+0.5, min(L/2-0.5, drones(i,2)));
    end
    
    % Store metrics into history arrays
    min_drone_dist_hist(t) = frame_min_drone_dist;
    min_obs_dist_hist(t) = frame_min_obs_dist;
    
    trail_hist_x = [drones(:,1), trail_hist_x(:, 1:end-1)];
    trail_hist_y = [drones(:,2), trail_hist_y(:, 1:end-1)];
    
    % --- F. Fluid Smooth Renderer Sampling ---
    if mod(t, 2) == 0
        % Update Figure 1 (Arena)
        if ishandle(figArena)
            set(density_plot, 'CData', density);
            set(drone_p1, 'XData', drones(:,1), 'YData', drones(:,2));
            set(goal_p1, 'XData', goal_x, 'YData', goal_y);
            
            t_x = [trail_hist_x, NaN(num_drones, 1)]'; t_y = [trail_hist_y, NaN(num_drones, 1)]';
            set(trail_plots, 'XData', t_x(:), 'YData', t_y(:));
            
            set(phase_plot, 'CData', angle(psi));
            set(drone_p2, 'XData', drones(:,1), 'YData', drones(:,2));
            set(goal_p2, 'XData', goal_x, 'YData', goal_y);
            set(quiver_plot, 'UData', vx_field(1:q_skip:end, 1:q_skip:end), 'VData', vy_field(1:q_skip:end, 1:q_skip:end));
        end
        
        % Update Figure 2 (Telemetry Lines)
        if ishandle(figTelemetry)
            set(line_drone, 'YData', min_drone_dist_hist);
            set(line_obs, 'YData', min_obs_dist_hist);
        end
        
        drawnow;
    end
    
end

%% 6. Finalization & Image Export
if ishandle(figTelemetry)
    fprintf('\n>> Exporting finalized distance metrics dashboard view to directory...\n');
    exportgraphics(figTelemetry, 'final_safety_telemetry.png', 'Resolution', 300);
    fprintf('>> Success! File saved as "final_safety_telemetry.png"\n');
end