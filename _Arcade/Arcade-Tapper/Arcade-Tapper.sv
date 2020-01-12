//============================================================================
//  Arcade: Tapper
//
//  Port to MiSTer
//  Copyright (C) 2019 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        VGA_CLK,

	//Multiple resolutions are supported using different VGA_CE rates.
	//Must be based on CLK_VIDEO
	output        VGA_CE,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,

	
	// DB9 Joystick
	input [5:0] joy_o_db9,    // CB UDLR negative Logic
	output      db9_Select,
	output      splitter_select,   
	
	
	//Base video clock. Usually equals to CLK_SYS.
	output        HDMI_CLK,

	//Multiple resolutions are supported using different HDMI_CE rates.
	//Must be based on CLK_VIDEO
	output        HDMI_CE,

	output  [7:0] HDMI_R,
	output  [7:0] HDMI_G,
	output  [7:0] HDMI_B,
	output        HDMI_HS,
	output        HDMI_VS,
	output        HDMI_DE,   // = ~(VBlank | HBlank)
	output  [1:0] HDMI_SL,   // scanlines fx

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	output  [7:0] HDMI_ARX,
	output  [7:0] HDMI_ARY,

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,    // 1 - signed audio samples, 0 - unsigned

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE, 

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT
);

assign VGA_F1    = 0;
assign USER_OUT  = '1;
assign LED_USER  = ioctl_download;
assign LED_DISK  = 0;
assign LED_POWER = 0;

//assign HDMI_ARX = status[1] ? 8'd16 : status[2] ? 8'd4 : 8'd3;
//assign HDMI_ARY = status[1] ? 8'd9  : status[2] ? 8'd3 : 8'd4;
//assign HDMI_ARX = status[1] ? 8'd16 : status[2] ? 8'd21 : 8'd20;
//;assign HDMI_ARY = status[1] ? 8'd9  : status[2] ? 8'd20 : 8'd21;
assign HDMI_ARX = status[1] ? 8'd16 : 8'd4;
assign HDMI_ARY = status[1] ? 8'd9  : 8'd3;


`include "build_id.v" 
localparam CONF_STR = {
	"A.TAPPER_DB9;;",
	"H0O1,Aspect Ratio,Original,Wide;",
	//"H0O2,Orientation,Vert,Horz;",
	"O35,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;",
	"-;",
	"O6,Service,Off,On;",
	"O7,Audio,Mono,Stereo;",
	//"O8,Demo Sounds,Off,On;",
	//"OC,Cabinet,Upright,Cocktail;",
	"OD,Deinterlacer,Off,On;",
	"-;",
	//"OEF,DB9 MegaJoy,Player1,Player2,P1+P2(Splitter),OFF;",
	//"OG,Swap Joysticks,No,Yes;",
	"-;",
	"R0,Reset;",
	"J1,Serve,Start 1P,Start 2P,Coin;",
	"jn,A,Start,Select,R;",
	"V,v",`BUILD_DATE
};

////////////////////   JOYSTICKS   ///////////////////

// First we applied the Splitter , later 6 buttons Megadrive 
// I/O 2 Joystick splititer option added from joy_o_db9 ////////////////

// create a binary counter
//reg [31:0] cnt; // 32-bit counter

//initial begin
//     cnt <= 32'h00000000; // start at zero
//end
//always @(posedge CLK_50M) begin
//     cnt <= cnt + 1; // count up
//end


//////  I/O 2 Joystick s[;iter option added from JOYAV ////////////////
reg  [5:0] joy_1, joy_2;   // CB UDLR  Positive Logic

reg joy_split = 1'b1;
//assign splitter_select = joy_split;   
//
//always @(posedge cnt[8])  // 50/256  = 195 khz 
//  begin
//    if (joy_split)
//	   begin
//	     joy_1 <= joy_o_db9;
//		  joy_split <= 1'b0;
//		end
//    else 
//	   begin
//        joy_2 <= joy_o_db9; 
//		  joy_split <= 1'b1;
//		end
//  end


// Now we applu the menu options

wire [5:0] JOYAV_T1;      // CB UDLR  in negative logic
wire [5:0] JOYAV_T2;      // CB UDLR  in negative logic


