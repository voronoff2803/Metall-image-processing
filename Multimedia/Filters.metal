//
//  Test.metal
//  MetalImageProcessing
//
//  Created by Alexey Voronov on 24/03/2019.
//  Copyright © 2019 Alexey Voronov. All rights reserved.
//

#include <metal_stdlib>

using namespace metal;

float clip(float value)
{
    if (value > 1) {
        return 1;
    } else if (value < 0) {
        return 0;
    } else {
        return value;
    }
}

inline void swap(thread float4 &a, thread float4 &b)
{
    float4 tmp = a; a = min(a,b); b = max(tmp, b); // swap sort of two elements
}

// квантование
uint quant(float value, int steps)
{
    return ((int)((value * steps) + 0.5));
}

float rand(int x, int y, int z)
{
    int seed = x + y * 57 + z * 241;
    seed= (seed<< 13) ^ seed;
    return (( 1.0 - ( (seed * (seed * seed * 15731 + 789221) + 1376312589) & 2147483647) / 1073741824.0f) + 1.0f) / 2.0f;
}

// восстановление после квантования
float quant_rec(uint value, int steps)
{
    return clip((float)value / (steps - 1));
}

// перевод в черно-белый aka яркость точки
float to_grayscale(float4 in_color)
{
    float result = in_color.r * 0.299 + in_color.g * 0.587 + in_color.b * 0.114;
    return clip(result);
}

// mse одного пикселя
uint get_mse(float4 in_color, float4 out_color)
{
    float delta = ((abs(in_color.r - out_color.r) + abs(in_color.g - out_color.g) + abs(in_color.b - out_color.b))/3);
    return delta * delta * 255;   // домнажаем на 255 для того что бы можно было использовать атомарный uint
}

// RGB в YUV
float4 rgbToYuv(float4 inP)
{
    float3 outP;
    outP.r = 0.299 * inP.r + 0.587 * inP.g + 0.114 * inP.b;
    outP.g = -0.1687 * inP.r - 0.3313 * inP.g + 0.5 * inP.b + 0.5;
    outP.b = 0.5 * inP.r - 0.4187 * inP.g - 0.0813 * inP.b + 0.5;
    return float4(outP, 1);
}

// YUV в RGB
float4 yuvToRgb(float4 inP)
{
    float Y = inP.r;
    float Cb = inP.g;
    float Cr = inP.b;
    float3 outP;
    outP.r = Y + 1.402 * (Cr - 0.5);
    outP.g = Y - 0.34414 * (Cb - 0.5) - 0.71414 * (Cr - 0.5);
    outP.b = Y + 1.772 * (Cb - 0.5);
    return float4(outP, 1);
}

// децимация aka пикселизация
float4 pixelation(uint size,
                  texture2d<float, access::sample> in_texture,
                  uint2 gid)
{
    uint2 new_gid = (gid / size) * size;
    float4 out_color = in_texture.read(uint2(new_gid.x + size/2, new_gid.y + size/2));
    return out_color;
}


// Первое задание
kernel void kernel_task1(
                                    texture2d<float, access::sample> in_texture [[texture(0)]],
                                    texture2d<float, access::write> out_texture [[texture(1)]],
                                    constant float &steps [[buffer(0)]],
                                    device atomic_uint &mse [[buffer(1)]],
                                    device atomic_uint *histogram [[buffer(2)]],
                                    uint2 gid [[thread_position_in_grid]]
                                    )
{
    float4 in_color = in_texture.read(gid);   // получаем пиксель
    float value = to_grayscale(in_color);     // находим его яркость
    in_color = float4(float3(value), 1);      // сохраняем черно-белый пиксель (для нахождения mse)
    
    uint value_int = quant(value, steps);          // квантуем значение
    float final_value = quant_rec(value_int, steps);       // восстанавливаем значение
    
    
    float4 out_color = float4(float3(final_value), 1.0);  // делаем новый пиксель из квантованного значения

    out_texture.write(out_color, gid);        // записываем пиксель в конечную текстуру
    
    
    // находим mse пикселя и прибовляем его к сумме
    atomic_fetch_add_explicit(&mse, get_mse(in_color, out_color), memory_order_relaxed);
    
    // добавляем 1 в индекс цвета в гистограмме

    uint index = final_value * 255;
    out_texture.write(float4(1,1,1,0), uint2(index, index));
    atomic_fetch_add_explicit(&histogram[index], 1, memory_order_relaxed);
}

