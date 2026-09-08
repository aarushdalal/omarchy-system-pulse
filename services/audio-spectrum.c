/*
 * Native Ultra Low-Latency 60 FPS Audio Spectrum Analyzer
 * Connects directly to PulseAudio / PipeWire Pulse with zero buffer lag (<5ms).
 */

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>
#include <math.h>
#include <signal.h>
#include <pulse/simple.h>
#include <pulse/error.h>

#define CHUNK_SIZE 368
#define SAMPLE_RATE 22050
#define NUM_BANDS 18

typedef struct {
    double coeff;
    double cos_w;
    double sin_w;
    double eq_boost;
} Filter;

static Filter filters[NUM_BANDS];
static double smooth[NUM_BANDS];
static double rolling_max = 50.0;
static volatile sig_atomic_t running = 1;

void handle_signal(int sig) {
    (void)sig;
    running = 0;
}

void init_filters(void) {
    for (int b = 0; b < NUM_BANDS; b++) {
        double freq = 45.0 * pow(1.36, b);
        int k = (int)(0.5 + (CHUNK_SIZE * freq / SAMPLE_RATE));
        double omega = (2.0 * M_PI * k) / CHUNK_SIZE;
        filters[b].coeff = 2.0 * cos(omega);
        filters[b].cos_w = cos(omega);
        filters[b].sin_w = sin(omega);
        filters[b].eq_boost = 1.0 + (b * 0.08);
        if (b < 4) filters[b].eq_boost += 0.35; // punchy bass
        smooth[b] = 0.0;
    }
}

static void get_target_device(char *dest, size_t maxlen) {
    strncpy(dest, "@DEFAULT_MONITOR@", maxlen - 1);
    dest[maxlen - 1] = '\0';
    FILE *fp = popen("pactl list short sinks 2>/dev/null", "r");
    if (fp) {
        char line[256];
        while (fgets(line, sizeof(line), fp)) {
            if (strstr(line, "easyeffects_sink")) {
                strncpy(dest, "easyeffects_sink.monitor", maxlen - 1);
                break;
            }
        }
        pclose(fp);
    }
}

int main(void) {
    signal(SIGTERM, handle_signal);
    signal(SIGINT, handle_signal);

    init_filters();

    static const pa_sample_spec ss = {
        .format = PA_SAMPLE_S16LE,
        .rate = SAMPLE_RATE,
        .channels = 1
    };
    
    static const pa_buffer_attr ba = {
        .maxlength = (uint32_t) -1,
        .tlength = (uint32_t) -1,
        .prebuf = (uint32_t) -1,
        .minreq = (uint32_t) -1,
        .fragsize = CHUNK_SIZE * sizeof(int16_t)
    };

    char target[128];
    get_target_device(target, sizeof(target));

    int error = 0;
    pa_simple *s = pa_simple_new(
        NULL,
        "SystemPlusVisualizer",
        PA_STREAM_RECORD,
        target,
        "Spectrum Analyzer",
        &ss,
        NULL,
        &ba,
        &error
    );

    if (!s && strcmp(target, "@DEFAULT_MONITOR@") != 0) {
        s = pa_simple_new(NULL, "SystemPlusVisualizer", PA_STREAM_RECORD, "@DEFAULT_MONITOR@", "Spectrum Analyzer", &ss, NULL, &ba, &error);
    }

    if (!s) {
        fprintf(stderr, "Failed to connect to audio monitor: %s\n", pa_strerror(error));
        return 1;
    }

    int16_t samples[CHUNK_SIZE];
    double mags[NUM_BANDS];

    while (running) {
        if (pa_simple_read(s, samples, sizeof(samples), &error) < 0) {
            // If read error (e.g. server reset), try to recover
            usleep(20000);
            continue;
        }

        int max_amp = 0;
        for (int i = 0; i < CHUNK_SIZE; i++) {
            int a = abs(samples[i]);
            if (a > max_amp) max_amp = a;
        }

        if (max_amp < 5) {
            for (int b = 0; b < NUM_BANDS; b++) {
                smooth[b] *= 0.65;
                if (smooth[b] < 1.0) smooth[b] = 0;
                printf("%d%c", (int)smooth[b], (b == NUM_BANDS - 1) ? '\n' : ',');
            }
            fflush(stdout);
            continue;
        }

        double frame_max = 1.0;
        for (int b = 0; b < NUM_BANDS; b++) {
            double q0 = 0.0, q1 = 0.0, q2 = 0.0;
            double coeff = filters[b].coeff;
            for (int i = 0; i < CHUNK_SIZE; i++) {
                q0 = coeff * q1 - q2 + samples[i];
                q2 = q1;
                q1 = q0;
            }
            double real = q1 - q2 * filters[b].cos_w;
            double imag = q2 * filters[b].sin_w;
            double mag = (sqrt(real * real + imag * imag) / CHUNK_SIZE) * filters[b].eq_boost;
            mags[b] = mag;
            if (mag > frame_max) frame_max = mag;
        }

        if (frame_max > rolling_max) {
            rolling_max = rolling_max * 0.6 + frame_max * 0.4;
        } else {
            rolling_max = fmax(15.0, rolling_max * 0.985);
        }

        for (int b = 0; b < NUM_BANDS; b++) {
            double ratio = fmin(1.0, fmax(0.0, mags[b] / fmax(10.0, rolling_max)));
            double val = fmin(100.0, fmax(0.0, pow(ratio, 0.65) * 100.0));

            if (val > smooth[b]) {
                smooth[b] = val;
            } else {
                smooth[b] = fmax(0.0, smooth[b] * 0.68 + val * 0.32);
            }
            printf("%d%c", (int)smooth[b], (b == NUM_BANDS - 1) ? '\n' : ',');
        }
        fflush(stdout);
    }

    if (s) pa_simple_free(s);
    return 0;
}