//always @(posedge clk_mem)
//  begin
//    case (status[15:14])
//        2'b00 : begin						// Player 1
//						JOYAV_T1 <=  joy_o_db9;
//						JOYAV_T2 <=  6'b111111; // because is negative logic
//					 end
//        2'b01 : begin						// Player 2
//						JOYAV_T1 <=  6'b111111; // because is negative logic
//						JOYAV_T2 <=  joy_o_db9;
//					 end
//        2'b10 : begin						// P1 + P2 (Splitter)
//						JOYAV_T1 <=  joy_1;
//						JOYAV_T2 <=  joy_2;
//					 end
//		  2'b11 : begin						// DB9 OFF
//						JOYAV_T1 <=  6'b111111; // because is negative logic
//						JOYAV_T2 <=  6'b111111; // because is negative logic
//					 end
//   // default : r_RESULT <= 9; 
//    endcase
//  end

assign JOYAV_T1 =  joy_o_db9;
assign JOYAV_T2 =  joy_o_db9;

// Now we apply the megadrive desmultiplexor conversor

wire [11:0] joy1_o;   // MXYZ SACB RLDU  in negative logic
wire [11:0] joy2_o;   // MXYZ SACB RLDU  in negative logic

// Llamamos a la maquina de estados para leer los 6 botones del mando de Megadrive
// Formato joy1_o [11:0] =  MXYZ SACB RLDU
sega_joystick joy_genesys (
	.joy1_up_i		(JOYAV_T1[3]),   // joy1 // CB UDLR
	.joy1_down_i	(JOYAV_T1[2]),
	.joy1_left_i	(JOYAV_T1[1]),
	.joy1_right_i	(JOYAV_T1[0]),
	.joy1_p6_i		(JOYAV_T1[4]),
	.joy1_p9_i		(JOYAV_T1[5]),
	.joy2_up_i		(JOYAV_T2[3]),
	.joy2_down_i	(JOYAV_T2[2]),
	.joy2_left_i	(JOYAV_T2[1]),
	.joy2_right_i	(JOYAV_T2[0]),
	.joy2_p6_i		(JOYAV_T2[4]),
	.joy2_p9_i		(JOYAV_T2[5]),
	.vga_hsync_n_s (VGA_HS),
	.joyX_p7_o		(db9_Select), // select signal
	.joy1_o			(joy1_o),    // MXYZ SACB RLDU
	.joy2_o			(joy2_o)     // MXYZ SACB RLDU 
);


// option Buttons 1    //Coin   S2 S1  F  UDLR    F is Fire (or )ABC
wire [7:0] JOYAV_1;   // Mode   XY  S ABC UDLR   in positive logic    
//wire [7:0] JOYAV_2;   // SMZX AYBC UDLR   in positive logic

assign JOYAV_1 = ~{joy1_o[11] ,joy1_o[10] & joy1_o[9] , joy1_o[7]  ,joy1_o[6] & joy1_o[5] & joy1_o[4],  joy1_o[0],joy1_o[1],joy1_o[2],joy1_o[3]};  
//assign JOYAV_2 = ~{joy2_o[11]  ,joy2_o[6] & joy2_o[5] & joy2_o[4],  joy2_o[0],joy2_o[1],joy2_o[2],joy2_o[3]};  
  


////////////////////   CLOCKS   ///////////////////

wire clk_sys,clk_80M;
wire clk_mem = clk_80M;
wire pll_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(clk_sys), // 40M
	.outclk_1(clk_80M), // 80M
	.locked(pll_locked)
);

///////////////////////////////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire        direct_video;

wire        ioctl_download;
wire        ioctl_wr;
wire [24:0] ioctl_addr;
wire  [7:0] ioctl_dout;

wire [10:0] ps2_key;

wire [15:0] joystick_0, joystick_1;
wire [15:0] joy = joystick_0 | joystick_1 | JOYAV_1;
wire [15:0] joy_a;

wire [21:0] gamma_bus;

hps_io #(.STRLEN($size(CONF_STR)>>3)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.conf_str(CONF_STR),

	.buttons(buttons),
	.status(status),
	.status_menumask(direct_video),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),
	.direct_video(direct_video),

	.ioctl_download(ioctl_download),
	.ioctl_wr(ioctl_wr),
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),

	.joystick_0(joystick_0),
	.joystick_1(joystick_1),
	.joystick_analog_0(joy_a),
	.ps2_key(ps2_key)
);

wire [15:0] rom_addr;
wire [15:0] rom_do;
wire [13:0] snd_addr;
wire [15:0] snd_do;
wire [14:0] sp_addr;
wire [31:0] sp_do;

// ROM structure:

