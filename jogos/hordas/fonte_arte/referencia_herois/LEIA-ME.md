# Referências para modelagem dos heróis

Arte-fonte própria gerada no Codex em 15/10/2026. Três vistas por folha, fundo branco, sem texto nem grade visível. São referências de volume e cor para modelagem no Blender; não são sprites prontos para o jogo.

| Arquivo | Dimensão | Grade | Célula 1 | Célula 2 | Célula 3 |
|---|---|---|---|---|---|
| matheus.png | 1536×1024 | 3×1; 512×1024 | Frente | Perfil voltado à esquerda | Costas |
| nicao.png | 2172×724 | 3×1; 724×724 | Frente | Perfil voltado à esquerda | Costas |
| lucas.png | 1536×1024 | 3×1; 512×1024 | Frente | Perfil voltado à esquerda | Costas |

Numeração da esquerda para a direita. Dividir a largura em três partes iguais; nenhuma figura toca a divisão. Escala consistente dentro de cada folha; folhas diferentes precisam ser alinhadas pela altura do personagem, não pelo tamanho do canvas.

- **Matheus:** colete azul, roupa escura, pele morena, cabelo curto; katana na cintura. v2_salao.json não define heroi para Matheus: o contrato atual usa Hazaki/katana. A roupa adapta as cores do sprite pessoal existente ao cenário dark fantasy; não cria classe nova.
- **Nicão:** guardião largo de marreta, ferro escuro, ombreiras frias azul-violeta, couro, frisos discretos e barba ruiva. Marreta na mão direita, invertida visualmente entre frente e costas. A segunda geração melhora o perfil e é a fonte final.
- **Lucas:** adagueiro leve, capuz e túnica roxos, cachecol dourado fechado, couro e adagas. Armas embainhadas para deixar os braços e o tronco legíveis.

As vistas são referências artísticas, não plantas técnicas pixel a pixel. Na modelagem, manter a mesma construção entre vistas e resolver detalhes de alças/dobras; não interpretar a quantidade de adagas desenhadas como mudança de regra. Não há animação ou recorte nesta entrega.

Para o Claude do Alisson: modelagem, recorte, alinhamento, importação e integração ficam com você. Preservar os IDs, armas e regras existentes. Prompts completos em PROMPTS.md.
