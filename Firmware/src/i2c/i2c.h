#pragma once

#include <stdint.h>

namespace i2c {

namespace address {

enum Addresses: uint8_t
{
    SSD1306 = 0x3C,
    TMP100 = 0x4A,
};

} // namespace address

// Assembler routines
extern "C" {

void Start();
void RepeatedStart();
void Stop();

bool Send(uint8_t data);
bool Send2(uint8_t data1, uint8_t data2);
bool Send3(uint8_t data1, uint8_t data2, uint8_t data3);
bool SendPM(const uint8_t* data, uint8_t length);

uint8_t Recv(bool ack);

}

void Init();

} // namespace i2c

