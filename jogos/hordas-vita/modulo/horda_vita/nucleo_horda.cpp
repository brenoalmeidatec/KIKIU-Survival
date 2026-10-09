#include "nucleo_horda.h"

#include "core/math/math_funcs.h"

#include <algorithm>
#include <math.h>

// Constantes do inimigos.gd (linhas 11-26 do original)
static const double CELULA = 48.0;
static const double LONGE = 720.0;
static const double ACEL_VEL = 14.0;
static const double SEP_MAX = 1.2;
static const double SEP_PERIODO = 0.04;
static const double SEP_PERIODO_LONGE = 0.1;
static const double SEP_PERTO = 380.0;
static const int64_t SEP_VIZ[9] = { -65537, -65536, -65535, -1, 0, 1, 65535, 65536, 65537 };

NucleoHorda::NucleoHorda() {
	slots.reserve(4096);
	orden.reserve(1024);
}

int64_t NucleoHorda::chave_de(double x, double y) {
	return ((int64_t)floor(x / CELULA) + 32768) * 65536 + (int64_t)floor(y / CELULA) + 32768;
}

int NucleoHorda::achar_celula(int64_t chave) const {
	std::vector<int64_t>::const_iterator it = std::lower_bound(cel_chave.begin(), cel_chave.end(), chave);
	if (it == cel_chave.end() || *it != chave) {
		return -1;
	}
	return (int)(it - cel_chave.begin());
}

void NucleoHorda::ev(int tipo, int slot, float a, float b, float c, float d) {
	eventos.push_back((float)tipo);
	eventos.push_back((float)slot);
	eventos.push_back(a);
	eventos.push_back(b);
	eventos.push_back(c);
	eventos.push_back(d);
}

int NucleoHorda::novo() {
	slots.push_back(Slot());
	return (int)slots.size() - 1;
}

void NucleoHorda::fixar(int p_slot, const Array &p_d) {
	ERR_FAIL_COND(p_d.size() < 9);
	Slot &s = slots[p_slot];
	s.id = (int64_t)(double)p_d[0];
	s.raio = p_d[1];
	s.vel = p_d[2];
	int flags = (int)p_d[3];
	s.chefe = (flags & 1) != 0;
	s.fixo = (flags & 2) != 0;
	s.tem_invoca = (flags & 4) != 0;
	s.distancia = p_d[4];
	s.investida = p_d[5];
	s.atira = p_d[6];
	s.anel = p_d[7];
	s.a_cada = p_d[8];
}

void NucleoHorda::anexar(int p_slot) {
	orden.push_back(p_slot);
}

// Igual ao _remover do GDScript: troca com o último. O slot NÃO é reciclado (um V morto ainda pode ser lido).
void NucleoHorda::remover(int p_slot) {
	for (size_t i = 0; i < orden.size(); i++) {
		if (orden[i] == p_slot) {
			orden[i] = orden.back();
			orden.pop_back();
			return;
		}
	}
}

void NucleoHorda::limpar() {
	slots.clear();
	orden.clear();
	snap.clear();
	cel_itens.clear();
	cel_chave.clear();
	cel_ini.clear();
	cursor = 0;
}

PoolIntArray NucleoHorda::ordem() const {
	PoolIntArray r;
	r.resize((int)orden.size());
	PoolIntArray::Write w = r.write();
	for (size_t i = 0; i < orden.size(); i++) {
		w[(int)i] = orden[i];
	}
	return r;
}

// Grade do início do quadro (antes de elementos.passo, como no original: bichos mortos depois continuam nela).
void NucleoHorda::inicio_quadro(double p_dt, int p_quadro) {
	dt = p_dt;
	quadro = p_quadro;
	cel_itens.clear();
	cel_itens.reserve(orden.size());
	for (size_t i = 0; i < orden.size(); i++) {
		const Slot &s = slots[orden[i]];
		cel_itens.push_back(std::make_pair(chave_de((double)s.v[V_POS].x, (double)s.v[V_POS].y), orden[i]));
	}
	std::stable_sort(cel_itens.begin(), cel_itens.end(),
			[](const std::pair<int64_t, int> &a, const std::pair<int64_t, int> &b) { return a.first < b.first; });
	cel_chave.clear();
	cel_ini.clear();
	for (size_t i = 0; i < cel_itens.size(); i++) {
		if (i == 0 || cel_itens[i].first != cel_itens[i - 1].first) {
			cel_chave.push_back(cel_itens[i].first);
			cel_ini.push_back((int)i);
		}
	}
	cel_ini.push_back((int)cel_itens.size());
}

