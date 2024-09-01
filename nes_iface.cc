// Чтение из видеопамяти
uint8_t TB::readv(uint16_t A)
{
    // Знакогенератор CHR-ROM и видеопамять для PPU
    if (A < 0x2000) {

        // Зависит от выбора маппера
        switch (mapper) {

            case 1: // MMC1

                printf("MMC1V\n"); exit(1);
                break;

            default:

                return chrrom[A];
        }
    }
    // Зеркалирование VRAM [4 страницы] 2Dendy + 2Cartridge
    else if (A >= 0x2000 && A < 0x3F00) {
        return videom[0x2000 + (A & vmemsize)];
    }

    return 0xFF;
}

// Чтение из памяти с различными мапперами
uint8_t TB::read(uint16_t A)
{
    uint8_t  I;
    uint16_t a = A;

    // Оперативная память
    if (A < 0x2000) {
        I = ram[A & 0x7FF];
    }
    // Память программ
    else if (A >= 0x8000) {

        a &= 0x7FFF;

        switch (mapper) {

            case 1: // MMC1

                printf("MMC1R\n"); exit(1);
                break;

            case 2: // UnROM

                a &= 0x3FFF;
                I  = program[a + 16384*(A >= 0xC000 ? cnt_prg_rom-1 : prg_bank)];
                break;

            default:

                I = program[a];
                break;
        }
    }

    if (PPU_MODEL == 2) {
        return eppu_rw(A, I, 1, 0, 0);
    }

    return I;
}

// Писать можно только в память
void TB::write(uint16_t A, uint8_t D)
{
    if (PPU_MODEL == 2) {
        eppu_rw(A, 0, 0, 1, D);
    }

    switch (mapper) {

        case 1: // MMC1

            // Запись D0 только при _cpu_m0=1
            // After the fifth write, the shift register is cleared automatically

            printf("MMC1W\n"); exit(1);
            _cpu_m0 = 0;
            break;

        case 2: // UnROM :: пишется банк

            if (A >= 0x8000) prg_bank = D & 15;
            break;

    }

    if (A < 0x2000) {
        ram[A & 0x7FF] = D;
    }
}

// 1 Такт CPU + PPU обвязка + VGA
int TB::tick()
{
    // 4=0xFFF 2=0x7FFF || 2 страницы
    int vmemsize = 0xFFF;

    // Для сканлайна 25 Мгц тактируется
    if (ppu->x2w) { x2line[ppu->x2a] = ppu->x2o; }
    ppu->x2i = x2line[ppu->x2a];

    // --------------------------------
    ppu->mapper_chrw = (mapper == 2);
    ppu->mapper_nt   = 0; // 2k | 4k NT

    // --------------------------------
    ppu->chrd = readv(ppu->chra);

    // Запись в OAM
    if (ppu->oam2w) oam[ppu->oam2a] = ppu->oam2o;

    // Запись в видеопамять
    if (ppu->vida >= 0x2000 && ppu->vida < 0x3F00 && ppu->vidw) {
        videom[0x2000 + (ppu->vida & vmemsize)] = ppu->vido;
    }
    // Запись в CHR-ROM [Если можно]
    else if (ppu->vida < 0x2000 && ppu->vidw && mapper_chrw) {
        videom[ppu->vida] = ppu->vido;
        chrrom[ppu->vida] = ppu->vido;
    }

    // Чтение OAM, CHR
    ppu->oamd  = oam[ppu->oama];
    ppu->oam2i = oam[ppu->oam2a];
    ppu->vidi  = readv(ppu->vida);

    // -----------------------------------

    // Подготовка данных для PPU
    ppu->cpu_a = cpu->A;
    ppu->cpu_o = cpu->D;
    ppu->cpu_w = cpu->W;
    ppu->cpu_r = cpu->R;

    // Джойстики
    ppu->joy1 = joy1;
    ppu->joy2 = joy2;

    // Запись и чтение в зависимости от мапперов
    if (ppu->prgw) { write(ppu->prga, ppu->prgd); }

    // Читаться для PPU, не CPU.
    ppu->prgi = read(ppu->prga);

    // -- PPU здесь --
    ppu->clock25 = 0; ppu->eval();
    ppu->clock25 = 1; ppu->eval();

    // Для CPU данные готовятся в PPU
    cpu->I   = ppu->cpu_i;
    cpu->ce  = ppu->ce_cpu;
    cpu->nmi = ppu->nmi;

    // Для маппера
    if (cpu->m0) _cpu_m0 = 1;

    debug();
    cpu->clock = 0; cpu->eval();
    cpu->clock = 1; cpu->eval();

    if (cpu->ce) cycles_count++;

    vga(ppu->hs, ppu->vs, ppu->r*16*65536 + ppu->g*16*256 + ppu->b*16);

    return 1;
}
