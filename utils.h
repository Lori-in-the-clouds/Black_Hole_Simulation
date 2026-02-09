#ifndef UTILS_H
#define UTILS_H
#include <vector>
#include <iostream>
#include <cstdio>
#include "glad/glad.h"
#include <string>
#include <vector>
#include <cstdio>

struct VideoRecorder {
    FILE* ffmpegPipe = nullptr;
    int width, height;
    std::vector<unsigned char> pixels;

    void start(const char* filename, int w, int h, int fps);
    void captureFrame();
    void stop();
};

std::string readShaderFile(const char* filePath);

#endif