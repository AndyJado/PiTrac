/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Copyright (C) 2022-2026, Verdant Consultants, LLC.
 *
 * ML-based spin prediction from ball image pairs.
 * Replaces the brute-force 3D rotation search (~800ms) with a trained
 * regression model (~10ms) that predicts rotation angles directly.
 */

#pragma once

#include <ncnn/net.h>
#include <opencv2/opencv.hpp>
#include <string>
#include <mutex>
#include <atomic>

namespace golf_sim {

class SpinDetector {
public:
    struct SpinResult {
        float rotation_x_deg;   // Pitch rotation in degrees
        float rotation_y_deg;   // Yaw rotation in degrees
        float rotation_z_deg;   // Roll rotation in degrees
        float inference_ms;     // Inference time
        bool valid;             // Whether inference succeeded
    };

    struct Config {
        std::string param_path;         // NCNN .param file
        std::string bin_path;           // NCNN .bin file
        int crop_size = 128;            // Expected input crop size (must match training)
        int num_threads = 3;            // Inference threads
        bool use_fp16_packing = true;   // ARM FP16 optimization
    };

    explicit SpinDetector(const Config& config);
    ~SpinDetector();

    bool Initialize();

    // Predict rotation between two ball crops
    // Both crops must be square grayscale images of crop_size x crop_size
    SpinResult Predict(const cv::Mat& ball_crop1, const cv::Mat& ball_crop2);

    void WarmUp(int iterations = 3);

    bool IsInitialized() const { return initialized_; }

private:
    Config config_;
    ncnn::Net net_;
    bool initialized_ = false;

    // Pre-allocated buffers
    cv::Mat resized1_;
    cv::Mat resized2_;

    // Preprocess a ball crop: resize + normalize to [0, 1]
    void PreprocessCrop(const cv::Mat& crop, ncnn::Mat& out);
};

}  // namespace golf_sim