//  0000 -  DFFF - Main ROM (8 bit)
//  E000 -  11FFF - Super Sound board ROM (8 bit)
// 12000 -  31FFF - Sprite ROMs (32 bit)
// 32000 -  39FFF - BG ROMS

//wire [24:0] rom_ioctl_addr = ~ioctl_addr[16] ? ioctl_addr : // 8 bit ROMs
//                             {ioctl_addr[24:16], ioctl_addr[15], ioctl_addr[13:0], ioctl_addr[14]}; // 16 bit ROM

wire [24:0] sp_ioctl_addr = ioctl_addr - 17'h12000; //SP ROM offset: 0x12000
wire [24:0] dl_addr = ioctl_addr - 18'h32000; //background offset

reg port1_req, port2_req;
sdram sdram
(
	.*,
	.init_n        ( pll_locked   ),
	.clk           ( clk_mem      ),

	// port1 used for main + sound CPUs
	.port1_req     ( port1_req    ),
	.port1_ack     ( ),
	.port1_a       ( ioctl_addr[23:1] ),
	.port1_ds      ( {ioctl_addr[0], ~ioctl_addr[0]} ),
	.port1_we      ( ioctl_download ),
	.port1_d       ( {ioctl_dout, ioctl_dout} ),
	.port1_q       ( ),

	.cpu1_addr     ( ioctl_download ? 16'hffff : {1'b0, rom_addr[15:1]} ),
	.cpu1_q        ( rom_do ),
	.cpu2_addr     ( ioctl_download ? 16'hffff : (16'h7000 + snd_addr[13:1]) ),
	.cpu2_q        ( snd_do ),
	

	// port2 for sprite graphics
	.port2_req     ( port2_req ),
	.port2_ack     ( ),
	.port2_a       ( {sp_ioctl_addr[18:17], sp_ioctl_addr[14:0], sp_ioctl_addr[16]} ), // merge sprite roms to 32-bit wide words
	.port2_ds      ( {sp_ioctl_addr[15], ~sp_ioctl_addr[15]} ),
	.port2_we      ( ioctl_download ),
	.port2_d       ( {ioctl_dout, ioctl_dout} ),
	.port2_q       ( ),

	.sp_addr       ( ioctl_download ? 15'h7fff : sp_addr ),
	.sp_q          ( sp_do )
);

// ROM download controller
always @(posedge clk_sys) begin
	reg        ioctl_wr_last = 0;

	ioctl_wr_last <= ioctl_wr;
	if (ioctl_download) begin
		if (~ioctl_wr_last && ioctl_wr) begin
			port1_req <= ~port1_req;
			port2_req <= ~port2_req;
		end
	end
end

