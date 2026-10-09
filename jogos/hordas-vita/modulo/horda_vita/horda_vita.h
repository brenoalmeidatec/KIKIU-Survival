// Horda do port PS Vita (KIKIU Survival) em C++: simulação, grade espacial, separação, LOD, projéteis, golpe,
// ordem por Y e desenho de TODOS os inimigos e projéteis numa triangle array por quadro (no GLES2 do godot-vita,
// cada triangle array é um único glDrawElements). O GDScript só configura e lê as estatísticas.
// Medido no Vita com a horda em GDScript: ~0,064 ms de lógica e ~0,045 ms de desenho por inimigo; aqui a meta é
// ficar perto de microssegundos por inimigo, para o quadro caber em 20-25 ms (40-50 fps) com 300+ inimigos.

#ifndef HORDA_VITA_H
#define HORDA_VITA_H

#include "core/math/rect2.h"
#include "scene/2d/node_2d.h"
#include "scene/resources/texture.h"

#include <stdint.h>
#include <vector>

class HordaVita : public Node2D {
	GDCLASS(HordaVita, Node2D);

	struct Tipo {
		float vel = 50.0f;
		float raio = 10.0f;
		float qx = 16.0f; // largura do quadro na tela (px)
		float qy = 16.0f; // altura do quadro no atlas, já com a faixa da sombra embaixo
		float quadro_px = 0.1f; // quadros de andar por px andado
		int nq = 2; // quadros de andar
		int vistas = 1;
		bool luz = false;
		std::vector<Rect2> uv; // recorte normalizado de cada quadro: [linha * nq + coluna]
	};

	struct Proj {
		float x, y, vx, vy, vida;
	};

	std::vector<Tipo> tipos;
	Ref<Texture> atlas;
	Rect2 uv_proj;
	Vector2 tam_proj;

	// inimigos, estrutura de arrays
	std::vector<float> px, py, vx, vy, spd, fase;
	std::vector<uint8_t> tp, linha, vira, perto;
	std::vector<Proj> projeteis;

	// grade espacial (só dos inimigos perto da tela), contagem + soma de prefixos
	std::vector<int> cel_ini, cel_itens, cel_cursor;
	int gx0 = 0, gy0 = 0, gw = 0, gh = 0;

	// desenho
	std::vector<uint64_t> ordem;
	Vector<Point2> pontos, uvs;
	Vector<int> indices;
	Vector<Color> cores;

	Vector2 alvo;
	Rect2 visivel = Rect2(0, 0, 480, 272);
	int max_desenho = 2000;
	int lod_longe = 4;
	bool ordenar_y = true;
	uint32_t quadro = 0;
	uint32_t semente = 2463534242u;

	int n_perto = 0;
	int n_desenhados = 0;
	int acertos = 0;
	int us_logica = 0;
	int us_desenho = 0;
	int us_proj = 0;

	float aleatorio(); // 0..1
	Vector2 ponto_no_anel();
	void montar_grade(const Rect2 &p_perto);
	int celula(float p_x, float p_y) const; // -1 fora da grade
	void desenhar();

protected:
	void _notification(int p_what);
	static void _bind_methods();

public:
	void configurar(const Ref<Texture> &p_atlas, const Array &p_tipos, const Rect2 &p_src_proj);
	void definir_quantidade(int p_n);
	void definir_alvo(const Vector2 &p_alvo, const Rect2 &p_visivel);
	void definir_limites(int p_max_desenho, int p_lod_longe, bool p_ordenar_y);
	void passo(float p_dt);
	PoolVector2Array golpe(const Vector2 &p_centro, float p_raio);
	void disparar(const Vector2 &p_origem, const Vector2 &p_vel, float p_vida);
	PoolVector2Array luzes(const Rect2 &p_area, int p_max) const;
	Dictionary estatisticas() const;
	int quantidade() const { return (int)px.size(); }

	HordaVita();
};

#endif // HORDA_VITA_H
