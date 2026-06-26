% =========================================================================
% COMPLETE: GPE Quantum Swarm Navigation (Smoothed Cinematic Movement Edition)
% Cluttered Environment Strategy with Moving Goal, Dual Figures & Image Export
% =========================================================================
clear; clc; close all;

%% 1. Grid & Environment Setup
N = 200;                
L = 30;                 
x = linspace(-L/2, L/2, N);
y = linspace(-L/2, L/2, N);
dx = x(2) - x(1);
dy = y(2) - y(1);
[X, Y] = meshgrid(x, y);
kx = (2*pi/L) * [0:N/2-1, -N/2:-1]; 
[KX, KY] = meshgrid(kx, kx);
K2 = KX.^2 + KY.^2;     

%% 2. Physics & Swarm Parameters
hbar = 1;               
m = 1;                  
g = 55.0;               % Boosted interaction term slightly for better splitting around clutter
dt_wave = 0.005;        
dt_drone = 0.05;        
density_thresh = 1e-3;  
arrival_radius = 0.8;   

% --- SMOOTHING TUNERS ---
max_total_v = 10.0;     % Max speed cap for drones
max_force = 15.0;       % Max steering force applied per step (prevents jerky snaps)
drone_inertia = 0.75;   % Velocity smoothing weight (0 = instantaneous, 0.9 = heavy lag/drift)
k_rep_obs = 180.0;      % Smooth exponential obstacle repulsion force magnitude
classical_speed = 3.8;  
quantum_gain = 6.0;     

% --- SWARM SEPARATION TUNERS ---
k_rep_drone = 45.0;     % Repulsive push strength between drones
d_drone = 1.40;         % Inter-drone clearance boundary zone

%% 3. Cluttered Layout & Moving Goal Definitions
start_x = -10; start_y = -8;
% Generate static obstacle fields (clutter elements)
obs_amp = 700;
V_room = zeros(N, N);
% Fixed coordinates for scattered columns across the zone
clutter_centers = [
    -5,  5;   0,  6;   6,  5;
    -7,  0;   2, -2;   6, -3;
    -6, -5;  -1, -6;   4, -7;
    -1,  2;   5,  1;  -3, -2
];
clutter_radius = 0.7;
for k = 1:size(clutter_centers, 1)
    cx = clutter_centers(k, 1);
    cy = clutter_centers(k, 2);
    V_room = V_room + obs_amp * exp(-((X - cx).^2 + (Y - cy).^2) / (2 * clutter_radius^2));
end
V_bound = 120 * (abs(X) > L/2 - 2) + 120 * (abs(Y) > L/2 - 2);

% Initialize Swarm near bottom left corner
num_drones = 400;    %%%%%%%%%%%%%%%%%%%%%%%%<<<<<<<<<<<<<<<<<<<<<<<<<<<-------------------------
drones = [start_x + randn(num_drones,1)*0.7, start_y + randn(num_drones,1)*0.7];
drone_vel = zeros(num_drones, 2); % Persistent drone velocities tracker for tracking momentum
max_trail_len = 20;
trail_hist_x = repmat(drones(:,1), 1, max_trail_len);
trail_hist_y = repmat(drones(:,2), 1, max_trail_len);

% Telemetry metrics logging arrays
max_steps = 1800;
time_hist = 1:max_steps;
min_drone_dist_hist = NaN(1, max_steps);
min_obs_dist_hist = NaN(1, max_steps);

% Initialize Wave Function centered on starting drone swarm location
psi = exp(-((X - start_x).^2 + (Y - start_y).^2) / 4.0);
psi = 0.001* psi / sqrt(trapz(y, trapz(x, abs(psi).^2, 2)));

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
    rectangle('Position', [clutter_centers(k,1)-clutter_radius, clutter_centers(k,2)-clutter_radius, clutter_radius*2, clutter_radius*2], ...
              'Curvature', [1 1], 'FaceColor', [0.15 0.15 0.18], 'EdgeColor', 'none', 'Parent', ax1);
end
trail_plots = plot(NaN, NaN, 'Color', [0.93 0.69 0.13 0.35], 'LineWidth', 1.1, 'Parent', ax1); 
goal_p1 = plot(NaN, NaN, 'gp', 'MarkerSize', 14, 'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k');
drone_p1 = plot(drones(:,1), drones(:,2), 'wo', 'MarkerSize', 5.0, 'MarkerFaceColor', [0.85 0.33 0.10], 'MarkerEdgeColor', 'w');

% Subplot 2: Phase Map & Vectors
ax2 = subplot(1, 2, 2);
phase_plot = imagesc(x, y, angle(psi));
set(ax2, 'YDir', 'normal', 'Layer', 'top'); hold on; axis equal; xlim([-13 13]); ylim([-13 13]);
colormap(ax2, max(min(2.8*(sky)-1.8,1),0));%colormap(ax2, max(min(1.8*flipud(sky),1),0)); %colormap(ax2,max(min(0.1+1.4*flipud(abyss),1),0));
colorbar(ax2);
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
    
    % --- A. Update Dynamic Target Mechanics (Lissajous Exploration Vector) ---
    goal_x = 9.5 * sin(0.015 * t + 0.3);
    goal_y = 8.5 * sin(0.008 * t);
    
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
    fprintf('>> Exporting finalized distance metrics dashboard view to directory...\n');
    exportgraphics(figTelemetry, 'final_safety_telemetry.png', 'Resolution', 300);
    fprintf('>> Success! File saved as "final_safety_telemetry.png"\n');
end