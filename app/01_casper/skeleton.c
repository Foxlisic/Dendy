
#define PPU_CTRL    *((unsigned char*)0x2000)
#define PPU_MASK    *((unsigned char*)0x2001)
#define PPU_STATUS  *((unsigned char*)0x2002)
#define SCROLL      *((unsigned char*)0x2005)
#define PPU_ADDRESS *((unsigned char*)0x2006)
#define PPU_DATA    *((unsigned char*)0x2007)


unsigned char NMI_flag;
unsigned char frame_count;
unsigned char index;
unsigned char curSymbol;

const unsigned char TEXT[] = {
    "RETRO CODE"
};

const unsigned char PALLETE[] = {
    0x0F, 0x00, 0x10, 0x20
}; // black | gray | lt_gray | white

void disablePPU(void)
{
    // off ppu
    PPU_CTRL = 0;
    PPU_MASK = 0;
}

void enablePPU(void)
{
    // turn on screen
    PPU_CTRL = 0x90; // screen on | NMI on
    PPU_MASK = 0x1e;
}

void loadPallete(void)
{
    // load pallette
    PPU_ADDRESS = 0x3f; // set an address in the PPU of 0x3f00
    PPU_ADDRESS = 0x00;
    for (index = 0; index < sizeof(PALLETE); ++index) {
        PPU_DATA = PALLETE[index];
    }
}

void loadText(void)
{
    if (curSymbol < sizeof(TEXT)) {
        PPU_ADDRESS = 0x21; // set an address in the PPU of 0x21ca
        PPU_ADDRESS = 0xca + curSymbol; // about the middle of the screen
        PPU_DATA = TEXT[curSymbol];
        ++curSymbol;
    } else {
        curSymbol = 0;
        PPU_ADDRESS = 0x21; // set an address in the PPU of 0x21ca
        PPU_ADDRESS = 0xca; // about the middle of the screen
        for (index = 0; index < sizeof(TEXT); ++index) {
            PPU_DATA = 0; // clear
        }
    }
}

void resetScroll(void)
{
    // reset scroll
    PPU_ADDRESS = 0;
    PPU_ADDRESS = 0;
    SCROLL = 0;
    SCROLL = 0;
}

void main(void)
{
    disablePPU();
    loadPallete();
    resetScroll();
    enablePPU();

    // infinity
    while(1) {

        // wait NMI
        while (NMI_flag == 0);
        NMI_flag = 0;

        if (frame_count == 30) { // frames per second
            loadText();
            resetScroll();
            frame_count = 0;
        }
    }
}







