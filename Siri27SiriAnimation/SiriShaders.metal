#include <metal_stdlib>
using namespace metal;

struct SiriUniforms {
    float2 iResolution;
    float iTime;
    float padding;
};

struct VertexOut {
    float4 position [[position]];
};

vertex VertexOut siriFullscreenVertex(uint vertexID [[vertex_id]]) {
    VertexOut out;
    float2 position = vertexID == 0 ? float2(-1.0, -1.0)
        : vertexID == 1 ? float2(3.0, -1.0)
        : float2(-1.0, 3.0);
    out.position = float4(position, 0.0, 1.0);
    return out;
}

constant float W_PI = 3.14159265359;
constant float W_AMPLITUDE = 0.32;
constant float W_FREQ = 1.1;
constant float W_ABER_FREQ = 1.0;
constant float W_SPEED = 2.4;
constant float W_WAVE_SCALE = 0.6;
constant float W_ABERRATION = 2.6;
constant float W_THICKNESS = 3.0;
constant float W_INTENSITY = 2.0;
constant float W_FALLOFF = 1.7;
constant float W_EDGE_MASK = 0.4;
constant float W_EDGE_INSET = 0.0;
constant float W_BAND_FILL = 30000.0;
constant float W_BAND_THICK = 0.08;
constant float W_SOFTNESS = 2.5;
constant float W_LOW_AMP = 6.0;
constant float W_LOW_INT = 1.5;
constant float W_MID_ABER = 0.8;
constant float W_MID_ABAMP = 0.05;
constant float W_MID_SOFT = 0.4;
constant float W_HIGH_ABER = 0.5;
constant float W_HIGH_ABAMP = 0.06;
constant float W_RESOLVED = 1.0;
constant float W_UNRES_SCALE = 0.14;

float3 waveSpectral4(int s) {
    float x = float(s);
    return clamp(
        float3(abs(x - 3.0) - 1.0, 2.0 - abs(x - 2.0), 2.0 - abs(x - 4.0)),
        float3(0.0),
        float3(1.0)
    );
}

float4 waveMain(float2 fragCoord, float2 resolution, float time) {
    float2 r = resolution.xy;
    float aspect = r.x / r.y;
    float2 p = (fragCoord + 0.5) * 2.0 / r - 1.0;
    p.x *= aspect;
    float yScreen = p.y;
    p /= max(W_WAVE_SCALE, 0.1);

    float t = time;
    float low = clamp(0.45 + 0.45 * sin(t * 0.8) * sin(t * 0.37 + 1.0), 0.0, 1.0);
    float mid = clamp(0.40 + 0.40 * sin(t * 1.7 + 2.0) * sin(t * 0.53), 0.0, 1.0);
    float high = clamp(0.30 + 0.30 * sin(t * 2.9 + 4.0) * sin(t * 0.71 + 2.0), 0.0, 1.0);

    float res = clamp(W_RESOLVED, 0.0, 1.0);
    float drift = fmod(t, 20.0 * W_PI) * W_SPEED;

    float xN = p.x / max(aspect, 1.0);
    float env = cos(W_PI * 0.5 * min(abs(0.9 * xN), 1.0));
    env *= env;

    float a1 = W_AMPLITUDE + 0.01 * low * W_LOW_AMP;
    float a2 = a1 + mid * W_MID_ABAMP + high * W_HIGH_ABAMP;
    float ab = (W_ABERRATION + mid * W_MID_ABER + high * W_HIGH_ABER) * res;
    float th = mix(0.1, 0.01 * W_THICKNESS, res);
    float inten = mix(0.1, 0.01 * (W_INTENSITY + low * W_LOW_INT), res);
    float soft = 0.01 * res * max(0.0, W_SOFTNESS + mid * W_MID_SOFT);

    float dUnres = max(length(p) - mix(0.14, W_UNRES_SCALE, res), 0.0);
    float yMain = a1 * env * res * sin(p.x * W_FREQ + drift);

    float bandFillTh = max(W_BAND_THICK, 1e-4);
    float bandAmt = 1e-4 * W_BAND_FILL * inten;
    float3 num = float3(0.0);
    float3 den = float3(0.0);

    for (int s = 0; s < 4; s++) {
        float3 hue = mix(float3(1.0), waveSpectral4(s), res);
        den += hue;
        float chroma = mix(-ab, ab, float(s) / 3.0);
        float yL = a2 * env * res * sin(p.x * W_ABER_FREQ + drift + chroma);
        float d = mix(dUnres, abs(p.y - yL), res);
        float lor = mix(1.0 / (1.0 + (0.02 * d) * (0.02 * d)), 1.0, res);
        float line = inten / (sqrt(d * d + soft * soft) + th);
        float lo = min(yMain, yL);
        float hi = max(yMain, yL);
        float dBand = max(0.0, max(p.y - hi, lo - p.y));
        float band = bandAmt / (dBand + bandFillTh);
        num += hue * lor * (line + band);
    }

    float3 col = num / den;

    float dM = mix(dUnres, abs(p.y - yMain), res);
    float lorM = mix(1.0 / (1.0 + (0.02 * dM) * (0.02 * dM)), 1.0, res);
    float boost = (1.0 - res) * (14.0 * low + 4.0);
    col += 0.5 * inten * (lorM + boost) / (sqrt(dM * dM + soft * soft) + th);

    col = pow(max(col, float3(0.0)), float3(1.5));
    float emT = clamp((abs(yScreen) - 1.0 + W_EDGE_INSET) / (-max(W_EDGE_MASK, 1e-4)), 0.0, 1.0);
    float em = emT * emT * (3.0 - 2.0 * emT);
    float gauss = exp(-pow(xN * W_FALLOFF, 2.0));
    col *= mix(1.0, em * gauss, res);
    col *= res;

    return float4(col, 1.0);
}