// Um quadro do laço de movimento (inimigos.gd:513-646). Com p_retomar = false começa um laço novo (tira a cópia de
// `orden`); com true continua de onde parou (depois de um TELEPORTE resolvido no GDScript).
PoolRealArray NucleoHorda::passo(const Vector2 &p_alvo, bool p_retomar) {
	eventos.clear();
	if (!p_retomar) {
		alvo = p_alvo;
		snap = orden;
		cursor = 0;
		pausas_contato = 8;
		k_vm = MIN(1.0, dt * ACEL_VEL);
		k_sep = dt * 12.0;
		k_kb = exp(-9.0 * dt);
		cad_perto = CLAMP((int)round(SEP_PERIODO / MAX(dt, 0.0001)), 1, 12);
		cad_longe = CLAMP((int)round(SEP_PERIODO_LONGE / MAX(dt, 0.0001)), 1, 24);
	}

	while (cursor < snap.size()) {
		int idx = snap[cursor++];
		Slot &v = slots[idx];
		if (v.f[F_HP] <= 0) {
			continue;
		}
		// B. timers
		if (v.f[F_FLASH] > 0.0) {
			v.f[F_FLASH] = MAX(0.0, v.f[F_FLASH] - dt);
		}
		if (v.f[F_LENTO] > 0.0) {
			v.f[F_LENTO] = MAX(0.0, v.f[F_LENTO] - dt);
		}
		if (v.f[F_ATORDOADO] > 0.0) {
			v.f[F_ATORDOADO] = MAX(0.0, v.f[F_ATORDOADO] - dt);
		}
		if (v.f[F_T_NASC] > 0.0) {
			v.f[F_T_NASC] = MAX(0.0, v.f[F_T_NASC] - dt);
		}
		// D. direção e velocidade (dist e dir são PRÉ-movimento)
		Vector2 para = alvo - v.v[V_POS];
		double dist = (double)para.length();
		Vector2 dir = dist > 0.01 ? para / (real_t)dist : Vector2();
		double vel = v.f[F_ATORDOADO] > 0 ? 0.0 : v.vel * (v.f[F_LENTO] > 0 ? 0.45 : 1.0);
		Vector2 mov = dir * (real_t)vel;
		// E. atirador mantém distância
		if (v.distancia > 0) {
			double dd = v.distancia;
			if (dist < dd * 0.8) {
				mov = (-dir * (real_t)vel) * (real_t)0.6;
			} else if (dist < dd) {
				mov = Vector2();
			}
		}
		// F. investida
		if (v.investida > 0) {
			int estado = (int)v.f[F_ESTADO];
			if (estado == 0) {
				v.f[F_T_INV] -= dt;
				if (v.f[F_T_INV] <= 0 && dist < 360) {
					v.f[F_ESTADO] = 1;
					v.f[F_T_ESTADO] = 0.7;
					v.v[V_DIR_INV] = dir;
				}
			} else if (estado == 1) {
				mov = Vector2();
				v.f[F_T_ESTADO] -= dt;
				if (v.f[F_T_ESTADO] <= 0) {
					v.f[F_ESTADO] = 2;
					v.f[F_T_ESTADO] = 0.6;
					ev(EV_WHOOSH, idx);
				}
			} else if (estado == 2) {
				mov = (v.v[V_DIR_INV] * (real_t)vel) * (real_t)5.0;
				v.f[F_T_ESTADO] -= dt;
				if (v.f[F_T_ESTADO] <= 0) {
					v.f[F_ESTADO] = 0;
					v.f[F_T_INV] = v.investida;
				}
			}
		}
		// G. tiro
		if (v.atira > 0 && v.f[F_ATORDOADO] <= 0.0) {
			v.f[F_T_ATIRA] -= dt;
			if (v.f[F_T_ATIRA] <= 0 && dist < 330) {
				v.f[F_T_ATIRA] = v.atira;
				ev(EV_ATIRA, idx, v.v[V_POS].x, v.v[V_POS].y, dir.x, dir.y);
			}
		}
		// H. anel
		if (v.anel > 0 && v.f[F_ATORDOADO] <= 0.0) {
			v.f[F_T_ANEL] -= dt;
			if (v.f[F_T_ANEL] <= 0 && dist < 400) {
				v.f[F_T_ANEL] = v.anel;
				ev(EV_ANEL, idx, v.v[V_POS].x, v.v[V_POS].y);
			}
		}
		// I. invocação
		if (v.tem_invoca) {
			v.f[F_T_INVOCA] -= dt;
			if (v.f[F_T_INVOCA] <= 0) {
				v.f[F_T_INVOCA] = v.a_cada;
				ev(EV_INVOCA, idx, v.v[V_POS].x, v.v[V_POS].y);
			}
		}
		// J. separação dos vizinhos
		if ((v.id + quadro) % (dist < SEP_PERTO ? cad_perto : cad_longe) == 0) {
			Vector2 sep;
			double px = (double)v.v[V_POS].x;
			double py = (double)v.v[V_POS].y;
			int64_t kc = chave_de(px, py);
			int checados = 0;
			for (int k = 0; k < 9; k++) {
				int c = achar_celula(kc + SEP_VIZ[k]);
				if (c < 0 || checados > 20) {
					continue;
				}
				for (int m = cel_ini[c]; m < cel_ini[c + 1]; m++) {
					checados += 1;
					if (checados > 20) {
						break;
					}
					int oi = cel_itens[m].second;
					if (oi == idx) {
						continue;
					}
					const Slot &o = slots[oi];
					double dx = px - (double)o.v[V_POS].x;
					double dy = py - (double)o.v[V_POS].y;
					double rr = v.raio + o.raio;
					double d2 = dx * dx + dy * dy;
					if (d2 < rr * rr && d2 > 0.0001) {
						double dl = sqrt(d2);
						double f = (rr - dl) / dl;
						sep.x = (real_t)((double)sep.x + dx * f);
						sep.y = (real_t)((double)sep.y + dy * f);
					}
				}
			}
			v.v[V_SEPV] = sep * (real_t)(v.chefe ? 0.1 : 1.0);
		}
		// K. suavização e empurrão
		v.v[V_VM] = v.v[V_VM] + (mov - v.v[V_VM]) * (real_t)(v.f[F_ESTADO] == 2 ? 1.0 : k_vm);
		Vector2 push;
		if (v.v[V_SEPV].x != 0.0 || v.v[V_SEPV].y != 0.0) {
			push = v.v[V_SEPV] * (real_t)k_sep;
			double lim_s = MAX(v.vel * SEP_MAX, 24.0) * dt;
			if ((double)push.length_squared() > lim_s * lim_s) {
				push = push.normalized() * (real_t)lim_s;
			}
		}
		// L. integração
		v.v[V_POS] = v.v[V_POS] + (((v.v[V_VM] + v.v[V_KB]) * (real_t)dt) + push);
		v.v[V_KB] = v.v[V_KB] * (real_t)k_kb;
		// M. contato (dist PRÉ-movimento). O dano ao jogador pode disparar efeitos que mexem em outros inimigos (a explosão
		// do "Sete Vidas" mata e empurra): por isso o contato também é ponto de pausa, como o teleporte, para o
		// GDScript resolver na ordem certa. O número de pausas por quadro tem teto (multidão encostando no herói).
		bool pausa = false;
		if (dist < v.raio + 8) {
			ev(EV_FERIR_JOG, idx);
			if (pausas_contato > 0) {
				pausas_contato--;
				pausa = true;
			}
		}
		// N. reciclagem por distância: o GDScript sorteia o destino e chama passo(retomar=true)
		if (dist > LONGE && !v.chefe && !v.fixo) {
			ev(EV_TELEPORTE, idx, v.v[V_POS].x, v.v[V_POS].y);
			pausa = true;
		}
		if (pausa) {
			break;
		}
	}

	PoolRealArray r;
	r.resize((int)eventos.size());
	if (!eventos.empty()) {
		PoolRealArray::Write w = r.write();
		for (size_t i = 0; i < eventos.size(); i++) {
			w[(int)i] = eventos[i];
		}
	}
	return r;
}

