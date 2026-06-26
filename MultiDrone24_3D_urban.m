% =========================================================================
% COMPLETE: 3D GPE Quantum City Swarm Navigation (Urban Canyon Edition)
% Skyscrapers & Streets Environment Strategy with Dynamically Moving Goal Layout
% =========================================================================
clear; clc; close all;

%% 1. Grid & Environment Setup
N = 64;                 % 3D Grid Resolution 
L = 30;                 % Scaled up for urban footprint
x = linspace(-L/2, L/2, N);
y = linspace(-L/2, L/2, N);
z = linspace(0, L, N);  % Z starts at 0 (Ground Level) up to ceiling
dx = x(2) - x(1);
dy = y(2) - y(1);
dz = z(2) - z(1);
[X, Y, Z] = meshgrid(x, y, z);

% 3D Fourier space setup
kx = (2*pi/L) * [0:N/2-1, -N/2:-1]; 
kz = (2*pi/L) * [0:N/2-1, -N/2:-1]; % Adjusted boundary frequencies for Z
[KX, KY, KZ] = meshgrid(kx, kx, kz);
K2 = KX.^2 + KY.^2 + KZ.^2;     

%% 2. Physics & Swarm Parameters
hbar = 1;               
m = 1;                  
g = 35.0;               % High interaction for crisp canyon splitting
dt_wave = 0.005;        
dt_drone = 0.05;        
density_thresh = 1e-4;  

% --- SMOOTHING TUNERS ---
max_total_v = 14.0;     % Snappy city speeds
max_force = 22.0;       % Responsive steering handles sharp turns
drone_inertia = 0.65;   % Balanced inertia for tighter cornering
k_rep_obs = 250.0;      % Strong obstacle repulsion for rigid walls
classical_speed = 4.5;  
quantum_gain = 6.0;     
k_rep_drone = 9.0;      
d_drone = 0.75;          

%% 3. Urban Layout Definition (City Blocks & Skyscrapers)
% Define matrix of building footprints: [CenterX, CenterY, WidthX, WidthY, Height]
buildings = [
    -10, -10,  4,  4, 18;   -10,  -4,  4,  3, 14;   -10,   3,  4,  4, 22;   -10,  10,  4,  4, 12;
     -4, -10,  3,  4, 15;    -4,  -4,  3,  3,  0;   -4,   3,  3,  4, 16;    -4,  10,  3,  4, 25;
      3, -10,  4,  4, 20;     3,  -4,  4,  3, 18;    3,   3,  4,  4,  0;     3,  10,  4,  4, 14;
     10, -10,  4,  4, 11;    10,  -4,  4,  3, 24;   10,   3,  4,  4, 17;    10,  10,  4,  4, 20
];

% Generate Static City Potential Map using a smooth but steep Super-Gaussian 
obs_amp = 1000;
V_room = zeros(N, N, N);
for b = 1:size(buildings, 1)
    bx = buildings(b,1); by = buildings(b,2); 
    bw_x = buildings(b,3); bw_y = buildings(b,4); bh = buildings(b,5);
    if bh == 0, continue; end % Open plazas/intersections
    
    % Mask out 3D rectangular columns with soft exponential edges
    V_room = V_room + obs_amp * exp(-((X - bx)/(bw_x/2)).^6 - ((Y - by)/(bw_y/2)).^6) .* (Z <= bh);
end

% Boundary limits (City perimeter walls and sky limit)
V_bound = 150 * (abs(X) > L/2 - 1.5) + 150 * (abs(Y) > L/2 - 1.5) + 150 * (Z > L - 2);

% Swarm Initialization (Staged inside a street alley at ground level)
start_x = -7.0; start_y = -7.0; start_z = 2.0;
num_drones = 60;
drones = [start_x + randn(num_drones,1)*0.4, ...
          start_y + randn(num_drones,1)*0.4, ...
          start_z + rand(num_drones,1)*1.5];
drone_vel = zeros(num_drones, 3); 

max_trail_len = 15;
trail_hist_x = repmat(drones(:,1), 1, max_trail_len);
trail_hist_y = repmat(drones(:,2), 1, max_trail_len);
trail_hist_z = repmat(drones(:,3), 1, max_trail_len);

