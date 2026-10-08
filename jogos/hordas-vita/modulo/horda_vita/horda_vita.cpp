#include "horda_vita.h"

#include "core/math/math_funcs.h"
#include "core/os/os.h"
#include "servers/visual_server.h"

#include <algorithm>
#include <math.h>

static const float CELULA = 32.0f;
static const float INV_CELULA = 1.0f / 32.0f;
static const float MARGEM = 48.0f;
static const int VIZ_MAX = 8; // teto de vizinhos olhados na separação
static const int QUADS_POR_LOTE = 1800; // 7200 vértices: cabe no buffer de polígono padrão (128 KB) com UV e cor única

float HordaVita::aleatorio() {
	// xorshift32: barato e determinístico
	semente ^= semente << 13;
	semente ^= semente >> 17;
	semente ^= semente << 5;
	return (semente >> 8) * (1.0f / 16777216.0f);
}

Vector2 HordaVita::ponto_no_anel() {
	float meia = visivel.size.length() * 0.5f;
	float r = meia + 20.0f + aleatorio() * 220.0f;
	float a = aleatorio() * (float)Math_TAU;
	return alvo + Vector2(cosf(a), sinf(a)) * r;
}

void HordaVita::configurar(const Ref<Texture> &p_atlas, const Array &p_tipos, const Rect2 &p_src_proj) {
	ERR_FAIL_COND(p_atlas.is_null());
	atlas = p_atlas;
	float aw = (float)atlas->get_width();
	float ah = (float)atlas->get_height();
	tipos.clear();
	for (int i = 0; i < p_tipos.size(); i++) {
		Dictionary d = p_tipos[i];
		Tipo t;
		t.vel = d.get("vel", 50.0);
		t.raio = d.get("raio", 10.0);
		t.qx = d.get("qx", 16.0);
		t.qy = d.get("qy", 16.0);
		t.quadro_px = d.get("quadro_px", 0.1);
		t.nq = MAX(1, (int)d.get("nq", 2));
		t.vistas = MAX(1, (int)d.get("vistas", 1));
		t.luz = d.get("luz", false);
		Array src = d.get("src", Array());
		for (int k = 0; k < src.size(); k++) {
			Rect2 r = src[k];
			t.uv.push_back(Rect2(r.position.x / aw, r.position.y / ah, r.size.x / aw, r.size.y / ah));
		}
		if ((int)t.uv.size() < t.nq * t.vistas) {
			// mantém o índice do tipo (o GDScript conta por posição): completa com o primeiro recorte
			ERR_PRINT("HordaVita: tipo sem recortes suficientes");
			Rect2 reserva = t.uv.empty() ? Rect2(0, 0, 0, 0) : t.uv[0];
			t.uv.resize(t.nq * t.vistas, reserva);
		}
		tipos.push_back(t);
	}
	for (size_t i = 0; i < tp.size(); i++) {
		if (tp[i] >= tipos.size()) {
			tp[i] = 0;
		}
	}
	uv_proj = Rect2(p_src_proj.position.x / aw, p_src_proj.position.y / ah, p_src_proj.size.x / aw, p_src_proj.size.y / ah);
	tam_proj = p_src_proj.size;
}

void HordaVita::definir_quantidade(int p_n) {
	ERR_FAIL_COND(tipos.empty());
	int antes = (int)px.size();
	px.resize(p_n);
	py.resize(p_n);
	vx.resize(p_n);
	vy.resize(p_n);
	spd.resize(p_n);
	fase.resize(p_n);
	tp.resize(p_n);
	linha.resize(p_n);
	vira.resize(p_n);
	perto.resize(p_n);
	for (int i = antes; i < p_n; i++) {
		Vector2 p = ponto_no_anel();
		px[i] = p.x;
		py[i] = p.y;
		vx[i] = vy[i] = spd[i] = 0.0f;
		fase[i] = aleatorio() * 6.0f;
		tp[i] = (uint8_t)(semente % tipos.size());
		aleatorio();
		linha[i] = vira[i] = perto[i] = 0;
	}
	cel_itens.resize(p_n);
	// a grade antiga aponta para índices que podem não existir mais: invalida até o próximo passo()
	cel_ini.clear();
	gw = gh = 0;
	n_perto = 0;
}

void HordaVita::definir_alvo(const Vector2 &p_alvo, const Rect2 &p_visivel) {
	alvo = p_alvo;
	visivel = p_visivel;
}

void HordaVita::definir_limites(int p_max_desenho, int p_lod_longe, bool p_ordenar_y) {
	max_desenho = MAX(0, p_max_desenho);
	lod_longe = CLAMP(p_lod_longe, 1, 16);
	ordenar_y = p_ordenar_y;
}

