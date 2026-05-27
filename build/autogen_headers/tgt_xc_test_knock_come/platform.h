#ifndef HAVE_PLATFORM_H
#define HAVE_PLATFORM_H

#include <xs1.h>

/*
 * Platform description header file.
 * Automatically generated from "/Applications/XMOS_XTC_15.3.1/targets/XK-EVK-XU316/XK-EVK-XU316.xn".
 */

#ifdef __XC__
/* Core array declaration. */
extern tileref tile[2];
#endif

#ifdef __XC__
/* Service prototypes. */
service xscope_host_data(chanend c);;
#endif

#if defined(__XC__)
#define PORT_SQI_CS on tile[0]: XS1_PORT_1B
#define PORT_SQI_SCLK on tile[0]: XS1_PORT_1C
#define PORT_SQI_SIO on tile[0]: XS1_PORT_4B
#define PORT_LEDS on tile[0]: XS1_PORT_4C
#define PORT_BUTTONS on tile[0]: XS1_PORT_4D
#define WIFI_WIRQ on tile[0]: XS1_PORT_1I
#define WIFI_MOSI on tile[0]: XS1_PORT_1J
#define WIFI_WUP_RST_N on tile[0]: XS1_PORT_4E
#define WIFI_CS_N on tile[0]: XS1_PORT_4F
#define WIFI_CLK on tile[0]: XS1_PORT_1L
#define WIFI_MISO on tile[0]: XS1_PORT_1M
#define PORT_PDM_CLK on tile[1]: XS1_PORT_1G
#define PORT_PDM_DATA on tile[1]: XS1_PORT_1F
#define PORT_MCLK_IN on tile[1]: XS1_PORT_1D
#define PORT_I2S_BCLK on tile[1]: XS1_PORT_1C
#define PORT_I2S_LRCLK on tile[1]: XS1_PORT_1B
#define PORT_I2S_DAC_DATA on tile[1]: XS1_PORT_1A
#define PORT_I2S_ADC_DATA on tile[1]: XS1_PORT_1N
#define PORT_CODEC_RST_N on tile[1]: XS1_PORT_4A
#else
#define PORT_SQI_CS XS1_PORT_1B
#define PORT_SQI_SCLK XS1_PORT_1C
#define PORT_SQI_SIO XS1_PORT_4B
#define PORT_LEDS XS1_PORT_4C
#define PORT_BUTTONS XS1_PORT_4D
#define WIFI_WIRQ XS1_PORT_1I
#define WIFI_MOSI XS1_PORT_1J
#define WIFI_WUP_RST_N XS1_PORT_4E
#define WIFI_CS_N XS1_PORT_4F
#define WIFI_CLK XS1_PORT_1L
#define WIFI_MISO XS1_PORT_1M
#define PORT_PDM_CLK XS1_PORT_1G
#define PORT_PDM_DATA XS1_PORT_1F
#define PORT_MCLK_IN XS1_PORT_1D
#define PORT_I2S_BCLK XS1_PORT_1C
#define PORT_I2S_LRCLK XS1_PORT_1B
#define PORT_I2S_DAC_DATA XS1_PORT_1A
#define PORT_I2S_ADC_DATA XS1_PORT_1N
#define PORT_CODEC_RST_N XS1_PORT_4A
#endif

#define PORT_SQI_CS_TILE tile[0]
#define PORT_SQI_CS_TILE_NUM 0
#define PORT_SQI_SCLK_TILE tile[0]
#define PORT_SQI_SCLK_TILE_NUM 0
#define PORT_SQI_SIO_TILE tile[0]
#define PORT_SQI_SIO_TILE_NUM 0
#define PORT_LEDS_TILE tile[0]
#define PORT_LEDS_TILE_NUM 0
#define PORT_BUTTONS_TILE tile[0]
#define PORT_BUTTONS_TILE_NUM 0
#define WIFI_WIRQ_TILE tile[0]
#define WIFI_WIRQ_TILE_NUM 0
#define WIFI_MOSI_TILE tile[0]
#define WIFI_MOSI_TILE_NUM 0
#define WIFI_WUP_RST_N_TILE tile[0]
#define WIFI_WUP_RST_N_TILE_NUM 0
#define WIFI_CS_N_TILE tile[0]
#define WIFI_CS_N_TILE_NUM 0
#define WIFI_CLK_TILE tile[0]
#define WIFI_CLK_TILE_NUM 0
#define WIFI_MISO_TILE tile[0]
#define WIFI_MISO_TILE_NUM 0
#define PORT_PDM_CLK_TILE tile[1]
#define PORT_PDM_CLK_TILE_NUM 1
#define PORT_PDM_DATA_TILE tile[1]
#define PORT_PDM_DATA_TILE_NUM 1
#define PORT_MCLK_IN_TILE tile[1]
#define PORT_MCLK_IN_TILE_NUM 1
#define PORT_I2S_BCLK_TILE tile[1]
#define PORT_I2S_BCLK_TILE_NUM 1
#define PORT_I2S_LRCLK_TILE tile[1]
#define PORT_I2S_LRCLK_TILE_NUM 1
#define PORT_I2S_DAC_DATA_TILE tile[1]
#define PORT_I2S_DAC_DATA_TILE_NUM 1
#define PORT_I2S_ADC_DATA_TILE tile[1]
#define PORT_I2S_ADC_DATA_TILE_NUM 1
#define PORT_CODEC_RST_N_TILE tile[1]
#define PORT_CODEC_RST_N_TILE_NUM 1


/* Reference frequency definition. */
#define PLATFORM_REFERENCE_HZ 100000000
#define PLATFORM_REFERENCE_KHZ 100000
#define PLATFORM_REFERENCE_MHZ 100
#define PLATFORM_NODE_0_SYSTEM_FREQUENCY_HZ 600000000
#define PLATFORM_NODE_0_SYSTEM_FREQUENCY_KHZ 600000
#define PLATFORM_NODE_0_SYSTEM_FREQUENCY_MHZ 600

#endif /* HAVE_PLATFORM_H */