% Initialize 3D Wave Function in the starting alleyway
psi = exp(-((X - start_x).^2 + (Y - start_y).^2 + (Z - start_z).^2) / 5.0);
psi = psi / sqrt(trapz(z, trapz(y, trapz(x, abs(psi).^2, 2), 1), 3));

%% 4. Video & Dashboard Initialization
video_filename = 'quantum_city_navigation.mp4';
v_writer = VideoWriter(video_filename, 'MPEG-4');
v_writer.FrameRate = 30; v_writer.Quality = 98;     
open(v_writer);

fig = figure('Name', 'GPE Control Center: Urban Drone Operations', 'Color', 'w', 'Position', [50, 50, 1100, 850]);
ax = axes('Parent', fig); hold(ax, 'on'); grid(ax, 'on'); box(ax, 'on');
view(ax, -14, 66); % Custom camera perspective applied here
axis equal; xlim([-L/2 L/2]); ylim([-L/2 L/2]); zlim([0 L-5]);
xlabel('East-West Streets'); ylabel('North-South Avenues'); zlabel('Altitude');
title('3D Quantum Fluid Guidance: Urban Metropolis Layout', 'FontSize', 12, 'FontWeight', 'bold');

% Draw Realistic Multi-Faceted Skyscrapers with Windows
for b = 1:size(buildings, 1)
    bx = buildings(b,1); by = buildings(b,2); 
    bw_x = buildings(b,3); bw_y = buildings(b,4); bh = buildings(b,5);
    if bh == 0, continue; end
    
    % Pick a distinct architectural theme color for this building
    color_themes = [
        0.38, 0.42, 0.48;  % Steel gray
        0.28, 0.35, 0.45;  % Reflective dark blue
        0.44, 0.46, 0.49;  % Concrete panels
        0.22, 0.28, 0.38   % Deep tint glass
    ];
    b_color = color_themes(mod(b, size(color_themes, 1)) + 1, :);
    
    % Construct the 6 orthogonal faces of a rectangular high-rise cuboid
    % Coordinates relative to building center
    hx = bw_x / 2; hy = bw_y / 2;
    
    % Define the 8 corner vertices of the skyscraper
    v = [ -hx, -hy,  0;  hx, -hy,  0;  hx,  hy,  0; -hx,  hy,  0; ...
          -hx, -hy, bh;  hx, -hy, bh;  hx,  hy, bh; -hx,  hy, bh ];
    % Shift to real-world positions
    v(:,1) = v(:,1) + bx; v(:,2) = v(:,2) + by;
    
    % Define vertex connectivity tracking the 6 square faces
    f = [ 1 2 6 5;  2 3 7 6;  3 4 8 7;  4 1 5 8;  1 2 3 4;  5 6 7 8 ];
    
    % Draw the primary structural mass
    patch('Vertices', v, 'Faces', f, 'FaceColor', b_color, ...
          'EdgeColor', [0.2 0.2 0.25], 'LineWidth', 0.8, 'FaceAlpha', 0.9, ...
          'AmbientStrength', 0.4, 'DiffuseStrength', 0.6, 'SpecularStrength', 0.3, 'Parent', ax);
      
    % --- PROCEDURAL WINDOW CORRIDORS ---
    % Add window rows across the 4 vertical facades
    win_rows = floor(bh / 1.5); 
    win_cols_x = floor(bw_x / 0.8);
    win_cols_y = floor(bw_y / 0.8);
    
    % Draw rows on the X-Facing Facades (Front/Back walls)
    if win_rows > 2 && win_cols_x > 2
        [wx, wz] = meshgrid(linspace(-hx+0.3, hx-0.3, win_cols_x), linspace(1.5, bh-1.0, win_rows));
        % Randomize window light states (yellow-white glow vs dark unlit offices)
        w_status = rand(size(wx)) > 0.4; 
        w_colors = zeros(size(wx,1), size(wx,2), 3);
        w_colors(:,:,1) = w_status * 0.95 + (~w_status)*0.15;
        w_colors(:,:,2) = w_status * 0.90 + (~w_status)*0.15;
        w_colors(:,:,3) = w_status * 0.60 + (~w_status)*0.25;
        
        % Scatter window lights symmetrically on South face
        scatter3(ax, wx(:) + bx, repmat(-hy - 0.02, numel(wx), 1) + by, wz(:), ...
                 10, reshape(w_colors, [], 3), 'filled', 'square', 'MarkerEdgeColor', 'none');
        % Scatter window lights symmetrically on North face
        scatter3(ax, wx(:) + bx, repmat(hy + 0.02, numel(wx), 1) + by, wz(:), ...
                 10, reshape(w_colors, [], 3), 'filled', 'square', 'MarkerEdgeColor', 'none');
    end
    
    % Draw rows on the Y-Facing Facades (Left/Right walls)
    if win_rows > 2 && win_cols_y > 2
        [wy, wz] = meshgrid(linspace(-hy+0.3, hy-0.3, win_cols_y), linspace(1.5, bh-1.0, win_rows));
        w_status = rand(size(wy)) > 0.4;
        w_colors = zeros(size(wy,1), size(wy,2), 3);
        w_colors(:,:,1) = w_status * 0.95 + (~w_status)*0.15;
        w_colors(:,:,2) = w_status * 0.90 + (~w_status)*0.15;
        w_colors(:,:,3) = w_status * 0.60 + (~w_status)*0.25;
        
        % Scatter window lights symmetrically on West face
        scatter3(ax, repmat(-hx - 0.02, numel(wy), 1) + bx, wy(:) + by, wz(:), ...
                 10, reshape(w_colors, [], 3), 'filled', 'square', 'MarkerEdgeColor', 'none');
        % Scatter window lights symmetrically on East face
        scatter3(ax, repmat(hx + 0.02, numel(wy), 1) + bx, wy(:) + by, wz(:), ...
                 10, reshape(w_colors, [], 3), 'filled', 'square', 'MarkerEdgeColor', 'none');
    end
