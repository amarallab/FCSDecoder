#include <metal_stdlib>
using namespace metal;

typedef struct {
    int diff;
    int channel_id;
    int channel_count;
    int event_count;
} find_min_max_uniforms_t;

// Int32 version
typedef struct {
    uint min;
    uint max;
} min_max_int_values_t;

kernel void find_min_max_init_channel_int(device find_min_max_uniforms_t &uniforms [[ buffer(0) ]])
{
    uniforms.diff = 1;
}

kernel void find_min_max_copy_int(device find_min_max_uniforms_t &uniforms [[ buffer(0) ]],
                                  device const uint *data[[ buffer(1) ]],
                                  device uint *mins [[ buffer(2) ]],
                                  device uint *maxs [[ buffer(3) ]],
                                  uint gid [[ thread_position_in_grid ]])
{
    auto offset = uniforms.channel_count * gid + uniforms.channel_id;
    mins[gid] = data[offset];
    maxs[gid] = data[offset];
}

kernel void find_min_max_step_int(device find_min_max_uniforms_t &uniforms [[ buffer(0) ]],
                                  device uint *mins [[ buffer(2) ]],
                                  device uint *maxs [[ buffer(3) ]],
                                  uint gid [[ thread_position_in_grid ]])
{
    const int step = uniforms.diff * 2;
    const int near_index = gid * step;
    const int far_index = gid * step + uniforms.diff;
    if (far_index < uniforms.event_count) {
        mins[near_index] = min(mins[near_index], mins[far_index]);
        maxs[near_index] = max(maxs[near_index], maxs[far_index]);
    }
}

kernel void find_min_max_after_step_int(device find_min_max_uniforms_t &uniforms [[ buffer(0) ]])
{
    uniforms.diff <<= 1;
}

kernel void find_min_max_final_int(device find_min_max_uniforms_t &uniforms [[ buffer(0) ]],
                                   device uint *mins [[ buffer(2) ]],
                                   device uint *maxs [[ buffer(3) ]],
                                   device min_max_int_values_t *min_max_values [[ buffer(4) ]])
{
    min_max_values[uniforms.channel_id] = {
        mins[0],
        maxs[0]
    };
    uniforms.channel_id += 1;
}
//
//// Float32 veresion
//typedef struct {
//    float min;
//    float max;
//} min_max_float_values_t;
//
//
//kernel void find_min_max_copy_float(device find_min_max_uniforms_t &uniforms [[ buffer(0) ]],
//                                    device const float *data[[ buffer(1) ]],
//                                    device float *mins [[ buffer(2) ]],
//                                    device float *maxs [[ buffer(3) ]],
//                                    uint gid [[ thread_position_in_grid ]])
//{
//    auto offset = uniforms.channel_count * gid + uniforms.channel_id;
//    mins[gid] = data[offset];
//    maxs[gid] = data[offset];
//}
//
//kernel void find_min_max_step_float(device find_min_max_uniforms_t &uniforms [[ buffer(0) ]],
//                                    device float *mins [[ buffer(2) ]],
//                                    device float *maxs [[ buffer(3) ]],
//                                    uint gid [[ thread_position_in_grid ]])
//{
//    const int step = uniforms.diff * 2;
//    const int near_index = gid * step;
//    const int far_index = gid * step + uniforms.diff;
//    if (far_index < uniforms.event_count) {
//        mins[near_index] = min(mins[near_index], mins[far_index]);
//        maxs[near_index] = max(maxs[near_index], maxs[far_index]);
//    }
//}
//
//kernel void find_min_max_after_step_float(device find_min_max_uniforms_t &uniforms [[ buffer(0) ]])
//{
//    uniforms.diff <<= 1;
//}
//
//kernel void find_min_max_final_float(device find_min_max_uniforms_t &uniforms [[ buffer(0) ]],
//                                     device float *mins [[ buffer(2) ]],
//                                     device float *maxs [[ buffer(3) ]],
//                                     device min_max_float_values_t *min_max_values [[ buffer(4) ]])
//{
//    min_max_values[uniforms.channel_id].min = mins[0];
//    min_max_values[uniforms.channel_id].max = maxs[0];
//    uniforms.channel_id += 1;
//}
