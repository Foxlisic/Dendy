#define PPU_CTRL    *((unsigned char*)0x2000)
#define PPU_MASK    *((unsigned char*)0x2001)
#define PPU_STATUS  *((unsigned char*)0x2002)
#define SCROLL      *((unsigned char*)0x2005)
#define PPU_ADDRESS *((unsigned char*)0x2006)
#define PPU_DATA    *((unsigned char*)0x2007)

unsigned char NMI_flag;
unsigned char frame_count;

void PPU_off(void) { PPU_CTRL = 0x00; PPU_MASK = 0x00; }
void PPU_on (void) { PPU_CTRL = 0x90; PPU_MASK = 0x1E; }

void main(void)
{
    PPU_off();
    PPU_on();

    while (1)
    {
        while (NMI_flag == 0); NMI_flag = 0;
    }
}