constant float O_TAU = 6.28318530718;
constant int O_N = 6;
constant float O_SMOOTH_K = 0.08;
constant float O_INTENSITY = 0.0025;
constant float O_FALLOFF_P = 1.35;
constant float O_FADE_START = 0.02;
constant float O_FADE_END = 0.56;
constant float O_ABERR = 0.005;
constant float3 O_SPECTRAL = float3(0.0, 0.5, 1.0) * O_ABERR;
constant float O_HUE_SPEED = 0.06;
constant float O_COLOR_K = 0.5;
constant float O_SAT = 0.01;
constant float O_HUE_SPAN = 0.667;
constant float O_MERGE_PERIOD = 6.0;
constant float O_STAGGER = 0.33;
constant float O_HOLD = 0.0;
constant float O_W = 4.6;
constant float O_L = 3.2;
constant float O_PIERCE = 0.12;
constant float O_RECOIL = 0.035;
constant float O_REC_LAG = 0.11;
constant float O_GATHER_PERIOD = 12.0;
constant float O_GATHER_START = 9.2;
constant float O_GATHER_HOLD = 0.8;
constant float O_GATHER_R = 0.008;
constant float O_GATHER_DIM = 0.85;
constant float O_GATHER_IN = 1.8;
constant float O_GATHER_IN_L = 7.5;
constant float O_BURST_W = 6.5;
constant float O_BURST_L = 4.0;
constant float O_CHARGE_T = 0.30;
constant float O_CHARGE_SHRK = 0.18;
constant float O_CHARGE_GLOW = 0.35;
constant float O_FLASH_GAIN = 1.2;
constant float O_FLASH_DECAY = 7.0;

