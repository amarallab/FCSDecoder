#include <metal_stdlib>
using namespace metal;

typedef struct {
    uint32_t event_count;
    uint32_t x_bins_count;
    uint32_t y_bins_count;
    uint32_t x_offset;
    uint32_t y_offset;
    uint32_t stride;
    float x_min;
    float x_step;
    float y_min;
    float y_step;
    bool use_ln;
} main_uniforms_t;

kernel void intHeatMapAssignBin(device const uint *data [[ buffer(0) ]],
                                device const main_uniforms_t &main [[ buffer(1) ]],
                                device int *assigned_bin_buffer [[ buffer(2) ]],
                                uint2 gid [[ thread_position_in_grid ]])
{
    const auto bins_count = gid.x == 0 ? main.x_bins_count : main.y_bins_count;
    const auto offset = gid.x == 0 ? main.x_offset : main.y_offset;
    const auto _min = gid.x == 0 ? main.x_min : main.y_min;
    const auto step = gid.x == 0 ? main.x_step : main.y_step;

    const auto buffer_index = gid.y * main.stride/32 + offset/32;
    const auto out_index = gid.y * 2 + gid.x;
    const auto in_value = float(data[buffer_index]);
    if (main.use_ln && in_value < 1) {
        assigned_bin_buffer[out_index] = -1;
    } else {
        float value = main.use_ln ? log(in_value) : in_value;
        uint bin = step != 0.0 ? uint((value - _min) / step) : 0;
        assigned_bin_buffer[out_index] = max(uint(0), min(bin, bins_count - 1));
    }
}

kernel void floatHeatMapAssignBin(device const float *data [[ buffer(0) ]],
                                  device const main_uniforms_t &main [[ buffer(1) ]],
                                  device int *assigned_bin_buffer [[ buffer(2) ]],
                                  uint2 gid [[ thread_position_in_grid ]])
{
    const auto bins_count = gid.x == 0 ? main.x_bins_count : main.y_bins_count;
    const auto offset = gid.x == 0 ? main.x_offset : main.y_offset;
    const auto _min = gid.x == 0 ? main.x_min : main.y_min;
    const auto step = gid.x == 0 ? main.x_step : main.y_step;

    const auto buffer_index = gid.y * main.stride/32 + offset/32;
    const auto out_index = gid.y * 2 + gid.x;
    const auto in_value = float(data[buffer_index]);
    if (main.use_ln && in_value < 1) {
        assigned_bin_buffer[out_index] = -1;
    } else {
        float value = main.use_ln ? log(in_value) : in_value;
        uint bin = step != 0.0 ? uint((value - _min) / step) : 0;
        assigned_bin_buffer[out_index] = max(uint(0), min(bin, bins_count - 1));
    }
}
