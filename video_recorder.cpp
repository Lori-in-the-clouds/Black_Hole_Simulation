#include <cstdio>
#include <vector>
#include <iostream>

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