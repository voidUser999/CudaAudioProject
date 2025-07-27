// File: AudioFilter.cu
// Compile with:
//   nvcc -std=c++17 AudioFilter.cu -I/path/to/AudioFile -o bin/AudioFilter

#define DR_WAV_IMPLEMENTATION
#include "AudioFile.h"
#include <iostream>
#include <string>
#include <vector>
#include <cuda_runtime.h>
#include <filesystem>

namespace fs = std::filesystem;


// CUDA error-check helper
inline void checkCuda(cudaError_t err, const char *msg) {
    if (err != cudaSuccess) {
        std::cerr << "CUDA Error: " << msg
                  << " (" << cudaGetErrorString(err) << ")\n";
        std::exit(EXIT_FAILURE);
    }
}

// GPU kernel: low-pass FIR on interleaved data (supports N channels)
__global__
void lowPassInterleaved(const float* __restrict__ in,
                        float*       __restrict__ out,
                        int frames,
                        int channels,
                        int kernelRadius)
{
    int tid   = blockIdx.x * blockDim.x + threadIdx.x;
    int total = frames * channels;
    if (tid >= total) return;

    int frame = tid / channels;
    int ch    = tid % channels;

    float sum = 0.0f;
    int count = 0;
    for (int k = -kernelRadius; k <= kernelRadius; ++k) {
        int f = frame + k;
        if      (f <  0)      f = 0;
        else if (f >= frames) f = frames - 1;
        sum += in[f*channels + ch];
        ++count;
    }
    out[frame*channels + ch] = sum / float(count);
}


// Process a single WAV file: load, filter, save
void processFile(const fs::path &inPath, const fs::path &outPath) {
    std::cout << "Loading: " << inPath << "\n";
    AudioFile<float> audioFile;
    if (!audioFile.load(inPath.string())) {
        std::cerr << "ERROR: failed to load " << inPath << "\n";
        return;
    }

    int channels   = audioFile.getNumChannels();
    int frames     = audioFile.getNumSamplesPerChannel();
    int bitDepth   = audioFile.getBitDepth();
    float rate     = audioFile.getSampleRate();
    int samples    = frames * channels;

    std::cout << " Loaded " << samples << " samples @ "
              << rate << " Hz, " << bitDepth
              << "-bit, " << channels << "-channel\n";

    // Flatten interleaved host buffer
    std::vector<float> h_in(samples), h_out(samples);
    for (int ch = 0; ch < channels; ++ch) {
        const auto &chan = audioFile.samples[ch];
        for (int f = 0; f < frames; ++f) {
            h_in[f*channels + ch] = chan[f];
        }
    }

    // Allocate & copy to GPU
    float *d_in = nullptr, *d_out = nullptr;
    size_t bytes = size_t(samples) * sizeof(float);
    checkCuda(cudaMalloc(&d_in,  bytes), "cudaMalloc d_in");
    checkCuda(cudaMalloc(&d_out, bytes), "cudaMalloc d_out");
    checkCuda(cudaMemcpy(d_in, h_in.data(), bytes, cudaMemcpyHostToDevice),
              "H2D memcpy");
    std::cout << " Copied to GPU\n";

    // Launch kernel
    const int KERNEL_RADIUS = 16;   // radius -> taps = 2*radius+1
    int threads = 256;
    int blocks  = (samples + threads - 1) / threads;
    lowPassInterleaved<<<blocks, threads>>>(
        d_in, d_out, frames, channels, KERNEL_RADIUS
    );
    checkCuda(cudaPeekAtLastError(),  "kernel launch");
    checkCuda(cudaDeviceSynchronize(), "kernel sync");
    std::cout << " Low-pass FIR done (radius=" << KERNEL_RADIUS << ")\n";

    // Copy back & un-flatten
    checkCuda(cudaMemcpy(h_out.data(), d_out, bytes, cudaMemcpyDeviceToHost),
              "D2H memcpy");
    std::cout << " Copied back to host\n";

    AudioFile<float> outFile;
    outFile.setAudioBufferSize(channels, frames);
    outFile.setSampleRate(rate);
    outFile.setBitDepth(bitDepth);
    for (int ch = 0; ch < channels; ++ch) {
        for (int f = 0; f < frames; ++f) {
            outFile.samples[ch][f] = h_out[f*channels + ch];
        }
    }

    if (outFile.save(outPath.string())) {
        std::cout << " Saved filtered WAV to " << outPath << "\n";
    } else {
        std::cerr << "ERROR: failed to save " << outPath << "\n";
    }

    cudaFree(d_in);
    cudaFree(d_out);
}

int main(int argc, char** argv) {
    if (argc != 3) {
        std::cerr << "Usage: " << argv[0]
                  << " <input_dir> <output_dir>\n";
        return 1;
    }

    fs::path inDir  = argv[1];
    fs::path outDir = argv[2];

    // Create output directory
    fs::create_directories(outDir);

    for (auto &entry : fs::directory_iterator(inDir)) {
        if (!entry.is_regular_file()) continue;
        if (entry.path().extension() != ".wav") continue;

        fs::path inPath  = entry.path();
        std::string stem = inPath.stem().string();
        fs::path outPath = outDir / (stem + "_filtered.wav");

        processFile(inPath, outPath);
    }

    std::cout << "Done.\n";
    return 0;
}
