#version 330 core
out vec4 FragColor;
uniform vec2 u_resolution;
uniform float u_time;
uniform int u_scenario;

// =========================================================
// 1. UTILS
// =========================================================

vec3 aces_tonemap(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}

float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

float create_noise(vec2 p) {
    vec2 i = floor(p); // Cella della griglia intera
    vec2 f = fract(p); // Posizione dentro la cella
    f = smoothstep(0.0, 1.0, f); // Sfumatura per i bordi

    // Campioniamo i 4 angoli della cella
    float a = hash21(i);
    float b = hash21(i + vec2(1.0, 0.0));
    float c = hash21(i + vec2(0.0, 1.0));
    float d = hash21(i + vec2(1.0, 1.0));

    // Interpoliamo tra i 4 valori
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

vec3 blackbody_color(float temp) {
    vec3 baseColor = vec3(2.8, 1.1, 0.15);
    vec3 color_weights = vec3(0.1, 1.2, 5.0);
    return baseColor * exp(-color_weights / max(0.001, temp));
}

// =========================================================
// 2.RENDERING (The Black Hole)
// =========================================================
float flowNoise(vec2 uv) {
    float f = 0.0;
    float amp = 0.5;
    vec2 shift = vec2(100.0);
    mat2 rot = mat2(cos(0.5), sin(0.5), -sin(0.5), cos(0.5));

    for (int i = 0; i < 5; i++) {
        float n = create_noise(uv);
        uv += vec2(n * 0.5, n * 0.5); // Domain Warping (Distorce le coordinate)
        f += n * amp;
        uv = uv * 2.0 * rot + shift;
        amp *= 0.45;
    }
    return f;
}

vec3 createStars(vec3 rd,vec3 glow) {
    vec3 starCoord = (rd + vec3(u_time * 0.005, 0.0, 0.0)) * 400.0;
    vec3 grid = floor(starCoord);
    float s = fract(sin(dot(grid, vec3(12.989, 78.233, 45.164))) * 43758.5453);

    //Stars Shapes
    float distToCenter = length(fract(starCoord) - 0.5);
    float variazione = pow(fract(s * 10.0), 3.0);
    float raggio_variabile = 0.01 + 0.8 * variazione;
    float starShape = smoothstep(raggio_variabile, 0.0, distToCenter);
    float brillamento = 1.0 + 0.2 * sin(u_time * 10.0 + s * 62.0);

    float finalStars = step(0.85, s) * starShape * brillamento;
    return vec3(finalStars) + glow * 0.3;
}

vec3 accretionDisk(vec3 p,vec3 rd,vec3 glow,float d) {
    float angle = atan(p.x, p.z);
    float radius = length(p.xz);
    // Time Dilation & Velocità
    float dilation = sqrt(clamp(1.0 - 1.0 / radius, 0.0, 1.0));
    float localTime = u_time * dilation;
    float speed = 2.0 / (radius * radius) * dilation;

    // Definiamo le coordinate UV polari.
    // angle * 6.0: Aumentiamo il moltiplicatore per avere più "strisce" sottili
    vec2 polarUV = vec2(angle * 6.0 - localTime * speed, radius - u_time * 0.2);
    float gasPattern = flowNoise(polarUV);

    // Aumentiamo il contrasto per rendere le venature del gas ben visibili
    gasPattern = smoothstep(0.3, 0.8, gasPattern);

    float alpha = smoothstep(0.1, 0.0, abs(p.y));
    // 1. CALCOLO VELOCITÀ DEL GAS, il gas ruota nel piano XZ. Calcoliamo il vettore tangente (velocità).
    vec3 velocity = normalize(cross(vec3(0.0, 1.0, 0.0), p));
    float v_proj = dot(rd, velocity);

    // 3. RELATIVISTIC BEAMING (Il "Faro")
    // Il gas che viene verso di noi (v_proj > 0) diventa esponenzialmente più luminoso.
    // Il gas che si allontana diventa buio.
    // "pow(..., 3.5)" aumenta drasticamente il contrasto tra i due lati.
    float beaming = pow(1.0 + v_proj * 0.5, 3.5);

    // 4. REDSHIFT GRAVITAZIONALE (Luce Stanca)
    float g_redshift = sqrt(clamp(1.0 - 1.2 / d, 0.0, 1.0)); // 1.2 per scurire prima dell'orizzonte
    g_redshift = pow(g_redshift, 2.0); // Rendiamo la curva più ripida

    // 5. CALCOLO TEMPERATURA E COLORE
    float baseTemp = 0.6 / (d - 2.0);

    float finalTemp = baseTemp * beaming * g_redshift;
    vec3 diskColor = blackbody_color(finalTemp);

    float innerEdge = smoothstep(2.2, 2.8, d);
    float outerEdge = smoothstep(5.0, 3.0, d);
    return diskColor * alpha * gasPattern * innerEdge * outerEdge + glow;
}


vec3 getDiskEmission(vec3 p, vec3 rd, float d) {
    float angle = atan(p.x, p.z);
    float radius = length(p.xz);

    // Time Dilation & Velocità
    float dilation = sqrt(clamp(1.0 - 1.0 / radius, 0.0, 1.0));
    float localTime = u_time * dilation;
    float speed = 2.0 / (radius * radius) * dilation;

    // Pattern del gas
    vec2 polarUV = vec2(angle * 6.0 - localTime * speed, radius - u_time * 0.2);
    float gasPattern = flowNoise(polarUV);
    gasPattern = smoothstep(0.3, 0.8, gasPattern);

    // Velocità e Relativistic Beaming
    vec3 velocity = normalize(cross(vec3(0.0, 1.0, 0.0), p));
    float v_proj = dot(rd, velocity);
    float beaming = pow(1.0 + v_proj * 0.5, 3.5);

    // Redshift Gravitazionale
    float g_redshift = sqrt(clamp(1.0 - 1.2 / d, 0.0, 1.0));
    g_redshift = pow(g_redshift, 2.0);

    // Calcolo Temperatura
    float baseTemp = 0.6 / (d - 2.0);
    float finalTemp = baseTemp * beaming * g_redshift;

    // Ritorna il colore puro del gas in questo punto
    return blackbody_color(finalTemp) * gasPattern;
}

vec3 render_Black_Hole(vec3 ro,vec3 rd) {
    float dither = hash21(gl_FragCoord.xy + u_time) * 0.05;
    vec3 p = ro + rd * dither;
    vec3 col = vec3(0.0);   // Background color (black)
    vec3 glow = vec3(0.0);  // Accumulates gas glow even if the ray doesn't hit the disk

    vec3 accumulated_color = vec3(0.0);
    float transmittance = 1.0; // Quanta luce riesce ancora a passare (1.0 = 100% trasparente)

    // Simulate the photon path
    for(int i = 0; i < 1300; i++) {

        float d = length(p); // // Distance from the ray to the center (0,0,0)

        // GRAVITATIONAL LENSING (Einstein ring logic)
        float gravity = 0.05/ (d * d);

        // Update ray direction
        rd = normalize(rd + normalize(-p) * gravity);

        // ADAPTIVE STEP SIZE -> move faster far away, slower near the black hole for precision
        float stepSize = max(0.001, min(0.1, d * 0.02));
        if(abs(p.y) < 0.05 && d < 6.0) stepSize *= 0.5;
        p += rd * stepSize;

        // The closer to the disk (p.y -> 0) and the center, the more "luminous fog"
        float distToDisk = length(vec2(d - 3.5, p.y * 5.0));
        float darkness = 0.65;
        glow += (vec3(1, 0.3, 0.1) - darkness * vec3(1, 0.3, 0.1)) * 0.075 / (0.5 + distToDisk * distToDisk);

        // EVENT HORIZON -> if light enters here, it never escapes
        if(d < 1.0) {
            return vec3(0.0) + glow * 0.1;
        }

        // BACKGROUND EXIT (Stars)
        if(length(p) > 50.0) {
            return createStars(rd,glow);
        }

        // ACCRETION DISK COLLISION
        if(abs(p.y) < 0.05 && d > 2.2 && d < 6.0) {
            return accretionDisk(p,rd,glow,d);
        }
    }
    return col + glow;
}

// =========================================================
// 3. CAMERA SYSTEM (La parte che volevi spostare)
// =========================================================
vec3 get_camera_pos(float t, float dist, float speed, float height, float startAngle) {
    float angle = startAngle + t * speed;
    return vec3(sin(angle) * dist, height, cos(angle) * dist);
}

vec3 get_camera_ray(vec3 ro, vec3 target, vec2 uv, float zoom) {
    vec3 forward = normalize(target - ro);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
    vec3 up = cross(forward, right);
    return normalize(forward * zoom + right * uv.x + up * uv.y);
}

// =========================================================
// 4. MAIN
// =========================================================
struct video_scenario {
    float dist;
    float speed;
    float dynamicHeight;
    float start_angle;
    float zoom;
};

void main() {
    // 1. Screen Coordinates Setup
    // Normalize pixel coordinates to range [-1, 1] and correct aspect ratio
    vec2 uv = (gl_FragCoord.xy / u_resolution.xy) * 2.0 - 1.0;
    float ratio = u_resolution.x / u_resolution.y;
    uv.x *= ratio;

    video_scenario set;

    // 2. Calculate Camera Position
    if (u_scenario == 1) {
        set.dist = 14.0;
        set.speed = 0.1;
        set.dynamicHeight = 0.0;
        set.start_angle = 0.0;
        set.zoom = 1;
    }

    if (u_scenario == 2) {
        set.dist = 14.0;
        set.speed = 0.1;
        set.dynamicHeight = 0.0;
        set.start_angle = 0.0;
        set.zoom = 1.5;
    }

    if (u_scenario == 3) {
        set.dist = 14.00;
        set.speed = 0.0;
        set.dynamicHeight = 45.0;
        set.start_angle = 0.0;
        set.zoom = 2.7;
    }

    if (u_scenario == 4) {
        set.dist = max(1.1, 15.0 - u_time * 2.5);
        set.speed = 0.2;
        set.dynamicHeight = 0.1;
        set.start_angle = 0.0;
        set.zoom = 1.0 + (u_time * 0.4);
    }

    if (u_scenario == 5) {
        float radius = 15.0;            // Distanza costante dal centro del buco nero
        float videoDuration = 25.0;     // Durata del video in secondi (1500 frame a 60fps = 25s)

        // 2. Progresso normalizzato del video (da 0.0 all'inizio a 1.0 alla fine)
        float progress = clamp(u_time / videoDuration, 0.0, 1.0);

        // 3. L'arco dell'elevazione (da 0 a PI)
        // PI = 3.14159. Usiamo questo perché sin(0)=0, sin(PI/2)=1 (apice), sin(PI)=0 (ritorno)
        float elevation = progress * 3.14159265;

        // 4. Calcolo Sferico
        // L'altezza sale al massimo a metà video e poi scende
        set.dynamicHeight = radius * sin(elevation);

        // La distanza orizzontale diminuisce man mano che si sale per mantenere il raggio perfetto
        // Usiamo abs() così quando scende dall'altra parte non inverte le coordinate
        set.dist = radius * abs(cos(elevation));

        // 5. Rotazione continua di 360 gradi
        set.speed = 0.3;
        set.start_angle = 0.0;
        set.zoom = 1.1;
    }

    vec3 ro = get_camera_pos(u_time,set.dist,set.speed,set.dynamicHeight,set.start_angle);
    vec3 rd = get_camera_ray(ro, vec3(0.0), uv, set.zoom);

    // 4. BlackHole Render
    vec3 color = render_Black_Hole(ro, rd);

    color = aces_tonemap(color);
    color = pow(color, vec3(1.0 / 2.2));

    // 6. Vignettatura
    color *= 1.0 - 0.3 * length(uv);

    float grain = hash21(uv * u_time) * 0.05;
    color += vec3(grain);
    FragColor = vec4(color, 1.0);
}