// второе задание
kernel void kernel_task2(
                         texture2d<float, access::sample> in_texture [[texture(0)]],
                         texture2d<float, access::write> out_texture [[texture(1)]],
                         constant float &steps [[buffer(0)]],
                         device atomic_uint &mse [[buffer(1)]],
                         device atomic_uint *histogram [[buffer(2)]],
                         uint2 gid [[thread_position_in_grid]]
                         )
{
    float4 in_color = in_texture.read(gid);                           // получаем пиксель
    float4 in_color_pixelated = pixelation(steps, in_texture, gid);   // выполняем децимацию
    
    float4 in_color_yuv = rgbToYuv(in_color);                         // переводим из RGB в YUV
    float4 in_color_yuv_pixelated = rgbToYuv(in_color_pixelated);     // переводим децимированную картинку из RGB в YUV
    float4 out_color_yuv = float4(in_color_yuv.x, in_color_yuv_pixelated.yz, 1); // используем недецемированный канал Y и децемированные Cr и Cb
    
    float4 out_color = yuvToRgb(out_color_yuv); // переводим обратно в RGB
    out_texture.write(out_color, gid);          // записываем пиксель в конечную текстуру
    
    
    // находим mse пикселя и прибовляем его к сумме
    atomic_fetch_add_explicit(&mse, get_mse(in_color, out_color), memory_order_relaxed);
    
    // добавляем 1 в индекс цвета в гистограмме
    uint index = out_color[0] * 255;
    atomic_fetch_add_explicit(&histogram[index], 1, memory_order_relaxed);
}


kernel void kernel_task3(
                         texture2d<float, access::sample> in_texture [[texture(0)]],
                         texture2d<float, access::write> out_texture [[texture(1)]],
                         device atomic_uint *histogram [[buffer(2)]],
                         uint2 gid [[thread_position_in_grid]]
                         )
{
    float4 in_color = in_texture.read(gid);                           // получаем пиксель
    uint index = to_grayscale(in_color) * 255;
    out_texture.write(in_color, gid);
    atomic_fetch_add_explicit(&histogram[index], 1, memory_order_relaxed);
}


kernel void grayscale_filter(
                         texture2d<float, access::sample> in_texture [[texture(0)]],
                         texture2d<float, access::write> out_texture [[texture(2)]],
                         constant float &param [[buffer(0)]],
                         device atomic_uint *histogram [[buffer(2)]],
                         uint2 gid [[thread_position_in_grid]]
                         )
{
    float4 in_color = in_texture.read(gid);                           // получаем пиксель
    float value = clip(to_grayscale(in_color) * param * 2);
    
    out_texture.write(value, gid);
    
    uint index = (value + 0.002) * 255;
    atomic_fetch_add_explicit(&histogram[index], 1, memory_order_relaxed);
}

kernel void red_filter(
                             texture2d<float, access::sample> in_texture [[texture(0)]],
                             texture2d<float, access::write> out_texture [[texture(2)]],
                             constant float &param [[buffer(0)]],
                             device atomic_uint *histogram [[buffer(2)]],
                             uint2 gid [[thread_position_in_grid]]
                             )
{
    float4 in_color = in_texture.read(gid);                           // получаем пиксель
    float value = clip(in_color.r);
    
    out_texture.write(value, gid);
    
    uint index = (value + 0.002) * 255;
    atomic_fetch_add_explicit(&histogram[index], 1, memory_order_relaxed);
}

