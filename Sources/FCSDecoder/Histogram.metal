#include <metal_stdlib>
using namespace metal;

typedef struct {
    uint32_t channel_count;
    uint32_t event_count;
} main_uniforms_t;

typedef struct {
    float min;
    float step;
    uint offset;
    uint bins_count;
    bool use_ln;
    int valid_event_count;
    uint max_value;
} channel_info_uniforms_t;

kernel void intHistogramAssignBin(device const uint *data [[ buffer(0) ]],
                                  device const main_uniforms_t &main [[ buffer(1) ]],
                                  device const channel_info_uniforms_t *channel_infos [[ buffer(2) ]],
                                  device int *assigned_bin_buffer [[ buffer(3) ]],
                                  uint2 gid [[ thread_position_in_grid ]])
{
    const auto channel_index = gid.x;
    const auto buffer_index = gid.y * main.channel_count + channel_index;
    const auto channel_info = channel_infos[channel_index];
    const auto in_value = float(data[buffer_index]);
    if (channel_info.use_ln && in_value < 1) {
        assigned_bin_buffer[buffer_index] = -1;
    } else {
        float value = channel_info.use_ln ? log10(float(in_value)) : float(in_value);
        uint bin = channel_info.step != 0.0 ? uint((value - channel_info.min) / channel_info.step) : 0;
        assigned_bin_buffer[buffer_index] = max(uint(0), min(bin, channel_info.bins_count - 1));
    }
}

kernel void floatHistogramAssignBin(device const float *data [[ buffer(0) ]],
                                    device const main_uniforms_t &main [[ buffer(1) ]],
                                    device const channel_info_uniforms_t *channel_infos [[ buffer(2) ]],
                                    device int *assigned_bin_buffer [[ buffer(3) ]],
                                    uint2 gid [[ thread_position_in_grid ]])
{
    const auto channel_index = gid.x;
    const auto buffer_index = gid.y * main.channel_count + channel_index;
    const auto channel_info = channel_infos[channel_index];
    const auto in_value = float(data[buffer_index]);
    if (channel_info.use_ln && in_value < 1) {
        assigned_bin_buffer[buffer_index] = -1;
    } else {
        float value = channel_info.use_ln ? log10(in_value) : in_value;
        uint bin = channel_info.step != 0.0 ? uint((value - channel_info.min) / channel_info.step) : 0;
        assigned_bin_buffer[buffer_index] = max(uint(0), min(bin, channel_info.bins_count - 1));
    }
}

kernel void histogram(device const main_uniforms_t &main [[ buffer(0) ]],
                         device channel_info_uniforms_t *channel_infos [[ buffer(1) ]],
                         const device int *assigned_bin_buffer [[ buffer(2) ]],
                         device uint *histogram_buffer [[ buffer(3) ]],
                         uint gid [[ thread_position_in_grid ]])
{
    const auto channel_index = gid;
    auto channel_info = channel_infos[channel_index];
    for (uint bin = 0; bin < channel_info.bins_count; bin++) {
        histogram_buffer[channel_info.offset + bin] = 0;
    }
    int valid_event_count = 0;
    for (uint i = 0; i < main.event_count; i++) {
        int buffer_index = i * main.channel_count + channel_index;
        int bin = assigned_bin_buffer[buffer_index];
        if (bin != -1) {
            histogram_buffer[channel_info.offset + bin] += 1;
            valid_event_count += 1;
        }
    }
    uint max_value = 0;
    for (int i = 0; i < int(channel_info.bins_count); i++) {
        max_value = max(max_value, histogram_buffer[channel_info.offset + i]);
    }
    
    channel_info.valid_event_count = valid_event_count;
    channel_info.max_value = max_value;
    channel_infos[channel_index] = channel_info;
}
