shader_type canvas_item;

// Ball parameters
uniform float rotation_x : hint_range(-20.0, 20.0) = 0.0;
uniform float rotation_y : hint_range(-20.0, 20.0) = 0.0;
uniform int ball_skin : hint_range(0, 5) = 0;
uniform float ball_radius : hint_range(10.0, 50.0) = 10.0;
uniform bool debug_mode = false;

// Skin colors
const vec3 CLASSIC_WHITE = vec3(1.0, 1.0, 1.0);
const vec3 BLUE_STEEL = vec3(0.2, 0.4, 0.8);
const vec3 GOLDEN = vec3(1.0, 0.8, 0.2);
const vec3 CHROME = vec3(0.8, 0.8, 0.9);
const vec3 WOOD_GRAIN = vec3(0.6, 0.4, 0.2);

// Rotation matrices
mat3 rotate_x(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat3(
        vec3(1.0, 0.0, 0.0),
        vec3(0.0, c, -s),
        vec3(0.0, s, c)
    );
}

mat3 rotate_y(float angle) {
    float c = cos(angle);
    float s = sin(angle);
    return mat3(
        vec3(c, 0.0, s),
        vec3(0.0, 1.0, 0.0),
        vec3(-s, 0.0, c)
    );
}

// Convert screen position to 3D sphere coordinates
vec3 screen_to_sphere(vec2 pos) {
    float len = length(pos);
    if (len > 1.0) return vec3(0.0); // Outside sphere

    float z = sqrt(1.0 - len * len); // Z coordinate on sphere
    return vec3(pos.x, pos.y, z);
}

// Apply 3D rotations to a point
vec3 apply_rotations(vec3 point) {
    mat3 rot_x = rotate_x(rotation_x);
    mat3 rot_y = rotate_y(rotation_y);
    return rot_y * rot_x * point;
}

// Generate dimple pattern
float get_dimple_pattern(vec3 sphere_pos) {
    // Convert sphere coordinates to a pattern
    float u = atan(sphere_pos.x, sphere_pos.z) * 2.0;
    float v = acos(sphere_pos.y) * 2.0;

    // Multiple sine wave patterns for realistic dimples
    float pattern1 = sin(u * 6.0) * sin(v * 6.0);
    float pattern2 = sin((u + 1.0) * 4.2) * sin((v + 0.5) * 4.2);
    float pattern3 = sin((u - 0.5) * 8.5) * sin((v - 1.0) * 8.5);

    float combined = (pattern1 + pattern2 * 0.5 + pattern3 * 0.3) / 2.8;

    // Only create dimples in the middle area of the ball
    float radial_dist = length(sphere_pos.xy);
    if (radial_dist < 0.2 || radial_dist > 0.85) return 0.0;

    return smoothstep(0.4, 0.6, combined) * 0.3;
}

// Check if we're in the Callaway logo area
float get_logo_pattern(vec3 sphere_pos) {
    // Logo is positioned at front of ball (0, 0, 1)
    vec3 logo_pos = vec3(0.0, 0.0, 1.0);
    float dist_to_logo = distance(sphere_pos, logo_pos);

    // Only show if logo is facing toward us (positive Z after rotation)
    if (sphere_pos.z < 0.1) return 0.0;

    // Logo size based on distance from logo center
    float logo_size = 0.35;
    if (dist_to_logo > logo_size) return 0.0;

    // Create letter pattern within logo area
    vec2 local_pos = (sphere_pos.xy - logo_pos.xy) / logo_size;

    // Simple "CALLAWAY" pattern using horizontal and vertical lines
    float letter_pattern = 0.0;

    // Horizontal lines (top, middle, bottom)
    if (abs(local_pos.y) < 0.12 ||
        abs(local_pos.y - 0.5) < 0.1 ||
        abs(local_pos.y + 0.5) < 0.1) {
        if (abs(local_pos.x) < 0.8) {
            letter_pattern = 1.0;
        }
    }

    // Vertical separators between letters
    for (int i = -3; i <= 3; i++) {
        float sep_x = float(i) * 0.25;
        if (abs(local_pos.x - sep_x) < 0.06 && abs(local_pos.y) < 0.6) {
            letter_pattern = 1.0;
        }
    }

    return letter_pattern * sphere_pos.z; // Fade based on depth
}

// Check if we're in the number "1" area
float get_number_pattern(vec3 sphere_pos) {
    // Number is on opposite side of ball (0, 0, -1)
    vec3 number_pos = vec3(0.0, 0.0, -1.0);
    float dist_to_number = distance(sphere_pos, number_pos);

    // Only show if facing toward us
    if (sphere_pos.z < 0.1) return 0.0;

    float number_size = 0.3;
    if (dist_to_number > number_size) return 0.0;

    vec2 local_pos = (sphere_pos.xy - number_pos.xy) / number_size;

    float number_pattern = 0.0;

    // Vertical line of "1"
    if (abs(local_pos.x) < 0.15 && abs(local_pos.y) < 0.6) {
        number_pattern = 1.0;
    }

    // Top angle of "1"
    if (local_pos.y < -0.3 && local_pos.y > -0.6 &&
        local_pos.x > -0.4 && local_pos.x < 0.15) {
        number_pattern = 1.0;
    }

    // Base line of "1"
    if (abs(local_pos.y - 0.6) < 0.1 && abs(local_pos.x) < 0.4) {
        number_pattern = 1.0;
    }

    return number_pattern * sphere_pos.z;
}