kernel void green_filter(
                       texture2d<float, access::sample> in_texture [[texture(0)]],
                       texture2d<float, access::write> out_texture [[texture(2)]],
                       constant float &param [[buffer(0)]],
                       device atomic_uint *histogram [[buffer(2)]],
                       uint2 gid [[thread_position_in_grid]]
                       )
{
    float4 in_color = in_texture.read(gid);                           // получаем пиксель
    float value = clip(in_color.g);
    
    out_texture.write(value, gid);
    
    uint index = (value + 0.002) * 255;
    atomic_fetch_add_explicit(&histogram[index], 1, memory_order_relaxed);
}

kernel void blue_filter(
                       texture2d<float, access::sample> in_texture [[texture(0)]],
                       texture2d<float, access::write> out_texture [[texture(2)]],
                       constant float &param [[buffer(0)]],
                       device atomic_uint *histogram [[buffer(2)]],
                       uint2 gid [[thread_position_in_grid]]
                       )
{
    float4 in_color = in_texture.read(gid);                           // получаем пиксель
    float value = clip(in_color.b);
    
    out_texture.write(value, gid);
    
    uint index = (value + 0.002) * 255;
    atomic_fetch_add_explicit(&histogram[index], 1, memory_order_relaxed);
}

kernel void difference_filter(texture2d<float, access::sample> in_texture1 [[texture(0)]],
                              texture2d<float, access::sample> in_texture2 [[texture(1)]],
                              texture2d<float, access::write> out_texture [[texture(2)]],
                              device atomic_uint *histogram [[buffer(2)]],
                              uint2 gid [[thread_position_in_grid]]
                              )
{
    float4 in_color1 = in_texture1.read(gid);
    float4 in_color2 = in_texture2.read(gid);
    
    float4 difference = fabs(in_color1 - in_color2);
    
    out_texture.write(float4(difference.rgb, 1), gid);
}

kernel void differenceclip_filter(texture2d<float, access::sample> in_texture1 [[texture(0)]],
                              texture2d<float, access::sample> in_texture2 [[texture(1)]],
                              texture2d<float, access::write> out_texture [[texture(2)]],
                              device atomic_uint *histogram [[buffer(2)]],
                              uint2 gid [[thread_position_in_grid]]
                              )
{
    float4 in_color1 = in_texture1.read(gid);
    float4 in_color2 = in_texture2.read(gid);
    
    float4 difference = float4(clip(in_color1.r - in_color2.r),clip(in_color1.g - in_color2.g),clip(in_color1.b - in_color2.b),0);
    
    out_texture.write(float4(difference.rgb, 1), gid);
}

kernel void empty_filter(texture2d<float, access::sample> in_texture [[texture(0)]],
                              texture2d<float, access::write> out_texture [[texture(2)]],
                              constant float &param [[buffer(0)]],
                              device atomic_uint *histogram [[buffer(2)]],
                              uint2 gid [[thread_position_in_grid]]
                              )
{
    float4 in_color = in_texture.read(gid);
    
    out_texture.write(in_color, gid);
    
    float value = to_grayscale(in_color);
    
    uint index = (value + 0.002) * 255;
    atomic_fetch_add_explicit(&histogram[index], 1, memory_order_relaxed);
}

kernel void combine_filter(texture2d<float, access::sample> in_textureR [[texture(0)]],
                           texture2d<float, access::sample> in_textureG [[texture(1)]],
                           texture2d<float, access::sample> in_textureB [[texture(3)]],
                           texture2d<float, access::write> out_texture [[texture(2)]],
                           device atomic_uint *histogram [[buffer(2)]],
                           uint2 gid [[thread_position_in_grid]]
                           )
{
    float4 in_colorR = in_textureR.read(gid);
    float4 in_colorG = in_textureG.read(gid);
    float4 in_colorB = in_textureB.read(gid);
    
    float4 out_color = float4(in_colorR.r, in_colorG.g, in_colorB.b, 1);
    
    float value = to_grayscale(out_color);
    
    out_texture.write(out_color, gid);
    
    uint index = (value + 0.002) * 255;
    atomic_fetch_add_explicit(&histogram[index], 1, memory_order_relaxed);
}



