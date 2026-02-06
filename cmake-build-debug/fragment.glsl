#version 330 core

out vec4 FragColor;
uniform vec2 u_resolution; // Assicurati che il nome sia identico al C++
uniform float u_time;

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
        p += rd * 0.15;

        // 2. NUOVO: Calcolo del Glow Volumetrico
        // Più siamo vicini al disco (p.y vicino a 0) e al centro, più c'è "nebbia" luminosa
        float distToDisk = length(vec2(d - 3.5, p.y * 5.0)); // Distanza approssimata dalla ciambella
        glow += vec3(1.0, 0.4, 0.1) * 0.02 / (0.1 + distToDisk * distToDisk);

        // 1. ORIZZONTE DEGLI EVENTI, definisco in questo modo la grandezza del buco nero
        if(d < 1.0) {
            return vec3(0.0) + glow * 0.2;// Se entra nel buco nero, è nero assoluto
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
            float raggio_variabile = 0.01 + 0.7 * variazione;
            float starShape = smoothstep(raggio_variabile, 0.0, distToCenter);
            // 4. BRILLAMENTO NATURALE (non intermittenza totale)
            // Usiamo una frequenza alta (10.0) ma un'ampiezza piccola (0.2)
            // La stella non si spegne mai, oscilla solo tra 0.8 e 1.2 di luminosità
            float brillamento = 1.0 + 0.2 * sin(u_time * 10.0 + s * 62.0);
            // 5. Risultato finale
            float finalStars = step(0.98, s) * starShape * brillamento;
            return vec3(finalStars) + glow * 0.5;
        }

        // 3. DISCO DI ACCRESCIMENTO REALISTICO
        if(abs(p.y) < 0.05 && d > 2.2 && d < 6.0) {
            // Sfumatura bordi (morbidezza)
            float alpha = smoothstep(0.05, 0.0, abs(p.y));

            // TEMPERATURA: Gradiente di colore
            // d=2.2 (vicino) -> Caldo (Giallo/Bianco)
            // d=6.0 (lontano) -> Freddo (Rosso scuro)
            float temp = (d - 2.2) / 3.8; // 0.0 interno, 1.0 esterno
            vec3 hotColor = vec3(1.5, 1.2, 0.8); // Bianco caldissimo
            vec3 coldColor = vec3(0.8, 0.1, 0.05); // Rosso cupo
            vec3 diskColor = mix(hotColor, coldColor, temp);

            // Pattern (Noise migliorato leggermente)
            float noise = 0.5 + 0.5 * sin(d * 20.0 - u_time * 4.0 + atan(p.x, p.z) * 5.0);

            // Doppler (luce più forte da un lato)
            float doppler = 1.0 + dot(rd, vec3(1.0, 0.0, 0.0)) * 0.7;

            // Somma finale: Colore Disco + Glow accumulato
            return diskColor * alpha * noise * doppler + glow;
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


    //definiamo il ray direction
    vec3 colore = render_Black_Hole(ro, rd);
    FragColor = vec4(colore, 1.0);
}