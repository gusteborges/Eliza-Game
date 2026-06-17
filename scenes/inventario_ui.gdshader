shader_type canvas_item;

// === PARÂMETROS ===
uniform vec4  line_color   : source_color = vec4(0.05, 1.0, 0.45, 1.0);
uniform float thickness    : hint_range(0.002, 0.06) = 0.018;
uniform float sweep_speed  : hint_range(0.05, 0.5)   = 0.16;  // velocidade do cursor (UV/seg)
uniform float heart_rate   : hint_range(0.3,  6.0)   = 0.6;   // batimentos por segundo
uniform float glow_spread  : hint_range(2.0,  30.0)  = 8.0;
uniform float tail_length  : hint_range(0.1,  0.95)  = 0.62;
uniform float arrhythmia   : hint_range(0.0,  1.0)   = 0.0;

// ──────────────────────────────────────────────
float hash(float n) {
    return fract(sin(n * 127.1 + 311.7) * 43758.5453);
}

float gpeak(float x, float center, float width, float height) {
    float d = (x - center) * width;
    return height * exp(-d * d);
}

// ──────────────────────────────────────────────
//  ECG SINUSAL — ritmo regular e limpo
//  Curva PQRST consistente, sem variação aleatória
// ──────────────────────────────────────────────
float ecg_normal(float t) {
    float y = 0.0;
    y += gpeak(t, 0.190, 52.0, 0.14);   // P  — bump suave antes do QRS
    y -= gpeak(t, 0.358, 240.0, 0.22);  // Q  — descida rápida
    y += gpeak(t, 0.393, 300.0, 1.15);  // R  — pico principal estreito e alto
    y -= gpeak(t, 0.430, 210.0, 0.28);  // S  — descida abaixo da linha
    y += gpeak(t, 0.625, 26.0,  0.27);  // T  — bump largo pós-QRS
    return y;
}

// ──────────────────────────────────────────────
//  ECG ARRÍTMICO — variação caótica por batimento
// ──────────────────────────────────────────────
float ecg_arritmia(float t, float beat_id) {
    float h0 = hash(beat_id);
    float h1 = hash(beat_id + 7.3);
    float h2 = hash(beat_id + 13.7);
    float h3 = hash(beat_id + 31.1);
    float h4 = hash(beat_id + 53.9);

    float amp_r = 0.50 + h0 * 1.15;
    float pos_r = 0.35 + h1 * 0.08;
    float wid_r = 220.0 + h2 * 180.0;
    float amp_t = 0.16 + h3 * 0.35;
    float pos_t = 0.58 + h3 * 0.12;
    float amp_p = 0.12 + h4 * 0.15;

    float y = 0.0;
    y += gpeak(t, 0.15, 46.0, amp_p);
    y -= gpeak(t, pos_r - 0.050, 160.0, 0.30 + h1 * 0.16);
    y += gpeak(t, pos_r, wid_r, amp_r);
    if (h2 > 0.45)
        y += gpeak(t, pos_r + 0.028, wid_r * 0.46, amp_r * 0.33);
    y -= gpeak(t, pos_r + 0.057, 170.0, 0.32 + h0 * 0.16);
    y += gpeak(t, pos_t, 20.0 + h1 * 14.0, amp_t);
    return y;
}

// ──────────────────────────────────────────────
//  FRAGMENT — abordagem osciloscópio (cursor varre da esq. para dir.)
// ──────────────────────────────────────────────
void fragment() {
    // Posição do cursor varrendo continuamente de 0 → 1
    float cursor = fract(TIME * sweep_speed);

    // "Idade" deste pixel: 0 = cursor acabou de passar, 1 = cursor vai voltar em breve
    float age = fract(cursor - UV.x + 1.0);

    // Zona de apagamento: pequena região à frente do cursor (será redesenhada)
    const float ERASE = 0.05;
    float in_erase = step(1.0 - ERASE, age);

    // Fade da trilha: brilhante perto, some com o tempo
    float fade = mix(1.0 - smoothstep(0.0, tail_length, age), 0.0, in_erase);

    // ── Qual ECG estava sendo desenhado quando o cursor passou aqui? ──
    float t_visit   = TIME - age / sweep_speed;       // tempo real daquele momento
    float ecg_phase = t_visit * heart_rate;            // fase do batimento
    float beat_id   = floor(ecg_phase);
    float beat_t    = fract(ecg_phase);

    // Mistura entre sinusal e arrítmico
    float wave_n = ecg_normal(beat_t);
    float wave_a = ecg_arritmia(beat_t, beat_id);
    float wave_y = 0.5 - mix(wave_n, wave_a, arrhythmia) * 0.22;
    wave_y = clamp(wave_y, 0.03, 0.97);

    float dist = abs(UV.y - wave_y);

    // ── Camadas de brilho ──
    float core  = smoothstep(thickness,                      0.0, dist);
    float glow1 = smoothstep(thickness * glow_spread * 0.38, 0.0, dist);
    float glow2 = smoothstep(thickness * glow_spread,         0.0, dist);

    vec3 white_core = mix(line_color.rgb, vec3(1.0), 0.70);
    vec3 col =
          white_core     * core  * 1.0
        + line_color.rgb * glow1 * 0.95
        + line_color.rgb * glow2 * 0.45;

    float alpha = clamp(core * 2.2 + glow1 * 1.1 + glow2 * 0.55, 0.0, 1.0);

    col   *= fade;
    alpha *= fade;
	
	float scan = 0.92 + sin(UV.y * 180.0) * 0.08;
	col *= scan;
	
    COLOR = vec4(col, alpha);
}