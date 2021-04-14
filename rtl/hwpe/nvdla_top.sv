import nvdla_package::*;
import hwpe_ctrl_package::*;

module nvdla_top
#(
    parameter int unsigned N_CORES = 2,
    parameter int unsigned MP  = 5,
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
    ctrl_csb_streamer_t  streamer_csb_ctrl;
    flags_csb_streamer_t streamer_csb_flags;
    ctrl_dbb_streamer_t  streamer_dbb_ctrl;
    flags_dbb_streamer_t streamer_dbb_flags;
    ctrl_engine_t    engine_ctrl;
    flags_engine_t   engine_flags;

    hwpe_stream_intf_stream #(
        .DATA_WIDTH ( 32 )
        // .DATA_WIDTH ( `NVDLA_PRIMARY_MEMIF_WIDTH )
    ) dbb_i (
        .clk ( clk_i )
    );
    hwpe_stream_intf_stream #(
        .DATA_WIDTH ( 32 )
        // .DATA_WIDTH ( `NVDLA_PRIMARY_MEMIF_WIDTH )
    ) dbb_o (
        .clk ( clk_i )
    );
    hwpe_stream_intf_stream #(
        .DATA_WIDTH ( 32 )
    ) csb_i (
        .clk ( clk_i )
    );
    hwpe_stream_intf_stream #(
        .DATA_WIDTH ( 32 )
    ) csb_o (
        .clk ( clk_i )
    );

    nvdla_engine i_engine (
        .clk_i            ( clk_i              ),
        .core_clk_i       ( core_clk_i         ),
        .csb_clk_i        ( csb_clk_i          ),
        .rst_ni           ( rst_ni             ),
        .test_mode_i      ( test_mode_i        ),
        .dbb_i            ( dbb_i.sink         ),
        .dbb_o            ( dbb_o.source       ),
        .csb_i            ( csb_i.sink         ),
        .csb_o            ( csb_o.source       ),
        .ctrl_streamer_o  ( streamer_dbb_ctrl  ),
        .flags_streamer_i ( streamer_dbb_flags ),
        .ctrl_i           ( engine_ctrl        ),
        .flags_o          ( engine_flags       )
    );

    nvdla_streamer #(
        .MP ( MP )
    ) i_streamer (
        .clk_i            ( clk_i              ),
        .rst_ni           ( rst_ni             ),
        .test_mode_i      ( test_mode_i        ),
        .enable_i         ( enable             ),
        .clear_i          ( clear              ),
        .dbb_o            ( dbb_i.source       ),
        .dbb_i            ( dbb_o.sink         ),
        .csb_o            ( csb_i.source       ),
        .csb_i            ( csb_o.sink         ),
        .tcdm             ( tcdm               ),
        .ctrl_csb_i       ( streamer_csb_ctrl  ),
        .flags_csb_o      ( streamer_csb_flags ),
        .ctrl_dbb_i       ( streamer_dbb_ctrl  ),
        .flags_dbb_o      ( streamer_dbb_flags )
    );

    nvdla_ctrl #(
        .N_CORES   ( 2  ),
        .N_CONTEXT ( 2  ),
        .N_IO_REGS ( 8 ),
        .ID ( ID )
    ) i_ctrl (
        .clk_i            ( clk_i              ),
        .rst_ni           ( rst_ni             ),
        .test_mode_i      ( test_mode_i        ),
        .evt_o            ( evt_o              ),
        .clear_o          ( clear              ),
        .ctrl_streamer_o  ( streamer_csb_ctrl  ),
        .flags_streamer_i ( streamer_csb_flags ),
        .ctrl_engine_o    ( engine_ctrl        ),
        .flags_engine_i   ( engine_flags       ),
        .periph           ( periph             )
    );

    assign enable = 1'b1;

endmodule // nvdla_top