kernel void robast_filter(texture2d<float, access::sample> in_texture [[texture(0)]],
                          texture2d<float, access::write> out_texture [[texture(2)]],
                          constant float &param1 [[buffer(0)]],
                          constant float &param2 [[buffer(1)]],
                          device atomic_uint *histogram [[buffer(2)]],
                          uint2 gid [[thread_position_in_grid]]
                          )
{
    float4 in_color = in_texture.read(gid);
    float4 out_color = (in_color - param1)*(1/(param2 - param1));
    
    out_texture.write(out_color, gid);
    
    uint index = (to_grayscale(out_color) + 0.002) * 255;
    atomic_fetch_add_explicit(&histogram[index], 1, memory_order_relaxed);
}

kernel void grayworld_filter(texture2d<float, access::sample> in_texture [[texture(0)]],
                             texture2d<float, access::write> out_texture [[texture(2)]],
                             constant float &param1 [[buffer(0)]],
                             constant float &param2 [[buffer(1)]],
                             constant float &param3 [[buffer(3)]],
                             device atomic_uint *histogram [[buffer(2)]],
                             uint2 gid [[thread_position_in_grid]]
                             )
{
    float4 in_color = in_texture.read(gid);
    float4 out_color = float4(in_color.r * param1, in_color.g * param2, in_color.b * param3, 1);
    
    out_texture.write(out_color, gid);
    
    uint index = (to_grayscale(out_color) + 0.002) * 255;
    atomic_fetch_add_explicit(&histogram[index], 1, memory_order_relaxed);
}

kernel void noise_filter(texture2d<float, access::sample> in_texture [[texture(0)]],
                         texture2d<float, access::write> out_texture [[texture(2)]],
                         constant float &param [[buffer(0)]],
                         device atomic_uint *histogram [[buffer(2)]],
                         uint2 gid [[thread_position_in_grid]]
                         )
{
    float4 in_color = in_texture.read(gid);
    
    
    float random = rand(gid.x, gid.y, 100);
    
    if (random > 0.99 - param * 0.1) {
        in_color = 0;
    }
    
    if (random < 0.001 + param * 0.01) {
        in_color = 1;
    }
    
    out_texture.write(in_color, gid);
    
    float value = to_grayscale(in_color);
    
    uint index = (value + 0.002) * 255;
    atomic_fetch_add_explicit(&histogram[index], 1, memory_order_relaxed);
}

kernel void median_filter(texture2d<float, access::read> in_texture [[texture(0)]],
                          texture2d<float, access::write> out_texture [[texture(2)]],
                          constant float &param [[buffer(0)]],
                          device atomic_uint *histogram [[buffer(2)]],
                          uint2 gid [[thread_position_in_grid]]) {
    int radius = 2.6 * param;
    int size = radius * 2 + 1;
    float4 v[24];
    
    
    for (int i = 0; i < size; i++) {
        for (int j = 0; j < size; j++) {
            uint2 current_index(gid.x + (i - radius), gid.y + (j - radius));
            float4 current = in_texture.read(current_index);
            v[i * 3 + j] = current;
        }
    }
    
    for (int i = 0; i < size * size - 1; i++) {
        for (int j = 0; j < size * size - 1; j++) {
            swap(v[j], v[j + 1]);
        }
    }
    
    float4 out_color = v[(size*size)/2];
    out_texture.write(out_color, gid);
    
    float value = to_grayscale(out_color);
    
    uint index = (value + 0.002) * 255;
    atomic_fetch_add_explicit(&histogram[index], 1, memory_order_relaxed);
}

