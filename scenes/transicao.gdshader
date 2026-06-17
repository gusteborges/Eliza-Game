shader_type canvas_item;

// Controla onde a mancha vai ficar (0.0 a 1.0). 
// X: 0.9 e Y: 0.85 normalmente é o canto inferior direito da tela.
uniform vec2 posicao_logo = vec2(0.9, 0.85); 

// O tamanho do "miolo" totalmente escuro da mancha
uniform float tamanho_mancha = 0.05; 

// O quão suave a borda da mancha se mistura com o vídeo (para não parecer um adesivo duro)
uniform float suavidade = 0.15; 

// A cor da mancha (Preto)
uniform vec4 cor_mancha : source_color = vec4(0.0, 0.0, 0.0, 1.0); 

void fragment() {
    // Calcula a distância do pixel atual até a coordenada da logo
    float distancia = distance(UV, posicao_logo);
    
    // Cria um efeito de esfumaçado: 1.0 no centro da posição, e 0.0 fora dela
    float forca_mancha = smoothstep(tamanho_mancha + suavidade, tamanho_mancha, distancia);
    
    // Aplica a cor preta com a transparência apenas onde a mancha existe
    COLOR = vec4(cor_mancha.rgb, cor_mancha.a * forca_mancha);
}