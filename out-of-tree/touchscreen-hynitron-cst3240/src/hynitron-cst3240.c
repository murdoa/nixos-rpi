// SPDX-License-Identifier: GPL-2.0-only
/*
 *  Driver for Hynitron CST3240 Touchscreen (CSTMutual)
 *
 *  Based on the cst3xx driver by Chris Morgan and
 *  reference implementation from Hynitron's TouchLib
 */

#include <linux/delay.h>
#include <linux/err.h>
#include <linux/gpio/consumer.h>
#include <linux/i2c.h>
#include <linux/input.h>
#include <linux/input/mt.h>
#include <linux/input/touchscreen.h>
#include <linux/mod_devicetable.h>
#include <linux/module.h>
#include <linux/property.h>
#include <linux/unaligned.h>

/* CST3240 (CSTMutual) I2C Address */
#define CST3240_I2C_ADDR		0x1A

/* CST3240 Information Registers */
#define CST3240_INFO_1_REG		0xD1F4
#define CST3240_INFO_2_REG		0xD1F8
#define CST3240_INFO_3_REG		0xD1FC
#define CST3240_INFO_4_REG		0xD204
#define CST3240_INFO_5_REG		0xD208
#define CST3240_INFO_6_REG		0xD20C

/* CST3240 Control Registers */
#define CST3240_MODE_DEBUG_INFO_REG	0xD101
#define CST3240_SYSTEM_RESET_REG	0xD102
#define CST3240_REDO_CALIBRATION_REG	0xD104
#define CST3240_DEEP_SLEEP_REG		0xD105
#define CST3240_MODE_DEBUG_POINT_REG	0xD108
#define CST3240_MODE_NORMAL_REG		0xD109

/* CST3240 Touch Data Registers (MODE_NORMAL) */
#define CST3240_TOUCH_BASE_REG		0xD000
#define CST3240_TOUCH_COUNT_REG		0xD005
#define CST3240_TOUCH_CHK_REG		0xD006

/* Touch data constants */
#define CST3240_TOUCH_CHK_VAL		0xAB
#define CST3240_TOUCH_STATE_PRESSED	0x06
#define CST3240_TOUCH_COUNT_MASK	0x0F
#define CST3240_IC_CHKCODE		0xA5A50000
#define CST3240_MAX_TOUCH_NUM		5
#define CST3240_TOUCH_DATA_SIZE		27

/* Per chip data */
struct hynitron_ts_chip_data {
	unsigned int max_touch_num;
	u32 ic_chkcode;
	int (*firmware_info)(struct i2c_client *client);
	int (*init_input)(struct i2c_client *client);
	void (*report_touch)(struct i2c_client *client);
};

/* Data generic to all (supported and non-supported) controllers. */
struct hynitron_ts_data {
	const struct hynitron_ts_chip_data *chip;
	struct i2c_client *client;
	struct input_dev *input_dev;
	struct touchscreen_properties prop;
	struct gpio_desc *reset_gpio;
};

/*
 * CST3240 uses 16-bit register addressing with big-endian byte order.
 * The register address is sent as two bytes: high byte first, then low byte.
 */
static int cst3240_i2c_write(struct i2c_client *client,
			     u16 reg, u8 *buf, int len)
{
	u8 *write_buf;
	int ret;
	int retries = 0;

	write_buf = kmalloc(len + 2, GFP_KERNEL);
	if (!write_buf)
		return -ENOMEM;

	write_buf[0] = reg >> 8;    /* High byte of register */
	write_buf[1] = reg & 0xFF;  /* Low byte of register */
	memcpy(&write_buf[2], buf, len);

	while (retries < 2) {
		ret = i2c_master_send(client, write_buf, len + 2);
		if (ret == len + 2) {
			kfree(write_buf);
			return 0;
		}
		if (ret <= 0)
			retries++;
		else
			break;
	}

	kfree(write_buf);
	return ret < 0 ? ret : -EIO;
}

