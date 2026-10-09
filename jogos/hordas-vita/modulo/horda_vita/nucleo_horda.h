// Núcleo da horda do jogo de verdade (inimigos.gd) em C++: dono do estado de movimento de cada inimigo, da grade
// espacial, da separação e da integração. Reproduz o laço `atualizar` do inimigos.gd operação por operação (mesma ordem,
// mesma aritmética float32 do Vector2 do Godot), para o jogo convertido dar o mesmo resultado, só que ~20-40x mais
// rápido no Vita. O que é raro ou tem regra de jogo (tiro, anel, invocação, dano ao jogador, teleporte com sorteio)
// sai como EVENTO e é resolvido no GDScript, na ordem em que aconteceu.
// Especificação: jogos/hordas-vita/PLANO_BACKPORT.md e STATUS.md ("Horda do jogo em C++").

#ifndef NUCLEO_HORDA_H
#define NUCLEO_HORDA_H

#include "core/math/vector2.h"
#include "core/reference.h"
#include "core/pool_vector.h"

#include <stdint.h>
#include <vector>

class NucleoHorda : public Reference {
	GDCLASS(NucleoHorda, Reference);

public:
	enum Escalar {
		F_HP, F_FLASH, F_LENTO, F_ATORDOADO, F_T_NASC, F_T_ATIRA, F_T_ANEL, F_T_INVOCA, F_T_INV, F_T_ESTADO, F_ESTADO,
		F_QUANTOS,
		// campos de comportamento (membros do Slot, também lidos e escritos pela ponte do GDScript)
		F_VEL, F_RAIO, F_DISTANCIA, F_INVESTIDA, F_ATIRA, F_ANEL, F_CHEFE
	};
	enum Vetor { V_POS, V_VM, V_KB, V_SEPV, V_DIR_INV, V_QUANTOS };
	enum Evento { EV_WHOOSH, EV_ATIRA, EV_ANEL, EV_INVOCA, EV_FERIR_JOG, EV_TELEPORTE };

private:
	struct Slot {
		Vector2 v[V_QUANTOS];
		double f[F_QUANTOS];
		double raio = 8.0, vel = 40.0, distancia = 0.0, investida = 0.0, atira = 0.0, anel = 0.0, a_cada = 5.0;
		int64_t id = 0;
		bool chefe = false, fixo = false, tem_invoca = false;
		Slot() {
			for (int i = 0; i < F_QUANTOS; i++) {
				f[i] = 0.0;
			}
			f[F_HP] = 1.0;
		}
	};

	std::vector<Slot> slots;
	std::vector<int> orden; // slots na ordem de `lista` do GDScript (mesmo swap-com-o-último de _remover)
	std::vector<int> snap; // cópia de orden tirada no início do laço (lista.duplicate())
	size_t cursor = 0;
	int pausas_contato = 8;

	// grade: chaves ordenadas (estável: a ordem de inserção por célula é a ordem de `orden`)
	std::vector<std::pair<int64_t, int>> cel_itens; // (chave, slot) ordenado por chave, estável
	std::vector<int64_t> cel_chave; // chaves únicas, ordenadas
	std::vector<int> cel_ini; // início de cada chave em cel_itens (tamanho = cel_chave.size() + 1)

	double dt = 0.016;
	int64_t quadro = 0;
	double k_vm = 0, k_sep = 0, k_kb = 0;
	int cad_perto = 2, cad_longe = 6;
	Vector2 alvo;

	std::vector<float> eventos;

	static int64_t chave_de(double x, double y);
	int achar_celula(int64_t chave) const; // índice em cel_chave ou -1
	void ev(int tipo, int slot, float a = 0, float b = 0, float c = 0, float d = 0);

protected:
	static void _bind_methods();

public:
	int novo();
	// p_flags: 1 = chefe, 2 = fixo, 4 = tem invocação
	// p_d = [id, raio, vel, flags, distancia, investida, atira, anel, a_cada]
	void fixar(int p_slot, const Array &p_d);
	void anexar(int p_slot);
	void remover(int p_slot);
	void limpar();

	// Um V morto (ou de uma fase anterior, depois de limpar) ainda pode ser lido: índice fora = zero, sem travar.
	double gf(int p_slot, int p_campo) const {
		ERR_FAIL_INDEX_V(p_slot, (int)slots.size(), 0.0);
		const Slot &s = slots[p_slot];
		switch (p_campo) {
			case F_VEL: return s.vel;
			case F_RAIO: return s.raio;
			case F_DISTANCIA: return s.distancia;
			case F_INVESTIDA: return s.investida;
			case F_ATIRA: return s.atira;
			case F_ANEL: return s.anel;
			case F_CHEFE: return s.chefe ? 1.0 : 0.0;
			default: return s.f[p_campo];
		}
	}
	void sf(int p_slot, int p_campo, double p_valor) {
		ERR_FAIL_INDEX(p_slot, (int)slots.size());
		Slot &s = slots[p_slot];
		switch (p_campo) {
			case F_VEL: s.vel = p_valor; break;
			case F_RAIO: s.raio = p_valor; break;
			case F_DISTANCIA: s.distancia = p_valor; break;
			case F_INVESTIDA: s.investida = p_valor; break;
			case F_ATIRA: s.atira = p_valor; break;
			case F_ANEL: s.anel = p_valor; break;
			case F_CHEFE: s.chefe = p_valor != 0.0; break;
			default: s.f[p_campo] = p_valor;
		}
	}
	Vector2 gv(int p_slot, int p_campo) const {
		ERR_FAIL_INDEX_V(p_slot, (int)slots.size(), Vector2());
		return slots[p_slot].v[p_campo];
	}
	void sv(int p_slot, int p_campo, const Vector2 &p_valor) {
		ERR_FAIL_INDEX(p_slot, (int)slots.size());
		slots[p_slot].v[p_campo] = p_valor;
	}

	void inicio_quadro(double p_dt, int p_quadro);
	PoolRealArray passo(const Vector2 &p_alvo, bool p_retomar);
	bool pendente() const { return cursor < snap.size(); }

	PoolIntArray no_circulo(const Vector2 &p_c, double p_r) const;
	int mais_perto(const Vector2 &p_p, double p_maximo) const;
	PoolIntArray n_mais_perto(const Vector2 &p_p, int p_n, double p_maximo) const;
	int quantidade() const { return (int)orden.size(); }
	PoolIntArray ordem() const;

	NucleoHorda();
};

#endif // NUCLEO_HORDA_H
