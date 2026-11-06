-- CMake (cmake-language-server).
return {
    cmd = { 'cmake-language-server' },
    filetypes = { 'cmake' },
    root_markers = { 'CMakeLists.txt', 'CMakePresets.json', '.git' },
    init_options = { buildDirectory = 'build' },
}
