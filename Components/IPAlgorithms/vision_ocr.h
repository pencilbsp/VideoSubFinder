#pragma once

#include <opencv2/core.hpp>
#include <string>
#include <vector>
#include <memory>

struct VisionOCRResult {
    std::string text;
    float       confidence;
    cv::Rect2f  bbox_norm;  // normalized [0,1], top-left origin (OpenCV convention)
};

// Wraps VNRecognizeTextRequest (Apple Vision). Runs on ANE/GPU automatically.
class VisionOCR {
public:
    VisionOCR();
    ~VisionOCR();

    // BCP-47 language codes, e.g. {"zh-Hans", "zh-Hant", "en-US"}
    void set_languages(std::vector<std::string> langs);

    // Minimum confidence to keep a result (0..1). Default: 0.3
    void set_min_confidence(float t) { min_conf_ = t; }

    // true = VNRequestTextRecognitionLevelAccurate (default), false = Fast
    void set_accurate(bool accurate);

    // VNRecognizeTextRequest.usesLanguageCorrection. Default: true
    void set_language_correction(bool on);

    // VNRecognizeTextRequest.minimumTextHeight (0..1). Default: 0 (auto)
    void set_min_text_height(float h);

    // Recognize text in a BGR cv::Mat. Returns empty vector on failure or no text.
    std::vector<VisionOCRResult> recognize(const cv::Mat& bgr_frame);

    bool has_text(const cv::Mat& bgr_frame) { return !recognize(bgr_frame).empty(); }

private:
    struct Impl;
    std::unique_ptr<Impl> impl_;
    float min_conf_ = 0.3f;
};