int HordaVita::celula(float p_x, float p_y) const {
	int cx = (int)floorf(p_x * INV_CELULA) - gx0;
	int cy = (int)floorf(p_y * INV_CELULA) - gy0;
	if (cx < 0 || cy < 0 || cx >= gw || cy >= gh) {
		return -1;
	}
	return cy * gw + cx;
}

void HordaVita::montar_grade(const Rect2 &p_perto) {
	gx0 = (int)floorf(p_perto.position.x * INV_CELULA);
	gy0 = (int)floorf(p_perto.position.y * INV_CELULA);
	gw = (int)floorf((p_perto.position.x + p_perto.size.x) * INV_CELULA) - gx0 + 1;
	gh = (int)floorf((p_perto.position.y + p_perto.size.y) * INV_CELULA) - gy0 + 1;
	int nc = gw * gh;
	cel_ini.assign(nc + 1, 0);
	cel_cursor.resize(nc);
	int n = (int)px.size();
	const float x0 = p_perto.position.x, y0 = p_perto.position.y;
	const float x1 = x0 + p_perto.size.x, y1 = y0 + p_perto.size.y;
	n_perto = 0;
	for (int i = 0; i < n; i++) {
		bool dentro = px[i] >= x0 && px[i] < x1 && py[i] >= y0 && py[i] < y1;
		perto[i] = dentro;
		if (dentro) {
			int c = celula(px[i], py[i]);
			if (c >= 0) {
				cel_ini[c + 1]++;
				n_perto++;
			} else {
				perto[i] = 0;
			}
		}
	}
	for (int c = 0; c < nc; c++) {
		cel_ini[c + 1] += cel_ini[c];
		cel_cursor[c] = cel_ini[c];
	}
	for (int i = 0; i < n; i++) {
		if (perto[i]) {
			cel_itens[cel_cursor[celula(px[i], py[i])]++] = i;
		}
	}
}

void HordaVita::passo(float p_dt) {
	uint64_t t0 = OS::get_singleton()->get_ticks_usec();
	quadro++;
	Rect2 r_perto = visivel.grow(MARGEM);
	montar_grade(r_perto);
	int n = (int)px.size();
	float longe = visivel.size.length() * 1.6f;
	float longe2 = longe * longe;
	const float ax = alvo.x, ay = alvo.y;

	for (int i = 0; i < n; i++) {
		const Tipo &t = tipos[tp[i]];
		float x = px[i], y = py[i];
		if (perto[i]) {
			// separação: vizinhos nas 3x3 células, com teto
			float lim = t.raio * 1.6f;
			float lim2 = lim * lim;
			float ex = 0.0f, ey = 0.0f;
			int olhados = 0;
			int cx = (int)floorf(x * INV_CELULA) - gx0;
			int cy = (int)floorf(y * INV_CELULA) - gy0;
			for (int oy = -1; oy <= 1 && olhados < VIZ_MAX; oy++) {
				int yy = cy + oy;
				if (yy < 0 || yy >= gh) {
					continue;
				}
				for (int ox = -1; ox <= 1 && olhados < VIZ_MAX; ox++) {
					int xx = cx + ox;
					if (xx < 0 || xx >= gw) {
						continue;
					}
					int c = yy * gw + xx;
					for (int k = cel_ini[c]; k < cel_ini[c + 1]; k++) {
						int j = cel_itens[k];
						if (j == i) {
							continue;
						}
						float dx = x - px[j], dy = y - py[j];
						float d2 = dx * dx + dy * dy;
						if (d2 < lim2 && d2 > 0.01f) {
							float d = sqrtf(d2);
							float f = (1.0f - d / lim) / d;
							ex += dx * f;
							ey += dy * f;
						}
						if (++olhados >= VIZ_MAX) {
							break;
						}
					}
				}
			}
			float dx = ax - x, dy = ay - y;
			float dist2 = dx * dx + dy * dy;
			float nvx = ex * 90.0f, nvy = ey * 90.0f;
			if (dist2 > 1.0f) {
				float k = t.vel / sqrtf(dist2);
				nvx += dx * k;
				nvy += dy * k;
			}
			vx[i] = nvx;
			vy[i] = nvy;
			float s = sqrtf(nvx * nvx + nvy * nvy);
			spd[i] = s;
			if (t.vistas > 1 && s > 0.5f) {
				// 0 de frente (descendo) .. 4 de costas; esquerda = espelho
				float ang = atan2f(fabsf(nvx), nvy) * (float)(180.0 / Math_PI);
				int l = (int)(ang / 45.0f + 0.5f);
				linha[i] = (uint8_t)CLAMP(l, 0, MIN(4, t.vistas - 1));
				vira[i] = nvx < 0.0f;
			}
			px[i] = x + nvx * p_dt;
			py[i] = y + nvy * p_dt;
			fase[i] += s * p_dt * t.quadro_px;
			if (fase[i] > 6000.0f) {
				fase[i] -= 6000.0f;
			}
		} else if (((uint32_t)i + quadro) % (uint32_t)lod_longe == 0) {
			float dx = ax - x, dy = ay - y;
			float d2 = dx * dx + dy * dy;
			if (d2 > longe2) {
				Vector2 p = ponto_no_anel();
				px[i] = p.x;
				py[i] = p.y;
			} else if (d2 > 0.01f) {
				float k = t.vel * p_dt * lod_longe / sqrtf(d2);
				px[i] = x + dx * k;
				py[i] = y + dy * k;
			}
		}
	}
	uint64_t t1 = OS::get_singleton()->get_ticks_usec();

	// projéteis: acertam pela grade (célula onde estão) e somem sem matar (inimigo com vida)
	for (int k = (int)projeteis.size() - 1; k >= 0; k--) {
		Proj &p = projeteis[k];
		p.x += p.vx * p_dt;
		p.y += p.vy * p_dt;
		p.vida -= p_dt;
		bool morreu = p.vida <= 0.0f;
		if (!morreu) {
			int c = celula(p.x, p.y);
			if (c >= 0) {
				for (int m = cel_ini[c]; m < cel_ini[c + 1]; m++) {
					int i = cel_itens[m];
					float r = tipos[tp[i]].raio + 4.0f;
					float dx = p.x - px[i], dy = p.y - (py[i] - 10.0f);
					if (dx * dx + dy * dy < r * r) {
						acertos++;
						morreu = true;
						break;
					}
				}
			}
		}
		if (morreu) {
			projeteis[k] = projeteis.back();
			projeteis.pop_back();
		}
	}
	uint64_t t2 = OS::get_singleton()->get_ticks_usec();
	us_logica = (int)(t1 - t0);
	us_proj = (int)(t2 - t1);
	update();
}