static int cst3240_i2c_read_register(struct i2c_client *client, u16 reg,
				     u8 *val, u16 len)
{
	u8 reg_buf[2];
	struct i2c_msg msgs[] = {
		{
			.addr = client->addr,
			.flags = 0,
			.len = 2,
			.buf = reg_buf,
		},
		{
			.addr = client->addr,
			.flags = I2C_M_RD,
			.len = len,
			.buf = val,
		}
	};
	int err;
	int ret;

	reg_buf[0] = reg >> 8;    /* High byte of register */
	reg_buf[1] = reg & 0xFF;  /* Low byte of register */

	ret = i2c_transfer(client->adapter, msgs, ARRAY_SIZE(msgs));
	if (ret == ARRAY_SIZE(msgs))
		return 0;

	err = ret < 0 ? ret : -EIO;
	dev_err(&client->dev, "Error reading %d bytes from 0x%04x: %d (%d)\n",
		len, reg, err, ret);

	return err;
}

static void hyn_reset_proc(struct i2c_client *client, int delay)
{
	struct hynitron_ts_data *ts_data = i2c_get_clientdata(client);

	if (ts_data->reset_gpio) {
		gpiod_set_value_cansleep(ts_data->reset_gpio, 1);
		msleep(20);
		gpiod_set_value_cansleep(ts_data->reset_gpio, 0);
		if (delay)
			msleep(delay);
	}
}

static int cst3240_firmware_info(struct i2c_client *client)
{
	u8 buf[4];
	u32 chkcode;
	int err;

	/* Read IC check code to verify device */
	err = cst3240_i2c_read_register(client, CST3240_INFO_3_REG, buf, 4);
	if (err)
		return err;

	/* INFO_3_REG contains 0xA5A5 in bytes 3-2 */
	chkcode = get_unaligned_le32(buf);
	if ((chkcode & 0xFFFF0000) != CST3240_IC_CHKCODE) {
		dev_err(&client->dev, "IC mismatch, chkcode is 0x%08x\n",
			chkcode);
		return -ENODEV;
	}

	/* Read firmware version from INFO_5_REG */
	err = cst3240_i2c_read_register(client, CST3240_INFO_5_REG, buf, 4);
	if (err)
		return err;

	dev_info(&client->dev, "Firmware version: %d.%d.%d\n",
		 buf[3], buf[2], get_unaligned_le16(&buf[0]));

	return 0;
}

static void cst3240_report_contact(struct hynitron_ts_data *ts_data,
				   u8 id, unsigned int x, unsigned int y,
				   u8 pressure)
{
	input_mt_slot(ts_data->input_dev, id);
	input_mt_report_slot_state(ts_data->input_dev, MT_TOOL_FINGER, 1);
	touchscreen_report_pos(ts_data->input_dev, &ts_data->prop, x, y, true);
	input_report_abs(ts_data->input_dev, ABS_MT_PRESSURE, pressure);
}

/*
 * CST3240 Touch Report Handler
 *
 * The CST3240 returns touch data in a different format than CST3XX:
 * - Reads 27 bytes starting from 0xD000
 * - Byte 5 (0xD005): touch count in lower 4 bits
 * - Byte 6 (0xD006): check byte, should be 0xAB
 * - Each touch point uses 5 bytes:
 *   Byte 0: [7:4] finger ID, [3:0] state (0x06 = pressed)
 *   Byte 1: X coordinate high 8 bits
 *   Byte 2: Y coordinate high 8 bits
 *   Byte 3: [7:4] X coordinate low 4 bits, [3:0] Y coordinate low 4 bits
 *   Byte 4: Pressure value
 * - Touch points are at offsets: 0, 7, 12, 17, 22
 * - After reading, write 0xAB to 0xD000 as sync signal
 */
