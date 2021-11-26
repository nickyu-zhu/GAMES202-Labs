#include "denoiser.h"

Denoiser::Denoiser() : m_useTemportal(false) {}

void Denoiser::Reprojection(const FrameInfo &frameInfo) {
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    Matrix4x4 preWorldToScreen =
        m_preFrameInfo.m_matrix[m_preFrameInfo.m_matrix.size() - 1];
    Matrix4x4 preWorldToCamera =
        m_preFrameInfo.m_matrix[m_preFrameInfo.m_matrix.size() - 2];
#pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            int id = static_cast<int>(frameInfo.m_id(x, y));
            if (id != -1) {
            // TODO: Reproject

                Float3 world_i = frameInfo.m_position(x, y);
                Matrix4x4 Last_Matrix = preWorldToCamera *
                                        m_preFrameInfo.m_matrix[id] *
                                        Inverse(frameInfo.m_matrix[id]);
                Float3 pre_screen_cor = Last_Matrix(world_i, Float3::Point);
                int pre_frame_x = static_cast<int>(pre_screen_cor.x);
                int pre_frame_y = static_cast<int>(pre_screen_cor.y);

                if ((pre_frame_x < width) && (pre_frame_y < height) &&
                    (pre_frame_x >= 0) && (pre_frame_y >= 0) &&
                    static_cast<int> (m_preFrameInfo.m_id(pre_frame_x, pre_frame_y)) == id ) {

                    m_valid(x, y) = true;
                    m_misc(x, y) = m_accColor(pre_frame_x,pre_frame_y);
                    
                } else {

                    m_valid(x, y) = false;
                    m_misc(x, y) = frameInfo.m_beauty(x, y);
                }
                
            } else {
                m_valid(x, y) = false;
                m_misc(x, y) = frameInfo.m_beauty(x,y);
            }


           /* m_valid(x, y) = false;
            m_misc(x, y) = Float3(0.f);*/
        }
    }
    std::swap(m_misc, m_accColor);
}

void Denoiser::TemporalAccumulation(const Buffer2D<Float3> &curFilteredColor) {
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    int kernelRadius = 16;
// #pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Temporal clamp
            Float3 sum_Color = Float3(0.f);
            Float3 variance = Float3(0.f);
            
            int kernel = kernelRadius;
            int count = 0;
            
            
            for (int j = y - kernel; j < height && j <= y + kernel; j++)
                for (int i = x - kernel; i < width && i <= x + kernel; i++)
                {
                    if ( j < 0 || i < 0)
                        continue;
                    sum_Color += m_accColor(i, j);
                    count++;
                    
                }
            Float3 mean = sum_Color / (static_cast<float>(count));
           
            for (int j = y - kernel; j < height && j <= y + kernel; j++)
                for (int i = x - kernel; i < width && i <= x + kernel; i++) {

                   if (j < 0 || i < 0)
                        continue;
                   variance += Sqr(m_accColor(i, j) - mean);

                }
            variance = variance / Sqr(static_cast<float>(count));
            
            variance = SafeSqrt(variance);

            Float3 color = Clamp(m_accColor(x, y), mean - variance * m_colorBoxK,
                                     mean + variance * m_colorBoxK);


            // TODO: Exponential moving average
            float alpha = 1;
            if (m_valid(x, y))
                alpha = m_alpha;
        
            m_misc(x, y) = Lerp(color, curFilteredColor(x, y), alpha);


            /* Float3 color = curFilteredColor(x, y);
            // TODO: Exponential moving average
            float alpha = 1.0f;
            m_misc(x, y) = Lerp(color, curFilteredColor(x, y), alpha);*/
        }
    }
    std::swap(m_misc, m_accColor);
}

