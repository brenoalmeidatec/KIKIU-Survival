// Acesso direto ao hardware do PS Vita para o port do KIKIU Survival: touch frontal e TRASEIRO (o godot-vita só lê o
// frontal, em coordenadas cruas do painel), acelerômetro + giroscópio, clocks reais e bateria.
// Fora do Vita, os métodos devolvem vazio/zero, para o mesmo GDScript rodar no PC.

#ifndef VITA_HW_H
#define VITA_HW_H

#include "core/reference.h"

class VitaHW : public Reference {
	GDCLASS(VitaHW, Reference);

	bool iniciado = false;
	float frente_max_x = 1920.0f, frente_max_y = 1088.0f;
	float tras_min_x = 0.0f, tras_min_y = 108.0f, tras_max_x = 1919.0f, tras_max_y = 889.0f;

protected:
	static void _bind_methods();

public:
	bool no_vita() const;
	void iniciar();
	PoolVector2Array toques_frente(); // 0..1 na tela
	PoolVector2Array toques_tras(); // 0..1 no painel traseiro (x da esquerda para a direita, visto de frente)
	Dictionary movimento(); // {"acel": Vector3 (g), "giro": Vector3 (rad/s)}
	Dictionary clocks(); // MHz: {"arm", "bus", "gpu", "xbar"}
	Dictionary bateria(); // {"porcento", "carregando", "minutos"}
};

#endif // VITA_HW_H
