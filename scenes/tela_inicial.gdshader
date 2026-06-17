shader_type canvas_item;

// Variáveis no Inspetor
uniform vec4 cor_vinheta : source_color = vec4(0.0, 0.0, 0.0, 1.0); 
uniform float raio_interno = 0.12; // Bem fechado no centro
uniform float suavidade = 0.60; // Escurece mais rápido
uniform float intensidade = 0.4; // NOVO: Deixa as sombras mais agressivas

void fragment() {
    vec2 uv = UV;
    vec2 centro = uv - vec2(0.5);
    
    // DICA PRO: Descomente a linha abaixo removendo as duas barras "//" 
    // se quiser que a vinheta fique redondinha (assumindo uma tela 16:9). 
    // Se preferir ela esticada acompanhando a tela, deixe como está.
    // centro.x *= 16.0 / 9.0; 
    
    float distancia = length(centro);
    
    float vinheta = smoothstep(raio_interno, suavidade, distancia);
    
    // Aplica uma potência para deixar o escuro mais denso nas bordas
    vinheta = pow(vinheta, intensidade);
    
    COLOR = vec4(cor_vinheta.rgb, cor_vinheta.a * vinheta);
}