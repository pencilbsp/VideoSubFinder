#include "vision_ocr.h"
#include <opencv2/imgproc.hpp>
#include <CoreGraphics/CoreGraphics.h>

#import <Vision/Vision.h>
#import <Foundation/Foundation.h>

// ── Impl ──────────────────────────────────────────────────────────────────────

struct VisionOCR::Impl {
    VNRecognizeTextRequest* request = nil;
};

// ── Helpers ───────────────────────────────────────────────────────────────────

static CGImageRef mat_to_cgimage(const cv::Mat& rgb) {
    CGColorSpaceRef cs = CGColorSpaceCreateDeviceRGB();
    CGDataProviderRef dp = CGDataProviderCreateWithData(
        nullptr, rgb.data,
        static_cast<size_t>(rgb.rows) * rgb.step[0],
        nullptr);
    CGImageRef img = CGImageCreate(
        static_cast<size_t>(rgb.cols),
        static_cast<size_t>(rgb.rows),
        8, 24,
        rgb.step[0],
        cs,
        kCGBitmapByteOrderDefault | kCGImageAlphaNone,
        dp, nullptr, false,
        kCGRenderingIntentDefault);
    CGDataProviderRelease(dp);
    CGColorSpaceRelease(cs);
    return img;
}

// ── VisionOCR ─────────────────────────────────────────────────────────────────

VisionOCR::VisionOCR() : impl_(std::make_unique<Impl>()) {
    @autoreleasepool {
        impl_->request = [[VNRecognizeTextRequest alloc] init];
        impl_->request.recognitionLevel = VNRequestTextRecognitionLevelAccurate;
        impl_->request.usesLanguageCorrection = YES;
        impl_->request.recognitionLanguages = @[@"zh-Hans", @"zh-Hant", @"en-US"];
    }
}

VisionOCR::~VisionOCR() = default;

void VisionOCR::set_languages(std::vector<std::string> langs) {
    @autoreleasepool {
        NSMutableArray<NSString*>* arr = [NSMutableArray array];
        for (const auto& l : langs)
            [arr addObject:[NSString stringWithUTF8String:l.c_str()]];
        impl_->request.recognitionLanguages = arr;
    }
}

void VisionOCR::set_accurate(bool accurate) {
    impl_->request.recognitionLevel = accurate
        ? VNRequestTextRecognitionLevelAccurate
        : VNRequestTextRecognitionLevelFast;
}

void VisionOCR::set_language_correction(bool on) {
    impl_->request.usesLanguageCorrection = on ? YES : NO;
}

void VisionOCR::set_min_text_height(float h) {
    impl_->request.minimumTextHeight = h;
}

std::vector<VisionOCRResult> VisionOCR::recognize(const cv::Mat& bgr_frame) {
    if (bgr_frame.empty()) return {};

    std::vector<VisionOCRResult> results;

    @autoreleasepool {
        cv::Mat rgb;
        cv::cvtColor(bgr_frame, rgb, cv::COLOR_BGR2RGB);

        CGImageRef cg = mat_to_cgimage(rgb);
        if (!cg) return {};

        NSError* err = nil;
        VNImageRequestHandler* handler =
            [[VNImageRequestHandler alloc] initWithCGImage:cg options:@{}];
        CGImageRelease(cg);

        BOOL ok = [handler performRequests:@[impl_->request] error:&err];
        if (!ok || err) return {};

        for (VNRecognizedTextObservation* obs in impl_->request.results) {
            VNRecognizedText* top = [obs topCandidates:1].firstObject;
            if (!top || top.confidence < min_conf_) continue;
            CGRect vbox = obs.boundingBox;
            cv::Rect2f bbox(
                static_cast<float>(vbox.origin.x),
                static_cast<float>(1.0 - vbox.origin.y - vbox.size.height),
                static_cast<float>(vbox.size.width),
                static_cast<float>(vbox.size.height));
            results.push_back({
                std::string([top.string UTF8String]),
                static_cast<float>(top.confidence),
                bbox
            });
        }
    }

    return results;
}