static void cst3240_touch_report(struct i2c_client *client)
{
	struct hynitron_ts_data *ts_data = i2c_get_clientdata(client);
	u8 buf[CST3240_TOUCH_DATA_SIZE];
	u8 touch_cnt;
	u8 sync_val = CST3240_TOUCH_CHK_VAL;
	unsigned int i;
	int err;

	/* Touch point offsets in the data buffer */
	const unsigned int touch_offsets[CST3240_MAX_TOUCH_NUM] = {
		0, 7, 12, 17, 22
	};

	/* Read touch data */
	err = cst3240_i2c_read_register(client, CST3240_TOUCH_BASE_REG,
					buf, CST3240_TOUCH_DATA_SIZE);
	if (err) {
		dev_err(&client->dev, "Failed to read touch data: %d\n", err);
		return;
	}

	/* Validate check byte */
	if (buf[6] != CST3240_TOUCH_CHK_VAL) {
		dev_dbg(&client->dev, "Invalid check byte: 0x%02x\n", buf[6]);
		return;
	}

	/* Send sync signal to acknowledge read */
	err = cst3240_i2c_write(client, CST3240_TOUCH_BASE_REG,
				&sync_val, 1);
	if (err) {
		dev_err(&client->dev, "Failed to send sync signal: %d\n", err);
		return;
	}

	/* Get touch count */
	touch_cnt = buf[5] & CST3240_TOUCH_COUNT_MASK;

	/* Process each touch point */
	for (i = 0; i < touch_cnt && i < CST3240_MAX_TOUCH_NUM; i++) {
		unsigned int idx = touch_offsets[i];
		u8 state = buf[idx] & 0x0F;
		u8 finger_id = (buf[idx] >> 4) & 0x0F;
		unsigned int x, y;
		u8 pressure;

		/* Check if touch is pressed */
		if (state == CST3240_TOUCH_STATE_PRESSED) {
			/* Extract coordinates using COMBINE_H8L4 format:
			 * X = (buf[idx+1] << 4) | (buf[idx+3] >> 4)
			 * Y = (buf[idx+2] << 4) | (buf[idx+3] & 0x0F)
			 */
			x = (buf[idx + 1] << 4) | (buf[idx + 3] >> 4);
			y = (buf[idx + 2] << 4) | (buf[idx + 3] & 0x0F);
			pressure = buf[idx + 4];

			cst3240_report_contact(ts_data, finger_id, x, y,
					       pressure);
		}
	}

	input_mt_sync_frame(ts_data->input_dev);
	input_sync(ts_data->input_dev);
}

static irqreturn_t hyn_interrupt_handler(int irq, void *dev_id)
{
	struct i2c_client *client = dev_id;
	struct hynitron_ts_data *ts_data = i2c_get_clientdata(client);

	ts_data->chip->report_touch(client);

	return IRQ_HANDLED;
}

static int cst3240_input_dev_int(struct i2c_client *client)
{
	struct hynitron_ts_data *ts_data = i2c_get_clientdata(client);
	int err;

	ts_data->input_dev = devm_input_allocate_device(&client->dev);
	if (!ts_data->input_dev) {
		dev_err(&client->dev, "Failed to allocate input device\n");
		return -ENOMEM;
	}

	ts_data->input_dev->name = "Hynitron CST3240 Touchscreen";
	ts_data->input_dev->phys = "input/ts";
	ts_data->input_dev->id.bustype = BUS_I2C;

	input_set_drvdata(ts_data->input_dev, ts_data);

	input_set_capability(ts_data->input_dev, EV_ABS, ABS_MT_POSITION_X);
	input_set_capability(ts_data->input_dev, EV_ABS, ABS_MT_POSITION_Y);
	input_set_abs_params(ts_data->input_dev, ABS_MT_PRESSURE,
			     0, 255, 0, 0);

	touchscreen_parse_properties(ts_data->input_dev, true, &ts_data->prop);

	if (!ts_data->prop.max_x || !ts_data->prop.max_y) {
		dev_err(&client->dev,
			"Invalid x/y (%d, %d), using defaults\n",
			ts_data->prop.max_x, ts_data->prop.max_y);
		ts_data->prop.max_x = 480;
		ts_data->prop.max_y = 480;
		input_abs_set_max(ts_data->input_dev,
				  ABS_MT_POSITION_X, ts_data->prop.max_x);
		input_abs_set_max(ts_data->input_dev,
				  ABS_MT_POSITION_Y, ts_data->prop.max_y);
	}

	err = input_mt_init_slots(ts_data->input_dev,
				  ts_data->chip->max_touch_num,
				  INPUT_MT_DIRECT | INPUT_MT_DROP_UNUSED);
	if (err) {
		dev_err(&client->dev,
			"Failed to initialize input slots: %d\n", err);
		return err;
	}

	err = input_register_device(ts_data->input_dev);
	if (err) {
		dev_err(&client->dev,
			"Input device registration failed: %d\n", err);
		return err;
	}

	return 0;
}

