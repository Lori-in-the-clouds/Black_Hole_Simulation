cmake_minimum_required(VERSION 3.20)
project(BlackHoleSimulation)

set(CMAKE_CXX_STANDARD 17)

# 1. Diciamo a CMake dove cercare le librerie di Homebrew (fondamentale su Apple Silicon)
link_directories(/opt/homebrew/lib)
include_directories(/opt/homebrew/include)

# 2. Definiamo l'eseguibile
add_executable(BlackHoleSimulation main.cpp glad.c video_recorder.cpp)


# 3. Specifichiamo i percorsi degli header locali (glad/KHR)
target_include_directories(BlackHoleSimulation PRIVATE ${CMAKE_CURRENT_SOURCE_DIR})

# 4. Troviamo GLFW in modo esplicito
find_library(GLFW_LIB glfw PATHS /opt/homebrew/lib)

# 5. Colleghiamo TUTTO
target_link_libraries(BlackHoleSimulation
        ${GLFW_LIB}
        "-framework OpenGL"
        "-framework Cocoa"
        "-framework IOKit"
        "-framework CoreVideo"
)

configure_file(vertex.glsl vertex.glsl COPYONLY)
configure_file(fragment.glsl fragment.glsl COPYONLY)