// Copyright 2024 Cii
//
// This file is part of Rasen.
//
// Rasen is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Rasen is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Rasen.  If not, see <http://www.gnu.org/licenses/>.

#include <metal_stdlib>
#include <metal_graphics>
using namespace metal;

struct BasicVertex {
    float4 position [[position]];
    float4 color;
};
vertex BasicVertex basicVertex(const device float4 *positions [[buffer(0)]],
                               const device float4 &color [[buffer(1)]],
                               const device float4x4 &transform [[buffer(2)]],
                               const uint vid [[vertex_id]]) {
    BasicVertex v;
    v.position = positions[vid] * transform;
    v.color = color;
    return v;
}
vertex BasicVertex colorsVertex(const device float4 *positions [[buffer(0)]],
                                const device float4 *colors [[buffer(1)]],
                                const device float4x4 &transform [[buffer(2)]],
                                const uint vid [[vertex_id]]) {
    BasicVertex v;
    v.position = positions[vid] * transform;
    v.color = colors[vid];
    return v;
}
fragment float4 basicFragment(BasicVertex vertexIn [[stage_in]]) {
    return vertexIn.color;
}

struct TextureVertex {
    float4 position [[position]];
    float2 cordinate;
};
vertex TextureVertex textureVertex(const device float4 *positions [[buffer(0)]],
                                   const device float4 *cordinates [[buffer(1)]],
                                   const device float4x4 &transform [[buffer(2)]],
                                   const uint vid [[vertex_id]]) {
    float4 cordinate4 = cordinates[vid];
    TextureVertex v;
    v.position = positions[vid] * transform;
    v.cordinate = float2(cordinate4.x, cordinate4.y);
    return v;
}
fragment float4 textureFragment(TextureVertex vertexIn [[stage_in]],
                                texture2d<float> texture2D [[texture(0)]]) {
    constexpr sampler sampler2D(filter:: linear, mip_filter:: linear);
    return texture2D.sample(sampler2D, vertexIn.cordinate);
}

struct StencilVertex {
    float4 position [[position]];
};
vertex StencilVertex stencilVertex(const device float4 *positions [[buffer(0)]],
                                   const device float4x4 &transform [[buffer(1)]],
                                   const uint vid [[vertex_id]]) {
    StencilVertex v;
    v.position = positions[vid] * transform;
    return v;
}

struct StencilBVertex {
    float4 position [[position]];
    float2 p;
};
vertex StencilBVertex stencilBVertex(const device float4 *positions [[buffer(0)]],
                                     const device float4x4 &transform [[buffer(1)]],
                                     const uint vid [[vertex_id]]) {
    float4 position = positions[vid];
    StencilBVertex v;
    v.position = float4(position.x, position.y, 0, 1) * transform;
    v.p.x = position[2];
    v.p.y = position[3];
    return v;
}

// Referenced algorithm:
// Charles Loop. Jim Blinn.
// “Chapter 25. Rendering Vector Art on the GPU”. GPU Gems 3.
// https://developer.nvidia.com/gpugems/gpugems3/part-iv-image-effects/chapter-25-rendering-vector-art-gpu, (accessed 2020-08-19)
fragment float4 stencilBFragment(StencilBVertex vertexIn [[stage_in]]) {
    float2 uv = vertexIn.p;
    float2 uvdx = dfdx(uv), uvdy = dfdy(uv);
    float u2 = 2 * uv.x;
    
    float dqdx = u2 * uvdx.x - uvdx.y;
    float dqdy = u2 * uvdy.x - uvdy.y;
    
    float n = (uv.x * uv.x - uv.y) / sqrt(dqdx * dqdx + dqdy * dqdy);
    float a = 0.5 - n;
    if (a > 1) {
        return float4(1);
    } else {
        if (a < 0) {
            discard_fragment();
        }
        return float4(a);
    }
}
