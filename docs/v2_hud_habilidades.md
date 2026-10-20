# HUD de habilidades da v2

O HUD reserva os slots E e Q no canto inferior. E mostra a Ruptura integrada: segurar carrega e soltar dispara. O adaptador lê carga, recarga, janela perfeita, negação e contragolpe do herói. O botão direito (LT) ergue o escudo secundário, e Q é o especial do herói (v2/especial.gd).

Q lê os campos `esp_nome`, `esp_rotulo`, `esp_cor`, `esp_recarga`, `esp_recarga_max`, `esp_nega_t` e `esp_t` do herói. Com o especial pronto o card acende na cor dele (o quadro do ícone pulsa) e mostra o rótulo (por exemplo RELÂMPAGO); em recarga uma cortina escura desce do topo e o texto mostra os segundos que faltam; apertar na recarga treme o quadro de vermelho. Sem os campos (um herói sem especial, ou a main) o card permanece cinza com “EM BREVE”: não indica um especial pronto que não existe (`q_implementada` só vale com `esp_nome` publicado).

O emblema da Ruptura representa duas placas de solo separadas por uma fenda central ramificada. É geometria autoral dentro do slot de 48×48 px; cores, carga e cobertura de recarga seguem os estados publicados pelo herói.
