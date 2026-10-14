// Copyright 2026 Federico Runco (federico.runco@gmail.com)
// SPDX-License-Identifier: Apache-2.0 WITH SHL-2.1
// 
// Licensed under the Solderpad Hardware License v2.1 (the “License”); 
// you may not use this file except in compliance with the License, or, 
// at your option, the Apache License version 2.0. You may obtain a copy 
// of the License at https://solderpad.org/licenses/SHL-2.1/
// 
// Unless required by applicable law or agreed to in writing, any work 
// distributed under the License is distributed on an “AS IS” BASIS, WITHOUT 
// WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the 
// License for the specific language governing permissions and limitations 
// under the License.

#if defined(__APPLE__)
#include <util.h>
#else
#define _GNU_SOURCE
#include <pty.h>
#endif

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <termios.h>
#include <unistd.h>
#include <svdpi.h>

#define RX_BUF_SIZE (64 * 1024) // 64 KB userspace cache (power of 2)

typedef struct {
    int      master_fd;
    int      slave_fd;
    char     pts_name[256];
    uint8_t  rx_buf[RX_BUF_SIZE];
    uint32_t head;
    uint32_t tail;
    int      client_connected;
} uartdpi_ctx_t;

#ifdef __cplusplus
extern "C" {
#endif

void* uartdpi_create(const char* name) {
    uartdpi_ctx_t* ctx = (uartdpi_ctx_t*)calloc(1, sizeof(uartdpi_ctx_t));
    struct termios tty;

    // Pass NULL for name and query via ttyname_r for macOS + Linux safety
    if (openpty(&ctx->master_fd, &ctx->slave_fd, NULL, NULL, NULL) == -1) {
        perror("dpi: openpty failed");
        free(ctx);
        return NULL;
    }

    if (ttyname_r(ctx->slave_fd, ctx->pts_name, sizeof(ctx->pts_name)) != 0) {
        perror("dpi: ttyname_r failed");
        close(ctx->master_fd);
        close(ctx->slave_fd);
        free(ctx);
        return NULL;
    }

    // Raw mode: disable all line discipline overhead & byte mangling
    if (tcgetattr(ctx->slave_fd, &tty) == 0) {
        cfmakeraw(&tty);
        tcsetattr(ctx->slave_fd, TCSANOW, &tty);
    }

    if (tcgetattr(ctx->master_fd, &tty) == 0) {
        cfmakeraw(&tty);
        tcsetattr(ctx->master_fd, TCSANOW, &tty);
    }

    // Non-blocking master_fd
    int flags = fcntl(ctx->master_fd, F_GETFL, 0);
    fcntl(ctx->master_fd, F_SETFL, flags | O_NONBLOCK);

    // Create symlink (e.g. ./uart0 -> /dev/ttys004 or /dev/pts/X)
    unlink(name);
    if (symlink(ctx->pts_name, name) == 0) {
        printf("\n[UART-DPI] Virtual UART ready: %s -> ./%s\n", ctx->pts_name, name);
    } else {
        printf("\n[UART-DPI] Virtual UART ready: %s\n", ctx->pts_name);
    }
    fflush(stdout);

    return (void*)ctx;
}

int uartdpi_get_byte(void* ctx_void) {
    uartdpi_ctx_t* ctx = (uartdpi_ctx_t*)ctx_void;
    if (!ctx) return -1;

    // 1. Userspace hit (Zero syscalls!)
    if (ctx->head != ctx->tail) {
        uint8_t b = ctx->rx_buf[ctx->tail];
        ctx->tail = (ctx->tail + 1) & (RX_BUF_SIZE - 1);
        return (int)b;
    }

    // 2. Userspace empty -> Bulk read up to 64 KB in a single syscall
    ctx->head = 0;
    ctx->tail = 0;
    ssize_t n = read(ctx->master_fd, ctx->rx_buf, RX_BUF_SIZE - 1);
    if (n > 0) {
        ctx->client_connected = 1;
        ctx->head = (uint32_t)n;
        uint8_t b = ctx->rx_buf[0];
        ctx->tail = 1;
        return (int)b;
    }

    return -1;
}

void uartdpi_put_byte(void* ctx_void, char c) {
    uartdpi_ctx_t* ctx = (uartdpi_ctx_t*)ctx_void;
    if (!ctx) return;

    putchar((unsigned char)c);
    fflush(stdout);

    ssize_t unused = write(ctx->master_fd, &c, 1);
    (void)unused;

    if (c == '\n' && !ctx->client_connected) {
        printf("[DPI UART] Bootloader mode detected. Waiting for upload on uart0... ");
        fflush(stdout);

        const char* banner = "BOOTRDY\n";
        while (ctx->head == ctx->tail) {
            struct pollfd pfd = { .fd = ctx->master_fd, .events = POLLIN };
            if (poll(&pfd, 1, 200) > 0) {
                ssize_t n = read(ctx->master_fd, ctx->rx_buf, RX_BUF_SIZE - 1);
                if (n > 0) {
                    ctx->head = (uint32_t)n;
                    ctx->tail = 0;
                    ctx->client_connected = 1;
                    break;
                }
            }
            // Beacon "BOOTRDY\n" every 200ms while paused so upload script catches it whenever it opens ./uart0
            ssize_t w = write(ctx->master_fd, banner, 8);
            (void)w;
            usleep(200000);
        }

        printf("*** ok ***\n", ctx->head);
        fflush(stdout);
    }
}

void uartdpi_close(void* ctx_void) {
    uartdpi_ctx_t* ctx = (uartdpi_ctx_t*)ctx_void;
    if (!ctx) return;
    close(ctx->master_fd);
    close(ctx->slave_fd);
    free(ctx);
}

#ifdef __cplusplus
}
#endif