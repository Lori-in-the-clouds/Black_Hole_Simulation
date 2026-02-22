#include "glad/glad.h"
#include <GLFW/glfw3.h>
#include "utils.h"
#include <iostream>
#include <vector>

const int SCR_WIDTH = 1920;
const int SCR_HEIGHT = 1080;

int main(int argc, char* argv[]) {
    // 1. Inizializzazione Base
    if (!glfwInit()) return -1;
    glfwWindowHint(GLFW_CONTEXT_VERSION_MAJOR, 3);
    glfwWindowHint(GLFW_CONTEXT_VERSION_MINOR, 3);
    glfwWindowHint(GLFW_OPENGL_PROFILE, GLFW_OPENGL_CORE_PROFILE);
    glfwWindowHint(GLFW_OPENGL_FORWARD_COMPAT, GL_TRUE); // Necessario su Mac

    GLFWwindow* window = glfwCreateWindow(SCR_WIDTH, SCR_HEIGHT, "Black Hole Simulation", NULL, NULL);
    if (!window) { glfwTerminate(); return -1; }
    glfwMakeContextCurrent(window);

    if (!gladLoadGLLoader((GLADloadproc)glfwGetProcAddress)) {
        std::cout << "Errore GLAD" << std::endl;
        return -1;
    }

    // 2. Compilazione Shader (Caricati dai file)
    std::string vSource = readShaderFile("vertex.glsl");
    std::string fSource = readShaderFile("fragment.glsl");
    const char* vShaderCode = vSource.c_str();
    const char* fShaderCode = fSource.c_str();

    unsigned int vertexShader = glCreateShader(GL_VERTEX_SHADER);
    glShaderSource(vertexShader, 1, &vShaderCode, NULL);
    glCompileShader(vertexShader);

    unsigned int fragmentShader = glCreateShader(GL_FRAGMENT_SHADER);
    glShaderSource(fragmentShader, 1, &fShaderCode, NULL);
    glCompileShader(fragmentShader);

    unsigned int shaderProgram = glCreateProgram();
    glAttachShader(shaderProgram, vertexShader);
    glAttachShader(shaderProgram, fragmentShader);
    glLinkProgram(shaderProgram);

    glDeleteShader(vertexShader);
    glDeleteShader(fragmentShader);

    // 3. Geometria Semplificata (Triangle Strip)
    // Non servono indici (EBO). Basta definire i 4 angoli nell'ordine giusto per una "Z".
    float vertices[] = {
        -1.0f,  1.0f, // Alto-SX
        -1.0f, -1.0f, // Basso-SX
         1.0f,  1.0f, // Alto-DX
         1.0f, -1.0f  // Basso-DX
    };

    unsigned int VAO, VBO;
    glGenVertexArrays(1, &VAO);
    glGenBuffers(1, &VBO);

    glBindVertexArray(VAO);
    glBindBuffer(GL_ARRAY_BUFFER, VBO);
    glBufferData(GL_ARRAY_BUFFER, sizeof(vertices), vertices, GL_STATIC_DRAW);

    // Diciamo a OpenGL che ogni vertice ha 2 float (x, y)
    glVertexAttribPointer(0, 2, GL_FLOAT, GL_FALSE, 2 * sizeof(float), (void*)0);
    glEnableVertexAttribArray(0);

    // 4. Setup Registrazione
    int w, h;
    glfwGetFramebufferSize(window, &w, &h);
    glViewport(0, 0, w, h);

    std::vector<int> video_scenarios = {};

    if (argc > 1) {
        for (int i = 1; i < argc; i++) {
            try {
                video_scenarios.push_back(std::stoi(argv[i]));
            } catch (...) {
                std::cout << "Argomento non valido ignorato: " << argv[i] << std::endl;
            }
        }
    } else {
        // Se non inserisci nulla, possiamo mettere uno scenario di default (es. lo scenario 5)
        std::cout << "Nessuno scenario specificato. Uso lo scenario di default: 6" << std::endl;
        video_scenarios.push_back(6);
    }

    // Uniform Locations (le cerchiamo una volta sola)
    int timeLoc = glGetUniformLocation(shaderProgram, "u_time");
    int resLoc = glGetUniformLocation(shaderProgram, "u_resolution");
    int video_types = glGetUniformLocation(shaderProgram, "u_scenario");



    for (int i = 0; i < video_scenarios.size(); i++) {

        std::string fileName = "/Users/lorenzodimaio/Documents/Black_Hole_Simulation/videos/render_scenario_" + std::to_string(video_scenarios[i]) + ".mp4";
        std::cout << "\n>>> STARTING RENDER: " << fileName << std::endl;
        VideoRecorder recorder;
        recorder.start(fileName.c_str(), w, h, 60);

        int frameCount = 0;
        int maxFrames = 1500; // 20 secondi di video a 60fps

        while (frameCount < maxFrames) {
            if (glfwWindowShouldClose(window)) break;

            glClear(GL_COLOR_BUFFER_BIT);
            glUseProgram(shaderProgram);

            float currentSimTime = (float)frameCount / 60.0f;
            // Passa Uniforms
            glUniform2f(resLoc, (float)w, (float)h);
            glUniform1f(timeLoc, currentSimTime);
            glUniform1i(video_types, video_scenarios[i]);

            // Disegna (Triangle Strip invece di Triangles + EBO)
            glBindVertexArray(VAO);
            glDrawArrays(GL_TRIANGLE_STRIP, 0, 4);

            recorder.captureFrame();
            if (frameCount % 60 == 0) std::cout << "Rendering: " << (int)((float)frameCount/maxFrames*100) << "%" << std::endl;
            frameCount++;

            glfwSwapBuffers(window);
            glfwPollEvents();
        }
        recorder.stop();
        std::cout << ">>> Video " << fileName << " completato!" << std::endl;

        // Se l'utente ha premuto la X sulla finestra durante il render, usciamo dal ciclo FOR
        if (glfwWindowShouldClose(window)) break;
    }

    // Pulizia finale
    glDeleteVertexArrays(1, &VAO);
    glDeleteBuffers(1, &VBO);
    glfwTerminate();
    return 0;
}