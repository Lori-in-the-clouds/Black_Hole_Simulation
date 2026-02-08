#include "glad/glad.h"
#include <GLFW/glfw3.h>
#include <iostream>
#include <sstream>
#include <fstream>
#include <cstdio>
#include <vector>


// --- INIZIO VIDEO RECORDER ---
struct VideoRecorder {
    FILE* ffmpegPipe = nullptr;
    int width, height;
    std::vector<unsigned char> pixels;

    // 1. Apre il video
    void start(const char* filename, int w, int h, int fps) {
        width = w;
        height = h;
        pixels.resize(width * height * 3);

        // Costruiamo il comando per FFmpeg
        // -y: sovrascrivi file
        // -f rawvideo: dati grezzi
        // -vcodec rawvideo: codec input nullo
        // -s: risoluzione
        // -pix_fmt rgb24: formato pixel OpenGL
        // -r: framerate
        // -i -: prende i dati dalla PIPE (stdin)
        // -vf vflip: OpenGL è a testa in giù, lo giriamo
        // -an: niente audio
        char cmd[512];
        sprintf(cmd,
            "ffmpeg -y -f rawvideo -vcodec rawvideo -s %dx%d -pix_fmt rgb24 -r %d -i - -vf vflip -c:v libx264 -preset ultrafast -qp 0 -pix_fmt yuv420p \"%s\"",
            width, height, fps, filename);

        std::cout << "Avvio registrazione: " << filename << "..." << std::endl;

        // Apre la pipe (Windows usa _popen, Linux/Mac usa popen)
        #ifdef _WIN32
            ffmpegPipe = _popen(cmd, "wb");
        #else
            ffmpegPipe = popen(cmd, "w");
        #endif

        if (!ffmpegPipe) {
            std::cerr << "ERRORE: Impossibile avviare FFmpeg! E' installato nel sistema?" << std::endl;
        }
    }

    // 2. Cattura il frame corrente e lo invia a FFmpeg
    void captureFrame() {
        if (!ffmpegPipe) return;

        // Legge i pixel dallo schermo (GPU -> RAM)
        glReadPixels(0, 0, width, height, GL_RGB, GL_UNSIGNED_BYTE, pixels.data());

        // Scrive i dati grezzi nella pipe di FFmpeg
        fwrite(pixels.data(), 1, width * height * 3, ffmpegPipe);
    }

    // 3. Chiude il file e salva
    void stop() {
        if (ffmpegPipe) {
            #ifdef _WIN32
                _pclose(ffmpegPipe);
            #else
                pclose(ffmpegPipe);
            #endif
            ffmpegPipe = nullptr;
            std::cout << "Video salvato con successo!" << std::endl;
        }
    }
};
// --- FINE VIDEO RECORDER ---
std::string readShaderFile(const char* filePath) {
    std::ifstream file(filePath);
    std::stringstream buffer;
    if (file.is_open()) {
        buffer << file.rdbuf();
        file.close();
        return buffer.str();
    } else {
        std::cerr << "ERRORE: Impossibile trovare il file: " << filePath << std::endl;
        return "";
    }
}



const int SCR_WIDTH = 3840;
const int SCR_HEIGHT = 2160;



