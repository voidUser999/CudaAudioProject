# CUDA-Accelerated Audio Filter

## Overview

This project is a command-line utility that demonstrates GPU acceleration for audio processing. It processes a directory of `.wav` files, applies a low-pass filter (moving average) to each one using a custom CUDA kernel, and saves the filtered audio to an output directory. The CUDA kernel is designed to efficiently handle interleaved, multi-channel audio data.

This project was developed for the "CUDA at Scale for the Enterprise" course.

---

## Dependencies

* **CUDA Toolkit 11.4** or newer.
* A C++ compiler that supports the **C++17 standard** (e.g., g++ 7 or newer).
* The `AudioFile.h` library is included in the `src/` directory.

---

## Code Organization

* `src/`: Contains all source code (`AudioFilter.cu`) and the required `AudioFile.h` library.
* `data/`: Contains an `input/` folder for your source `.wav` files and an `output/` folder where the results are saved.
* `bin/`: Stores the compiled executable, `AudioFilter`.
* `Makefile`: The script used to build the project.

---

## How to Build

To compile the project, navigate to the root directory in your terminal and run the `make` command.

```bash
make

```
## How to Run

Place your .wav files in the data/input directory.

Run the program using the make run shortcut:

```bash
make run
```
##Algorithm Details
The core of the signal processing is a custom CUDA kernel named lowPassInterleaved. Each CUDA thread is assigned to calculate a single output sample. The kernel handles interleaved, multi-channel audio by calculating the correct frame and channel for each sample's global index. The filter is a moving average with a configurable radius, implemented with boundary clamping to correctly process samples at the beginning and end of the signal


##Output Files
Genrated .wav files are present in CudaAudioProject>data>output.