// Get base color based on skin type
vec3 get_skin_color(vec3 sphere_pos, int skin) {
    vec3 base_color;

    if (skin == 0) { // CLASSIC_WHITE
        base_color = CLASSIC_WHITE;
    } else if (skin == 1) { // BLUE_STEEL
        base_color = BLUE_STEEL;

        // Metallic highlight
        vec3 highlight_pos = normalize(vec3(-0.3, -0.3, 0.8));
        float highlight = max(0.0, dot(sphere_pos, highlight_pos));
        base_color = mix(base_color, vec3(1.0), pow(highlight, 8.0) * 0.6);

    } else if (skin == 2) { // GOLDEN
        base_color = GOLDEN;

        // Shiny highlight based on viewing angle
        float shine = max(0.0, sphere_pos.z);
        base_color = mix(base_color, vec3(1.0), pow(shine, 4.0) * 0.3);

    } else if (skin == 3) { // RAINBOW
        // Rainbow based on sphere coordinates
        float hue = (atan(sphere_pos.x, sphere_pos.z) + PI) / (2.0 * PI);
        // Convert HSV to RGB (simplified)
        vec3 c = vec3(hue * 6.0);
        vec3 rgb = clamp(abs(mod(c, 6.0) - 3.0) - 1.0, 0.0, 1.0);
        base_color = rgb * 0.9;

    } else if (skin == 4) { // CHROME
        base_color = CHROME;

        // Multiple chrome highlights
        vec3 highlight1_pos = normalize(vec3(-0.4, -0.4, 0.8));
        vec3 highlight2_pos = normalize(vec3(0.3, 0.2, 0.9));

        float highlight1 = max(0.0, dot(sphere_pos, highlight1_pos));
        float highlight2 = max(0.0, dot(sphere_pos, highlight2_pos));

        if (pow(highlight1, 20.0) > 0.8) {
            base_color = vec3(1.0);
        } else if (pow(highlight2, 15.0) > 0.7) {
            base_color = mix(base_color, vec3(1.0), 0.7);
        }

    } else { // WOOD_GRAIN
        base_color = WOOD_GRAIN;

        // Wood grain pattern
        float grain = sin(sphere_pos.x * 15.0) * 0.2 + sin(sphere_pos.y * 5.0) * 0.1;
        base_color *= (1.0 + grain);
    }

    return base_color;
}

void fragment() {
    vec2 center = vec2(0.5, 0.5);
    vec2 pos = (UV - center) * 2.0; // Convert to -1 to 1 range
    float dist = length(pos);

    if (dist > 1.0) {
        COLOR = vec4(0.0, 0.0, 0.0, 0.0); // Transparent outside ball
    } else {

    // Convert to 3D sphere coordinates
    vec3 sphere_pos = screen_to_sphere(pos);

    // Apply rotations
    sphere_pos = apply_rotations(sphere_pos);

    // Get base color based on skin
    vec3 final_color = get_skin_color(sphere_pos, ball_skin);

    // Add 3D shading (simple Lambert lighting)
    vec3 light_dir = normalize(vec3(-0.5, -0.7, 1.0));
    float light_intensity = max(0.3, dot(sphere_pos, light_dir));
    final_color *= light_intensity;

    // Add dimples
    float dimple_factor = get_dimple_pattern(sphere_pos);
    final_color *= (1.0 - dimple_factor);

    // Add Callaway logo
    float logo_pattern = get_logo_pattern(sphere_pos);
    if (logo_pattern > 0.0) {
        vec3 logo_color = vec3(0.1, 0.2, 0.8); // Blue logo
        final_color = mix(final_color, logo_color, logo_pattern * 0.8);
    }

    // Add number
    float number_pattern = get_number_pattern(sphere_pos);
    if (number_pattern > 0.0) {
        vec3 number_color = vec3(0.1, 0.1, 0.3); // Dark number
        final_color = mix(final_color, number_color, number_pattern * 0.8);
    }

    // Debug mode - show red dot at logo position
    if (debug_mode) {
        vec3 logo_3d = apply_rotations(vec3(0.0, 0.0, 1.0));
        if (logo_3d.z > 0.0) {
            vec2 logo_screen = logo_3d.xy * 0.8;
            if (distance(pos, logo_screen) < 0.1) {
                final_color = vec3(1.0, 0.0, 0.0); // Red debug dot
            }
        }
    }

    // Edge anti-aliasing
    float edge_alpha = 1.0 - smoothstep(0.98, 1.0, dist);

    COLOR = vec4(final_color, edge_alpha);
    } // Close the else block
}