PoolVector2Array HordaVita::golpe(const Vector2 &p_centro, float p_raio) {
	PoolVector2Array mortes;
	float r2 = p_raio * p_raio;
	int alc = (int)ceilf(p_raio * INV_CELULA);
	int cx = (int)floorf(p_centro.x * INV_CELULA) - gx0;
	int cy = (int)floorf(p_centro.y * INV_CELULA) - gy0;
	for (int yy = cy - alc; yy <= cy + alc; yy++) {
		if (yy < 0 || yy >= gh) {
			continue;
		}
		for (int xx = cx - alc; xx <= cx + alc; xx++) {
			if (xx < 0 || xx >= gw) {
				continue;
			}
			int c = yy * gw + xx;
			for (int m = cel_ini[c]; m < cel_ini[c + 1]; m++) {
				int i = cel_itens[m];
				float dx = px[i] - p_centro.x, dy = py[i] - p_centro.y;
				if (dx * dx + dy * dy < r2) {
					mortes.push_back(Vector2(px[i], py[i]));
					Vector2 p = ponto_no_anel();
					px[i] = p.x;
					py[i] = p.y;
					perto[i] = 0; // a grade fica velha até o próximo passo; não acerta o mesmo duas vezes
				}
			}
		}
	}
	return mortes;
}

void HordaVita::disparar(const Vector2 &p_origem, const Vector2 &p_vel, float p_vida) {
	if (projeteis.size() >= 256) {
		return;
	}
	Proj p = { p_origem.x, p_origem.y, p_vel.x, p_vel.y, p_vida };
	projeteis.push_back(p);
}

PoolVector2Array HordaVita::luzes(const Rect2 &p_area, int p_max) const {
	PoolVector2Array r;
	int n = (int)px.size();
	for (int i = 0; i < n && r.size() < p_max; i++) {
		if (tipos[tp[i]].luz && p_area.has_point(Vector2(px[i], py[i]))) {
			r.push_back(Vector2(px[i], py[i]));
		}
	}
	return r;
}

Dictionary HordaVita::estatisticas() const {
	Dictionary d;
	d["perto"] = n_perto;
	d["desenhados"] = n_desenhados;
	d["us_logica"] = us_logica;
	d["us_desenho"] = us_desenho;
	d["us_proj"] = us_proj;
	d["projeteis"] = (int)projeteis.size();
	d["acertos"] = acertos;
	return d;
}