end

% Set up multiple camera lights for cinematic skyline ambiance
light('Position', [10, -20, 30], 'Style', 'local');
light('Position', [-15, 20, 15], 'Style', 'local');
lighting gouraud;

% Plot Handles
drone_plot = plot3(drones(:,1), drones(:,2), drones(:,3), 'ro', 'MarkerSize', 4.5, 'MarkerFaceColor', [0.9 0.2 0.1], 'MarkerEdgeColor', 'w');
goal_plot  = plot3(NaN, NaN, NaN, 'gp', 'MarkerSize', 16, 'MarkerFaceColor', 'g', 'MarkerEdgeColor', 'k');
trail_plots = plot3(NaN, NaN, NaN, 'Color', [0.93 0.69 0.13 0.35], 'LineWidth', 1.3);
density_patch = patch(isosurface(X, Y, Z, abs(psi).^2, 0.005), 'FaceColor', [0.15 0.60 0.90], 'EdgeColor', 'none', 'FaceAlpha', 0.15);

%% 5. Main Simulation Loop
for t = 1:1500
    
    % --- A. Update 3D Target Mechanics (Rooftop & Canyon Patrolling) ---
    goal_x = 11.0 * sin(0.015 * t + 0.2);
    goal_y = 11.0 * sin(0.008 * t);
    goal_z = 12.0 + 8.0 * cos(0.012 * t); % Target dips into avenues and swoops over roofs
    
    % --- B. Quantum Well Translation ---
    V_target_well = -22.0 * exp(-((X - goal_x).^2 + (Y - goal_y).^2 + (Z - goal_z).^2) / 14.0);
    V = V_room + V_target_well - 1i * V_bound; 
    
    % --- C. 3D Split Step Fourier Step ---
    density = abs(psi).^2;
    psi = psi .* exp(-1i * (V + g * density) * (dt_wave / 2) / hbar);
    
    psi_k = fftn(psi);
    psi_k = psi_k .* exp(-1i * (hbar^2 / (2*m)) * K2 * dt_wave / hbar);
    psi = ifftn(psi_k);
    
    density = abs(psi).^2;
    psi = psi .* exp(-1i * (V + g * density) * (dt_wave / 2) / hbar);
    
    % --- D. Phase Current Computations ---
    [dpsi_dx, dpsi_dy, dpsi_dz] = gradient(psi, dx, dy, dz);
    Jx = imag(conj(psi) .* dpsi_dx); Jy = imag(conj(psi) .* dpsi_dy); Jz = imag(conj(psi) .* dpsi_dz);
    
    vx_field = zeros(N, N, N); vy_field = zeros(N, N, N); vz_field = zeros(N, N, N);
    mask = density > density_thresh;
    vx_field(mask) = (hbar / m) * (Jx(mask) ./ density(mask));
    vy_field(mask) = (hbar / m) * (Jy(mask) ./ density(mask));
    vz_field(mask) = (hbar / m) * (Jz(mask) ./ density(mask));
    
    max_v_quantum = 18.0;
    speed_field = sqrt(vx_field.^2 + vy_field.^2 + vz_field.^2);
    too_fast = speed_field > max_v_quantum;
    vx_field(too_fast) = vx_field(too_fast) ./ speed_field(too_fast) * max_v_quantum;
    vy_field(too_fast) = vy_field(too_fast) ./ speed_field(too_fast) * max_v_quantum;
    vz_field(too_fast) = vz_field(too_fast) ./ speed_field(too_fast) * max_v_quantum;
    
    % --- E. Drone Kinematics Loop ---
    target_vx = interp3(X, Y, Z, vx_field, drones(:,1), drones(:,2), drones(:,3), 'linear', 0);
    target_vy = interp3(X, Y, Z, vy_field, drones(:,1), drones(:,2), drones(:,3), 'linear', 0);
    target_vz = interp3(X, Y, Z, vz_field, drones(:,1), drones(:,2), drones(:,3), 'linear', 0);
    
    for i = 1:num_drones
        dir_to_goal = [goal_x, goal_y, goal_z] - drones(i,:);
        dist_to_goal = norm(dir_to_goal);
        
        v_classical_x = classical_speed * (dir_to_goal(1) / max(dist_to_goal, 0.1));
        v_classical_y = classical_speed * (dir_to_goal(2) / max(dist_to_goal, 0.1));
        v_classical_z = classical_speed * (dir_to_goal(3) / max(dist_to_goal, 0.1));
        
        v_quantum_x = target_vx(i) * quantum_gain;
        v_quantum_y = target_vy(i) * quantum_gain;
        v_quantum_z = target_vz(i) * quantum_gain;
        
        % Separation Forces
        v_rep_x = 0; v_rep_y = 0; v_rep_z = 0;
        for j = 1:num_drones
            if i ~= j
                diff_vec = drones(i,:) - drones(j,:);
                dist_to_drone = norm(diff_vec);
                if dist_to_drone < d_drone && dist_to_drone > 0.05
                    rep_mag = k_rep_drone * (1/dist_to_drone - 1/d_drone) / (dist_to_drone + 0.1);
                    v_rep_x = v_rep_x + rep_mag * (diff_vec(1) / dist_to_drone);
                    v_rep_y = v_rep_y + rep_mag * (diff_vec(2) / dist_to_drone);
                    v_rep_z = v_rep_z + rep_mag * (diff_vec(3) / dist_to_drone);
                end
            end
        end
        
        % Rigid Building Wall Repulsion 
        v_obs_x = 0; v_obs_y = 0; v_obs_z = 0;
        for b = 1:size(buildings, 1)
            bx = buildings(b,1); by = buildings(b,2); 
            bw_x = buildings(b,3); bw_y = buildings(b,4); bh = buildings(b,5);
            if bh == 0, continue; end
            
            % Check proximity to building boundary limits
            dx_b = abs(drones(i,1) - bx) - (bw_x/2);
            dy_b = abs(drones(i,2) - by) - (bw_y/2);
            dz_b = drones(i,3) - bh;
            
            % If inside or approaching the building volume buffer zone
            if dx_b < 1.0 && dy_b < 1.0 && drones(i,3) < bh + 1.0
                push = k_rep_obs * exp(-max(dx_b, 0.01)*2) * exp(-max(dy_b, 0.01)*2);
                v_obs_x = v_obs_x + push * sign(drones(i,1) - bx);
                v_obs_y = v_obs_y + push * sign(drones(i,2) - by);
                if dz_b < 0, v_obs_z = v_obs_z + push * 0.5; end % Upward lift push away from roof
            end
        end
        
        % Calculate Steering Vector
        desired_vx = v_classical_x + v_quantum_x + v_rep_x + v_obs_x;
        desired_vy = v_classical_y + v_quantum_y + v_rep_y + v_obs_y;
        desired_vz = v_classical_z + v_quantum_z + v_rep_z + v_obs_z;
        
        steer_x = desired_vx - drone_vel(i,1);
        steer_y = desired_vy - drone_vel(i,2);
        steer_z = desired_vz - drone_vel(i,3);
        
        steer_norm = sqrt(steer_x^2 + steer_y^2 + steer_z^2);
        if steer_norm > max_force
            steer_x = (steer_x / steer_norm) * max_force;
            steer_y = (steer_y / steer_norm) * max_force;
            steer_z = (steer_z / steer_norm) * max_force;
        end
        
        % Integration
        drone_vel(i,1) = drone_vel(i,1) * drone_inertia + steer_x * (1 - drone_inertia);
        drone_vel(i,2) = drone_vel(i,2) * drone_inertia + steer_y * (1 - drone_inertia);
        drone_vel(i,3) = drone_vel(i,3) * drone_inertia + steer_z * (1 - drone_inertia);
        
        total_speed = sqrt(drone_vel(i,1)^2 + drone_vel(i,2)^2 + drone_vel(i,3)^2);
        if total_speed > max_total_v
            drone_vel(i,1) = (drone_vel(i,1) / total_speed) * max_total_v;
            drone_vel(i,2) = (drone_vel(i,2) / total_speed) * max_total_v;
            drone_vel(i,3) = (drone_vel(i,3) / total_speed) * max_total_v;
        end
        
        drones(i,1) = drones(i,1) + drone_vel(i,1) * dt_drone;
        drones(i,2) = drones(i,2) + drone_vel(i,2) * dt_drone;
        drones(i,3) = drones(i,3) + drone_vel(i,3) * dt_drone;
        
        % Safety Arena Hard Boundaries
        drones(i,1) = max(-L/2+0.5, min(L/2-0.5, drones(i,1)));
        drones(i,2) = max(-L/2+0.5, min(L/2-0.5, drones(i,2)));
        drones(i,3) = max(0.2, min(L-2, drones(i,3)));
    end
    
    trail_hist_x = [drones(:,1), trail_hist_x(:, 1:end-1)];
    trail_hist_y = [drones(:,2), trail_hist_y(:, 1:end-1)];
    trail_hist_z = [drones(:,3), trail_hist_z(:, 1:end-1)];
    
    % --- F. Graphical Updates ---
    if mod(t, 3) == 0
        delete(density_patch);
        iso_data = isosurface(X, Y, Z, density, 0.007);
        density_patch = patch(ax, iso_data, 'FaceColor', [0.15 0.60 0.90], 'EdgeColor', 'none', 'FaceAlpha', 0.15);
        
        set(drone_plot, 'XData', drones(:,1), 'YData', drones(:,2), 'ZData', drones(:,3));
        set(goal_plot, 'XData', goal_x, 'YData', goal_y, 'ZData', goal_z);
        
        t_x = [trail_hist_x, NaN(num_drones, 1)]'; 
        t_y = [trail_hist_y, NaN(num_drones, 1)]';
        t_z = [trail_hist_z, NaN(num_drones, 1)]';
        set(trail_plots, 'XData', t_x(:), 'YData', t_y(:), 'ZData', t_z(:));
        
        drawnow;
        writeVideo(v_writer, getframe(fig));
    end
    
    % --- G. High-Resolution Snapshots (Every 67 frames) ---
    if mod(t, 67) == 0
        img_filename = sprintf('urban_frame_%04d.png', t);
        exportgraphics(fig, img_filename, 'Resolution', 150); 
    end
end

%% 6. Finalization
close(v_writer);
fprintf('\n>> Export Complete! Urban city video saved to: %s\n', video_filename);