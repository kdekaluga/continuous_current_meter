#include "../includes.h"

#include "i2c.h"

namespace i2c {

extern "C" {

void i2c_delay_low();
void i2c_delay_high();

}

#define SCL_TOGGLE USICR = BV(USIWM1) | BV(USITC)
#define DATA_SHIFT USICR = BV(USIWM1) | BV(USICLK)

void Init()
{
    PORTB |= BV(PIN_SCL) | BV(PIN_SDA);
    DDRB |= BV(PIN_SCL) | BV(PIN_SDA);

    // Reset the start detection flag and switch USI to the TWI mode
    USISR = BV(USISIF);
    USIDR = 0xFF;
    USICR = BV(USIWM1);
}

/*
void Start()
{
    // Both SDA and SCL lines must be high.
    // Wait for some time in case we are called right after
    // a STOP command
    i2c_delay_low();

    // Pull SDA low by setting the USIDR MSB to 0
    USIDR = 0x00;
    i2c_delay_high();

    // Lower the SCL line
    PORTB &= ~(BV(PIN_SCL));

    // Clear the start detector state
    USISR = BV(USISIF);

    i2c_delay_low();
}

void RepeatedStart()
{
    // SCL must be low, SDA may be at any level
    USIDR = 0xFF;
    i2c_delay_low();

    SCL_TOGGLE;
    Start();
}

void Stop()
{
    // SCL must be low and SDA is undefined. Set SDA to low
    USIDR = 0x00;
    i2c_delay_low();

    // Set SCL to high
    PORTB |= BV(PIN_SCL);
    i2c_delay_high();

    // Set SDA to high
    USIDR = 0xFF;
}

bool Send(uint8_t data)
{
    // SCL must be low. Output the first bit (MSB)
    USIDR = data;

    // Transfer 7 bits
    for (uint8_t i = 0u; i < 7; ++i)
    {
        i2c_delay_low();
        
        // Generate a clock impulse
        SCL_TOGGLE;
        i2c_delay_high();
        SCL_TOGGLE;

        DATA_SHIFT;
    }

    // Send the 8th bit
    i2c_delay_low();
    SCL_TOGGLE;
    i2c_delay_high();
    SCL_TOGGLE;

    // SCL is low, set SDA to high and read the (N)ACK bit
    USIDR = 0xFF;
    i2c_delay_low();
    SCL_TOGGLE;
    i2c_delay_high();
    DATA_SHIFT;
    SCL_TOGGLE;

    // SCL is low, SDA is high
    return (USIDR & 1) == 0;
}

bool Send2(uint8_t data1, uint8_t data2)
{
    return Send(data1) && Send(data2);
}

bool Send3(uint8_t data1, uint8_t data2, uint8_t data3)
{
    return Send(data1) && Send(data2) && Send(data3);
}

bool SendPM(const uint8_t* data, uint8_t length)
{
    for (; length > 0; --length)
    {
        if (!Send(pgm_read_byte(data++)))
            return false;
    }

    return true;
}
*/

uint8_t Recv(bool ack)
{
    // SCL must be low. Set SDA high and make sure it won't go low
    USIDR = 0xFF;

    // We can't receive all 8 bits at once because the USIDR register is used as both
    // send and receive buffer, so when we receive the 8th bit, the SDA line may go low
    // as it will output the first received bit. Thus receive only the first 7 bits.
    for (uint8_t i = 0u; i < 7; ++i)
    {
        i2c_delay_low();
        
        // Generate a clock impulse
        SCL_TOGGLE;
        i2c_delay_high();
        DATA_SHIFT;
        SCL_TOGGLE;
    }

    // Receive the 8th bit
    i2c_delay_low();
    SCL_TOGGLE;
    i2c_delay_high();

    // Get the first 7 bits (0b1xxxxxxx) and make sure the SDA will be high
    // after one more data shift
    uint8_t result = USIDR << 1;
    USIDR = 0xFF;
    DATA_SHIFT;
    SCL_TOGGLE;

    // Get the last 8th bit
    result |= USIDR & 0x01;

    // Send (N)ACK
    USIDR = ack ? 0x00 : 0xFF;
    i2c_delay_low();
    SCL_TOGGLE;
    i2c_delay_high();
    SCL_TOGGLE;

    // Return SDA back to high (just in case)
    USIDR = 0xFF;

    return result;
}

} // namespace i2c
