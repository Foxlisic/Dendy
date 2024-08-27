#include <verilated.h>
#include "obj_dir/Vcpu.h"
#include "obj_dir/Vppu.h"

#include "tb.h"

int main(int argc, char** argv)
{
    TB* tb = new TB(argc, argv);
    while (tb->main());
    return tb->destroy();
}
