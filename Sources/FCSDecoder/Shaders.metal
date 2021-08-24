#include <metal_stdlib>
using namespace metal;

typedef enum {
    int16_bigEndian = 0,
    int16_littleEndian = 1,
    int32_bigEndian = 2,
    int32_littleEndian = 3
} byte_ord_t;
    
typedef struct {
    int channelCount;
    int eventCount;
    int stride;
    int byte_ord; // byte_ord_t
} uniforms_t;

typedef union {
    uint64_t raw;
    uchar b[8];
} value_t;

kernel void converter(device const uniforms_t &uniforms [[ buffer(0) ]],
                      device const uchar *bitLengths [[ buffer(1) ]],
                      device const uchar *source [[ buffer(2) ]],
                      device uint32_t *destination [[ buffer(3) ]],
                      uint2 gid [[ thread_position_in_grid ]])
{
    value_t value;
    int offset = 0;
    for (uint i = 0; i < gid.x; i++)
        offset += bitLengths[i];

    const int base = gid.y * int(uniforms.stride/8) + int(offset/8);
    value.raw =
        uint64_t(source[base + 0]) << 32
      | uint64_t(source[base + 1]) << 24
      | uint64_t(source[base + 2]) << 16
      | uint64_t(source[base + 3]) << 8
      | uint64_t(source[base + 4]);

    value.raw >>= 40 - bitLengths[gid.x] - (offset % 8);
    value.raw &= ((1 << bitLengths[gid.x]) - 1);

    uint32_t result = 0;
    switch (uniforms.byte_ord) {
        case int16_littleEndian:
            result = (value.b[1] << 8) + value.b[0];
            break;
        case int16_bigEndian:
            result = (value.b[0] << 8) + value.b[1];
            break;
        case int32_littleEndian:
            result = (value.b[3] << 24) + (value.b[2] << 16) + (value.b[1] << 8) + value.b[0];
            break;
        case int32_bigEndian:
            result = (value.b[0] << 24) + (value.b[1] << 16) + (value.b[2] << 8) + value.b[3];
            break;
    }
    destination[gid.y * uniforms.channelCount + gid.x] = result;
}


typedef struct {
    int channel_id;
    int channel_count;
    int event_count;
} find_min_max_uniforms_t;

typedef struct {
    int min;
    int max;
} final_values_t;

kernel void find_min_max(device const find_min_max_uniforms_t &uniforms [[ buffer(0) ]],
                         device const int *data[[ buffer(1) ]],
                         device int *mins [[ buffer(2) ]],
                         device int *maxs [[ buffer(3) ]],
                         device final_values_t *final_values [[ buffer(4) ]],
                         uint2 gid [[ thread_position_in_grid ]])
{
    auto offset = uniforms.channel_count * gid.x + uniforms.channel_id;
    mins[gid.x] = data[offset];
    maxs[gid.x] = data[offset];
    threadgroup_barrier(mem_flags::mem_none);
    for (int diff = 1; diff < uniforms.event_count; diff <<= 1) {
        const int step = diff << 1;
        const int near_index = gid.x * step;
        const int far_index = gid.x * step + diff;
        if (far_index < uniforms.event_count) {
            mins[near_index] = min(mins[near_index], mins[far_index]);
            maxs[near_index] = max(maxs[near_index], maxs[far_index]);
        }
        threadgroup_barrier(mem_flags::mem_none);
    }
    if (gid.x == 0) {
        final_values[uniforms.channel_id].min = mins[0];
        final_values[uniforms.channel_id].max = maxs[0];
    }
}