// reset signal generation
reg reset = 1;
reg rom_loaded = 0;
always @(posedge clk_sys) begin
	reg ioctl_downloadD;
	reg [15:0] reset_count;
	ioctl_downloadD <= ioctl_download;

	// generate a second reset signal - needed for some reason
	if (RESET | status[0] | buttons[1] | ~rom_loaded) reset_count <= 16'hffff;
	else if (reset_count != 0) reset_count <= reset_count - 1'd1;

	if (ioctl_downloadD & ~ioctl_download) rom_loaded <= 1;
	reset <= RESET | status[0] | buttons[1] | ~rom_loaded | (reset_count == 16'h0001);
end

wire       pressed = ps2_key[9];
wire [8:0] code    = ps2_key[8:0];
always @(posedge clk_sys) begin
	reg old_state;
	old_state <= ps2_key[10];
	
	if(old_state != ps2_key[10]) begin
		casex(code)
			'hX75: btn_up          <= pressed; // up
			'hX72: btn_down        <= pressed; // down
			'hX6B: btn_left        <= pressed; // left
			'hX74: btn_right       <= pressed; // right
			'h029: btn_fire        <= pressed; // space
			'h014: btn_fire2       <= pressed; // ctrl

			'h005: btn_start_1     <= pressed; // F1
			'h006: btn_start_2     <= pressed; // F2
			'h004: btn_coin_1	   <= pressed; // F3
			'h00C: btn_coin_2	   <= pressed; // F4

			'h003: btn_cheat       <= pressed; // F5

			// JPAC/IPAC/MAME Style Codes
			'h016: btn_start_1     <= pressed; // 1
			'h01E: btn_start_2     <= pressed; // 2
			'h02E: btn_coin_1      <= pressed; // 5
			'h036: btn_coin_2      <= pressed; // 6
			'h02D: btn_up_2        <= pressed; // R
			'h02B: btn_down_2      <= pressed; // F
			'h023: btn_left_2      <= pressed; // D
			'h034: btn_right_2     <= pressed; // G
			'h01C: btn_fire_2      <= pressed; // A
			//need btn_fire_22
		endcase
	end
end

reg btn_up    = 0;
reg btn_down  = 0;
reg btn_right = 0;
reg btn_left  = 0;
reg btn_fire  = 0;
reg btn_fire2 = 0;
reg btn_cheat = 0;

reg btn_start_1=0;
reg btn_start_2=0;
reg btn_coin_1=0;
reg btn_coin_2=0;
reg btn_up_2=0;
reg btn_down_2=0;
reg btn_left_2=0;
reg btn_right_2=0;
reg btn_fire_2=0;
reg btn_fire_22=0;

wire m_up     = btn_up    | joy[3];
wire m_down   = btn_down  | joy[2];
wire m_left   = btn_left  | joy[1];
wire m_right  = btn_right | joy[0];
wire m_fire   = btn_fire  | joy[4];
wire m_fire2  = btn_fire2;

wire m_up_2     = btn_up_2    | joy[3];
wire m_down_2   = btn_down_2  | joy[2];
wire m_left_2   = btn_left_2  | joy[1];
wire m_right_2  = btn_right_2 | joy[0];
wire m_fire_2   = btn_fire_2;
wire m_fire_22  = btn_fire_22;

wire m_start1 = btn_start_1  | joy[5];
wire m_start2 = btn_start_2  | joy[6];
wire m_coin   = btn_coin_1   | joy[7];
wire m_coin2  = btn_coin_2;


wire ce_pix_old;
wire hblank, vblank;
wire hs, vs;
wire [2:0] r,g;
wire [2:0] b;


reg ce_pix;
always @(posedge clk_sys) begin
        reg [2:0] div;

        div <= div + 1'd1;
        ce_pix <= !div;
end

// 512x480
//arcade_rotate_fx #(496,240,9) arcade_video
//arcade_fx #(480,9) arcade_video
arcade_fx #(512,9) arcade_video//505?
(
	.*,
	.ce_pix(status[13] ? ce_pix_old: ce_pix),
	.clk_video(clk_sys),
	.RGB_in({r,g,b}),
	.HBlank(hblank),
	.VBlank(vblank),
	.HSync(hs),
	.VSync(vs),

	.fx(status[5:3])
);

assign AUDIO_S = 0;
wire [15:0] audio_l, audio_r;


assign AUDIO_L = audio_l;
assign AUDIO_R = audio_r;

Tapper Tapper
(
	.clock_40(clk_sys),
	.reset(reset),
	.video_r(r),
	.video_g(g),
	.video_b(b),
	.video_vblank(vblank),
	.video_hblank(hblank),
	.video_hs(hs),
	.video_vs(vs),
	.video_ce(ce_pix_old),
	.tv15Khz_mode(~status[13]),
	//.separate_audio(1'b1),
	.separate_audio(status[7]),
	.audio_out_l(audio_l),
	.audio_out_r(audio_r),
	.coin1(m_coin),
	.coin2(m_coin2),	

	.start2(m_start2),
	.start1(m_start1),

	.p1_left(m_left), 
	.p1_right(m_right),
	.p1_up(m_up),
	.p1_down(m_down),
	.p1_fire1(m_fire),
	.p1_fire2(m_fire2),

	.p2_left(m_left_2),
	.p2_right(m_right_2),
	.p2_up(m_up_2),
	.p2_down(m_down_2),
	.p2_fire1(m_fire_2),
	.p2_fire2(m_fire_22),
	
	.upright(status[12]),
	.coin_meters(1),	
	//.demo_sound(status[8]),
	.service(status[6]),
	.cpu_rom_addr ( rom_addr ),
	.cpu_rom_do   ( rom_addr[0] ? rom_do[15:8] : rom_do[7:0] ),
	.snd_rom_addr ( snd_addr ),
	.snd_rom_do   ( snd_addr[0] ? snd_do[15:8] : snd_do[7:0] ),
	.sp_addr      ( sp_addr ),
	.sp_graphx32_do ( sp_do ),
	.dl_addr      ( dl_addr    ),
	.dl_wr        ( ioctl_wr   ),
	.dl_data      ( ioctl_dout )
);





endmodule