void HordaVita::desenhar() {
	uint64_t t0 = OS::get_singleton()->get_ticks_usec();
	if (atlas.is_null() || tipos.empty()) {
		return;
	}
	Rect2 vis = visivel.grow(32.0f);
	const float x0 = vis.position.x, y0 = vis.position.y;
	const float x1 = x0 + vis.size.x, y1 = y0 + vis.size.y;
	int n = (int)px.size();
	ordem.clear();
	for (int i = 0; i < n && (int)ordem.size() < max_desenho; i++) {
		if (px[i] >= x0 && px[i] < x1 && py[i] >= y0 && py[i] < y1) {
			// chave: Y em 1/16 px nos 32 bits altos, índice nos baixos
			uint32_t ky = ordenar_y ? (uint32_t)((py[i] - y0 + 64.0f) * 16.0f) : 0u;
			ordem.push_back(((uint64_t)ky << 32) | (uint32_t)i);
		}
	}
	if (ordenar_y) {
		std::sort(ordem.begin(), ordem.end());
	}
	n_desenhados = (int)ordem.size();
	int nq = n_desenhados + (int)projeteis.size();
	RID tex = atlas->get_rid();
	VisualServer *vs = VisualServer::get_singleton();
	RID ci = get_canvas_item();
	int feito = 0;
	while (feito < nq) {
		int lote = MIN(QUADS_POR_LOTE, nq - feito);
		pontos.resize(lote * 4);
		uvs.resize(lote * 4);
		indices.resize(lote * 6);
		Point2 *pw = pontos.ptrw();
		Point2 *uw = uvs.ptrw();
		int *iw = indices.ptrw();
		for (int q = 0; q < lote; q++) {
			int g = feito + q;
			float dx0, dy0, dx1, dy1, u0, v0, u1, v1;
			if (g < n_desenhados) {
				int i = (int)(ordem[g] & 0xffffffffu);
				const Tipo &t = tipos[tp[i]];
				int col = ((int)fase[i]) % t.nq;
				const Rect2 &uv = t.uv[linha[i] * t.nq + col];
				dx0 = px[i] - t.qx * 0.5f;
				dy0 = py[i] - t.qy + 6.0f;
				dx1 = dx0 + t.qx;
				dy1 = dy0 + t.qy;
				u0 = uv.position.x;
				u1 = u0 + uv.size.x;
				if (vira[i]) {
					float tmp = u0;
					u0 = u1;
					u1 = tmp;
				}
				v0 = uv.position.y;
				v1 = v0 + uv.size.y;
			} else {
				const Proj &p = projeteis[g - n_desenhados];
				dx0 = p.x - tam_proj.x * 0.5f;
				dy0 = p.y - tam_proj.y * 0.5f - 10.0f;
				dx1 = dx0 + tam_proj.x;
				dy1 = dy0 + tam_proj.y;
				u0 = uv_proj.position.x;
				u1 = u0 + uv_proj.size.x;
				v0 = uv_proj.position.y;
				v1 = v0 + uv_proj.size.y;
			}
			int b = q * 4;
			pw[b + 0] = Point2(dx0, dy0);
			pw[b + 1] = Point2(dx1, dy0);
			pw[b + 2] = Point2(dx1, dy1);
			pw[b + 3] = Point2(dx0, dy1);
			uw[b + 0] = Point2(u0, v0);
			uw[b + 1] = Point2(u1, v0);
			uw[b + 2] = Point2(u1, v1);
			uw[b + 3] = Point2(u0, v1);
			int *ix = iw + q * 6;
			ix[0] = b;
			ix[1] = b + 1;
			ix[2] = b + 2;
			ix[3] = b;
			ix[4] = b + 2;
			ix[5] = b + 3;
		}
		vs->canvas_item_add_triangle_array(ci, indices, pontos, cores, uvs, Vector<int>(), Vector<float>(), tex);
		feito += lote;
	}
	us_desenho = (int)(OS::get_singleton()->get_ticks_usec() - t0);
}

void HordaVita::_notification(int p_what) {
	if (p_what == NOTIFICATION_DRAW) {
		desenhar();
	}
}

void HordaVita::_bind_methods() {
	ClassDB::bind_method(D_METHOD("configurar", "atlas", "tipos", "src_proj"), &HordaVita::configurar);
	ClassDB::bind_method(D_METHOD("definir_quantidade", "n"), &HordaVita::definir_quantidade);
	ClassDB::bind_method(D_METHOD("definir_alvo", "alvo", "visivel"), &HordaVita::definir_alvo);
	ClassDB::bind_method(D_METHOD("definir_limites", "max_desenho", "lod_longe", "ordenar_y"), &HordaVita::definir_limites);
	ClassDB::bind_method(D_METHOD("passo", "dt"), &HordaVita::passo);
	ClassDB::bind_method(D_METHOD("golpe", "centro", "raio"), &HordaVita::golpe);
	ClassDB::bind_method(D_METHOD("disparar", "origem", "vel", "vida"), &HordaVita::disparar);
	ClassDB::bind_method(D_METHOD("luzes", "area", "max"), &HordaVita::luzes);
	ClassDB::bind_method(D_METHOD("estatisticas"), &HordaVita::estatisticas);
	ClassDB::bind_method(D_METHOD("quantidade"), &HordaVita::quantidade);
}

HordaVita::HordaVita() {
	cores.push_back(Color(1, 1, 1, 1));
}