static int hyn_probe(struct i2c_client *client)
{
	struct hynitron_ts_data *ts_data;
	int err;

	ts_data = devm_kzalloc(&client->dev, sizeof(*ts_data), GFP_KERNEL);
	if (!ts_data)
		return -ENOMEM;

	ts_data->client = client;
	i2c_set_clientdata(client, ts_data);

	ts_data->chip = device_get_match_data(&client->dev);
	if (!ts_data->chip)
		return -EINVAL;

	ts_data->reset_gpio = devm_gpiod_get_optional(&client->dev,
					     "reset", GPIOD_OUT_LOW);
	if (IS_ERR(ts_data->reset_gpio)) {
		err = PTR_ERR(ts_data->reset_gpio);
		dev_err(&client->dev, "request reset gpio failed: %d\n", err);
		return err;
	}

	hyn_reset_proc(client, 200);

	err = ts_data->chip->init_input(client);
	if (err < 0)
		return err;

	err = ts_data->chip->firmware_info(client);
	if (err < 0)
		return err;

	err = devm_request_threaded_irq(&client->dev, client->irq,
					NULL, hyn_interrupt_handler,
					IRQF_ONESHOT,
					"Hynitron CST3240 Touch", client);
	if (err) {
		dev_err(&client->dev, "failed to request IRQ: %d\n", err);
		return err;
	}

	return 0;
}

static const struct hynitron_ts_chip_data cst3240_data = {
	.max_touch_num		= CST3240_MAX_TOUCH_NUM,
	.ic_chkcode		= CST3240_IC_CHKCODE,
	.firmware_info		= &cst3240_firmware_info,
	.init_input		= &cst3240_input_dev_int,
	.report_touch		= &cst3240_touch_report,
};

static const struct i2c_device_id hyn_tpd_id[] = {
	{ .name = "hynitron_cst3240" },
	{ /* sentinel */ },
};
MODULE_DEVICE_TABLE(i2c, hyn_tpd_id);

static const struct of_device_id hyn_dt_match[] = {
	{ .compatible = "hynitron,cst3240", .data = &cst3240_data },
	{ /* sentinel */ },
};
MODULE_DEVICE_TABLE(of, hyn_dt_match);

static struct i2c_driver hynitron_i2c_driver = {
	.driver = {
		.name = "hynitron-cst3240",
		.of_match_table = hyn_dt_match,
		.probe_type = PROBE_PREFER_ASYNCHRONOUS,
	},
	.id_table = hyn_tpd_id,
	.probe = hyn_probe,
};

module_i2c_driver(hynitron_i2c_driver);

MODULE_AUTHOR("Based on Chris Morgan's work, adapted for CST3240");
MODULE_DESCRIPTION("Hynitron CST3240 Touchscreen Driver");
MODULE_LICENSE("GPL");
