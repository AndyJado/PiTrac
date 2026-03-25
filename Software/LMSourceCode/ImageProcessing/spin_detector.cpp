/* SPDX-License-Identifier: GPL-2.0-only */
/*
 * Copyright (C) 2022-2026, Verdant Consultants, LLC.
 */

#include "spin_detector.hpp"
#include <chrono>

namespace golf_sim {

SpinDetector::SpinDetector(const Config& config)
    : config_(config) {}

SpinDetector::~SpinDetector() = default;

bool SpinDetector::Initialize() {
    if (initialized_) return true;

    // Configure NCNN runtime
    net_.opt.num_threads = config_.num_threads;
    net_.opt.use_fp16_packed = config_.use_fp16_packing;
    net_.opt.use_fp16_storage = config_.use_fp16_packing;
    net_.opt.use_fp16_arithmetic = false;  // Keep FP32 for regression accuracy
    net_.opt.lightmode = true;

    // Load model files
    int ret = net_.load_param(config_.param_path.c_str());
    if (ret != 0) {
        return false;
    }

    ret = net_.load_model(config_.bin_path.c_str());
    if (ret != 0) {
        return false;
    }

    // Pre-allocate resize buffers
    resized1_ = cv::Mat(config_.crop_size, config_.crop_size, CV_8UC1);
    resized2_ = cv::Mat(config_.crop_size, config_.crop_size, CV_8UC1);

    initialized_ = true;
    return true;
}

void SpinDetector::PreprocessCrop(const cv::Mat& crop, ncnn::Mat& out) {
    cv::Mat gray;

    // Ensure grayscale
    if (crop.channels() == 3) {
        cv::cvtColor(crop, gray, cv::COLOR_BGR2GRAY);
    } else {
        gray = crop;
    }

    // Resize to expected input size
    cv::Mat resized;
    if (gray.rows != config_.crop_size || gray.cols != config_.crop_size) {
        cv::resize(gray, resized, cv::Size(config_.crop_size, config_.crop_size),
                   0, 0, cv::INTER_LINEAR);
    } else {
        resized = gray;
    }

    // Convert to NCNN Mat: single channel, normalized to [0, 1]
    out = ncnn::Mat::from_pixels(resized.data, ncnn::Mat::PIXEL_GRAY,
                                  config_.crop_size, config_.crop_size);

    // Normalize: divide by 255
    const float norm_vals[1] = {1.0f / 255.0f};
    out.substract_mean_normalize(nullptr, norm_vals);
}

SpinDetector::SpinResult SpinDetector::Predict(
    const cv::Mat& ball_crop1, const cv::Mat& ball_crop2) {

    SpinResult result = {0.0f, 0.0f, 0.0f, 0.0f, false};

    if (!initialized_) return result;

    auto t_start = std::chrono::high_resolution_clock::now();

    // Preprocess both crops
    ncnn::Mat input1, input2;
    PreprocessCrop(ball_crop1, input1);
    PreprocessCrop(ball_crop2, input2);

    // The model expects two single-channel inputs stacked as a 2-channel input
    // Create a 2-channel input by concatenating along the channel dimension
    ncnn::Mat combined(config_.crop_size, config_.crop_size, 2);
    memcpy((float*)combined.channel(0), (float*)input1.channel(0),
           config_.crop_size * config_.crop_size * sizeof(float));
    memcpy((float*)combined.channel(1), (float*)input2.channel(0),
           config_.crop_size * config_.crop_size * sizeof(float));

    // Run inference
    ncnn::Extractor ex = net_.create_extractor();
    ex.set_num_threads(config_.num_threads);
    ex.input("in0", combined);

    ncnn::Mat output;
    ex.extract("out0", output);

    // Output is [3] tensor: rotation_x, rotation_y, rotation_z in degrees
    if (output.w >= 3) {
        result.rotation_x_deg = ((float*)output)[0];
        result.rotation_y_deg = ((float*)output)[1];
        result.rotation_z_deg = ((float*)output)[2];
        result.valid = true;
    }

    auto t_end = std::chrono::high_resolution_clock::now();
    result.inference_ms = std::chrono::duration<float, std::milli>(t_end - t_start).count();

    return result;
}

void SpinDetector::WarmUp(int iterations) {
    if (!initialized_) return;

    cv::Mat dummy1 = cv::Mat::zeros(config_.crop_size, config_.crop_size, CV_8UC1);
    cv::Mat dummy2 = cv::Mat::zeros(config_.crop_size, config_.crop_size, CV_8UC1);

    for (int i = 0; i < iterations; i++) {
        Predict(dummy1, dummy2);
    }
}

}  // namespace golf_sim
