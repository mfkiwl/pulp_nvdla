import nvdla_package::*;
import hwpe_ctrl_package::*;

module nvdla_top
#(
    parameter int unsigned N_CORES = 2,
    parameter int unsigned MP  = 3,
    parameter int unsigned ID  = 10
)
(
    // global signals
    input  logic                                  clk_i,
    input  logic                                  core_clk_i,
    input  logic                                  csb_clk_i,
    input  logic                                  rst_ni,
    input  logic                                  test_mode_i,
    // events
    output logic [N_CORES-1:0][REGFILE_N_EVT-1:0] evt_o,
    // tcdm master ports
    hwpe_stream_intf_tcdm.master                  tcdm[MP-1:0],
    // periph slave port
    hwpe_ctrl_intf_periph.slave                   periph
);

    logic enable, clear;
    ctrl_streamer_t  streamer_ctrl;
    flags_streamer_t streamer_flags;
    ctrl_engine_t    engine_ctrl;
    flags_engine_t   engine_flags;

    hwpe_stream_intf_stream #(
        .DATA_WIDTH(32)
    ) dbb_i (
        .clk ( clk_i )
    );
    hwpe_stream_intf_stream #(
        .DATA_WIDTH(32)
    ) dbb_o (
        .clk ( clk_i )
    );
    hwpe_stream_intf_stream #(
        .DATA_WIDTH(32)
    ) csb (
        .clk ( clk_i )
    );

    nvdla_engine i_engine (
        .clk_i            ( clk_i          ),
        .core_clk_i       ( core_clk_i     ),
        .csb_clk_i        ( csb_clk_i      ),
        .rst_ni           ( rst_ni         ),
        .test_mode_i      ( test_mode_i    ),
        .dbb_i            ( dbb_i.sink     ),
        .dbb_o            ( dbb_o.source   ),
        .csb_o            ( csb.source     ),
        .ctrl_streamer_o  ( streamer_ctrl  ),
        .flags_streamer_i ( streamer_flags ),
        .ctrl_i           ( engine_ctrl    ),
        .flags_o          ( engine_flags   )
    );

    nvdla_streamer #(
        .MP ( MP )
    ) i_streamer (
        .clk_i            ( clk_i          ),
        .rst_ni           ( rst_ni         ),
        .test_mode_i      ( test_mode_i    ),
        .enable_i         ( enable         ),
        .clear_i          ( clear          ),
        .dbb_o            ( dbb_i.source   ),
        .dbb_i            ( dbb_o.sink     ),
        .csb_i            ( csb.sink       ),
        .tcdm             ( tcdm           ),
        .ctrl_i           ( streamer_ctrl  ),
        .flags_o          ( streamer_flags )
    );

    nvdla_ctrl #(
        .N_CORES   ( 2  ),
        .N_CONTEXT ( 2  ),
        .N_IO_REGS ( 8 ),
        .ID ( ID )
    ) i_ctrl (
        .clk_i            ( clk_i          ),
        .rst_ni           ( rst_ni         ),
        .test_mode_i      ( test_mode_i    ),
        .evt_o            ( evt_o          ),
        .clear_o          ( clear          ),
        .ctrl_streamer_o  ( streamer_ctrl  ),
        .flags_streamer_i ( streamer_flags ),
        .ctrl_engine_o    ( engine_ctrl    ),
        .flags_engine_i   ( engine_flags   ),
        .periph           ( periph         )
    );

    assign enable = 1'b1;

endmodule // nvdla_top
