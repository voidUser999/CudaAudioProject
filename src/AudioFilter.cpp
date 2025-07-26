#define DR_WAV_IMPLEMENTATION
#include "dr_wav.h"

#include <iostream>
#include <string>
#include <vector>

void log_error(const char *message)
{
    std::cerr << "ERROR: " << message << std::endl;
}

int main(int argc, char **argv)
{
    if (argc != 3)
    {
        log_error("Usage: <program> <input_directory> <output_directory>");
        return 1;
    }

    std::string input_dir = argv[1];
    std::string output_dir = argv[2];

    std::string test_file_path = input_dir + "/violin.wav";
    std::cout << "Attempting to load file: " << test_file_path << std::endl;

    drwav wav; // Use a drwav object instead of loose variables

    // 1. Initialize the WAV file from the path.
    if (!drwav_init_file(&wav, test_file_path.c_str(), NULL))
    {
        log_error("Failed to open audio file.");
        return -1;
    }

    // 2. Allocate memory to hold all the audio data as 32-bit floats.
    float *pSampleData = new float[wav.totalPCMFrameCount * wav.channels];
    if (pSampleData == NULL)
    {
        log_error("Failed to allocate memory for audio data.");
        drwav_uninit(&wav);
        return -1;
    }

    // 3. Read all the audio frames into the allocated buffer.
    drwav_uint64 framesRead = drwav_read_pcm_frames_f32(&wav, wav.totalPCMFrameCount, pSampleData);

    if (framesRead != wav.totalPCMFrameCount)
    {
        log_error("Failed to read all audio frames.");
        delete[] pSampleData; // Clean up allocated memory
        drwav_uninit(&wav);
        return -1;
    }

    // If we get here, the file loaded successfully.
    std::cout << "✅ File loaded successfully!" << std::endl;
    std::cout << "  Channels: " << wav.channels << std::endl;
    std::cout << "  Sample Rate: " << wav.sampleRate << " Hz" << std::endl;
    std::cout << "  Total Frames/Samples: " << wav.totalPCMFrameCount << std::endl;

    // 4. Free the memory we allocated and uninitialize the WAV file.
    delete[] pSampleData;
    drwav_uninit(&wav);

    return 0;
}