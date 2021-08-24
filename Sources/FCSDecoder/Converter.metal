#include <metal_stdlib>
using namespace metal;

typedef enum {
    int16_bigEndian = 0,
    int16_littleEndian = 1,
    int32_bigEndian = 2,
    int32_littleEndian = 3
} byte_ord_t;
    
typedef struct {
    uint channelCount;
    uint eventCount;
    uint stride;
    uint byte_ord; // byte_ord_t
} uniforms_t;

typedef union {
    ulong raw;
    uchar b[8];
} value_t;

kernel void converter(device const uniforms_t &uniforms [[ buffer(0) ]],
                      device const uchar *bitLengths [[ buffer(1) ]],
                      device const uchar *source [[ buffer(2) ]],
                      device uint *destination [[ buffer(3) ]],
                      uint2 gid [[ thread_position_in_grid ]])
{
    value_t value;
    uint offset = 0;
    for (uint i = 0; i < gid.x; i++)
        offset += bitLengths[i];

    const uint base = gid.y * uint(uniforms.stride/8) + uint(offset/8);
    value.raw =
        ulong(source[base + 0]) << 32
      | ulong(source[base + 1]) << 24
      | ulong(source[base + 2]) << 16
      | ulong(source[base + 3]) << 8
      | ulong(source[base + 4]);

    value.raw >>= 40 - bitLengths[gid.x] - (offset % 8);
    value.raw &= ((1 << bitLengths[gid.x]) - 1);

    uint result = 0;
    switch (uniforms.byte_ord) {
        case int16_bigEndian:
            result = (value.b[1] << 8) + value.b[0];
            break;
        case int16_littleEndian:
            result = (value.b[0] << 8) + value.b[1];
            break;
        case int32_bigEndian:
            result = (value.b[3] << 24) + (value.b[2] << 16) + (value.b[1] << 8) + value.b[0];
            break;
        case int32_littleEndian:
            result = (value.b[0] << 24) + (value.b[1] << 16) + (value.b[2] << 8) + value.b[3];
            break;
    }
    destination[gid.y * uniforms.channelCount + gid.x] = result;
}
