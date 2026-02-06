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

vec3 blackbody_color(float temp) {
    vec3 col = vec3(255.0, 240.0, 220.0) / 255.0; // Base bianca
    col *= exp(vec3(1.0, 0.9, 0.8) * temp);       // Tinta basata sul calore
    return col;
}

//rd direzione in cui si sta muovemno la luce
//spezzettimao il vettore e ongi volta ricalcoliamo la direzione, se scappa via > 15 nero
vec3 render_Black_Hole(vec3 ro,vec3 rd) {
    vec3 p = ro;             // Posizione corrente del raggio
    vec3 col = vec3(0.0);    // Colore di sfondo (nero spaziale)
    vec3 glow = vec3(0.0);  // Raccoglie la luce del gas anche se il raggio non tocca il disco

    for(int i = 0; i < 500; i++) {

        float d = length(p); // Distanza del raggio dal centro (0,0,0)
        // 2. LENTE GRAVITAZIONALE (Einstein ring logic), calcoliamo quanto lo spazio è curvo in quella località
        float gravity = 0.05 / (d * d);
        //aggiornamento direzione
        rd = normalize(rd + normalize(-p) * gravity);
        // AVANZAMENTO DEL RAGGIO, spostimo il raggio di un passo fisso (0.1 unità)
        p += rd * 0.10;

        // 2. NUOVO: Calcolo del Glow Volumetrico
        // Più siamo vicini al disco (p.y vicino a 0) e al centro, più c'è "nebbia" luminosa
        float distToDisk = length(vec2(d - 3.5, p.y * 5.0)); // Distanza approssimata dalla ciambella
        glow += vec3(1.0, 0.4, 0.1) * 0.02 / (0.1 + distToDisk * distToDisk);

        // 1. ORIZZONTE DEGLI EVENTI, definisco in questo modo la grandezza del buco nero
        if(d < 1.0) {
            return vec3(0.0) + glow * 0.1;// Se entra nel buco nero, è nero assoluto
        }

        //uscita, stelle
        // USCITA STELLE: accorciamo la distanza necessaria
        if(length(p) > 25.0) {
            // 1. MOVIMENTO DINAMICO: aggiungiamo u_time alla direzione rd
            // Questo fa sì che le stelle "scorrano" lentamente dietro il buco nero
            vec3 starCoord = (rd + vec3(u_time * 0.005, 0.0, 0.0)) * 150.0;
            vec3 grid = floor(starCoord);

            // 2. Seme per ogni stella
            float s = fract(sin(dot(grid, vec3(12.989, 78.233, 45.164))) * 43758.5453);

            // 3. FORMA della stella
            float distToCenter = length(fract(starCoord) - 0.5);
            float variazione = pow(fract(s * 10.0), 3.0);
            float raggio_variabile = 0.01 + 0.7 * variazione; //ATTENZIONE
            float starShape = smoothstep(raggio_variabile, 0.0, distToCenter);
            // 4. BRILLAMENTO NATURALE (non intermittenza totale)
            // Usiamo una frequenza alta (10.0) ma un'ampiezza piccola (0.2)
            // La stella non si spegne mai, oscilla solo tra 0.8 e 1.2 di luminosità
            float brillamento = 1.0 + 0.2 * sin(u_time * 10.0 + s * 62.0);
            // 5. Risultato finale
            float finalStars = step(0.98, s) * starShape * brillamento;
            return vec3(finalStars) + glow * 0.3;
        }

        // 3. DISCO DI ACCRESCIMENTO REALISTICO
        if(abs(p.y) < 0.05 && d > 2.2 && d < 6.0) {
            // --- A. Coordinate Polari & Animazione ---
            // Trasformiamo la posizione 3D (x,z) in Angolo e Raggio
            float angle = atan(p.x, p.z);
            float radius = length(p.xz);

            // --- DILATAZIONE TEMPORALE (Time Dilation) ---
            // Formula di Schwarzschild: t' = t * sqrt(1 - rs/r)
            // rs (raggio Schwarzschild) nel nostro caso è 1.0
            // Più siamo vicini a 1.0, più il fattore tende a 0 (tempo fermo)
            float dilation = sqrt(clamp(1.0 - 1.0 / radius, 0.0, 1.0));
            float localTime = u_time * dilation;

            // Velocità differenziale: il centro gira più veloce dell'esterno (Legge di Keplero)
            float speed = 2.0 / (radius * radius) * dilation;

            float temperatura = 0.6 / (d - 2.5);
            vec3 diskColor = blackbody_color(temperatura);

            // Se il colore è troppo scuro, moltiplicalo qui:
            //diskColor *= 7; //ATTENZIONE




            // Creiamo la coordinata 2D animata per il noise
            // Usiamo 'angle' per la X (rotazione) e 'radius' per la Y (distanza)
            vec2 polarUV = vec2(angle * 3.0 - localTime * speed, radius - u_time * 0.5);

            // --- B. Turbolenza Frattale (fBM) ---
            float turbolenza = 0.0;
            float ampiezza = 0.5;
            float frequenza = 2.0;

            // NOTA: Usiamo 'j' invece di 'i' per non rompere il ciclo principale!
            for (int j = 0; j < 5; j++) {
                // Campioniamo il noise usando le coordinate polari
                float n = create_noise(polarUV * frequenza);

                // Opzionale: abs(n * 2.0 - 1.0) crea venature più simili al fuoco/elettricità
                turbolenza += n * ampiezza;

                frequenza *= 2.1; // Lacunarity
                ampiezza *= 0.45;  // Gain ridotto per dettagli fini
            }

            // Intensifichiamo l'effetto per creare "buchi" nel gas
            turbolenza = smoothstep(0.2, 0.9, turbolenza);

            // --- C. Colore e Fisica ---

            float alpha = smoothstep(0.05, 0.0, abs(p.y));
            //float temp = (d - 2.2) / 3.8;
            //vec3 hotColor = vec3(1.8, 1.3, 0.8); // Più luminoso del bianco (HDR)
            //vec3 coldColor = vec3(0.8, 0.1, 0.02);
            //vec3 diskColor = mix(hotColor, coldColor, temp);

            // Doppler (Luce relativistica)
            float doppler = 1.0 + dot(rd, vec3(1.0, 0.0, 0.0)) * 0.8;
            float innerEdge = smoothstep(2.6, 2.8, d);

            // Somma finale: Colore * Forma(Alpha) * Gas(Turbolenza) * Fisica(Doppler) + Glow
            return diskColor * alpha * turbolenza * doppler + glow * innerEdge;
        }
    }
    return col + glow;
}

void main() {
    // 1. Mapping corretto
    vec2 uv = (gl_FragCoord.xy / u_resolution.xy) * 2.0 - 1.0;
    // 2. Correzione Aspect Ratio
    float ratio = u_resolution.x / u_resolution.y;
    uv.x *= ratio;


    //definiamo la ray origin, il putno della fotocamera da dove guardare
    vec3 ro = vec3(0,0.7,-13.0);
    //definisce la direzione dello sguardo, 1.5 rappresenta lo zoom
    vec3 rd = normalize(vec3(uv, 1.5));


    // 3. Render: Qui otteniamo valori HDR (anche > 1.0)
    vec3 colore = render_Black_Hole(ro, rd);
    colore = aces_tonemap(colore);
    colore = pow(colore, vec3(1.0 / 1.5));




    //definiamo il ray direction
    //vec3 colore = render_Black_Hole(ro, rd);
    FragColor = vec4(colore, 1.0);
}