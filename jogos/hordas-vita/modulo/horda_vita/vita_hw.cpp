#include "vita_hw.h"

#ifdef VITA_ENABLED
#include <psp2/motion.h>
#include <psp2/power.h>
#include <psp2/touch.h>
#endif

bool VitaHW::no_vita() const {
#ifdef VITA_ENABLED
	return true;
#else
	return false;
#endif
}

void VitaHW::iniciar() {
	if (iniciado) {
		return;
	}
	iniciado = true;
#ifdef VITA_ENABLED
	sceTouchSetSamplingState(SCE_TOUCH_PORT_FRONT, SCE_TOUCH_SAMPLING_STATE_START);
	sceTouchSetSamplingState(SCE_TOUCH_PORT_BACK, SCE_TOUCH_SAMPLING_STATE_START);
	SceTouchPanelInfo info;
	if (sceTouchGetPanelInfo(SCE_TOUCH_PORT_FRONT, &info) >= 0) {
		frente_max_x = MAX(1, info.maxAaX);
		frente_max_y = MAX(1, info.maxAaY);
	}
	if (sceTouchGetPanelInfo(SCE_TOUCH_PORT_BACK, &info) >= 0) {
		tras_min_x = info.minAaX;
		tras_min_y = info.minAaY;
		tras_max_x = MAX(info.minAaX + 1, info.maxAaX);
		tras_max_y = MAX(info.minAaY + 1, info.maxAaY);
	}
	sceMotionStartSampling();
#endif
}

PoolVector2Array VitaHW::toques_frente() {
	PoolVector2Array r;
#ifdef VITA_ENABLED
	SceTouchData t;
	if (sceTouchPeek(SCE_TOUCH_PORT_FRONT, &t, 1) >= 0) {
		for (unsigned int i = 0; i < t.reportNum && i < SCE_TOUCH_MAX_REPORT; i++) {
			r.push_back(Vector2(t.report[i].x / frente_max_x, t.report[i].y / frente_max_y));
		}
	}
#endif
	return r;
}

PoolVector2Array VitaHW::toques_tras() {
	PoolVector2Array r;
#ifdef VITA_ENABLED
	SceTouchData t;
	if (sceTouchPeek(SCE_TOUCH_PORT_BACK, &t, 1) >= 0) {
		for (unsigned int i = 0; i < t.reportNum && i < SCE_TOUCH_MAX_REPORT; i++) {
			r.push_back(Vector2((t.report[i].x - tras_min_x) / (tras_max_x - tras_min_x),
					(t.report[i].y - tras_min_y) / (tras_max_y - tras_min_y)));
		}
	}
#endif
	return r;
}

Dictionary VitaHW::movimento() {
	Dictionary d;
	Vector3 acel, giro;
#ifdef VITA_ENABLED
	SceMotionSensorState s;
	if (sceMotionGetSensorState(&s, 1) >= 0) {
		acel = Vector3(s.accelerometer.x, s.accelerometer.y, s.accelerometer.z);
		giro = Vector3(s.gyro.x, s.gyro.y, s.gyro.z);
	}
#endif
	d["acel"] = acel;
	d["giro"] = giro;
	return d;
}

Dictionary VitaHW::clocks() {
	Dictionary d;
#ifdef VITA_ENABLED
	d["arm"] = scePowerGetArmClockFrequency();
	d["bus"] = scePowerGetBusClockFrequency();
	d["gpu"] = scePowerGetGpuClockFrequency();
	d["xbar"] = scePowerGetGpuXbarClockFrequency();
#else
	d["arm"] = 0;
	d["bus"] = 0;
	d["gpu"] = 0;
	d["xbar"] = 0;
#endif
	return d;
}

Dictionary VitaHW::bateria() {
	Dictionary d;
#ifdef VITA_ENABLED
	d["porcento"] = scePowerGetBatteryLifePercent();
	d["carregando"] = (bool)scePowerIsBatteryCharging();
	d["minutos"] = scePowerGetBatteryLifeTime();
#else
	d["porcento"] = -1;
	d["carregando"] = false;
	d["minutos"] = -1;
#endif
	return d;
}

void VitaHW::_bind_methods() {
	ClassDB::bind_method(D_METHOD("no_vita"), &VitaHW::no_vita);
	ClassDB::bind_method(D_METHOD("iniciar"), &VitaHW::iniciar);
	ClassDB::bind_method(D_METHOD("toques_frente"), &VitaHW::toques_frente);
	ClassDB::bind_method(D_METHOD("toques_tras"), &VitaHW::toques_tras);
	ClassDB::bind_method(D_METHOD("movimento"), &VitaHW::movimento);
	ClassDB::bind_method(D_METHOD("clocks"), &VitaHW::clocks);
	ClassDB::bind_method(D_METHOD("bateria"), &VitaHW::bateria);
}