float orbHash11(float n) {
    return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

float orbSettleWL(float tau, float w, float l) {
    if (tau <= 0.0) {
        return 0.0;
    }
    return 1.0 - exp(-l * tau) * cos(w * tau);
}

float orbSettle(float tau) {
    return orbSettleWL(tau, O_W, O_L);
}

float orbSettleCrit(float tau, float l) {
    if (tau <= 0.0) {
        return 0.0;
    }
    return 1.0 - exp(-l * tau) * (1.0 + l * tau);
}

float orbSmin(float a, float b, float k) {
    float h = max(k - abs(a - b), 0.0) / k;
    return min(a, b) - h * h * k * 0.25;
}

float3 orbHue2rgb(float h) {
    h = fract(h);
    float r = clamp(abs(h * 6.0 - 3.0) - 1.0, 0.0, 1.0);
    float g = clamp(2.0 - abs(h * 6.0 - 2.0), 0.0, 1.0);
    float b = clamp(2.0 - abs(h * 6.0 - 4.0), 0.0, 1.0);
    return float3(r, g, b);
}

float orbDotR(float fi, float seed, float t) {
    return 0.036 + 0.010 * sin(t * 1.3 + seed * O_TAU) + 0.005 * sin(t * 2.4 + fi * 1.3);
}

float orbDotSD(float2 p, float2 pos, float r, float t, float fi, float shapeDamp) {
    float2 d = p - pos;
    float sq = 0.075 * (0.5 + 0.5 * sin(t * 0.9 + fi * 2.0)) * shapeDamp;
    float ca = cos(t * 0.35 + fi);
    float sa = sin(t * 0.35 + fi);
    d = float2(ca * d.x + sa * d.y, -sa * d.x + ca * d.y);
    d *= float2(1.0 + sq, 1.0 - sq);
    return length(d) - r;
}

float3 orbScene(float2 p, float t) {
    float k = floor(t / O_MERGE_PERIOD);
    float u = fract(t / O_MERGE_PERIOD);
    float te = u * O_MERGE_PERIOD;
    float tg = fmod(t, O_GATHER_PERIOD);
    float g = orbSettleCrit((tg - O_GATHER_START) * O_GATHER_IN, O_GATHER_IN_L)
        - orbSettleWL(tg - O_GATHER_START - O_GATHER_HOLD, O_BURST_W, O_BURST_L);
    float gC = clamp(g, 0.0, 1.0);
    float tb = tg - (O_GATHER_START + O_GATHER_HOLD);
    float charge = smoothstep(-O_CHARGE_T, 0.0, min(tb, 0.0)) * gC;
    float flash = tb > 0.0 ? exp(-tb * O_FLASH_DECAY) : 0.0;
    float gBright = mix(1.0, O_GATHER_DIM, gC) * (1.0 + O_CHARGE_GLOW * charge + O_FLASH_GAIN * flash);

    float3 total3 = float3(1e5);
    float3 cAcc = float3(0.0);
    float wAcc = 1e-6;

    for (int i = 0; i < O_N; i++) {
        float fi = float(i);
        float seed = orbHash11(fi);
        float ang = fi / float(O_N) * O_TAU + t * 0.35;
        float2 dir = float2(cos(ang), sin(ang));
        float ringRadius = 0.17 + 0.010 * sin(t * 1.0) + 0.007 * sin(t * 1.3 + seed * O_TAU);
        float pairId = fmod(fi, 3.0);
        float moverLow = fmod(k + pairId, 2.0);
        float isMover = (fi < 2.5) ? step(moverLow, 0.5) : step(0.5, moverLow);
        float goStart = pairId * O_STAGGER;
        float retStart = 3.0 * O_STAGGER + O_HOLD + pairId * O_STAGGER;
        float m = (orbSettle(te - goStart) - orbSettle(te - retStart)) * isMover;
        float rec = (orbSettle(te - goStart - O_REC_LAG) - orbSettle(te - retStart - O_REC_LAG)) * (1.0 - isMover);

        float rSelf = orbDotR(fi, seed, t);
        rSelf = mix(rSelf, 0.036, gC);
        rSelf *= 1.0 - O_CHARGE_SHRK * charge;

        float fj = fmod(fi + 3.0, 6.0);
        float rPart = orbDotR(fj, orbHash11(fj), t);
        float deep = -(ringRadius + O_RECOIL) - O_PIERCE * rPart;
        float radial = mix(ringRadius, deep, m) + O_RECOIL * rec;
        radial = mix(radial, O_GATHER_R, g);
        float2 pos = radial * dir;

        float sdR = orbDotSD(p - O_SPECTRAL.r * dir, pos, rSelf, t, fi, 1.0 - gC);
        float sdG = orbDotSD(p - O_SPECTRAL.g * dir, pos, rSelf, t, fi, 1.0 - gC);
        float sdB = orbDotSD(p - O_SPECTRAL.b * dir, pos, rSelf, t, fi, 1.0 - gC);
        total3 = float3(
            orbSmin(total3.r, sdR, O_SMOOTH_K),
            orbSmin(total3.g, sdG, O_SMOOTH_K),
            orbSmin(total3.b, sdB, O_SMOOTH_K)
        );

        float hue = fract(fi / float(O_N) + t * O_HUE_SPEED) * O_HUE_SPAN;
        float3 dotCol = mix(float3(1.0), orbHue2rgb(hue), O_SAT);
        float w = exp(-sdG * O_COLOR_K);
        cAcc += w * dotCol;
        wAcc += w;
    }

    float3 sd3 = max(total3, float3(0.0)) + 1e-4;
    float3 core3 = clamp(O_INTENSITY / pow(sd3, float3(O_FALLOFF_P)), float3(0.0), float3(1.0));
    float3 edge3 = 1.0 - smoothstep(float3(O_FADE_START), float3(O_FADE_END), sd3);
    float3 bright = core3 * edge3 * gBright;
    return bright * (cAcc / wAcc);
}

float4 orbMain(float2 fragCoord, float2 resolution, float time) {
    float2 p = (2.0 * fragCoord - resolution) / min(resolution.x, resolution.y);
    float t = time;
    p /= 1.0 + 0.03 * sin(t * 1.0);
    float3 col = orbScene(p, t);
    col *= 1.0 + 0.05 * sin(t * 1.0 + 1.0);
    col = pow(col, float3(1.0 / 1.2));
    col = min(col, float3(1.0));
    float n = fract(sin(dot(fragCoord, float2(12.9898, 78.233))) * 43758.5453);
    col += (n - 0.5) / 255.0;
    return float4(col, 1.0);
}

fragment float4 siriWaveFragment(VertexOut in [[stage_in]],
                                 constant SiriUniforms &uniforms [[buffer(0)]]) {
    float2 fragCoord = float2(in.position.x, uniforms.iResolution.y - in.position.y);
    return waveMain(fragCoord, uniforms.iResolution, uniforms.iTime);
}

fragment float4 siriFluidDotsFragment(VertexOut in [[stage_in]],
                                      constant SiriUniforms &uniforms [[buffer(0)]]) {
    float2 fragCoord = float2(in.position.x, uniforms.iResolution.y - in.position.y);
    return orbMain(fragCoord, uniforms.iResolution, uniforms.iTime);
}