kernel void gaussian_filter(texture2d<float, access::read> in_texture [[texture(0)]],
                            texture2d<float, access::write> out_texture [[texture(2)]],
                            device atomic_uint *histogram [[buffer(2)]],
                            uint2 gid [[ thread_position_in_grid ]]) {
    int kernel_size = 3;
    int radius = kernel_size / 2;
    float filter_wight = 4.0;
    
    float3x3 gauss_kernel = float3x3(float3(0.25, 0.5, 0.25),
                                     float3(0.5, 1.0, 0.5),
                                     float3(0.25, 0.5, 0.25)
                                     );
    
    float4 out_color(0, 0, 0, 0);
    for (int j = 0; j <= kernel_size - 1; j++) {
        for (int i = 0; i <= kernel_size - 1; i++) {
            uint2 texture_index(gid.x + (i - radius), gid.y + (j - radius));
            out_color += gauss_kernel[i][j] * in_texture.read(texture_index).rgba;
        }
    }
    
    out_color = out_color / filter_wight;
    
    out_texture.write(out_color, gid);
    
    float value = to_grayscale(out_color);
    
    uint index = (value + 0.002) * 255;
    atomic_fetch_add_explicit(&histogram[index], 1, memory_order_relaxed);
}

kernel void gaussian_avg_filter(texture2d<float, access::read> in_texture [[texture(0)]],
                                texture2d<float, access::write> out_texture [[texture(2)]],
                                device atomic_uint *histogram [[buffer(2)]],
                                uint2 gid [[ thread_position_in_grid ]]) {
    int kernel_size = 3;
    int radius = kernel_size / 2;
    float filter_wight = 9.0;
    
    float3x3 gauss_kernel = float3x3(float3(1.0, 1.0, 1.0),
                                     float3(1.0, 1.0, 1.0),
                                     float3(1.0, 1.0, 1.0)
                                     );
    
    float4 out_color(0, 0, 0, 0);
    for (int j = 0; j <= kernel_size - 1; j++) {
        for (int i = 0; i <= kernel_size - 1; i++) {
            uint2 texture_index(gid.x + (i - radius), gid.y + (j - radius));
            out_color += gauss_kernel[i][j] * in_texture.read(texture_index).rgba;
        }
    }
    
    out_color = out_color / filter_wight;
    
    out_texture.write(out_color, gid);
    
    float value = to_grayscale(out_color);
    
    uint index = (value + 0.002) * 255;
    atomic_fetch_add_explicit(&histogram[index], 1, memory_order_relaxed);
}

kernel void gaussian_shift_filter(texture2d<float, access::read> in_texture [[texture(0)]],
                                texture2d<float, access::write> out_texture [[texture(2)]],
                                device atomic_uint *histogram [[buffer(2)]],
                                uint2 gid [[ thread_position_in_grid ]]) {
    int kernel_size = 3;
    int radius = kernel_size / 2;
    float filter_wight = 1.0;
    
    float3x3 gauss_kernel = float3x3(float3(0.0, 0.0, 0.0),
                                     float3(0.0, 0.0, 1.0),
                                     float3(0.0, 0.0, 0.0)
                                     );
    
    float4 out_color(0, 0, 0, 0);
    for (int j = 0; j <= kernel_size - 1; j++) {
        for (int i = 0; i <= kernel_size - 1; i++) {
            uint2 texture_index(gid.x + (i - radius), gid.y + (j - radius));
            out_color += gauss_kernel[i][j] * in_texture.read(texture_index).rgba;
        }
    }
    
    out_color = out_color / filter_wight;
    
    out_texture.write(out_color, gid);
    
    float value = to_grayscale(out_color);
    
    uint index = (value + 0.002) * 255;
    atomic_fetch_add_explicit(&histogram[index], 1, memory_order_relaxed);
}