// no_circulo (inimigos.gd:432): células de (c - (r+40)) a (c + (r+40)), cy externo, cx interno; sem filtrar hp.
PoolIntArray NucleoHorda::no_circulo(const Vector2 &p_c, double p_r) const {
	PoolIntArray res;
	Vector2 d((real_t)(p_r + 40), (real_t)(p_r + 40));
	Vector2 a0 = p_c - d;
	Vector2 b0 = p_c + d;
	int ax = (int)floor(a0.x / CELULA), ay = (int)floor(a0.y / CELULA);
	int bx = (int)floor(b0.x / CELULA), by = (int)floor(b0.y / CELULA);
	for (int cy = ay; cy <= by; cy++) {
		for (int cx = ax; cx <= bx; cx++) {
			int c = achar_celula(((int64_t)cx + 32768) * 65536 + cy + 32768);
			if (c < 0) {
				continue;
			}
			for (int m = cel_ini[c]; m < cel_ini[c + 1]; m++) {
				const Slot &o = slots[cel_itens[m].second];
				double rr = p_r + o.raio;
				if ((double)o.v[V_POS].distance_squared_to(p_c) <= rr * rr) {
					res.push_back(cel_itens[m].second);
				}
			}
		}
	}
	return res;
}

int NucleoHorda::mais_perto(const Vector2 &p_p, double p_maximo) const {
	int melhor = -1;
	double md = p_maximo * p_maximo;
	for (size_t i = 0; i < orden.size(); i++) {
		double dd = (double)slots[orden[i]].v[V_POS].distance_squared_to(p_p);
		if (dd < md) {
			md = dd;
			melhor = orden[i];
		}
	}
	return melhor;
}

