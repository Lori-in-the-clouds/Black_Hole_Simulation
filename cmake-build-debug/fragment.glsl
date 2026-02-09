#version 330 core

out vec4 FragColor;
uniform vec2 u_resolution;
uniform float u_time;



// Funzione ACES: Trasforma la luce HDR in colori "pellicola"
vec3 aces_tonemap(vec3 x) {
    const float a = 2.51;
    const float b = 0.03;
    const float c = 2.43;
    const float d = 0.59;
    const float e = 0.14;
    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
}


// Funzione per generare numeri pseudo-casuali da coordinate 2D
float hash21(vec2 p) {
    p = fract(p * vec2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

// Value Noise 2D: Prende una posizione e restituisce un valore liscio tra 0 e 1
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

// COLORE DARK (La tua funzione personalizzata)
// COLORE "INTERSTELLAR" (Bronzo, Rosso Scuro e Oro)
// COLORE "INTERSTELLAR" SCURO (Bronzo profondo)
// COLORE "MAGMA" (Oro vivo al centro, Rosso fuoco ai bordi)
// COLORE "CLASSIC GOLD" (Il look delle tue immagini preferite)
vec3 blackbody_color(float temp) {
    // 1. BASE COLOR:
    // Rosso alto (3.5) + Verde medio (1.1).
    // Questo mix (Rosso + Verde) crea il GIALLO/ORO intenso che ti piaceva.
    vec3 baseColor = vec3(3.5, 1.1, 0.2);

    // 2. PESI (Soglie):
    // Il blu (4.0) è alto per mantenere il cuore caldo e non bianco ghiaccio.
    vec3 color_weights = vec3(0.1, 1.0, 4.0);

    return baseColor * exp(-color_weights / max(0.001, temp));
}

// Noise fluido per simulare il plasma
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

//rd direzione in cui si sta muovemno la luce
//spezzettimao il vettore e ongi volta ricalcoliamo la direzione, se scappa via > 15 nero
vec3 render_Black_Hole(vec3 ro,vec3 rd) {
    vec3 p = ro;             // Posizione corrente del raggio
    vec3 col = vec3(0.0);    // Colore di sfondo (nero spaziale)
    vec3 glow = vec3(0.0);  // Raccoglie la luce del gas anche se il raggio non tocca il disco

    for(int i = 0; i < 1000; i++) {

        float d = length(p); // Distanza del raggio dal centro (0,0,0)
        // 2. LENTE GRAVITAZIONALE (Einstein ring logic), calcoliamo quanto lo spazio è curvo in quella località
        float gravity = 0.05/ (d * d);
        //aggiornamento direzione
        rd = normalize(rd + normalize(-p) * gravity);
        // AVANZAMENTO DEL RAGGIO, spostimo il raggio di un passo fisso (0.1 unità)
        // Il passo è una percentuale della distanza 'd'.
        // Se d=10, il passo è 0.4. Se d=1, il passo è 0.04.
        // max(0.005, ...) assicura che non diventi mai troppo piccolo (loop infinito)
        // min(0.2, ...) assicura che non diventi mai troppo grande (salti enormi)
        float stepSize = max(0.005, min(0.2, d * 0.04));

        // Rallentiamo ulteriormente SOLO se siamo proprio dentro il disco sottile
        if(abs(p.y) < 0.05 && d < 6.0) stepSize *= 0.5;

        p += rd * stepSize;

        // 2. NUOVO: Calcolo del Glow Volumetrico
        // Più siamo vicini al disco (p.y vicino a 0) e al centro, più c'è "nebbia" luminosa
        float distToDisk = length(vec2(d - 3.5, p.y * 5.0)); // Distanza approssimata dalla ciambella
        glow += vec3(1.4* 0.4, 0.4*0.4, 0.1*0.4) * 0.09 / (0.1 + distToDisk * distToDisk);

        // 1. ORIZZONTE DEGLI EVENTI, definisco in questo modo la grandezza del buco nero
        if(d < 1.0) {
            return vec3(0.0) + glow * 0.1;// Se entra nel buco nero, è nero assoluto
        }


        // USCITA STELLE: accorciamo la distanza necessaria
        if(length(p) > 25.0) {
            // 1. MOVIMENTO DINAMICO: aggiungiamo u_time alla direzione rd
            // Questo fa sì che le stelle "scorrano" lentamente dietro il buco nero
            vec3 starCoord = (rd + vec3(u_time * 0.005, 0.0, 0.0)) * 400.0;
            vec3 grid = floor(starCoord);

            // 2. Seme per ogni stella
            float s = fract(sin(dot(grid, vec3(12.989, 78.233, 45.164))) * 43758.5453);

            // 3. FORMA della stella
            float distToCenter = length(fract(starCoord) - 0.5);
            float variazione = pow(fract(s * 10.0), 3.0);
            float raggio_variabile = 0.01 + 0.8 * variazione; //ATTENZIONE
            float starShape = smoothstep(raggio_variabile, 0.0, distToCenter);
            // 4. BRILLAMENTO NATURALE (non intermittenza totale)
            // Usiamo una frequenza alta (10.0) ma un'ampiezza piccola (0.2)
            // La stella non si spegne mai, oscilla solo tra 0.8 e 1.2 di luminosità
            float brillamento = 1.0 + 0.2 * sin(u_time * 10.0 + s * 62.0);
            // 5. Risultato finale
            float finalStars = step(0.85, s) * starShape * brillamento;
            return vec3(finalStars) + glow * 0.3;
        }

        // 3. DISCO DI ACCRESCIMENTO REALISTICO
        // 3. DISCO DI ACCRESCIMENTO
        if(abs(p.y) < 0.05 && d > 2.2 && d < 6.0) {

            float angle = atan(p.x, p.z);
            float radius = length(p.xz);

            // Time Dilation & Velocità
            float dilation = sqrt(clamp(1.0 - 1.0 / radius, 0.0, 1.0));
            float localTime = u_time * dilation;
            float speed = 2.0 / (radius * radius) * dilation;

            // --- A. TEXTURE DEL GAS (Qui usiamo flowNoise!) ---

            // Definiamo le coordinate UV polari.
            // angle * 6.0: Aumentiamo il moltiplicatore per avere più "strisce" sottili
            vec2 polarUV = vec2(angle * 6.0 - localTime * speed, radius - u_time * 0.2);

            // CHIAMATA ALLA FUNZIONE FLUIDA
            float gasPattern = flowNoise(polarUV);

            // Aumentiamo il contrasto per rendere le venature del gas ben visibili
            gasPattern = smoothstep(0.3, 0.8, gasPattern);


            // --- B. & C. FISICA RELATIVISTICA COMPLETA ---

            float alpha = smoothstep(0.05, 0.0, abs(p.y));

            // 1. CALCOLO VELOCITÀ DEL GAS
            // Il gas ruota nel piano XZ. Calcoliamo il vettore tangente (velocità).
            vec3 velocity = normalize(cross(vec3(0.0, 1.0, 0.0), p));

            // 2. PROIEZIONE DOPPLER
            // Calcoliamo quanto il gas si sta muovendo verso la telecamera (rd)
            float v_proj = dot(rd, velocity);

            // 3. RELATIVISTIC BEAMING (Il "Faro")
            // Il gas che viene verso di noi (v_proj > 0) diventa esponenzialmente più luminoso.
            // Il gas che si allontana diventa buio.
            // "pow(..., 3.5)" aumenta drasticamente il contrasto tra i due lati.
            float beaming = pow(1.0 + v_proj * 0.5, 3.5);

            // 4. REDSHIFT GRAVITAZIONALE (Luce Stanca)
            // La luce perde energia cercando di uscire dal pozzo gravitazionale.
            // Più siamo vicini a 1.0 (Raggio di Schwarzschild), più il valore scende a 0 (nero).
            // Formula approssimata della metrica di Schwarzschild:
            float g_redshift = sqrt(clamp(1.0 - 1.2 / d, 0.0, 1.0)); // 1.2 per scurire prima dell'orizzonte
            g_redshift = pow(g_redshift, 2.0); // Rendiamo la curva più ripida

            // 5. CALCOLO TEMPERATURA E COLORE
            // Temperatura base: più caldo vicino al centro
            float baseTemp = 0.6 / (d - 2.0);

            // Applichiamo la fisica alla temperatura:
            // - Beaming: alza la temperatura a sinistra (Blu/Bianco), la abbassa a destra (Rosso)
            // - Redshift: abbassa la temperatura ovunque vicino al buco (Rosso Scuro -> Nero)
            float finalTemp = baseTemp * beaming * g_redshift;

            vec3 diskColor = blackbody_color(finalTemp);

            // Boost luminosità (necessario perché il redshift scurisce molto l'immagine)
            diskColor *= 0.25;

            // 6. BORDI E PULIZIA
            // ISCO: Inner Stable Circular Orbit (taglio netto interno)
            float innerEdge = smoothstep(2.6, 2.65, d);

            // Somma finale
            // Nota: gasPattern arriva dalla Parte A che hai già scritto sopra
            // Aggiungiamo 'outerEdge' per sfumare dolcemente il bordo esterno a distanza 6.0
            float outerEdge = smoothstep(6.5, 3.5, d);
            return diskColor * alpha * gasPattern * innerEdge * outerEdge + glow;
        }

    }
    return col + glow;
}

void main() {
    // 1. Setup Coordinate Schermo
    vec2 uv = (gl_FragCoord.xy / u_resolution.xy) * 2.0 - 1.0;
    float ratio = u_resolution.x / u_resolution.y;
    uv.x *= ratio;

    // --- 2. ANIMAZIONE CAMERA (ORBITALE LENTA) ---

    float dist = 20.0;             // Distanza
    // MODIFICA 1: Velocità ridotta da 0.1 a 0.03 per un movimento lento
    float speed = 0.06;
    float height = 3.5 * sin(u_time * 0.05); // Oscillazione verticale lenta

    // Calcolo posizione Camera (Ray Origin - ro)
    vec3 ro = vec3(sin(u_time * speed) * dist, height, cos(u_time * speed) * dist);

    // --- 3. SISTEMA DI PUNTAMENTO (LOOK AT) ---
    vec3 target = vec3(0.0); // Guardiamo il centro

    vec3 forward = normalize(target - ro);
    vec3 right = normalize(cross(vec3(0.0, 1.0, 0.0), forward));
    vec3 up = cross(forward, right);

    float zoom = 1.5;

    // --- 4. LANCIO RAGGIO SINGOLO (PULITO) ---
    // MODIFICA 2: Rimossa l'aberrazione cromatica.
    // Calcoliamo una sola direzione (rd) per pixel.
    vec3 rd = normalize(forward * zoom + right * uv.x + up * uv.y);

    // --- 5. RENDERIZZAZIONE ---
    // Un solo rendering, immagine nitida.
    vec3 colore = render_Black_Hole(ro, rd);

    // Tone Mapping & Gamma
    colore = aces_tonemap(colore);
    colore = pow(colore, vec3(1.0 / 2.2));

    // Vignettatura leggera (scurisce gli angoli)
    colore *= 1.0 - 0.3 * length(uv);

    FragColor = vec4(colore, 1.0);
}
