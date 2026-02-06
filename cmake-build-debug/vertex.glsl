#version 330 core
layout (location = 0) in vec2 aPos;

//Il vertex si occupa degli vertici
void main() {
    //Il Vertex Shader prende il primo punto del tuo rettangolo (es. l'angolo in alto a sinistra), lo impacchetta in un vec4 e lo consegna a gl_Position.
    //OpenGL vede quel valore e "pianta un chiodo" in quell'angolo della finestra. Ripete l'operazione per tutti e 4 i punti.
    gl_Position = vec4(aPos.x, aPos.y, 0.0, 1.0);
}