Buffer2D<Float3> Denoiser::Filter(const FrameInfo &frameInfo) {
    int height = frameInfo.m_beauty.m_height;
    int width = frameInfo.m_beauty.m_width;
    Buffer2D<Float3> filteredImage_1 = CreateBuffer2D<Float3>(width, height);
    Buffer2D<Float3> filteredImage_2 = CreateBuffer2D<Float3>(width, height);
    int kernelRadius = 32;
    int max_pass = 5;

// pass 0
   #pragma omp parallel for
    for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
            // TODO: Joint bilateral filter

            Float3 currentColor = frameInfo.m_beauty(x, y);
            Float3 currentPosition = frameInfo.m_position(x, y);

            Float3 currentNormal = (SqrLength(frameInfo.m_normal(x, y)) != 0.0f)
                                       ? Normalize(frameInfo.m_normal(x, y))
                                       : 0;

            Float3 sum_weighted_value = Float3(0.f);
            float sum_weight = 0.0f;

            kernelRadius = 2;

            for (int filter_X = -kernelRadius; filter_X <= kernelRadius; filter_X++)
                for (int filter_Y = -kernelRadius; filter_Y <= kernelRadius; filter_Y++) {
                    int sample_X = std::min(std::max(filter_X + x, 0), width - 1);
                    int sample_Y = std::min(std::max(filter_Y + y, 0), height - 1);

                    Float3 sampleColor = frameInfo.m_beauty(sample_X, sample_Y);
                    Float3 samplePosition = frameInfo.m_position(sample_X, sample_Y);

                    Float3 sampleNormal =
                        (SqrLength(frameInfo.m_normal(sample_X, sample_Y)) != 0.0f)
                            ? Normalize(frameInfo.m_normal(sample_X, sample_Y))
                            : 0;

                    float gaussianTerm = (Sqr(static_cast<float>(sample_X - x)) +
                                          Sqr(static_cast<float>(sample_Y - y))) /
                                         (2.0f * m_sigmaCoord * m_sigmaCoord);

                    float colorTerm = SqrLength(currentColor - sampleColor) /
                                      (2.0f * m_sigmaColor * m_sigmaColor);

                    float normalTerm = Sqr(SafeAcos(Dot(currentNormal, sampleNormal))) /
                                       (2.0f * m_sigmaNormal * m_sigmaNormal);

                    Float3 dir = samplePosition - currentPosition;
                    float D_plane = (SqrLength(dir) != 0.0f)
                                        ? Dot(currentNormal, Normalize(dir))
                                        : 1.0f;
                    float depthTerm = Sqr(D_plane) / (2.0f * m_sigmaPlane * m_sigmaPlane);

                    float weight =
                        std::exp(-(gaussianTerm + colorTerm + normalTerm + depthTerm));
                    sum_weight += weight;

                    Float3 weighted_value = sampleColor * weight;
                    sum_weighted_value += weighted_value;
                }

            sum_weighted_value /= sum_weight;
            filteredImage_1(x, y) = sum_weighted_value;
        }
    }

 // pass 1 to max_pass
    int pass = 1;
    for (pass = 1; pass < max_pass; pass++) {

      if (pass % 2 == 1){
        #pragma omp parallel for
            for (int y = 0; y < height; y++) {
              for (int x = 0; x < width; x++) {
                  // TODO: Joint bilateral filter

                  Float3 currentColor = filteredImage_1(x, y);
                  Float3 currentPosition = frameInfo.m_position(x, y);

                  Float3 currentNormal = (SqrLength(frameInfo.m_normal(x, y)) != 0.0f)
                                             ? Normalize(frameInfo.m_normal(x, y))
                                             : 0;

                  Float3 sum_weighted_value = Float3(0.f);
                  float sum_weight = 0.0f;

                  kernelRadius = std::pow(2, pass) * 2;

                  for (int filter_X = -kernelRadius; filter_X <= kernelRadius;
                       filter_X += std::pow(2, pass))
                      for (int filter_Y = -kernelRadius; filter_Y <= kernelRadius;
                           filter_Y += std::pow(2, pass)) {
                          int sample_X = std::min(std::max(filter_X + x, 0), width - 1);
                          int sample_Y = std::min(std::max(filter_Y + y, 0), height - 1);

                          Float3 sampleColor = filteredImage_1(sample_X, sample_Y);
                          Float3 samplePosition =
                              frameInfo.m_position(sample_X, sample_Y);

                          Float3 sampleNormal =
                              (SqrLength(frameInfo.m_normal(sample_X, sample_Y)) != 0.0f)
                                  ? Normalize(frameInfo.m_normal(sample_X, sample_Y))
                                  : 0;

                          float gaussianTerm = (Sqr(static_cast<float>(sample_X - x)) +
                                                Sqr(static_cast<float>(sample_Y - y))) /
                                               (2.0f * m_sigmaCoord * m_sigmaCoord);

                          float colorTerm = SqrLength(currentColor - sampleColor) /
                                            (2.0f * m_sigmaColor * m_sigmaColor);

                          float normalTerm =
                              Sqr(SafeAcos(Dot(currentNormal, sampleNormal))) /
                              (2.0f * m_sigmaNormal * m_sigmaNormal);

                          Float3 dir = samplePosition - currentPosition;
                          float D_plane = (SqrLength(dir) != 0.0f)
                                              ? Dot(currentNormal, Normalize(dir))
                                              : 1.0f;
                          float depthTerm =
                              Sqr(D_plane) / (2.0f * m_sigmaPlane * m_sigmaPlane);

                          float weight = std::exp(
                              -(gaussianTerm + colorTerm + normalTerm + depthTerm));
                          sum_weight += weight;

                          Float3 weighted_value = sampleColor * weight;
                          sum_weighted_value += weighted_value;
                      }

                  sum_weighted_value /= sum_weight;
                  filteredImage_2(x, y) = sum_weighted_value;
                
              }
            }
      }
      else {
        #pragma omp parallel for
          for (int y = 0; y < height; y++) {
              for (int x = 0; x < width; x++) {
                  // TODO: Joint bilateral filter

                  Float3 currentColor = filteredImage_2(x, y);
                  Float3 currentPosition = frameInfo.m_position(x, y);

                  Float3 currentNormal = (SqrLength(frameInfo.m_normal(x, y)) != 0.0f)
                                             ? Normalize(frameInfo.m_normal(x, y))
                                             : 0;

                  Float3 sum_weighted_value = Float3(0.f);
                  float sum_weight = 0.0f;

                  kernelRadius = std::pow(2, pass) * 2;

                  for (int filter_X = -kernelRadius; filter_X <= kernelRadius;
                       filter_X += std::pow(2, pass))
                      for (int filter_Y = -kernelRadius; filter_Y <= kernelRadius;
                           filter_Y += std::pow(2, pass)) {
                          int sample_X = std::min(std::max(filter_X + x, 0), width - 1);
                          int sample_Y = std::min(std::max(filter_Y + y, 0), height - 1);

                          Float3 sampleColor = filteredImage_2(sample_X, sample_Y);
                          Float3 samplePosition =
                              frameInfo.m_position(sample_X, sample_Y);

                          Float3 sampleNormal =
                              (SqrLength(frameInfo.m_normal(sample_X, sample_Y)) != 0.0f)
                                  ? Normalize(frameInfo.m_normal(sample_X, sample_Y))
                                  : 0;

                          float gaussianTerm = (Sqr(static_cast<float>(sample_X - x)) +
                                                Sqr(static_cast<float>(sample_Y - y))) /
                                               (2.0f * m_sigmaCoord * m_sigmaCoord);

                          float colorTerm = SqrLength(currentColor - sampleColor) /
                                            (2.0f * m_sigmaColor * m_sigmaColor);

                          float normalTerm =
                              Sqr(SafeAcos(Dot(currentNormal, sampleNormal))) /
                              (2.0f * m_sigmaNormal * m_sigmaNormal);

                          Float3 dir = samplePosition - currentPosition;
                          float D_plane = (SqrLength(dir) != 0.0f)
                                              ? Dot(currentNormal, Normalize(dir))
                                              : 1.0f;
                          float depthTerm =
                              Sqr(D_plane) / (2.0f * m_sigmaPlane * m_sigmaPlane);

                          float weight = std::exp(
                              -(gaussianTerm + colorTerm + normalTerm + depthTerm));
                          sum_weight += weight;

                          Float3 weighted_value = sampleColor * weight;
                          sum_weighted_value += weighted_value;
                      }

                  sum_weighted_value /= sum_weight;
                  filteredImage_1(x, y) = sum_weighted_value;
              }
          }
      }

      
    
    }
    if (pass % 2 == 1)
        return filteredImage_2;
    else
        return filteredImage_1;

    
}

void Denoiser::Init(const FrameInfo &frameInfo, const Buffer2D<Float3> &filteredColor) {
    m_accColor.Copy(filteredColor);
    int height = m_accColor.m_height;
    int width = m_accColor.m_width;
    m_misc = CreateBuffer2D<Float3>(width, height);
    m_valid = CreateBuffer2D<bool>(width, height);
}

void Denoiser::Maintain(const FrameInfo &frameInfo) { m_preFrameInfo = frameInfo; }

Buffer2D<Float3> Denoiser::ProcessFrame(const FrameInfo &frameInfo) {
    // Filter current frame
    Buffer2D<Float3> filteredColor;
    filteredColor = Filter(frameInfo);

    // Reproject previous frame color to current
    if (m_useTemportal) {
        Reprojection(frameInfo);
        TemporalAccumulation(filteredColor);
    } else {
        Init(frameInfo, filteredColor);
    }

    // Maintain
    Maintain(frameInfo);
    if (!m_useTemportal) {
        m_useTemportal = true;
    }
    return m_accColor;
}