int main() {
    // 1. Inizializza GLFW
    if (!glfwInit()) return -1;

    std::string vertexSourceStr = readShaderFile("vertex.glsl");
    std::string fragmentSourceStr = readShaderFile("fragment.glsl");
    const char* vertexShaderSource = vertexSourceStr.c_str();
    const char* fragmentShaderSource = fragmentSourceStr.c_str();


    // 2. IMPORTANTE PER MAC: Specifica la versione di OpenGL
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE);

    // 3. Crea la finestra
    GLFWwindow* window = glfwCreateWindow(SCR_WIDTH, SCR_HEIGHT, "Black Hole Simulation", NULL, NULL);
    if (!window) {
        glfwTerminate();
        return -1;
    }
    glfwMakeContextCurrent(window); //contenitore che contiene tutte le informazioni della simulazione

    // 4. ACCENDI IL TRADUTTORE (GLAD)
    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
        std::cout << "Errore nell'inizializzazione di GLAD" << std::endl;
        return -1;
    }

    // Compila Vertex Shader
    unsigned int vertexShader = glCreateShader(GL_VERTEX_SHADER); //crea un contenitore vuoto nella GPU
    glShaderSource(vertexShader, 1, &vertexShaderSource, NULL); //Prende la stringa di testo (quella che carichi dal file .glsl) e la "versa" dentro il contenitore appena creato.
    glCompileShader(vertexShader); //Copilazione

    // Compila Fragment Shader
    unsigned int fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fragmentShaderSource, NULL);
    glCompileShader(fragmentShader);

    // Crea il Programma Shader finale, colleghiamo i pezzi dentro l'involucro
    unsigned int shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);

    // Pulisci (non servono più i singoli pezzi)
    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    // 5. Ora puoi definire la geometria (perché GLAD è attivo)
    float vertices[] = {
        -1.0f,  1.0f,  // 0: Alto-Sinistra
         1.0f,  1.0f,  // 1: Alto-Destra
        -1.0f, -1.0f,  // 2: Basso-Sinistra
         1.0f, -1.0f   // 3: Basso-Destra
    };

    unsigned int indices[] = {
        0, 1, 2,
        1, 2, 3
    };

    unsigned int VAO, VBO, EBO;
    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);
    glGenBuffers(1, &EBO);

    glBindVertexArray(VAO);

    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    glBindBuffer(GL_ELEMENT_ARRAY_BUFFER, EBO);
    glBufferData(GL_ELEMENT_ARRAY_BUFFER, sizeof(indices), indices, GL_STATIC_DRAW);

    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    // 6. Loop principale
    int timeLocation = glGetUniformLocation(shaderProgram, "u_time");
    int resLocation = glGetUniformLocation(shaderProgram, "u_resolution");


    VideoRecorder recorder;
    int bufferWidth, bufferHeight;
    glfwGetFramebufferSize(window, &bufferWidth, &bufferHeight);
    recorder.start("buco_nero_interstellar.mp4", bufferWidth, bufferHeight, 60);

    int frameCount = 0;
    int maxFrames = 600;

    while (!glfwWindowShouldClose(window)) {
        // 1. Pulisci lo schermo
        glClearColor(0.0f, 0.0f, 0.0f, 1.0f);
        glClear(GL_COLOR_BUFFER_BIT);

        // 2. Attiva lo shader
        glUseProgram(shaderProgram);

        // 3. Gestisci la risoluzione DINAMICA
        int width, height;
        glfwGetFramebufferSize(window, &width, &height);
        glUniform2f(resLocation, (float)width, (float)height);

        // --- CANCELLA QUESTA RIGA: render_quad(); ---
        // L'abbiamo tolta perché il disegno lo fai qui sotto!

        // 4. Passa il tempo
        float timeValue = (float)glfwGetTime();
        glUniform1f(timeLocation, timeValue);

        // 5. DISEGNA (Questo è il tuo "render_quad" manuale)
        glBindVertexArray(VAO);
        glDrawElements(GL_TRIANGLES, 6, GL_UNSIGNED_INT, 0);

        // 6. CATTURA VIDEO
        if (frameCount < maxFrames) {
            // Nota: Se la finestra cambia dimensione, bisogna aggiornare width/height nel recorder
            // Ma per ora assumiamo resti fissa come da impostazioni iniziali
            recorder.captureFrame();

            if (frameCount % 60 == 0)
                std::cout << "Registrazione: " << frameCount << "/" << maxFrames << std::endl;

            frameCount++;
        } else if (frameCount == maxFrames) {
            recorder.stop();
            frameCount++;
            std::cout << "Rendering Finito!" << std::endl;
            glfwSetWindowShouldClose(window, true);
        }

        // 7. Swap e Poll
        glfwSwapBuffers(window);
        glfwPollEvents();
    }

    // Pulizia
    glDeleteVertexArrays(1, &VAO);
    glDeleteBuffers(1, &VBO);
    glDeleteBuffers(1, &EBO);

    glfwTerminate();
    return 0;
}