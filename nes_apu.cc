void TB::wavStart(const char* filename)
{
    wave_fp = fopen(filename, "wb");
    fseek(wave_fp, sizeof(WAVEFMTHEADER), SEEK_SET);

    for (int i = 0; i < 2; i++) {

        // Volume/Envelope
        square[i].duty      = 0;
        square[i].loop      = 0;
        square[i].cnst      = 0;
        square[i].vol       = 0;
        square[i].env_c     = 0;
        square[i].decay     = 0;
        // Sweep
        square[i].sweep     = 0;
        // Timer
        square[i].timer     = 0;
        square[i].counter   = 0;
        square[i].period    = 0;
        square[i].tmp       = 0;
        square[i].ac        = 0;
        square[i].bitp      = 0;
    }
}

void TB::wavStop()
{
    if (wave_fp) {

        struct WAVEFMTHEADER head = {
            0x46464952,
            (wav_size + 0x24),
            0x45564157,
            0x20746d66,
            16,     // 16=PCM
            1,      // Тип
            2,      // Каналы
            44100,  // Частота дискретизации
            88200,  // Байт в секунду
            2,      // Байт на семпл (1+1)
            8,      // Битность
            0x61746164, // "data"
            wav_size
        };

        fseek(wave_fp, 0, SEEK_SET);
        fwrite(&head, 1, sizeof(WAVEFMTHEADER), wave_fp);

        fclose(wave_fp);
    }
}

// Обработка APU фрейма [CPU 1789773 HZ / 29830 = 60 Hz]
uint8_t TB::eApu(uint16_t A, uint8_t D, uint8_t I, int W, int R)
{
    int apu_frame       = 0, // Фрейм 60Hz
        apu_frame_half  = 0, // 1/2 фрейма 120Hz
        apu_frame_quart = 0, // 1/4 фрейма 240Hz
        apu_break       = 0; // BRK APU

    // Счетчик фреймов на нечетных
    switch (eapu_cycle) {

        case 7457:  apu_frame_quart = 1; break;
        case 14913: apu_frame_quart = 1; apu_frame_half = 1; break;
        case 22371: apu_frame_quart = 1; break;
        case 29829: apu_frame_quart = 1; apu_frame_half = 1; apu_frame = 1; break;
    }

    int channel = (A >> 2) & 1;

    if (W)
    switch (A)
    {
        // DD|LC|VVVV Скважность|Зацикленность|Константа|Громкость/Скорость убывания
        case 0x4000:
        case 0x4004: {

            square[channel].duty  = (D >> 6) & 3;
            square[channel].loop  = (D & 0x20) ? 1 : 0;
            square[channel].cnst  = (D & 0x10) ? 1 : 0;
            square[channel].vol   = D & 7;
            square[channel].env_c = D & 7; // Скорость убывания Envelope

            if (DEBUG3) printf("[%04X] D=%d L=%d C=%d V=%d\n", A, square[channel].duty, square[channel].loop, square[channel].cnst, square[channel].vol);
            break;
        }

        // EPPPNSSS Sweep
        case 0x4001:
        case 0x4005: {

            square[channel].sweep    = (D & 0x80) ? 1 : 0;
            square[channel].swperiod = (D >> 4) & 15;
            square[channel].negate   = (D & 0x08) ? 1 : 0;
            square[channel].shift    = (D & 0x07);

            if (DEBUG3 && square[channel].sweep) printf("[%04X] E=%d P=%d N=%d S=%d\n", A, square[channel].sweep, square[channel].swperiod, square[channel].negate, square[channel].shift);
            break;
        }

        // TTTTTTTT Timer Low
        case 0x4002:
        case 0x4006: {

            square[channel].tmp = D;
            break;
        }

        // PPPPPTTT Timer High + Period
        case 0x4003:
        case 0x4007: {

            square[channel].timer   = square[channel].tmp + (D & 7)*256;
            square[channel].period  = EAPU_Length[D >> 3];
            square[channel].counter = square[channel].timer;

            // Перезагрузка счетчиков
            square[channel].decay  = 15;       // Фаза Envelope

            if (DEBUG3) printf("[%04X] T=%d P=%d\n", A, square[channel].timer, square[channel].period);
            break;
        }
    }

    // ----------------

    // 2CPU = 1APU
    if (eapu_cycle & 1) {

        for (int i = 0; i < 2; i++) {

            // Форма сигнала
            if (square[i].counter > 0) {
                square[i].counter--;
            } else {
                square[i].counter = square[i].timer;
                square[i].ac      = square[i].timer >= 8 ? ((EAPU_duty[square[i].duty] >> (square[i].bitp & 7)) & 1) : 0;
                square[i].bitp    = (square[i].bitp - 1) & 7;
            }

            // Итоговая громкость (если не заглушен PERIOD)
            square[i].out = (square[i].ac && square[i].period) ? (square[i].cnst ? square[i].vol : square[i].decay) : 0;

            // -----------------------------------------------------------------
            // Если включен Envelope, то он работает на Frame Counter (60 Hz)
            // -----------------------------------------------------------------

            if (apu_frame) {

                // Ждем пока не прокатится от [V до 0]
                if (square[i].env_c == 0) {

                    // Перезагрузить счетчик скорости убывания
                    square[i].env_c = square[i].vol;

                    // [L=1] Loop Flag повторяет огибающую постоянно
                    if (square[i].loop) {
                        square[i].decay--;
                        square[i].decay &= 15;
                    }
                    // [L=0] Когда он выключен, то останавливается на 0
                    else if (square[i].decay) {
                        square[i].decay--;
                    }

                } else {
                    square[i].env_c = square[i].env_c - 1;
                }
            }

            // -----------------------------------------------------------------
            // Уменьшение счетчика Period
            // --------------------------------------

            if (apu_frame_half) {

                // Уменьшая до 0, останавливается нота
                if (square[i].period) square[i].period--;
            }
        }

        // Вывод в WAV файл
        if (wav_timer >= 10) {

            wav_timer = 0;
            uint8_t bv = (8*square[0].out + 8*square[1].out);
            fwrite(&bv, 1, 1, wave_fp);
            wav_size++;

        } else {
            wav_timer++;
        }
    }

    apu_break  = eapu_cycle >= 29828;
    eapu_cycle = (eapu_cycle >= 29830) ? 0 : eapu_cycle + 1;

    return I;
}
