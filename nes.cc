#include <verilated.h>
#include "obj_dir/Vcpu.h"
#include "obj_dir/Vppu.h"

// ---------------------------
// =0 Verilog =1 PPU C++ =2 CPU+PPU C++
#define PPU_MODEL 0
// Дебаг CPU
#define DEBUG1 2
// Порты
#define DEBUG2 0
// Видео область
#define DEBUG3 0
// ---------------------------

#include "nes_decl.h"
#include "nes_tb.h"
#include "nes_cpu.cc"
#include "nes_ppu.cc"
#include "nes_iface.cc"

int main(int argc, char** argv)
{
    TB* tb = new TB(argc, argv);
    while (tb->main());
    return tb->destroy();
}
