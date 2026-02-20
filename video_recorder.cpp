#include "utils.h"
#include <iostream>
#include <fstream>
#include <sstream>
#include <vector>

// --- IMPLEMENTAZIONE VIDEO RECORDER ---

// 1. Apre il video
void VideoRecorder::start(const char* filename, int w, int h, int fps) {
    width = w;
    height = h;
    pixels.resize(width * height * 3);

    // Costruiamo il comando per FFmpeg
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
void VideoRecorder::captureFrame() {
    if (!ffmpegPipe) return;

    // Legge i pixel dallo schermo (GPU -> RAM)
    glReadPixels(0, 0, width, height, GL_RGB, GL_UNSIGNED_BYTE, pixels.data());

    // Scrive i dati grezzi nella pipe di FFmpeg
    if (ffmpegPipe) {
        fwrite(pixels.data(), 1, width * height * 3, ffmpegPipe);
    }
}

// 3. Chiude il file e salva
void VideoRecorder::stop() {
    if (ffmpegPipe) {
        std::cout << "Chiusura registrazione video..." << std::endl;
        #ifdef _WIN32
            _pclose(ffmpegPipe);
        #else
            pclose(ffmpegPipe);
        #endif
        ffmpegPipe = nullptr;
        std::cout << "Video salvato con successo!" << std::endl;
    }
}

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