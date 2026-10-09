#include "register_types.h"

#include "core/class_db.h"
#include "horda_vita.h"
#include "nucleo_horda.h"
#include "vita_hw.h"

void register_horda_vita_types() {
	ClassDB::register_class<HordaVita>();
	ClassDB::register_class<VitaHW>();
	ClassDB::register_class<NucleoHorda>();
}

void unregister_horda_vita_types() {
}