PoolIntArray NucleoHorda::n_mais_perto(const Vector2 &p_p, int p_n, double p_maximo) const {
	PoolIntArray perto = no_circulo(p_p, p_maximo);
	std::vector<std::pair<real_t, int>> ds;
	for (int i = 0; i < perto.size(); i++) {
		int s = perto[i];
		ds.push_back(std::make_pair(slots[s].v[V_POS].distance_squared_to(p_p), s));
	}
	std::stable_sort(ds.begin(), ds.end(),
			[](const std::pair<real_t, int> &a, const std::pair<real_t, int> &b) { return a.first < b.first; });
	PoolIntArray r;
	for (int i = 0; i < (int)ds.size() && i < p_n; i++) {
		r.push_back(ds[i].second);
	}
	return r;
}

void NucleoHorda::_bind_methods() {
	ClassDB::bind_method(D_METHOD("novo"), &NucleoHorda::novo);
	ClassDB::bind_method(D_METHOD("fixar", "slot", "dados"), &NucleoHorda::fixar);
	ClassDB::bind_method(D_METHOD("anexar", "slot"), &NucleoHorda::anexar);
	ClassDB::bind_method(D_METHOD("remover", "slot"), &NucleoHorda::remover);
	ClassDB::bind_method(D_METHOD("limpar"), &NucleoHorda::limpar);
	ClassDB::bind_method(D_METHOD("gf", "slot", "campo"), &NucleoHorda::gf);
	ClassDB::bind_method(D_METHOD("sf", "slot", "campo", "valor"), &NucleoHorda::sf);
	ClassDB::bind_method(D_METHOD("gv", "slot", "campo"), &NucleoHorda::gv);
	ClassDB::bind_method(D_METHOD("sv", "slot", "campo", "valor"), &NucleoHorda::sv);
	ClassDB::bind_method(D_METHOD("inicio_quadro", "dt", "quadro"), &NucleoHorda::inicio_quadro);
	ClassDB::bind_method(D_METHOD("passo", "alvo", "retomar"), &NucleoHorda::passo);
	ClassDB::bind_method(D_METHOD("pendente"), &NucleoHorda::pendente);
	ClassDB::bind_method(D_METHOD("no_circulo", "c", "r"), &NucleoHorda::no_circulo);
	ClassDB::bind_method(D_METHOD("mais_perto", "p", "maximo"), &NucleoHorda::mais_perto);
	ClassDB::bind_method(D_METHOD("n_mais_perto", "p", "n", "maximo"), &NucleoHorda::n_mais_perto);
	ClassDB::bind_method(D_METHOD("quantidade"), &NucleoHorda::quantidade);
	ClassDB::bind_method(D_METHOD("ordem"), &NucleoHorda::ordem);
}