kernel void gaussian_sharp_filter(texture2d<float, access::read> in_texture [[texture(0)]],
                                  texture2d<float, access::write> out_texture [[texture(2)]],
                                  device atomic_uint *histogram [[buffer(2)]],
                                  uint2 gid [[ thread_position_in_grid ]]) {
    int kernel_size = 3;
    int radius = kernel_size / 2;
    float filter_wight = 0.8;
    
    float3x3 gauss_kernel = float3x3(float3(-0.1, -0.2, -0.1),
                                     float3(-0.2,  2.0, -0.2),
                                     float3(-0.1, -0.2, -0.1)
                                     );
    
    float4 out_color(0, 0, 0, 0);
    for (int j = 0; j <= kernel_size - 1; j++) {
        for (int i = 0; i <= kernel_size - 1; i++) {
            uint2 texture_index(gid.x + (i - radius), gid.y + (j - radius));
            out_color += gauss_kernel[i][j] * in_texture.read(texture_index).rgba;
        }
    }
    
    out_color = out_color / filter_wight;
    
    out_texture.write(out_color, gid);
    
    float value = to_grayscale(out_color);
    
    uint index = (value + 0.002) * 255;
    atomic_fetch_add_explicit(&histogram[index], 1, memory_order_relaxed);
}

kernel void overlay_filter(texture2d<float, access::read> in_texture1 [[texture(0)]],
                           texture2d<float, access::read> in_texture2 [[texture(1)]],
                           texture2d<float, access::write> out_texture [[texture(2)]],
                           constant float &param [[buffer(0)]],
                           device atomic_uint *histogram [[buffer(2)]],
                           uint2 gid [[ thread_position_in_grid ]]) {
    float4 in_color1 = in_texture1.read(gid);
    float4 in_color2 = in_texture2.read(gid);
    
    float4 out_color = in_color1 + in_color2 * param * 3;
    
    out_texture.write(out_color, gid);
    
    float value = to_grayscale(out_color);
    
    uint index = (value + 0.002) * 255;
    atomic_fetch_add_explicit(&histogram[index], 1, memory_order_relaxed);
}

float gauss(float x, float sigma) {
    return (1 / sqrt(400 * M_PI_H * sigma * sigma) * exp(-x * x / (sigma * sigma * 400)));
};

kernel void gaussian_blur_filter(texture2d<float, access::read> in_texture [[ texture(0) ]],
                                 texture2d<float, access::write> out_texture [[ texture(2) ]],
                                 constant float &sigma [[ buffer(0) ]],
                                 device atomic_uint *histogram [[buffer(2)]],
                                 uint2 gid [[ thread_position_in_grid ]]) {
    int kernel_size = 64 * sigma * sigma;
    int radius = kernel_size / 2;
    
    float kernel_weight = 0;
    for (int j = 0; j <= kernel_size - 1; j++) {
        for (int i = 0; i <= kernel_size - 1; i++) {
            int2 normalized_position(i - radius, j - radius);
            kernel_weight += gauss(normalized_position.x, sigma) * gauss(normalized_position.y, sigma);
        }
    }
    
    float4 acc_color(0, 0, 0, 0);
    for (int j = 0; j <= kernel_size - 1; j++) {
        for (int i = 0; i <= kernel_size - 1; i++) {
            int2 normalized_position(i - radius, j - radius);
            uint2 texture_index(gid.x + (i - radius), gid.y + (j - radius));
            float factor = gauss(normalized_position.x, sigma) * gauss(normalized_position.y, sigma) / kernel_weight;
            acc_color += factor * in_texture.read(texture_index).rgba;
        }
    }
    
    out_texture.write(acc_color, gid);
    
    float value = to_grayscale(acc_color);
    
    uint index = (value + 0.002) * 255;
    atomic_fetch_add_explicit(&histogram[index], 1, memory_order_relaxed);
}

